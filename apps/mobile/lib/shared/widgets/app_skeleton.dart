import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Lightweight loading placeholder for cards and list rows.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  const AppSkeleton.box({
    super.key,
    required double size,
    BorderRadius? borderRadius,
  })  : width = size,
        height = size,
        borderRadius = borderRadius;

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final base = colorScheme.surfaceContainerHighest;
    final highlight = colorScheme.surfaceContainerLow;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius:
                widget.borderRadius ?? BorderRadius.circular(AppSpacing.radiusSm),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                base,
                Color.lerp(base, highlight, _controller.value)!,
                base,
              ],
            ),
          ),
        );
      },
    );
  }
}

class AppSkeletonCard extends StatelessWidget {
  const AppSkeletonCard({super.key, this.lines = 3});

  final int lines;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppSkeleton(width: 120, height: 20),
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < lines; i++) ...[
              AppSkeleton(
                width: i == lines - 1 ? 180 : double.infinity,
                height: 14,
              ),
              if (i < lines - 1) const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}
