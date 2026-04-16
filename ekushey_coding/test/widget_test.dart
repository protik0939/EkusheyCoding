import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ekushey_coding/src/app.dart';

void main() {
  testWidgets('App boots and shows navigation', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const EkusheyCodingApp());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Tutorials'), findsWidgets);
    expect(find.text('Exercises'), findsWidgets);
  });
}
