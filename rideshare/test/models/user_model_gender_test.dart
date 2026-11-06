import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/models/user_model.dart';

void main() {
  test('a saved gender counts as chosen', () {
    final user = UserModel.fromJson({'gender': 'female'});

    expect(user.gender, 'female');
    expect(user.hasChosenGender, isTrue);
  });

  test('a missing gender keeps the fallback but is not chosen', () {
    final user = UserModel.fromJson({'gender': null});

    expect(user.gender, 'male');
    expect(user.hasChosenGender, isFalse);
  });

  test('the cached copy does not turn the fallback into a choice', () {
    final cached = UserModel.fromJson(UserModel.fromJson({}).toJson());

    expect(cached.hasChosenGender, isFalse);
  });

  test('copying keeps the state, and setting a gender chooses it', () {
    final user = UserModel.fromJson({});

    expect(user.copyWith(name: 'Sara').hasChosenGender, isFalse);
    expect(user.copyWith(gender: 'female').hasChosenGender, isTrue);
  });
}
