import 'package:flutter_test/flutter_test.dart';
import 'package:cidan/cidan.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CIDAN Package Export & Entry Point Tests', () {
    test('1. cidan.application() returns CidanApp widget', () {
      final widget = cidan.application();
      expect(widget, isA<CidanApp>());
      final app = widget as CidanApp;
      expect(app.standalone, isTrue);
      expect(app.isLoggedIn, isFalse);
    });

    test('2. Cidan.application() returns CidanApp widget with parameters', () {
      final widget = Cidan.application(
        userEmail: 'auditor@bank.com',
        isLoggedIn: true,
        standalone: false,
      );
      expect(widget, isA<CidanApp>());
      final app = widget as CidanApp;
      expect(app.userEmail, equals('auditor@bank.com'));
      expect(app.isLoggedIn, isTrue);
      expect(app.standalone, isFalse);
    });

    testWidgets('3. cidan.application() renders LoginScreen in widget tree',
        (WidgetTester tester) async {
      await tester.pumpWidget(cidan.application());
      await tester.pumpAndSettle();

      expect(find.byType(CidanApp), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('4. cidan.application(isLoggedIn: true) renders UploadDocumentScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        cidan.application(
          isLoggedIn: true,
          userEmail: 'auditor@bank.com',
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(UploadDocumentScreen), findsOneWidget);
    });
  });
}
