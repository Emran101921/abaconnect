import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Continue button disabled until checkbox is checked', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: _CheckboxHarness()),
      ),
    );

    final continueButton = find.widgetWithText(FilledButton, 'Continue');
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    expect(tester.widget<FilledButton>(continueButton).onPressed, isNotNull);
  });
}

/// Minimal harness mirroring acknowledgment gate UX without API calls.
class _CheckboxHarness extends StatefulWidget {
  const _CheckboxHarness();

  @override
  State<_CheckboxHarness> createState() => _CheckboxHarnessState();
}

class _CheckboxHarnessState extends State<_CheckboxHarness> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          CheckboxListTile(
            value: _checked,
            onChanged: (v) => setState(() => _checked = v ?? false),
            title: const Text(
              'I acknowledge receipt of the Notice of Privacy Practices.',
            ),
          ),
          FilledButton(
            onPressed: _checked ? () {} : null,
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
