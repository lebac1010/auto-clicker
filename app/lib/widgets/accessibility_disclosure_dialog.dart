import 'package:flutter/material.dart';

class AccessibilityDisclosureDialog {
  const AccessibilityDisclosureDialog._();

  static Future<bool> confirm(BuildContext context) async {
    final accepted =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Accessibility Disclosure'),
            content: const Text(
              'TapMacro uses Accessibility Service only to:\n'
              '- perform touch gestures that you configure in scripts\n'
              '- read click events while recording\n\n'
              'The app does not use Accessibility to read personal text, passwords, or payment data.\n\n'
              'Do you agree to open Accessibility Settings now?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('I Agree'),
              ),
            ],
          ),
        ) ??
        false;
    return accepted;
  }
}
