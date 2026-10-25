import 'package:flutter_test/flutter_test.dart';
import 'package:cidan/main.dart';
import 'package:cidan/core/constants/app_strings.dart';

void main() {
  testWidgets('CIDAN App loads login screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CidanApp());
    await tester.pumpAndSettle();

    // Verify that login screen elements are present
    expect(find.text(AppStrings.loginTitle), findsOneWidget);
    expect(find.text(AppStrings.sendOtpCode), findsOneWidget);
  });
}
