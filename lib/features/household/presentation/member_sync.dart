import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/firebase/fire.dart';

/// Makes sure the signed-in user has a members/{uid} entry (name for
/// allergy warnings) and backfills new seed data (allergens) once, also
/// for households created before these existed.
class MemberSync extends ConsumerStatefulWidget {
  const MemberSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MemberSync> createState() => _MemberSyncState();
}

class _MemberSyncState extends ConsumerState<MemberSync> {
  @override
  void initState() {
    super.initState();
    _sync();
  }

  void _sync() {
    final user = ref.read(authUserProvider).value;
    if (user != null) {
      fire(ref.read(memberRepositoryProvider).ensure(user.uid, user.bestName));
    }
    final hid = ref.read(householdIdProvider);
    if (hid != null) {
      fire(() async {
        final seed = await ref.read(seedIngredientsProvider.future);
        await ref.read(householdRepositoryProvider).backfillSeed(hid, seed);
      }());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Switching households: the new one needs the member entry too.
    ref.listen(householdIdProvider, (prev, next) {
      if (next != null && next != prev) _sync();
    });
    return widget.child;
  }
}
