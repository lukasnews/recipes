import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';

import '../../helpers/fakes.dart';

void main() {
  testWidgets('introduction shows once and is remembered', (tester) async {
    final db = FakeFirebaseFirestore();
    await seedHousehold(db);
    await db.collection('users').doc('u1').update({'onboardingDone': false});
    await tester.pumpWidget(
      testApp(db: db, auth: FakeAuthRepository(const AuthUser(uid: 'u1'))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rezepte sammeln'), findsOneWidget);
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    expect(find.text('Vorrat und Einkauf'), findsOneWidget);
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Los geht's"));
    await tester.pumpAndSettle();

    expect(find.text('Was kann ich kochen?'), findsNothing);
    final user = (await db.collection('users').doc('u1').get()).data()!;
    expect(user['onboardingDone'], isTrue);
  });
}
