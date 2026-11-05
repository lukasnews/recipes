import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/map_utils.dart';
import 'shared_recipe.dart';

/// Long random token for a shopping list link (not typed by hand).
String newListToken([Random? random]) {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  final r = random ?? Random.secure();
  return List.generate(22, (_) => chars[r.nextInt(chars.length)]).join();
}

/// The household's shopping list, shared live by link: whoever has it can
/// see the list in the browser and tick items (sharedLists/{token}).
class SharedList {
  const SharedList({
    required this.token,
    required this.householdId,
    required this.createdBy,
    required this.title,
    this.createdAt,
    this.expiresAt,
  });

  factory SharedList.create({
    required String householdId,
    required String uid,
    required String title,
    ShareValidity validity = ShareValidity.week,
    DateTime? now,
    String? token,
  }) {
    final at = now ?? DateTime.now();
    return SharedList(
      token: token ?? newListToken(),
      householdId: householdId,
      createdBy: uid,
      title: title,
      createdAt: at,
      expiresAt: validity.duration == null ? null : at.add(validity.duration!),
    );
  }

  factory SharedList.fromMap(String token, Map<String, dynamic> m) =>
      SharedList(
        token: token,
        householdId: m.str('householdId'),
        createdBy: m.str('createdBy'),
        title: m.str('title'),
        createdAt: m.date('createdAt'),
        expiresAt: m.date('expiresAt'),
      );

  final String token;
  final String householdId;
  final String createdBy;
  final String title;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  bool isExpired(DateTime now) => expiresAt != null && expiresAt!.isBefore(now);

  Map<String, dynamic> toMap() => {
    'householdId': householdId,
    'createdBy': createdBy,
    'title': title,
    'createdAt': createdAt == null
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(createdAt!),
    'expiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt!),
  };
}
