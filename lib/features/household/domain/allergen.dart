/// The 14 allergens that must be declared in the EU (incl. Austria).
enum Allergen {
  gluten,
  crustaceans,
  eggs,
  fish,
  peanuts,
  soy,
  milk,
  nuts,
  celery,
  mustard,
  sesame,
  sulphites,
  lupin,
  molluscs;

  static Set<Allergen> parseAll(Iterable<String> names) => {
    for (final n in names)
      for (final a in Allergen.values)
        if (a.name == n) a,
  };
}

/// A household member with their allergies and intolerances.
class HouseholdMember {
  const HouseholdMember({
    required this.uid,
    required this.displayName,
    this.allergens = const {},
  });

  factory HouseholdMember.fromMap(String uid, Map<String, dynamic> m) =>
      HouseholdMember(
        uid: uid,
        displayName: (m['displayName'] as String?) ?? '',
        allergens: Allergen.parseAll(
          ((m['allergens'] as List<dynamic>?) ?? const []).whereType<String>(),
        ),
      );

  final String uid;
  final String displayName;
  final Set<Allergen> allergens;
}
