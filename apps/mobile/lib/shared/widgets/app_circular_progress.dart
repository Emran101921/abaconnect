import 'package:flutter/material.dart';

/// Animated circular progress ring with centered label.
class AppCircularProgress extends StatelessWidget {
  const AppCircularProgress({
    super.key,
    required this.value,
    this.size = 56,
    this.strokeWidth = 6,
    this.label,
    this.color,
    this.trackColor,
  });

  final double value;
  final double size;
  final double strokeWidth;
  final String? label;
  final Color? color;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progressColor = color ?? scheme.primary;
    final track = trackColor ?? scheme.outlineVariant.withValues(alpha: 0.35);
    final clamped = value.clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: clamped),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, animated, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: animated,
                  strokeWidth: strokeWidth,
                  backgroundColor: track,
                  color: progressColor,
                  strokeCap: StrokeCap.round,
                ),
              ),
              if (label != null)
                Text(
                  label!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: size < 48 ? 10 : 11,
                      ),
                ),
            ],
          );
        },
      ),
    );
  }
}
