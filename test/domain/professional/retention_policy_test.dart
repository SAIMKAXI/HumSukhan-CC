import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/domain/professional/retention_policy.dart';

void main() {
  final DateTime created = DateTime(2026, 3, 1, 9);

  test('retention is clamped to the 15-day product maximum', () {
    expect(RetentionPolicy(90).days, RetentionPolicy.maximumDays);
    expect(RetentionPolicy(0).days, RetentionPolicy.minimumDays);
    expect(RetentionPolicy(7).days, 7);
  });

  test('every offered choice is within the supported range', () {
    for (final int choice in RetentionPolicy.choices) {
      expect(RetentionPolicy(choice).days, choice);
    }
  });

  test('the countdown counts down', () {
    final RetentionPolicy policy = RetentionPolicy(7);
    expect(policy.daysRemaining(created, created), 7);
    expect(
      policy.daysRemaining(created, created.add(const Duration(days: 5))),
      2,
    );
  });

  test('the countdown never runs backwards past zero', () {
    final RetentionPolicy policy = RetentionPolicy(3);
    expect(
      policy.daysRemaining(created, created.add(const Duration(days: 30))),
      0,
    );
  });

  test('expiry is exact', () {
    final RetentionPolicy policy = RetentionPolicy(3);
    expect(
      policy.hasExpired(created, created.add(const Duration(days: 3))),
      isTrue,
    );
    expect(
      policy.hasExpired(
        created,
        created
            .add(const Duration(days: 3))
            .subtract(const Duration(minutes: 1)),
      ),
      isFalse,
    );
  });
}
