import 'package:flutter/material.dart';

import 'app_bottom_nav.dart';
import 'app_scaffold.dart';

/// Parent main-tab shell — keeps bottom quick navigation on nested flows.
class ParentTabScaffold extends StatelessWidget {
  const ParentTabScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions,
    this.floatingActionButton,
    this.currentTab = CoreNavTab.home,
    this.showBackButton,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final CoreNavTab currentTab;
  final bool? showBackButton;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: title,
      subtitle: subtitle,
      actions: actions,
      floatingActionButton: floatingActionButton,
      showBackButton: showBackButton,
      bottomNavigationBar: RoleBottomNav(current: currentTab),
      body: body,
    );
  }
}

/// Therapist main-tab shell — keeps bottom quick navigation on nested flows.
class TherapistTabScaffold extends StatelessWidget {
  const TherapistTabScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions,
    this.floatingActionButton,
    this.currentTab = CoreNavTab.home,
    this.showBackButton,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final CoreNavTab currentTab;
  final bool? showBackButton;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: title,
      subtitle: subtitle,
      actions: actions,
      floatingActionButton: floatingActionButton,
      showBackButton: showBackButton,
      bottomNavigationBar: RoleBottomNav(current: currentTab),
      body: body,
    );
  }
}
