import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/marketplace_repository.dart';

/// Approximate ZIP-area map — pins are jittered around centroids, never exact addresses.
class MarketplaceApproxMap extends StatelessWidget {
  const MarketplaceApproxMap({
    super.key,
    required this.requests,
    this.onPinTap,
  });

  final List<MarketplaceRequestModel> requests;
  final ValueChanged<MarketplaceRequestModel>? onPinTap;

  @override
  Widget build(BuildContext context) {
    final pins = requests
        .where((r) => r.mapPinLat != null && r.mapPinLng != null)
        .toList();
    if (pins.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
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
        child: CustomPaint(
          painter: _ApproxMapPainter(
            pins: pins,
            colorScheme: Theme.of(context).colorScheme,
          ),
          child: Stack(
            children: [
              Positioned(
                left: 12,
                top: 12,
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
              ...pins.asMap().entries.map((entry) {
                final pin = entry.value;
                final offset = _pinOffset(pin, pins);
                return Positioned(
                  left: offset.dx,
                  top: offset.dy,
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
            ],
          ),
        ),
      ),
    );
  }

  Offset _pinOffset(
    MarketplaceRequestModel pin,
    List<MarketplaceRequestModel> all,
  ) {
    const padding = 48.0;
    const size = 280.0;
    final lats = all.map((p) => p.mapPinLat!).toList();
    final lngs = all.map((p) => p.mapPinLng!).toList();
    final minLat = lats.reduce(math.min);
    final maxLat = lats.reduce(math.max);
    final minLng = lngs.reduce(math.min);
    final maxLng = lngs.reduce(math.max);
    final latSpan = (maxLat - minLat).abs() < 0.001 ? 0.01 : maxLat - minLat;
    final lngSpan = (maxLng - minLng).abs() < 0.001 ? 0.01 : maxLng - minLng;
    final x =
        padding + ((pin.mapPinLng! - minLng) / lngSpan) * (size - padding * 2);
    final y =
        padding + ((maxLat - pin.mapPinLat!) / latSpan) * (size - padding * 2);
    return Offset(x.clamp(padding, size), y.clamp(padding, size));
  }
}

class _ApproxMapPainter extends CustomPainter {
  _ApproxMapPainter({required this.pins, required this.colorScheme});

  final List<MarketplaceRequestModel> pins;
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
  bool shouldRepaint(covariant _ApproxMapPainter oldDelegate) =>
      oldDelegate.pins != pins;
}
