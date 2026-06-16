import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/constants/maps_constants.dart';
import '../data/marketplace_repository.dart';

/// Approximate ZIP-area map — pins use jittered centroids, never exact addresses.
class MarketplaceApproxMap extends StatefulWidget {
  const MarketplaceApproxMap({
    super.key,
    required this.requests,
    this.onPinTap,
    this.emptyMessage,
  });

  final List<MarketplaceRequestModel> requests;
  final ValueChanged<MarketplaceRequestModel>? onPinTap;
  final String? emptyMessage;

  @override
  State<MarketplaceApproxMap> createState() => _MarketplaceApproxMapState();
}

class _MarketplaceApproxMapState extends State<MarketplaceApproxMap> {
  GoogleMapController? _mapController;
  bool _googleMapsFailed = false;

  List<MarketplaceRequestModel> get _pins => widget.requests
      .where((r) => r.mapPinLat != null && r.mapPinLng != null)
      .toList();

  bool get _showGoogleMap => !_googleMapsFailed;

  bool get _showMapsSetupHint =>
      _googleMapsFailed || (kIsWeb && !MapsConstants.isConfigured);

  void _handleGoogleMapsFailed() {
    if (!mounted || _googleMapsFailed) return;
    setState(() => _googleMapsFailed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_pins.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            widget.emptyMessage ??
                'No map pins in this area yet. Search by ZIP to find anonymous requests.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 1.1,
        child: _showGoogleMap
            ? _GoogleMarketplaceMap(
                pins: _pins,
                onPinTap: widget.onPinTap,
                onMapCreated: (controller) => _mapController = controller,
                onLoadFailed: _handleGoogleMapsFailed,
              )
            : _FallbackApproxMap(
                pins: _pins,
                onPinTap: widget.onPinTap,
                showSetupHint: _showMapsSetupHint,
                mapsLoadFailed: _googleMapsFailed,
              ),
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

class _GoogleMarketplaceMap extends StatefulWidget {
  const _GoogleMarketplaceMap({
    required this.pins,
    required this.onPinTap,
    required this.onMapCreated,
    required this.onLoadFailed,
  });

  final List<MarketplaceRequestModel> pins;
  final ValueChanged<MarketplaceRequestModel>? onPinTap;
  final ValueChanged<GoogleMapController> onMapCreated;
  final VoidCallback onLoadFailed;

  @override
  State<_GoogleMarketplaceMap> createState() => _GoogleMarketplaceMapState();
}

class _GoogleMarketplaceMapState extends State<_GoogleMarketplaceMap> {
  static const _loadTimeout = Duration(seconds: 8);

  Timer? _loadTimer;
  var _mapReady = false;

  @override
  void initState() {
    super.initState();
    _loadTimer = Timer(_loadTimeout, () {
      if (!_mapReady && mounted) {
        widget.onLoadFailed();
      }
    });
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    super.dispose();
  }

  void _markReady() {
    if (_mapReady) return;
    _mapReady = true;
    _loadTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bounds = _boundsForPins(widget.pins);
    final markers = widget.pins.map((pin) {
      return Marker(
        markerId: MarkerId(pin.id),
        position: LatLng(pin.mapPinLat!, pin.mapPinLng!),
        infoWindow: InfoWindow(
          title: pin.anonymousPublicId,
          snippet: pin.serviceAreaLabel,
        ),
        onTap: () => widget.onPinTap?.call(pin),
      );
    }).toSet();

    final circles = widget.pins.map((pin) {
      return Circle(
        circleId: CircleId('area-${pin.id}'),
        center: LatLng(pin.mapPinLat!, pin.mapPinLng!),
        radius: 1609,
        fillColor: colorScheme.primary.withValues(alpha: 0.12),
        strokeColor: colorScheme.primary.withValues(alpha: 0.45),
        strokeWidth: 1,
      );
    }).toSet();

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: bounds.center,
            zoom: _zoomForBounds(bounds),
          ),
          markers: markers,
          circles: circles,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: !kIsWeb,
          mapToolbarEnabled: false,
          onMapCreated: (controller) async {
            _markReady();
            widget.onMapCreated(controller);
            try {
              if (widget.pins.length > 1) {
                await controller.animateCamera(
                  CameraUpdate.newLatLngBounds(bounds.latLngBounds, 48),
                );
              }
            } catch (_) {
              if (mounted) widget.onLoadFailed();
            }
          },
        ),
        Positioned(
          left: 12,
          top: 12,
          right: 12,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                'Approximate ZIP areas only — not exact addresses',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MapBounds {
  const _MapBounds({
    required this.center,
    required this.latLngBounds,
  });

  final LatLng center;
  final LatLngBounds latLngBounds;
}

_MapBounds _boundsForPins(List<MarketplaceRequestModel> pins) {
  final lats = pins.map((p) => p.mapPinLat!).toList();
  final lngs = pins.map((p) => p.mapPinLng!).toList();
  final minLat = lats.reduce(math.min);
  final maxLat = lats.reduce(math.max);
  final minLng = lngs.reduce(math.min);
  final maxLng = lngs.reduce(math.max);

  final center = LatLng(
    (minLat + maxLat) / 2,
    (minLng + maxLng) / 2,
  );

  return _MapBounds(
    center: center,
    latLngBounds: LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    ),
  );
}

double _zoomForBounds(_MapBounds bounds) {
  final latSpan =
      (bounds.latLngBounds.northeast.latitude -
              bounds.latLngBounds.southwest.latitude)
          .abs();
  final lngSpan =
      (bounds.latLngBounds.northeast.longitude -
              bounds.latLngBounds.southwest.longitude)
          .abs();
  final span = math.max(latSpan, lngSpan);
  if (span < 0.02) return 13;
  if (span < 0.08) return 11;
  if (span < 0.3) return 9;
  return 7;
}

/// Grid fallback when Google Maps is unavailable (e.g. web without API key).
class _FallbackApproxMap extends StatelessWidget {
  const _FallbackApproxMap({
    required this.pins,
    required this.onPinTap,
    this.showSetupHint = false,
    this.mapsLoadFailed = false,
  });

  final List<MarketplaceRequestModel> pins;
  final ValueChanged<MarketplaceRequestModel>? onPinTap;
  final bool showSetupHint;
  final bool mapsLoadFailed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mapSize = Size(constraints.maxWidth, constraints.maxHeight);
        return CustomPaint(
          size: mapSize,
          painter: _ApproxMapPainter(
            colorScheme: Theme.of(context).colorScheme,
          ),
          child: Stack(
            children: [
              Positioned(
                left: 12,
                top: 12,
                right: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surface
                        .withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      'Approximate ZIP areas only',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              ...pins.map((pin) {
                final offset = _pinOffset(pin, pins, mapSize);
                return Positioned(
                  left: offset.dx - 14,
                  top: offset.dy - 14,
                  child: GestureDetector(
                    onTap: () => onPinTap?.call(pin),
                    child: Tooltip(
                      message: pin.anonymousPublicId,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.35),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.location_on,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              if (showSetupHint)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: _MapsSetupBanner(failed: mapsLoadFailed),
                ),
            ],
          ),
        );
      },
    );
  }

  Offset _pinOffset(
    MarketplaceRequestModel pin,
    List<MarketplaceRequestModel> all,
    Size size,
  ) {
    const padding = 40.0;
    final lats = all.map((p) => p.mapPinLat!).toList();
    final lngs = all.map((p) => p.mapPinLng!).toList();
    final minLat = lats.reduce(math.min);
    final maxLat = lats.reduce(math.max);
    final minLng = lngs.reduce(math.min);
    final maxLng = lngs.reduce(math.max);
    final latSpan = (maxLat - minLat).abs() < 0.001 ? 0.01 : maxLat - minLat;
    final lngSpan = (maxLng - minLng).abs() < 0.001 ? 0.01 : maxLng - minLng;
    final x = padding +
        ((pin.mapPinLng! - minLng) / lngSpan) * (size.width - padding * 2);
    final y = padding +
        ((maxLat - pin.mapPinLat!) / latSpan) * (size.height - padding * 2);
    return Offset(
      x.clamp(padding, size.width - padding),
      y.clamp(padding, size.height - padding),
    );
  }
}

class _ApproxMapPainter extends CustomPainter {
  _ApproxMapPainter({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = colorScheme.outlineVariant.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      final y = size.height * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  @override
  bool shouldRepaint(covariant _ApproxMapPainter oldDelegate) => false;
}

class _MapsSetupBanner extends StatelessWidget {
  const _MapsSetupBanner({this.failed = false});

  final bool failed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.map_outlined,
              size: 20,
              color: colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enable Google Maps tiles',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    failed
                        ? 'Google Maps could not load — showing approximate pin layout instead. Check Google Cloud Console:'
                        : 'If the map is blank or shows a JavaScript error, check Google Cloud Console:',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Enable Maps JavaScript API (web) and Maps SDK for iOS\n'
                    '• Turn on billing for the project\n'
                    '• Web referrers: http://localhost:8080/*\n'
                    '• iOS bundle ID: com.abaconnect.mobile\n'
                    '• Re-run: bash scripts/setup-google-maps.sh',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
