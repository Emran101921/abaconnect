import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';

/// Blocks screenshots and screen recording on clinical PHI screens.
class SecureClinicalScope extends StatefulWidget {
  const SecureClinicalScope({super.key, required this.child});

  final Widget child;

  @override
  State<SecureClinicalScope> createState() => _SecureClinicalScopeState();
}

class _SecureClinicalScopeState extends State<SecureClinicalScope> {
  @override
  void initState() {
    super.initState();
    ScreenProtector.preventScreenshotOn();
  }

  @override
  void dispose() {
    ScreenProtector.preventScreenshotOff();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
