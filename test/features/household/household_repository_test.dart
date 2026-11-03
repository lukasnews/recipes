import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/household/data/household_repository.dart';

import '../../helpers/fakes.dart';

void main() {
  test('create household copies seed and links user', () async {
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    final h = (await db.collection('households').doc(hid).get()).data()!;
    expect(h['memberIds'], ['u1']);
    expect((h['inviteCode'] as String).length, 6);
    final ings = await db.collection('households/$hid/ingredients').get();
    expect(
      ings.docs.map((d) => d.id),
      containsAll(['mehl-glatt', 'schlagobers']),
    );
    final invite = await db
        .collection('invites')
        .doc(h['inviteCode'] as String)
        .get();
    expect(invite.data()!['householdId'], hid);
    final user = (await db.collection('users').doc('u1').get()).data()!;
    expect(user['householdIds'], [hid]);
  });

  test('join by invite code adds member', () async {
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    final code =
        (await db.collection('households').doc(hid).get()).data()!['inviteCode']
            as String;
    final repo = HouseholdRepository(db);
    await repo.ensureUser('u2', 'Anna');
    final joined = await repo.joinHousehold(
      uid: 'u2',
      code: code.toLowerCase(),
    );
    expect(joined, hid);
    final h = (await db.collection('households').doc(hid).get()).data()!;
    expect(h['memberIds'], ['u1', 'u2']);
    final user = (await db.collection('users').doc('u2').get()).data()!;
    expect(user['householdIds'], [hid]);
  });

  test('unknown code throws', () async {
    final repo = HouseholdRepository(FakeFirebaseFirestore());
    expect(
      () => repo.joinHousehold(uid: 'u2', code: 'NOPE42'),
      throwsA(isA<InviteNotFoundException>()),
    );
  });
}
