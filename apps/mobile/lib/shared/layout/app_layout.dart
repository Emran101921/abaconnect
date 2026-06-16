import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/app_spacing.dart';
import 'app_breadcrumbs.dart';
import 'app_page_header.dart';
import 'app_top_header.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_web_sidebar.dart';

export '../widgets/app_web_sidebar.dart' show AppShellRole, AppWebSidebar;

/// Primary authenticated layout — sidebar (desktop), bottom nav (mobile), header.
///
/// Major layout change: screens keep passing [body] and optional [bottomNavigationBar];
/// this component chooses sidebar vs bottom navigation based on viewport width.
class AppLayout extends ConsumerWidget {
  const AppLayout({
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
    final width = MediaQuery.sizeOf(context).width;
    final useWideLayout = width >= AppSpacing.breakpointWide;
    final location = GoRouterState.of(context).matchedLocation;
    final userRole = ref.watch(authStateProvider).valueOrNull?.user.role;
    final shellRole = inferAppShellRole(location: location, userRole: userRole);

    if (useWideLayout) {
      return _buildWideLayout(context, shellRole, location);
    }
    return _buildMobileLayout(context);
  }

  Widget _buildWideLayout(
    BuildContext context,
    AppShellRole? shellRole,
    String location,
  ) {
    final pageBody = _wrapBody(context, wide: true);

    if (shellRole != null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: floatingActionButton,
        body: AppPageBackground(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppWebSidebar(role: shellRole, location: location),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTopHeader(
                      title: title,
                      subtitle: subtitle,
                      actions: actions,
                      showBackButton: showBackButton,
                      shellRole: shellRole,
                    ),
                    if (header != null && !extendBodyBehindHeader) header!,
                    Expanded(child: pageBody),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading:
            showBackButton ?? Navigator.of(context).canPop(),
        title: Text(title),
        actions: actions,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: floatingActionButton,
      body: AppPageBackground(child: pageBody),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final colorScheme = Theme.of(context).colorScheme;
    final pageBody = _wrapBody(context, wide: false);

    if (header != null) {
      return Scaffold(
        extendBodyBehindAppBar: extendBodyBehindHeader,
        appBar: AppBar(
          automaticallyImplyLeading: showBackButton != null
              ? showBackButton!
              : canPop,
          title: _mobileTitle(context),
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
            Expanded(child: pageBody),
          ],
        ),
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: bottomNavigationBar,
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: showBackButton != null
            ? showBackButton!
            : canPop,
        title: _mobileTitle(context),
        actions: actions,
        surfaceTintColor: Colors.transparent,
      ),
      body: AppPageBackground(child: pageBody),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }

  Widget _mobileTitle(BuildContext context) {
    if (subtitle == null) return Text(title);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title),
        Text(
          subtitle!,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _wrapBody(BuildContext context, {required bool wide}) {
    final child = showPageBreadcrumbs && wide
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  0,
                ),
                child: AppBreadcrumbs(),
              ),
              Expanded(child: body),
            ],
          )
        : body;

    if (!wide || !constrainBodyOnWide) {
      return child;
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Mobile bottom navigation wrapper — re-exports existing role tab bars.
class MobileBottomNav {
  MobileBottomNav._();

  static Widget parent(ParentNavTab current) =>
      ParentBottomNav(current: current);

  static Widget therapist(TherapistNavTab current) =>
      TherapistBottomNav(current: current);
}
