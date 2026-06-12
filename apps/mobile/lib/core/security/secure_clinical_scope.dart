import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';

/// Blocks screenshots and screen recording on clinical PHI screens.
///
/// Screenshot protection is disabled in debug builds because the iOS
/// implementation overlays a secure layer that makes the UI look blurry
/// in the simulator and during local development.
class SecureClinicalScope extends StatefulWidget {
  const SecureClinicalScope({super.key, required this.child});

  final Widget child;

  @override
  State<SecureClinicalScope> createState() => _SecureClinicalScopeState();
}

class _SecureClinicalScopeState extends State<SecureClinicalScope> {
  static bool get _enableScreenProtection => kReleaseMode;

  @override
  void initState() {
    super.initState();
    if (_enableScreenProtection) {
      ScreenProtector.preventScreenshotOn();
    }
  }

  @override
  void dispose() {
    if (_enableScreenProtection) {
      ScreenProtector.preventScreenshotOff();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
