import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/core/services/payment_service.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/models/wallet_account_model.dart';
import 'package:rideshare/screens/wallet/wallet_topup_request_screen.dart';

class _FakePayments extends PaymentService {
  @override
  Future<WalletAccountModel> getWalletAccountMe() async => WalletAccountModel(
    accountType: 'driver',
    currency: 'JOD',
    balance: 1990.8,
    isActive: true,
    minimumTopup: 5,
  );
}

void main() {
  testWidgets('states the minimum top-up before any attempt', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WalletTopupRequestScreen(
          preferCliq: true,
          paymentService: _FakePayments(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('الحد الأدنى للشحن: 5.00 JOD'), findsOneWidget);
  });
}
