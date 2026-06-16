import 'package:flutter/material.dart';

import 'app_bottom_nav.dart';
import 'app_scaffold.dart';
import '../layout/app_layout.dart';

/// Parent main-tab shell — keeps bottom quick navigation on nested flows.
class ParentTabScaffold extends StatelessWidget {
  const ParentTabScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions,
    this.floatingActionButton,
    this.currentTab = ParentNavTab.home,
    this.showBackButton,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final ParentNavTab currentTab;
  final bool? showBackButton;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: title,
      subtitle: subtitle,
      actions: actions,
      floatingActionButton: floatingActionButton,
      showBackButton: showBackButton,
      bottomNavigationBar: MobileBottomNav.parent(currentTab),
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
    this.currentTab = TherapistNavTab.home,
    this.showBackButton,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final TherapistNavTab currentTab;
  final bool? showBackButton;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: title,
      subtitle: subtitle,
      actions: actions,
      floatingActionButton: floatingActionButton,
      showBackButton: showBackButton,
      bottomNavigationBar: MobileBottomNav.therapist(currentTab),
      body: body,
    );
  }
}
