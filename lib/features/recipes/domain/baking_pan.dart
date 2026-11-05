import 'dart:math';

/// Baking tin a cake recipe is written for: round (diameter) or
/// rectangular (width × length), in cm. Converting to another tin scales
/// the amounts by the area ratio.
class BakingPan {
  const BakingPan.round(double this.diameter) : width = null, length = null;
  const BakingPan.rect(double this.width, double this.length) : diameter = null;

  static BakingPan? fromMap(Object? m) {
    if (m is! Map) return null;
    num? n(String k) => m[k] is num ? m[k] as num : null;
    final d = n('d');
    if (d != null && d > 0) return BakingPan.round(d.toDouble());
    final w = n('w');
    final l = n('l');
    if (w != null && l != null && w > 0 && l > 0) {
      return BakingPan.rect(w.toDouble(), l.toDouble());
    }
    return null;
  }

  final double? diameter;
  final double? width;
  final double? length;

  bool get isRound => diameter != null;

  double get area =>
      isRound ? pi * diameter! * diameter! / 4 : width! * length!;

  /// How much more (or less) dough [other] needs than this tin.
  double factorFor(BakingPan other) => other.area / area;

  Map<String, dynamic> toMap() =>
      isRound ? {'d': diameter} : {'w': width, 'l': length};

  @override
  bool operator ==(Object other) =>
      other is BakingPan &&
      other.diameter == diameter &&
      other.width == width &&
      other.length == length;

  @override
  int get hashCode => Object.hash(diameter, width, length);
}
