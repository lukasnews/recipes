import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/household/data/household_repository.dart';
import 'package:recipes/features/settings/data/account_deletion.dart';

import '../../helpers/fakes.dart';

Future<(String, String)> _twoHouseholds(FakeFirebaseFirestore db) async {
  final alone = await seedHousehold(db);
  final repo = HouseholdRepository(db);
  final shared = await repo.createHousehold(
    uid: 'u1',
    name: 'WG',
    seed: testSeed,
  );
  await repo.ensureUser('u2', 'Anna');
  final code =
      (await db.collection('households').doc(shared).get())
              .data()!['inviteCode']
          as String;
  await repo.joinHousehold(uid: 'u2', code: code);
  final a = db.collection('households').doc(alone);
  await a.collection('recipes').doc('r1').set({
    'title': 'Schmarrn',
    'photoPaths': ['households/$alone/recipes/r1/1.jpg'],
  });
  await a.collection('members').doc('u1').set({'displayName': 'Lukas'});
  final s = db.collection('households').doc(shared);
  await s.collection('recipes').doc('r2').set({'title': 'Gulasch'});
  await s.collection('members').doc('u1').set({'displayName': 'Lukas'});
  return (alone, shared);
}

void main() {
  test('deletes own household, leaves shared one, removes user', () async {
    final db = FakeFirebaseFirestore();
    final (alone, shared) = await _twoHouseholds(db);
    final aloneCode =
        (await db.collection('households').doc(alone).get())
                .data()!['inviteCode']
            as String;
    final deletedPhotos = <String>[];
    await db.collection('sharedRecipes').doc('K7MQX4PA').set({
      'title': 'Schmarrn',
      'createdBy': 'u1',
      'photoPath': 'shared/u1/K7MQX4PA.jpg',
    });
    await db.collection('sharedRecipes').doc('OTHER234').set({
      'title': 'Gulasch',
      'createdBy': 'u2',
    });

    await AccountDeletionService(
      db,
      (paths) async => deletedPhotos.addAll(paths),
    ).deleteData('u1');

    final a = db.collection('households').doc(alone);
    expect((await a.get()).exists, isFalse);
    expect((await a.collection('recipes').get()).docs, isEmpty);
    expect((await a.collection('ingredients').get()).docs, isEmpty);
    expect(
      (await db.collection('invites').doc(aloneCode).get()).exists,
      isFalse,
    );
    expect(deletedPhotos, [
      'households/$alone/recipes/r1/1.jpg',
      'shared/u1/K7MQX4PA.jpg',
    ]);
    expect(
      (await db.collection('sharedRecipes').doc('K7MQX4PA').get()).exists,
      isFalse,
    );
    expect(
      (await db.collection('sharedRecipes').doc('OTHER234').get()).exists,
      isTrue,
    );

    final s = db.collection('households').doc(shared);
    expect((await s.get()).data()!['memberIds'], ['u2']);
    expect((await s.collection('recipes').doc('r2').get()).exists, isTrue);
    expect((await s.collection('members').doc('u1').get()).exists, isFalse);

    expect((await db.collection('users').doc('u1').get()).exists, isFalse);
    expect((await db.collection('users').doc('u2').get()).exists, isTrue);
  });

  testWidgets('delete account from the settings', (tester) async {
    tester.view
      ..physicalSize = const Size(800, 3000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    final auth = FakeAuthRepository(const AuthUser(uid: 'u1'))
      ..usesPassword = true;
    await tester.pumpWidget(testApp(db: db, auth: auth));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Profil und Einstellungen'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Konto löschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Endgültig löschen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'geheim');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(auth.reauthPassword, 'geheim');
    expect(auth.deleted, isTrue);
    expect((await db.collection('households').doc(hid).get()).exists, isFalse);
    expect(find.text('Anmelden'), findsWidgets);
  });
}
