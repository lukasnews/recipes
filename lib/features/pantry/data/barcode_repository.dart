import 'package:cloud_firestore/cloud_firestore.dart';

/// Barcode the household already assigned to an ingredient.
class KnownBarcode {
  const KnownBarcode({
    required this.ingredientId,
    this.amount,
    this.unit,
    this.name,
  });

  final String ingredientId;
  final double? amount;
  final String? unit;
  final String? name;
}

/// households/{hid}/barcodes/{code}: remembered so the next scan works
/// offline and without asking.
class BarcodeRepository {
  BarcodeRepository(this._db, this._hid);

  final FirebaseFirestore _db;
  final String _hid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('households').doc(_hid).collection('barcodes');

  Future<KnownBarcode?> get(String code) async {
    final d = (await _col.doc(code).get()).data();
    final id = d?['ingredientId'] as String?;
    if (d == null || id == null) return null;
    return KnownBarcode(
      ingredientId: id,
      amount: (d['amount'] as num?)?.toDouble(),
      unit: d['unit'] as String?,
      name: d['name'] as String?,
    );
  }

  Future<void> save(String code, KnownBarcode b) => _col.doc(code).set({
    'ingredientId': b.ingredientId,
    'amount': ?b.amount,
    'unit': ?b.unit,
    'name': ?b.name,
    'updatedAt': FieldValue.serverTimestamp(),
  });
}
