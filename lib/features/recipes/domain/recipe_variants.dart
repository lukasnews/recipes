import 'recipe.dart';

/// Id of the original a recipe belongs to (itself if it is one, or if its
/// original is gone).
String variantRootId(Recipe r, Map<String, Recipe> byId) =>
    r.variantOf != null && byId.containsKey(r.variantOf) ? r.variantOf! : r.id;

/// Original first, then its variants by name. Just [r] without variants.
List<Recipe> variantFamily(Recipe r, Iterable<Recipe> all) {
  final byId = {for (final x in all) x.id: x};
  final root = byId[variantRootId(r, byId)]!;
  final variants = [
    for (final x in all)
      if (x.variantOf == root.id && x.id != root.id) x,
  ]..sort((a, b) => a.variantLabel.compareTo(b.variantLabel));
  return [root, ...variants];
}

/// Number of variants per original id.
Map<String, int> variantCounts(Iterable<Recipe> all) {
  final ids = {for (final r in all) r.id};
  final counts = <String, int>{};
  for (final r in all) {
    final root = r.variantOf;
    if (root != null && root != r.id && ids.contains(root)) {
      counts[root] = (counts[root] ?? 0) + 1;
    }
  }
  return counts;
}

/// Hides variants whose original is in [shown] too: the list shows one
/// tile per family, unless only a variant matches the filters.
List<T> collapseVariants<T>(List<T> shown, Recipe Function(T) recipeOf) {
  final ids = {for (final s in shown) recipeOf(s).id};
  return [
    for (final s in shown)
      if (!ids.contains(recipeOf(s).variantOf) ||
          recipeOf(s).variantOf == recipeOf(s).id)
        s,
  ];
}

/// When an original with variants is deleted, the first variant becomes
/// the new original and the others point to it: id -> new variantOf
/// (null = is the original now).
Map<String, String?> promoteOnDelete(Recipe deleted, Iterable<Recipe> all) {
  if (deleted.variantOf != null) return const {};
  final variants = [
    for (final x in all)
      if (x.variantOf == deleted.id && x.id != deleted.id) x,
  ]..sort((a, b) => a.variantLabel.compareTo(b.variantLabel));
  if (variants.isEmpty) return const {};
  final newRoot = variants.first.id;
  return {newRoot: null, for (final v in variants.skip(1)) v.id: newRoot};
}
