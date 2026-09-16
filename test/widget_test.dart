import 'package:fintrust/main.dart';
import 'package:fintrust/services/fintrust_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FINTRUST signs in and shows the home dashboard', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(FintrustApp(backend: DemoFintrustBackend()));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('login_email')),
      'demo@fintrust.app',
    );
    await tester.enterText(
      find.byKey(const Key('login_password')),
      'Fintrust#2026',
    );
    await tester.enterText(find.byKey(const Key('login_otp')), '123456');
    await tester.ensureVisible(find.byKey(const Key('login_button')));
    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle();

    expect(find.text('Total Balance'), findsOneWidget);
    expect(find.text('Scan'), findsWidgets);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('FINTRUST deposits and sends money from the dashboard', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(FintrustApp(backend: DemoFintrustBackend()));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login_email')),
      'demo@fintrust.app',
    );
    await tester.enterText(
      find.byKey(const Key('login_password')),
      'Fintrust#2026',
    );
    await tester.enterText(find.byKey(const Key('login_otp')), '123456');
    await tester.ensureVisible(find.byKey(const Key('login_button')));
    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Deposit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '100');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email transaction OTP'),
      '123456',
    );
    await tester.tap(find.text('Deposit now'));
    await tester.pumpAndSettle();
    expect(find.text(r'$18,520.75'), findsOneWidget);
    expect(find.text('MYR 18,520.75'), findsOneWidget);

    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Recipient A/C No.'),
      'FT-TEST-123456',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '50');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email transaction OTP'),
      '123456',
    );
    await tester.tap(find.text('Send money'));
    await tester.pumpAndSettle();
    expect(find.text(r'$18,470.75'), findsOneWidget);
    expect(find.text('MYR 18,470.75'), findsOneWidget);
  });
}
