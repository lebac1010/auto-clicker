import 'package:flutter_test/flutter_test.dart';

import 'package:auto_clicker/main.dart';

void main() {
  testWidgets('App shows splash on first frame', (WidgetTester tester) async {
    await tester.pumpWidget(const AutoClickerApp());

    expect(find.text('TapMacro'), findsOneWidget);
  });
}
