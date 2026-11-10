import 'package:flutter/widgets.dart';

import '../../features/household/domain/allergen.dart';
import '../../features/ingredients/domain/ingredient.dart';
import '../../features/pantry/domain/pantry_item.dart';
import '../../features/recipes/domain/recipe.dart';
import '../../features/sharing/domain/shared_recipe.dart';
import '../../l10n/app_localizations.dart';
import '../units/units.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

extension LabelL10n on AppLocalizations {
  String shareValidity(ShareValidity v) => switch (v) {
    ShareValidity.never => shareValidityNever,
    ShareValidity.week => shareValidityWeek,
    ShareValidity.month => shareValidityMonth,
    ShareValidity.year => shareValidityYear,
  };

  String aisle(Aisle a) => switch (a) {
    Aisle.produce => aisleProduce,
    Aisle.bread => aisleBread,
    Aisle.dairy => aisleDairy,
    Aisle.meat => aisleMeat,
    Aisle.baking => aisleBaking,
    Aisle.dry => aisleDry,
    Aisle.spices => aisleSpices,
    Aisle.frozen => aisleFrozen,
    Aisle.drinks => aisleDrinks,
    Aisle.other => aisleOther,
  };

  String location(StorageLocation l) => switch (l) {
    StorageLocation.fridge => locationFridge,
    StorageLocation.pantry => locationPantry,
    StorageLocation.freezer => locationFreezer,
  };

  String baseUnit(BaseUnit u) => switch (u) {
    BaseUnit.g => baseUnitG,
    BaseUnit.ml => baseUnitMl,
    BaseUnit.pcs => baseUnitPcs,
  };

  String category(String c) => switch (c) {
    RecipeCategories.cooking => categoryCooking,
    RecipeCategories.cake => categoryCake,
    RecipeCategories.cookies => categoryCookies,
    RecipeCategories.drinks => categoryDrinks,
    _ => c,
  };

  /// "Getränke · heiß" for drinks with a temperature, else the category.
  String recipeCategory(Recipe r) => switch (r.drinkTemp) {
    _ when r.category != RecipeCategories.drinks => category(r.category),
    DrinkTemp.hot => '${category(r.category)} · $drinkHot',
    DrinkTemp.cold => '${category(r.category)} · $drinkCold',
    _ => category(r.category),
  };

  String allergen(Allergen a) => switch (a) {
    Allergen.gluten => allergenGluten,
    Allergen.crustaceans => allergenCrustaceans,
    Allergen.eggs => allergenEggs,
    Allergen.fish => allergenFish,
    Allergen.peanuts => allergenPeanuts,
    Allergen.soy => allergenSoy,
    Allergen.milk => allergenMilk,
    Allergen.nuts => allergenNuts,
    Allergen.celery => allergenCelery,
    Allergen.mustard => allergenMustard,
    Allergen.sesame => allergenSesame,
    Allergen.sulphites => allergenSulphites,
    Allergen.lupin => allergenLupin,
    Allergen.molluscs => allergenMolluscs,
  };

  String allergenList(Iterable<Allergen> list) =>
      (list.toList()..sort((a, b) => a.index - b.index))
          .map(allergen)
          .join(', ');

  /// "Zuletzt vor 3 Wochen gekocht".
  String lastCooked(int days) {
    if (days <= 0) return lastCookedToday;
    if (days < 14) return lastCookedDays(days);
    if (days < 60) return lastCookedWeeks(days ~/ 7);
    return lastCookedMonths(days ~/ 30);
  }
}
