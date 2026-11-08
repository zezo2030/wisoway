import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/models/ride_payment.dart';

void main() {
  Map<String, dynamic> json(Map<String, dynamic> extra) => {
    'bookingId': 'b-1',
    'tripId': 't-1',
    'passengerId': 'p-1',
    'amount': '0.00',
    'currency': 'SAR',
    'method': 'cash',
    'status': 'paid',
    ...extra,
  };

  test('a booking nobody rode on is not a fare received in cash', () {
    final payment = RidePayment.fromJson(json({'rode': false}));
    expect(payment.rode, isFalse);
    expect(payment.isPaid, isTrue);
  });

  test('a ridden booking reads as ridden', () {
    expect(RidePayment.fromJson(json({'rode': true})).rode, isTrue);
  });

  test('an older server that does not say counts as ridden', () {
    expect(RidePayment.fromJson(json({})).rode, isTrue);
  });
}
