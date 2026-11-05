import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/core/firebase/fire.dart';

void main() {
  test('a failing write of any type is reported, not thrown', () async {
    final reported = <Object>[];
    final previous = reportError;
    reportError = (e, _) => reported.add(e);
    addTearDown(() => reportError = previous);

    Object? uncaught;
    await runZonedGuarded(() async {
      // A Future<String> passed as Future<void>, like repo.add(...).
      final Future<void> write = Future<String>.error(StateError('offline'));
      fire(write);
      await Future<void>.delayed(Duration.zero);
    }, (e, _) => uncaught = e);

    expect(uncaught, isNull);
    expect(reported.single, isA<StateError>());
  });
}
