import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/core/services/payment_service.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/models/payment_model.dart';
import 'package:rideshare/models/wallet_account_model.dart';
import 'package:rideshare/screens/wallet/cliq_topup_waiting_screen.dart';

PaymentModel _payment(PaymentStatus status, {String? note}) => PaymentModel(
  id: 'pay-1',
  userId: 'u-1',
  paymentType: 'wallet_topup',
  amount: 5,
  currency: 'JOD',
  method: PaymentMethod.cliq_a2a,
  status: status,
  adminNote: note,
  createdAt: DateTime(2026, 11, 4),
  updatedAt: DateTime(2026, 11, 4),
);

/// The gateway's view of the payment, changed by each test.
class _FakePayments extends PaymentService {
  PaymentModel current = _payment(PaymentStatus.pending);
  bool offline = false;
  int checks = 0;

  @override
  Future<PaymentModel> refreshCliqPaymentStatus(String paymentId) async {
    checks++;
    if (offline) throw TimeoutException('offline');
    return current;
  }

  @override
  Future<WalletAccountModel> getWalletAccountMe() async => WalletAccountModel(
    accountType: 'rider',
    currency: 'JOD',
    balance: 25.5,
    isActive: true,
  );
}

void main() {
  late _FakePayments payments;
  late DateTime clock;
  Object? popped;
  var didPop = false;

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              popped = await Navigator.push<CliqTopupOutcome>(
                context,
                MaterialPageRoute(
                  builder: (_) => CliqTopupWaitingScreen(
                    payment: _payment(PaymentStatus.pending),
                    account: 'MKBANAT00',
                    paymentService: payments,
                    now: () => clock,
                  ),
                ),
              );
              didPop = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> wait(WidgetTester tester, Duration time) async {
    clock = clock.add(time);
    await tester.pump(time);
    await tester.pump();
  }

  /// Drops the screen so its ticker does not outlive the test.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  setUp(() {
    payments = _FakePayments();
    clock = DateTime(2026, 11, 4, 12);
    popped = null;
    didPop = false;
  });

  testWidgets('tells the customer to approve in the bank app', (tester) async {
    await open(tester);

    expect(find.text('Approve the request in your bank app'), findsOneWidget);
    expect(find.text('5.00 JOD'), findsOneWidget);
    expect(find.text('MKBANAT00'), findsOneWidget);
    expect(find.text('05:00'), findsOneWidget);

    await close(tester);
  });

  testWidgets('counts down and asks the server every five seconds', (
    tester,
  ) async {
    await open(tester);

    await wait(tester, const Duration(seconds: 5));

    expect(find.text('04:55'), findsOneWidget);
    expect(payments.checks, 1);

    await close(tester);
  });

  testWidgets('shows the credited amount and the new balance', (tester) async {
    await open(tester);

    payments.current = _payment(PaymentStatus.approved);
    await wait(tester, const Duration(seconds: 5));
    await tester.pump();

    expect(find.text('Wallet topped up successfully via CliQ'), findsOneWidget);
    expect(find.text('Current balance'), findsOneWidget);
    expect(find.text('25.50 JOD'), findsOneWidget);

    await tester.tap(find.text('Back to wallet'));
    await tester.pumpAndSettle();

    expect(popped, CliqTopupOutcome.credited);
  });

  testWidgets('a refusal shows the reason and offers a retry', (tester) async {
    await open(tester);

    payments.current = _payment(PaymentStatus.rejected, note: 'Refused');
    await wait(tester, const Duration(seconds: 5));

    expect(find.text('Refused'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(popped, CliqTopupOutcome.retry);
  });

  testWidgets('a lost connection does not end the wait', (tester) async {
    await open(tester);

    payments.offline = true;
    await wait(tester, const Duration(seconds: 5));

    expect(find.text('Connection failed. Trying again...'), findsOneWidget);
    expect(find.text('Approve the request in your bank app'), findsOneWidget);

    await close(tester);
  });

  testWidgets('checking on request says when nothing has arrived yet', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(find.text('I approved it, check now'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('No confirmation yet. We keep following the request.'),
      findsOneWidget,
    );

    await close(tester);
  });

  testWidgets('a late approval is still caught after the time runs out', (
    tester,
  ) async {
    await open(tester);

    await wait(tester, CliqTopupWaitingScreen.approvalWindow);

    expect(find.text('No confirmation yet'), findsOneWidget);
    expect(find.textContaining('added automatically'), findsOneWidget);

    payments.current = _payment(PaymentStatus.approved);
    await tester.tap(find.text('Check now'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Current balance'), findsOneWidget);

    await close(tester);
  });

  testWidgets('leaving while waiting cancels nothing on the form', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(didPop, isTrue);
    expect(popped, isNull);
  });

  testWidgets('fits a small phone in Arabic', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CliqTopupWaitingScreen(
          payment: _payment(PaymentStatus.pending),
          account: '00962788533075',
          paymentService: payments,
          now: () => clock,
        ),
      ),
    );

    expect(tester.takeException(), isNull);

    await close(tester);
  });
}
