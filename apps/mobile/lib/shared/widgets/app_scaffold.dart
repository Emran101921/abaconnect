import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../layout/app_layout.dart';

/// Backward-compatible scaffold — delegates to [AppLayout] for responsive shell.
class AppScaffold extends ConsumerWidget {
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
    this.constrainBodyOnWide = true,
    this.showPageBreadcrumbs = false,
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
  final bool constrainBodyOnWide;
  final bool showPageBreadcrumbs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppLayout(
      title: title,
      subtitle: subtitle,
      body: body,
      actions: actions,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      showBackButton: showBackButton,
      header: header,
      extendBodyBehindHeader: extendBodyBehindHeader,
      constrainBodyOnWide: constrainBodyOnWide,
      showPageBreadcrumbs: showPageBreadcrumbs,
    );
  }
}

/// Max content width for web dashboards — keeps layouts readable on wide screens.
class AppContentContainer extends StatelessWidget {
  const AppContentContainer({
    super.key,
    required this.child,
    this.maxWidth = 1200,
    this.padding = const EdgeInsets.all(16),
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
