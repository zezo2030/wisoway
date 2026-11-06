import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/core/services/payment_service.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/models/wallet_account_model.dart';
import 'package:rideshare/screens/wallet/wallet_topup_request_screen.dart';

class _FakePayments extends PaymentService {
  _FakePayments({this.currency = 'JOD'});

  final String currency;

  @override
  Future<WalletAccountModel> getWalletAccountMe() async => WalletAccountModel(
    accountType: 'driver',
    currency: currency,
    balance: 1990.8,
    isActive: true,
    minimumTopup: 5,
  );
}

Future<void> _open(WidgetTester tester, {String currency = 'JOD'}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: WalletTopupRequestScreen(
        paymentService: _FakePayments(currency: currency),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('states the minimum top-up before any attempt', (tester) async {
    await _open(tester);

    expect(find.text('الحد الأدنى للشحن: 5.00 JOD'), findsOneWidget);
  });

  testWidgets('a dinar wallet opens on CliQ', (tester) async {
    await _open(tester);

    expect(find.text('الدفع عبر CliQ'), findsOneWidget);
  });

  testWidgets('the manual tab names the CliQ account to transfer to', (
    tester,
  ) async {
    await _open(tester);

    await tester.tap(find.text('تحويل يدوي'));
    await tester.pumpAndSettle();

    expect(find.textContaining('ALROYA26'), findsOneWidget);
  });

  testWidgets('a wallet CliQ cannot fund stays on manual, without the alias', (
    tester,
  ) async {
    await _open(tester, currency: 'SAR');

    expect(find.text('إرسال طلب الشحن'), findsOneWidget);
    expect(find.textContaining('ALROYA26'), findsNothing);
  });
}
