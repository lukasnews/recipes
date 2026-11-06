import '../../../core/firebase/map_utils.dart';
import 'baking_pan.dart';
import 'nutrition.dart';

/// Built-in categories; any other string is a custom category.
abstract final class RecipeCategories {
  static const cooking = 'cooking';
  static const cake = 'cake';
  static const cookies = 'cookies';
  static const builtIn = [cooking, cake, cookies];
}

class RecipeIngredient {
  const RecipeIngredient({
    required this.rawText,
    this.ingredientId,
    this.amount,
    this.unit,
    this.note,
    this.name,
  });

  factory RecipeIngredient.fromMap(Map<String, dynamic> m) => RecipeIngredient(
    rawText: m.str('rawText'),
    ingredientId: m.strOrNull('ingredientId'),
    amount: m.dbl('amount'),
    unit: m.strOrNull('unit'),
    note: m.strOrNull('note'),
    name: m.strOrNull('name'),
  );

  final String rawText;
  final String? ingredientId;
  final double? amount;
  final String? unit;
  final String? note;

  /// Name as written in the recipe (parsed from [rawText]).
  final String? name;

  Map<String, dynamic> toMap() => {
    'rawText': rawText,
    'ingredientId': ?ingredientId,
    'amount': ?amount,
    'unit': ?unit,
    'note': ?note,
    'name': ?name,
  };

  RecipeIngredient scaled(double factor) => RecipeIngredient(
    rawText: rawText,
    ingredientId: ingredientId,
    amount: amount == null ? null : amount! * factor,
    unit: unit,
    note: note,
    name: name,
  );

  RecipeIngredient withIngredientId(String? id) => RecipeIngredient(
    rawText: rawText,
    ingredientId: id,
    amount: amount,
    unit: unit,
    note: note,
    name: name,
  );
}

class RecipeStep {
  const RecipeStep(this.text, {this.timerSeconds});

  factory RecipeStep.fromMap(Map<String, dynamic> m) =>
      RecipeStep(m.str('text'), timerSeconds: m.integer('timerSeconds'));

  final String text;
  final int? timerSeconds;

  Map<String, dynamic> toMap() => {'text': text, 'timerSeconds': ?timerSeconds};
}

class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    this.category = RecipeCategories.cooking,
    this.tags = const [],
    this.servings = 4,
    this.prepMinutes,
    this.cookMinutes,
    this.photoPaths = const [],
    this.rating = 0,
    this.notes = '',
    this.sourceType = 'manual',
    this.sourceUrl,
    this.ingredients = const [],
    this.steps = const [],
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.nutrition,
    this.collections = const [],
    this.pan,
    this.variantOf,
    this.variantName,
  });

  factory Recipe.fromMap(String id, Map<String, dynamic> m) {
    final source =
        (m['source'] as Map<dynamic, dynamic>?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return Recipe(
      id: id,
      title: m.str('title'),
      category: m.str('category', RecipeCategories.cooking),
      tags: m.strings('tags'),
      servings: m.integer('servings') ?? 4,
      prepMinutes: m.integer('prepMinutes'),
      cookMinutes: m.integer('cookMinutes'),
      photoPaths: m.strings('photoPaths'),
      rating: m.integer('rating') ?? 0,
      notes: m.str('notes'),
      sourceType: source.str('type', 'manual'),
      sourceUrl: source.strOrNull('url'),
      ingredients: m.maps('ingredients').map(RecipeIngredient.fromMap).toList(),
      steps: m.maps('steps').map(RecipeStep.fromMap).toList(),
      createdBy: m.strOrNull('createdBy'),
      createdAt: m.date('createdAt'),
      updatedAt: m.date('updatedAt'),
      collections: m.strings('collections'),
      pan: BakingPan.fromMap(m['pan']),
      variantOf: m.strOrNull('variantOf'),
      variantName: m.strOrNull('variantName'),
      nutrition: Nutrition.fromMap(
        (m['nutrition'] as Map<dynamic, dynamic>?)?.cast<String, dynamic>(),
      ),
    );
  }

  /// Household collections ("Weihnachtsbäckerei"). Not part of [toMap]:
  /// changed only via RecipeRepository.setCollections, so saving the
  /// edited recipe keeps them (merge).
  final List<String> collections;

  /// Id of the original recipe this is a variant of ("vegan", "für 2").
  /// Always the original, never another variant.
  final String? variantOf;

  /// Short name of the variant for the switch chips ("vegan").
  final String? variantName;

  /// Chip label: the variant name, or empty for an original.
  String get variantLabel => variantName ?? '';

  /// Tin the amounts are for (cakes), to convert to another tin.
  final BakingPan? pan;

  /// AI estimate per serving. Not part of [toMap]: saving the edited
  /// recipe drops it, since the ingredients may have changed.
  final Nutrition? nutrition;

  final String id;
  final String title;
  final String category;
  final List<String> tags;
  final int servings;
  final int? prepMinutes;
  final int? cookMinutes;
  final List<String> photoPaths;
  final int rating;
  final String notes;
  final String sourceType;
  final String? sourceUrl;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int? get totalMinutes {
    if (prepMinutes == null && cookMinutes == null) return null;
    return (prepMinutes ?? 0) + (cookMinutes ?? 0);
  }

  List<String> get ingredientIds => {
    for (final i in ingredients)
      if (i.ingredientId != null) i.ingredientId!,
  }.toList();

  /// Map without timestamps; the repository adds those.
  Map<String, dynamic> toMap() => {
    'title': title,
    'category': category,
    'tags': tags,
    'servings': servings,
    'prepMinutes': prepMinutes,
    'cookMinutes': cookMinutes,
    'photoPaths': photoPaths,
    'rating': rating,
    'notes': notes,
    'source': {'type': sourceType, 'url': ?sourceUrl},
    'ingredients': ingredients.map((i) => i.toMap()).toList(),
    'ingredientIds': ingredientIds,
    'steps': steps.map((s) => s.toMap()).toList(),
    'createdBy': ?createdBy,
    // Explicit null so removing the tin in the editor clears it (merge).
    'pan': pan?.toMap(),
    'variantOf': ?variantOf,
    'variantName': ?variantName,
  };

  /// All amounts × [factor] (another baking tin), servings unchanged.
  Recipe scaledBy(double factor) => factor == 1
      ? this
      : copyWith(ingredients: [for (final i in ingredients) i.scaled(factor)]);

  Recipe copyWith({
    String? id,
    String? title,
    String? category,
    List<String>? tags,
    int? servings,
    int? Function()? prepMinutes,
    int? Function()? cookMinutes,
    int? rating,
    String? notes,
    List<RecipeIngredient>? ingredients,
    List<RecipeStep>? steps,
    String? createdBy,
    BakingPan? Function()? pan,
  }) => Recipe(
    id: id ?? this.id,
    title: title ?? this.title,
    category: category ?? this.category,
    tags: tags ?? this.tags,
    servings: servings ?? this.servings,
    prepMinutes: prepMinutes == null ? this.prepMinutes : prepMinutes(),
    cookMinutes: cookMinutes == null ? this.cookMinutes : cookMinutes(),
    photoPaths: photoPaths,
    rating: rating ?? this.rating,
    notes: notes ?? this.notes,
    sourceType: sourceType,
    sourceUrl: sourceUrl,
    ingredients: ingredients ?? this.ingredients,
    steps: steps ?? this.steps,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt,
    updatedAt: updatedAt,
    nutrition: nutrition,
    collections: collections,
    pan: pan == null ? this.pan : pan(),
    variantOf: variantOf,
    variantName: variantName,
  );
}
