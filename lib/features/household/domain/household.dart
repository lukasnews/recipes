import '../../../core/firebase/map_utils.dart';

class Household {
  const Household({
    required this.id,
    required this.name,
    required this.memberIds,
    required this.inviteCode,
  });

  factory Household.fromMap(String id, Map<String, dynamic> m) => Household(
    id: id,
    name: m.str('name'),
    memberIds: m.strings('memberIds'),
    inviteCode: m.str('inviteCode'),
  );

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
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> m) => AppUser(
    uid: uid,
    displayName: m.str('displayName'),
    householdIds: m.strings('householdIds'),
    unitDisplay: m.strOrNull('unitDisplay'),
    activeHouseholdId: m.strOrNull('activeHouseholdId'),
  );

  final String uid;
  final String displayName;
  final List<String> householdIds;

  /// Per-person preference, see UnitDisplay.
  final String? unitDisplay;

  /// Household picked in the settings; falls back to the first one.
  final String? activeHouseholdId;

  String? get currentHouseholdId => householdIds.contains(activeHouseholdId)
      ? activeHouseholdId
      : (householdIds.isEmpty ? null : householdIds.first);
}
