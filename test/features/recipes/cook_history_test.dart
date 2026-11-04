import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/recipes/domain/cook_history.dart';

void main() {
  final log = [
    CookLogEntry(id: '1', recipeId: 'a', cookedAt: DateTime(2026, 9, 2)),
    CookLogEntry(id: '2', recipeId: 'a', cookedAt: DateTime(2026, 10, 20)),
    CookLogEntry(id: '3', recipeId: 'b', cookedAt: DateTime(2026, 6, 2)),
    CookLogEntry(
      id: '4',
      recipeId: 'b',
      cookedAt: DateTime(2026, 11, 2),
      undone: true,
    ),
  ];

  test('counts and last cooked date, undone ignored', () {
    final s = cookStats(log);
    expect(s['a']!.count, 2);
    expect(s['a']!.lastCooked, DateTime(2026, 10, 20));
    expect(s['b']!.count, 1);
    expect(s['b']!.lastCooked, DateTime(2026, 6, 2));
  });

  test('long not cooked: oldest first, never cooked last', () {
    expect(longNotCooked(['a', 'b', 'c'], cookStats(log)), ['b', 'a', 'c']);
  });

  test('daysBetween ignores time of day', () {
    expect(daysBetween(DateTime(2026, 11, 3, 23), DateTime(2026, 11, 4, 1)), 1);
  });
}
