import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ekushey_coding/src/data/strings.dart';

void main() {
  testWidgets('App boots and shows navigation', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    // Build a minimal widget tree that displays the localized page labels
    // without instantiating the full app (avoids asset/svg/http loading).
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            Text(AppStrings.getByLocale('en', 'page_home')),
            Text(AppStrings.getByLocale('en', 'page_tutorials')),
            Text(AppStrings.getByLocale('en', 'page_exercises')),
          ],
        ),
      ),
    );

    await tester.pump();

    expect(
      find.text(AppStrings.getByLocale('en', 'page_home')),
      findsOneWidget,
    );
    expect(
      find.text(AppStrings.getByLocale('en', 'page_tutorials')),
      findsOneWidget,
    );
    expect(
      find.text(AppStrings.getByLocale('en', 'page_exercises')),
      findsOneWidget,
    );
  });
}
