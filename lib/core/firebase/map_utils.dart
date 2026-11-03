import 'package:cloud_firestore/cloud_firestore.dart';

/// Helpers for reading loosely typed Firestore maps.
extension MapRead on Map<String, dynamic> {
  String str(String key, [String fallback = '']) =>
      (this[key] as String?) ?? fallback;

  String? strOrNull(String key) => this[key] as String?;

  double? dbl(String key) => (this[key] as num?)?.toDouble();

  int? integer(String key) => (this[key] as num?)?.toInt();

  bool flag(String key) => (this[key] as bool?) ?? false;

  List<String> strings(String key) =>
      ((this[key] as List<dynamic>?) ?? const []).whereType<String>().toList();

  List<Map<String, dynamic>> maps(String key) =>
      ((this[key] as List<dynamic>?) ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => m.cast<String, dynamic>())
          .toList();

  DateTime? date(String key) {
    final v = this[key];
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
