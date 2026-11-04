import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/settings/data/backup_service.dart';

import '../../helpers/fakes.dart';

void main() {
  test('export -> JSON -> restore into another household', () async {
    final db = FakeFirebaseFirestore();
    final home = await seedHousehold(db);
    final h = db.collection('households').doc(home);
    await h.collection('recipes').doc('r1').set({
      'title': 'Gulasch',
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 1, 12)),
      'photoPaths': ['households/$home/recipes/r1/1.jpg'],
      'steps': [
        {'text': 'Zwiebeln rösten'},
      ],
    });
    await h.collection('pantry').doc('mehl-glatt').set({'amount': 1000});

    final json = await BackupService(db, home).export();
    final decoded = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
    final info = BackupService.inspect(decoded);
    expect(info.householdName, 'Zuhause');
    expect(info.recipes, 1);
    expect(info.counts['ingredients'], testSeed.length);

    final other = await seedHousehold(db, uid: 'u2');
    final written = BackupService(db, other).restore(decoded);
    expect(written, testSeed.length + 2);
    await Future<void>.delayed(Duration.zero);

    final o = db.collection('households').doc(other);
    final r = (await o.collection('recipes').doc('r1').get()).data()!;
    expect(r['title'], 'Gulasch');
    expect(
      (r['createdAt'] as Timestamp).toDate().toUtc(),
      DateTime.utc(2026, 10, 1, 12),
    );
    expect(r['photoPaths'], isEmpty, reason: 'foreign photos are dropped');
    expect(r['steps'], [
      {'text': 'Zwiebeln rösten'},
    ]);
    final p = (await o.collection('pantry').doc('mehl-glatt').get()).data()!;
    expect(p['amount'], 1000);
  });

  test('rejects files that are no backup', () {
    expect(
      () => BackupService.inspect({'foo': 1}),
      throwsA(isA<InvalidBackupException>()),
    );
  });
}
