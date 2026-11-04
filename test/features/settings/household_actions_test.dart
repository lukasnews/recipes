import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/core/widgets/url_opener.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/household/data/household_repository.dart';
import 'package:recipes/features/settings/data/account_deletion.dart';

import '../../helpers/fakes.dart';

Future<void> _openSettings(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Profil und Einstellungen'));
  await tester.pumpAndSettle();
}

void _bigScreen(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(800, 3200)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  test('renew invite code: old invite gone, new one points here', () async {
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    final h = db.collection('households').doc(hid);
    final old = (await h.get()).data()!['inviteCode'] as String;
    final code = await HouseholdRepository(db).renewInviteCode(hid, old);
    expect(code, isNot(old));
    expect((await h.get()).data()!['inviteCode'], code);
    expect((await db.collection('invites').doc(old).get()).exists, isFalse);
    expect(
      (await db.collection('invites').doc(code).get()).data()!['householdId'],
      hid,
    );
  });

  test('leave a shared household: data stays, user drops it', () async {
    final db = FakeFirebaseFirestore();
    final repo = HouseholdRepository(db);
    final home = await seedHousehold(db);
    final code =
        (await db.collection('households').doc(home).get())
                .data()!['inviteCode']
            as String;
    await repo.ensureUser('u2', 'Anna');
    await repo.joinHousehold(uid: 'u2', code: code);
    final service = AccountDeletionService(db, (_) async {});

    expect(await service.isLastMember('u2', home), isFalse);
    expect(await service.leaveHousehold('u2', home), isFalse);
    expect(
      (await db.collection('households').doc(home).get()).data()!['memberIds'],
      ['u1'],
    );
    final u2 = (await db.collection('users').doc('u2').get()).data()!;
    expect(u2['householdIds'], isEmpty);
    expect(u2.containsKey('activeHouseholdId'), isFalse);

    // Last member: the household goes away.
    expect(await service.isLastMember('u1', home), isTrue);
    expect(await service.leaveHousehold('u1', home), isTrue);
    expect((await db.collection('households').doc(home).get()).exists, isFalse);
  });

  testWidgets('change own name', (tester) async {
    _bigScreen(tester);
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    final auth = FakeAuthRepository(
      const AuthUser(uid: 'u1', displayName: 'Lukas'),
    );
    await tester.pumpWidget(testApp(db: db, auth: auth));
    await _openSettings(tester);

    await tester.tap(find.byTooltip('Name ändern'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Lukas B.');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(auth.currentUser!.displayName, 'Lukas B.');
    expect(
      (await db.collection('users').doc('u1').get()).data()!['displayName'],
      'Lukas B.',
    );
    final member = await db
        .collection('households')
        .doc(hid)
        .collection('members')
        .doc('u1')
        .get();
    expect(member.data()!['displayName'], 'Lukas B.');
  });

  testWidgets('privacy policy opens in the browser', (tester) async {
    _bigScreen(tester);
    final db = FakeFirebaseFirestore();
    await seedHousehold(db);
    final opener = FakeUrlOpener();
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
        urlOpener: opener,
      ),
    );
    await _openSettings(tester);
    await tester.tap(find.text('Datenschutzerklärung'));
    await tester.pump();
    expect(opener.opened, [Links.privacy]);
  });

  testWidgets('leave the only household: confirm, then setup screen', (
    tester,
  ) async {
    _bigScreen(tester);
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
      ),
    );
    await _openSettings(tester);

    await tester.tap(find.text('Haushalt verlassen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('letzte Person'), findsOneWidget);
    await tester.tap(find.text('Verlassen und löschen'));
    await tester.pumpAndSettle();

    expect((await db.collection('households').doc(hid).get()).exists, isFalse);
    expect(find.textContaining('Haushalt anlegen'), findsWidgets);
  });
}
