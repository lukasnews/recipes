import '../../../core/firebase/map_utils.dart';

class Household {
  const Household({
    required this.id,
    required this.name,
    required this.memberIds,
    required this.inviteCode,
    this.stores = defaultStores,
    this.storeLinks = const {},
    this.categoryOrder,
    this.hiddenCategories = const {},
  });

  factory Household.fromMap(String id, Map<String, dynamic> m) => Household(
    id: id,
    name: m.str('name'),
    memberIds: m.strings('memberIds'),
    inviteCode: m.str('inviteCode'),
    stores: m['stores'] is List ? m.strings('stores') : defaultStores,
    storeLinks: {
      for (final e
          in ((m['storeLinks'] as Map<dynamic, dynamic>?) ?? const {}).entries)
        if (e.value is String) '${e.key}': e.value as String,
    },
    categoryOrder: m['categoryOrder'] is List
        ? m.strings('categoryOrder')
        : null,
    hiddenCategories: m.strings('hiddenCategories').toSet(),
  );

  /// Suggested until the household changes the list.
  static const defaultStores = [
    'Hofer',
    'Billa',
    'Spar',
    'Lidl',
    'Penny',
    'dm',
  ];

  /// Shops the household buys at, in its own order.
  final List<String> stores;

  /// Own flyer links per shop (else the defaults for the big chains).
  final Map<String, String> storeLinks;

  /// Recipe categories in the household's order, incl. own ones without
  /// recipes yet; null = default order.
  final List<String>? categoryOrder;

  /// Built-in categories the household doesn't use ("Kekse").
  final Set<String> hiddenCategories;

  final String id;
  final String name;
  final List<String> memberIds;
  final String inviteCode;
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.householdIds,
    this.unitDisplay,
    this.activeHouseholdId,
    this.onboardingDone = false,
    this.aisleOrder,
    this.favoriteRecipeIds = const {},
    this.shoppingByStore = false,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> m) => AppUser(
    uid: uid,
    displayName: m.str('displayName'),
    householdIds: m.strings('householdIds'),
    unitDisplay: m.strOrNull('unitDisplay'),
    activeHouseholdId: m.strOrNull('activeHouseholdId'),
    onboardingDone: m.flag('onboardingDone'),
    aisleOrder: m['aisleOrder'] == null ? null : m.strings('aisleOrder'),
    favoriteRecipeIds: m.strings('favoriteRecipeIds').toSet(),
    shoppingByStore: m.flag('shoppingByStore'),
  );

  final String uid;
  final String displayName;
  final List<String> householdIds;

  /// Per-person preference, see UnitDisplay.
  final String? unitDisplay;

  /// Household picked in the settings; falls back to the first one.
  final String? activeHouseholdId;

  /// Saw the introduction (once per person, on any phone).
  final bool onboardingDone;

  /// Own order of the shopping list sections (aisle names); null = default.
  final List<String>? aisleOrder;

  /// This person's favourite recipes (any household).
  final Set<String> favoriteRecipeIds;

  /// Shopping list grouped by shop instead of aisle (per person).
  final bool shoppingByStore;

  String? get currentHouseholdId => householdIds.contains(activeHouseholdId)
      ? activeHouseholdId
      : (householdIds.isEmpty ? null : householdIds.first);
}
