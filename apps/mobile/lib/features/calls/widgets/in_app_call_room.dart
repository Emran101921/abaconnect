import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/providers/app_providers.dart';
import '../call_providers.dart';
import '../data/call_models.dart';

bool _isTerminalCallStatus(CallSessionStatus status) =>
    status == CallSessionStatus.ENDED ||
    status == CallSessionStatus.CANCELLED ||
    status == CallSessionStatus.DECLINED ||
    status == CallSessionStatus.MISSED ||
    status == CallSessionStatus.FAILED;

/// In-app call surface — media stays inside the app (no external browser).
class InAppCallRoom extends ConsumerStatefulWidget {
  const InAppCallRoom({
    super.key,
    required this.session,
    required this.onEndCall,
    this.onRemoteEnded,
    this.onCancelRinging,
  });

  final CallSessionModel session;
  final Future<void> Function() onEndCall;
  final VoidCallback? onRemoteEnded;
  final Future<void> Function()? onCancelRinging;

  @override
  ConsumerState<InAppCallRoom> createState() => _InAppCallRoomState();
}

class _InAppCallRoomState extends ConsumerState<InAppCallRoom> {
  late CallSessionModel _session;
  Timer? _pollTimer;
  Timer? _durationTimer;
  Duration _elapsed = Duration.zero;
  bool _muted = false;
  bool _speaker = true;
  bool _videoEnabled = true;
  WebViewController? _webViewController;
  bool _remoteEndHandled = false;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _videoEnabled = _session.callType == CallType.VIDEO;
    _initWebViewIfNeeded();
    _startSessionPolling();
    _startDurationTimerIfActive();
  }

  @override
  void didUpdateWidget(covariant InAppCallRoom oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.id != widget.session.id ||
        oldWidget.session.status != widget.session.status) {
      _session = widget.session;
      _initWebViewIfNeeded();
      _startSessionPolling();
      _startDurationTimerIfActive();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _durationTimer?.cancel();
    super.dispose();
  }

  bool get _isCaller {
    final me = ref.read(authStateProvider).valueOrNull?.user.id;
    return me != null && me == _session.initiatedByUserId;
  }

  bool get _isRinging => _session.status == CallSessionStatus.RINGING;

  bool get _isActive =>
      _session.status == CallSessionStatus.IN_PROGRESS ||
      _session.status == CallSessionStatus.ACCEPTED;

  bool get _useVendorWebView {
    final url = _session.joinUrl;
    if (url == null || url.isEmpty) return false;
    return url.contains('daily.co') || _session.providerName == 'daily';
  }

  String get _peerLabel {
    if (_isCaller) {
      return _session.recipientName ?? 'Contact';
    }
    return _session.initiatedByName;
  }

  void _initWebViewIfNeeded() {
    if (!_useVendorWebView || !_isActive) return;
    final url = _session.joinUrl;
    if (url == null) return;
    _webViewController ??= WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..loadRequest(Uri.parse(url));
  }

  void _handleRemoteEnded() {
    if (_remoteEndHandled || !mounted) return;
    _remoteEndHandled = true;
    _pollTimer?.cancel();
    widget.onRemoteEnded?.call();
  }

  void _startSessionPolling() {
    _pollTimer?.cancel();
    if (_isTerminalCallStatus(_session.status)) return;

    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final updated = await ref
          .read(callsRepositoryProvider)
          .fetchCallSession(_session.id);
      if (!mounted || updated == null) return;

      final statusChanged = updated.status != _session.status;
      final becameActive =
          !_isActive &&
          (updated.status == CallSessionStatus.IN_PROGRESS ||
              updated.status == CallSessionStatus.ACCEPTED);

      if (statusChanged || updated.joinUrl != _session.joinUrl) {
        setState(() {
          _session = updated;
          if (becameActive) {
            _webViewController = null;
          }
          _initWebViewIfNeeded();
          _startDurationTimerIfActive();
        });
      }

      if (_isTerminalCallStatus(updated.status)) {
        _pollTimer?.cancel();
        _handleRemoteEnded();
      }
    });
  }

  void _startDurationTimerIfActive() {
    _durationTimer?.cancel();
    if (!_isActive) return;
    final started = _session.startedAt ?? DateTime.now();
    _elapsed = DateTime.now().difference(started);
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed = DateTime.now().difference(started);
      });
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:$m:$s';
    }
    return '$m:$s';
  }

  String get _statusLabel {
    if (_isRinging) {
      return _isCaller ? 'Calling…' : 'Ringing…';
    }
    if (_isActive) {
      return _session.callType == CallType.VIDEO
          ? 'Video call'
          : 'Voice call';
    }
    return _session.status.name;
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = _session.callType == CallType.VIDEO;
    final colorScheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: const Color(0xFF0F172A),
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_useVendorWebView && _isActive && _webViewController != null)
              Positioned.fill(
                child: WebViewWidget(controller: _webViewController!),
              )
            else if (_isActive && isVideo)
              Center(
                child: Icon(
                  Icons.videocam_rounded,
                  size: 120,
                  color: colorScheme.primary.withValues(alpha: 0.35),
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(
                      alpha: _useVendorWebView ? 0.45 : 0.2,
                    ),
                    Colors.black.withValues(alpha: 0.75),
                  ],
                ),
              ),
            ),
            Column(
              children: [
                const SizedBox(height: 32),
                CircleAvatar(
                  radius: 48,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    _peerLabel.isNotEmpty ? _peerLabel[0].toUpperCase() : '?',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _peerLabel,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _statusLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white70,
                      ),
                ),
                if (_isActive) ...[
                  const SizedBox(height: 6),
                  Text(
                    _formatDuration(_elapsed),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white54,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                ],
                const Spacer(),
                if (!_useVendorWebView && _isActive)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Secure in-app call — numbers are never shared.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white54,
                          ),
                    ),
                  ),
                const SizedBox(height: 16),
                _CallControlBar(
                  isRinging: _isRinging,
                  isCaller: _isCaller,
                  isVideo: isVideo,
                  muted: _muted,
                  speaker: _speaker,
                  videoEnabled: _videoEnabled,
                  onToggleMute: () => setState(() => _muted = !_muted),
                  onToggleSpeaker: () => setState(() => _speaker = !_speaker),
                  onToggleVideo: () =>
                      setState(() => _videoEnabled = !_videoEnabled),
                  onEnd: widget.onEndCall,
                  onCancel: widget.onCancelRinging,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CallControlBar extends StatelessWidget {
  const _CallControlBar({
    required this.isRinging,
    required this.isCaller,
    required this.isVideo,
    required this.muted,
    required this.speaker,
    required this.videoEnabled,
    required this.onToggleMute,
    required this.onToggleSpeaker,
    required this.onToggleVideo,
    required this.onEnd,
    this.onCancel,
  });

  final bool isRinging;
  final bool isCaller;
  final bool isVideo;
  final bool muted;
  final bool speaker;
  final bool videoEnabled;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onToggleVideo;
  final Future<void> Function() onEnd;
  final Future<void> Function()? onCancel;

  @override
  Widget build(BuildContext context) {
    if (isRinging && isCaller) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _RoundCallButton(
            icon: Icons.call_end_rounded,
            label: 'Cancel',
            color: Colors.red.shade700,
            onPressed: () => (onCancel ?? onEnd)(),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _RoundCallButton(
          icon: muted ? Icons.mic_off_rounded : Icons.mic_rounded,
          label: muted ? 'Unmute' : 'Mute',
          onPressed: onToggleMute,
        ),
        if (isVideo)
          _RoundCallButton(
            icon: videoEnabled
                ? Icons.videocam_rounded
                : Icons.videocam_off_rounded,
            label: videoEnabled ? 'Video' : 'No video',
            onPressed: onToggleVideo,
          ),
        _RoundCallButton(
          icon: speaker ? Icons.volume_up_rounded : Icons.hearing_rounded,
          label: speaker ? 'Speaker' : 'Earpiece',
          onPressed: onToggleSpeaker,
        ),
        _RoundCallButton(
          icon: Icons.call_end_rounded,
          label: 'End',
          color: Colors.red.shade700,
          onPressed: () => onEnd(),
        ),
      ],
    );
  }
}

class _RoundCallButton extends StatelessWidget {
  const _RoundCallButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? Colors.white.withValues(alpha: 0.12);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: bg,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: 56,
              height: 56,
              child: Icon(icon, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white70,
              ),
        ),
      ],
    );
  }
}
