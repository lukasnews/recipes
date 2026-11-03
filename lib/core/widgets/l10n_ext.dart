import 'package:flutter/widgets.dart';

import '../../features/household/domain/allergen.dart';
import '../../features/ingredients/domain/ingredient.dart';
import '../../features/pantry/domain/pantry_item.dart';
import '../../features/recipes/domain/recipe.dart';
import '../../l10n/app_localizations.dart';
import '../units/units.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

extension LabelL10n on AppLocalizations {
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
    _ => c,
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
}
