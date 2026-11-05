import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';

import '../../helpers/fakes.dart';

void main() {
  testWidgets('share the list as live link, then stop it', (tester) async {
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    final sharer = FakeSharer();
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
        sharer: sharer,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Einkauf'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Liste teilen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Live-Link teilen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7 Tage'));
    await tester.pumpAndSettle();

    final links = await db.collection('sharedLists').get();
    expect(links.docs, hasLength(1));
    final link = links.docs.single;
    expect(link['householdId'], hid);
    expect(link['title'], 'Zuhause');
    expect(link['expiresAt'], isNotNull);
    expect(sharer.texts.single, contains('/recipes/l/?t=${link.id}'));

    await tester.tap(find.byTooltip('Liste teilen'));
    await tester.pumpAndSettle();
    expect(find.text('Aktive Links'), findsOneWidget);
    await tester.tap(find.byTooltip('Link beenden'));
    await tester.pumpAndSettle();
    expect((await db.collection('sharedLists').get()).docs, isEmpty);
  });
}
