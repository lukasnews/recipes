import '../../household/domain/allergen.dart';
import '../../ingredients/domain/ingredient.dart';
import 'recipe.dart';

/// All allergens of the recipe's linked ingredients.
Set<Allergen> recipeAllergens(Recipe recipe, Map<String, Ingredient> byId) => {
  for (final line in recipe.ingredients) ...?byId[line.ingredientId]?.allergens,
};

/// Members who can't eat the recipe, with the allergens that affect them.
List<(HouseholdMember, Set<Allergen>)> affectedMembers(
  Set<Allergen> allergens,
  List<HouseholdMember> members,
) => [
  for (final m in members)
    if (m.allergens.intersection(allergens).isNotEmpty)
      (m, m.allergens.intersection(allergens)),
];
