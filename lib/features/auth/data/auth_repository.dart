import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthUser {
  const AuthUser({required this.uid, this.email, this.displayName});

  final String uid;
  final String? email;
  final String? displayName;

  String get bestName {
    final n = displayName?.trim() ?? '';
    if (n.isNotEmpty) return n;
    final e = email ?? '';
    return e.contains('@') ? e.split('@').first : e;
  }
}

abstract class AuthRepository {
  Stream<AuthUser?> authStateChanges();
  AuthUser? get currentUser;
  Future<void> signInWithGoogle();
  Future<void> signInWithEmail(String email, String password);
  Future<void> registerWithEmail(String name, String email, String password);
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();

  /// Signed in with e-mail and password (re-authentication needs it).
  bool get usesPassword;

  /// Fresh sign-in, required by Firebase before deleting the account.
  Future<void> reauthenticate({String? password});

  Future<void> deleteUser();

  Future<void> updateDisplayName(String name);
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;

  AuthUser? _map(User? u) => u == null
      ? null
      : AuthUser(uid: u.uid, email: u.email, displayName: u.displayName);

  @override
  Stream<AuthUser?> authStateChanges() => _auth.userChanges().map(_map);

  @override
  AuthUser? get currentUser => _map(_auth.currentUser);

  /// Web client id; normally read by the plugin from google-services.json
  /// (`default_web_client_id`), this define only overrides it.
  static const _webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  Future<void>? _googleInit;

  /// Native account picker (Credential Manager), no browser round trip.
  /// Returns null when the native flow isn't configured, so the caller can
  /// fall back to the browser flow.
  Future<AuthCredential?> _nativeGoogleCredential() async {
    final google = GoogleSignIn.instance;
    try {
      await (_googleInit ??= google.initialize(
        serverClientId: _webClientId.isEmpty ? null : _webClientId,
      ));
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) return null;
      return GoogleAuthProvider.credential(idToken: idToken);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        throw const GoogleSignInCancelled();
      }
      debugPrint('Native Google sign-in unavailable: ${e.code}');
      return null;
    }
  }

  GoogleAuthProvider get _browserProvider =>
      GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'});

  @override
  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      await _auth.signInWithPopup(_browserProvider);
      return;
    }
    final credential = await _nativeGoogleCredential();
    if (credential != null) {
      await _auth.signInWithCredential(credential);
    } else {
      await _auth.signInWithProvider(_browserProvider);
    }
  }

  @override
  Future<void> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  @override
  Future<void> registerWithEmail(
    String name,
    String email,
    String password,
  ) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await cred.user?.updateDisplayName(name.trim());
    await cred.user?.reload();
  }

  @override
  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  @override
  Future<void> signOut() async {
    // Next sign-in shows the account picker again.
    if (!kIsWeb && _googleInit != null) {
      await GoogleSignIn.instance.signOut().catchError((Object _) {});
    }
    await _auth.signOut();
  }

  @override
  bool get usesPassword =>
      _auth.currentUser?.providerData.any(
        (p) => p.providerId == EmailAuthProvider.PROVIDER_ID,
      ) ??
      false;

  @override
  Future<void> reauthenticate({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (usesPassword) {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: user.email ?? '',
          password: password ?? '',
        ),
      );
    } else if (kIsWeb) {
      await user.reauthenticateWithPopup(GoogleAuthProvider());
    } else {
      final credential = await _nativeGoogleCredential();
      if (credential != null) {
        await user.reauthenticateWithCredential(credential);
      } else {
        await user.reauthenticateWithProvider(GoogleAuthProvider());
      }
    }
  }

  @override
  Future<void> deleteUser() async => _auth.currentUser?.delete();

  @override
  Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.updateDisplayName(name);
    await user.reload();
  }
}

/// The person closed the Google account picker.
class GoogleSignInCancelled implements Exception {
  const GoogleSignInCancelled();
}
