import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rideshare/core/services/payment_service.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/models/payment_model.dart';
import 'package:rideshare/models/user_model.dart';
import 'package:rideshare/providers/auth_provider.dart';
import 'package:rideshare/screens/payment/payment_history_screen.dart';

PaymentModel _payment(String id, PaymentStatus status, String type) =>
    PaymentModel(
      id: id,
      userId: 'u-1',
      paymentType: type,
      amount: 5,
      currency: 'JOD',
      method: PaymentMethod.cliq_a2a,
      status: status,
      createdAt: DateTime(2026, 11, 6, 14, 56),
      updatedAt: DateTime(2026, 11, 6, 14, 56),
    );

class _FakePayments extends PaymentService {
  _FakePayments(this.payments);
  final List<PaymentModel> payments;
  int reads = 0;

  @override
  Stream<List<PaymentModel>> getPaymentHistoryStream() async* {
    reads++;
    yield payments;
  }
}

class _FakeAuth extends AuthProvider {
  @override
  UserModel? get userModel => UserModel.fromJson(const {
    'id': 'u-1',
    'name': 'Test',
    'phone': '0790000000',
    'role': 'driver',
  });
}

void main() {
  Future<void> open(WidgetTester tester, _FakePayments payments) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => _FakeAuth(),
        child: MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PaymentHistoryScreen(paymentService: payments),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('reads the paged list the API sends', () {
    final payments = PaymentService.paymentsFromResponse({
      'success': true,
      'data': {
        'data': [
          {
            'id': 'f8ab75d2',
            'userId': 'u-1',
            'amount': '5.00',
            'currency': 'JOD',
            'method': 'cliq_a2a',
            'status': 'pending',
            'paymentType': 'wallet_topup',
            'createdAt': '2026-11-06T12:56:02.000Z',
            'updatedAt': '2026-11-06T12:56:02.000Z',
          },
        ],
        'meta': {'page': 1, 'limit': 20, 'total': 1, 'totalPages': 1},
      },
    });

    expect(payments.single.id, 'f8ab75d2');
    expect(payments.single.amount, 5);
    expect(payments.single.status, PaymentStatus.pending);
  });

  testWidgets('a top-up is labelled as a wallet top-up', (tester) async {
    await open(
      tester,
      _FakePayments([_payment('p', PaymentStatus.pending, 'wallet_topup')]),
    );

    expect(find.text('شحن المحفظة'), findsOneWidget);
    expect(find.text('رسوم فتح التواصل'), findsNothing);
  });

  testWidgets('a ride fare claims no purpose', (tester) async {
    await open(
      tester,
      _FakePayments([_payment('p', PaymentStatus.approved, 'ride_fare')]),
    );

    expect(find.text('رسوم فتح التواصل'), findsNothing);
    expect(find.text('الغرض'), findsNothing);
  });

  testWidgets('tabs filter by status without loading again', (tester) async {
    final payments = _FakePayments([
      _payment('a', PaymentStatus.pending, 'wallet_topup'),
      _payment('b', PaymentStatus.approved, 'wallet_topup'),
      _payment('c', PaymentStatus.rejected, 'wallet_topup'),
    ]);
    await open(tester, payments);

    expect(find.text('شحن المحفظة'), findsNWidgets(3));

    await tester.tap(find.widgetWithText(Tab, 'مرفوض'));
    await tester.pumpAndSettle();

    expect(find.text('شحن المحفظة'), findsOneWidget);
    expect(payments.reads, 1);
  });
}
