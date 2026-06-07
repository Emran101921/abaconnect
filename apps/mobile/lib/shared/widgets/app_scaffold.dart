import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.showBackButton,
    this.header,
    this.extendBodyBehindHeader = false,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool? showBackButton;
  final Widget? header;
  final bool extendBodyBehindHeader;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final colorScheme = Theme.of(context).colorScheme;

    if (header != null) {
      return Scaffold(
        extendBodyBehindAppBar: extendBodyBehindHeader,
        appBar: AppBar(
          automaticallyImplyLeading:
              showBackButton != null ? showBackButton! : canPop,
          title: subtitle == null
              ? Text(title)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
          actions: actions,
          backgroundColor: extendBodyBehindHeader
              ? Colors.transparent
              : colorScheme.surface,
          surfaceTintColor: Colors.transparent,
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!extendBodyBehindHeader) header!,
            Expanded(child: body),
          ],
        ),
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: bottomNavigationBar,
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading:
            showBackButton != null ? showBackButton! : canPop,
        title: subtitle == null
            ? Text(title)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
        actions: actions,
        surfaceTintColor: Colors.transparent,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

/// Max content width for web dashboards — keeps layouts readable on wide screens.
class AppContentContainer extends StatelessWidget {
  const AppContentContainer({
    super.key,
    required this.child,
    this.maxWidth = 1200,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
