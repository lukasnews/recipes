import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recipes/app/app.dart';
import 'package:recipes/app/providers.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/household/data/household_repository.dart';
import 'package:recipes/features/ingredients/domain/ingredient.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository([this._user]);

  AuthUser? _user;
  final _controller = StreamController<AuthUser?>.broadcast();

  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield _user;
    yield* _controller.stream;
  }

  @override
  AuthUser? get currentUser => _user;

  void _set(AuthUser? u) {
    _user = u;
    _controller.add(u);
  }

  @override
  Future<void> signInWithEmail(String email, String password) async =>
      _set(AuthUser(uid: 'u-$email', email: email));

  @override
  Future<void> registerWithEmail(String name, String email, String pw) async =>
      _set(AuthUser(uid: 'u-$email', email: email, displayName: name));

  @override
  Future<void> signInWithGoogle() async =>
      _set(const AuthUser(uid: 'google', displayName: 'Google User'));

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async => _set(null);
}

const testSeed = [
  Ingredient(id: 'mehl-glatt', name: 'Mehl glatt', synonyms: ['Mehl']),
  Ingredient(
    id: 'schlagobers',
    name: 'Schlagobers',
    synonyms: ['Sahne'],
    aisle: Aisle.dairy,
  ),
];

/// Signed-in user with a ready household; returns the household id.
Future<String> seedHousehold(FakeFirebaseFirestore db, {String uid = 'u1'}) {
  final repo = HouseholdRepository(db);
  return repo
      .ensureUser(uid, 'Lukas')
      .then(
        (_) => repo.createHousehold(uid: uid, name: 'Zuhause', seed: testSeed),
      );
}

Widget testApp({
  required FakeFirebaseFirestore db,
  required FakeAuthRepository auth,
}) => ProviderScope(
  overrides: [
    firestoreProvider.overrideWithValue(db),
    authRepositoryProvider.overrideWithValue(auth),
    seedIngredientsProvider.overrideWith((ref) async => testSeed),
  ],
  child: const RecipesApp(),
);
