import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../shared/widgets/glossy_button.dart';
import 'telehealth_join.dart';

/// In-app telehealth room — Daily media stays inside the app WebView.
class TelehealthRoomScreen extends StatefulWidget {
  const TelehealthRoomScreen({
    super.key,
    required this.joinUrl,
    this.title,
    this.vendor,
  });

  final String joinUrl;
  final String? title;
  final String? vendor;

  @override
  State<TelehealthRoomScreen> createState() => _TelehealthRoomScreenState();
}

class _TelehealthRoomScreenState extends State<TelehealthRoomScreen> {
  WebViewController? _controller;
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!isDailyTelehealthJoinUrl(widget.joinUrl, vendor: widget.vendor)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showTelehealthRoomLinkDialog(context, widget.joinUrl);
        context.pop();
      });
      return;
    }
    _initWebView();
  }

  void _initWebView() {
    final uri = Uri.tryParse(widget.joinUrl);
    if (uri == null) {
      setState(() {
        _loading = false;
        _error = 'Invalid session URL';
      });
      return;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _error = null;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _loading = false);
          },
          onWebResourceError: (details) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _error = details.description.isNotEmpty
                  ? details.description
                  : 'Could not load the video room';
            });
          },
        ),
      )
      ..loadRequest(uri);
  }

  void _retry() {
    setState(() {
      _loading = true;
      _error = null;
      _controller = null;
    });
    _initWebView();
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomTitle = widget.title?.trim();
    final displayTitle =
        roomTitle != null && roomTitle.isNotEmpty ? roomTitle : 'Telehealth';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_controller != null && _error == null)
              Positioned.fill(child: WebViewWidget(controller: _controller!)),
            if (_loading && _error == null)
              const Center(
                child: CircularProgressIndicator(color: Colors.white70),
              ),
            if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Colors.white70,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Could not load session',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      GlossyButton(
                        title: 'Retry',
                        icon: Icons.refresh_rounded,
                        variant: GlossyButtonVariant.tealBlue,
                        onPressed: _retry,
                      ),
                      const SizedBox(height: 12),
                      GlossyButton(
                        title: 'Leave session',
                        icon: Icons.close_rounded,
                        variant: GlossyButtonVariant.neutral,
                        onPressed: _leave,
                      ),
                    ],
                  ),
                ),
              ),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Leave session',
                        onPressed: _leave,
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                      ),
                      Expanded(
                        child: Text(
                          displayTitle,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (_error == null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: GlossyButton(
                      title: 'Leave session',
                      icon: Icons.logout_rounded,
                      variant: GlossyButtonVariant.redDarkRed,
                      onPressed: _leave,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
