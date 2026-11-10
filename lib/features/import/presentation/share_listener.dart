import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../settings/presentation/backup_actions.dart';
import '../data/shared_links.dart';
import 'import_actions.dart';

/// Starts a link import when a link is shared into the app, or a restore
/// when a backup file is.
class ShareListener extends ConsumerStatefulWidget {
  const ShareListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ShareListener> createState() => _ShareListenerState();
}

class _ShareListenerState extends ConsumerState<ShareListener> {
  StreamSubscription<SharedItem>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(sharedLinkSourceProvider).items().listen((item) {
      if (!mounted) return;
      unawaited(switch (item) {
        SharedLink(:final url) => importFromLink(context, ref, url),
        SharedFile(:final path) => restoreBackupFile(context, ref, path),
        SharedText(:final text) => importFromText(context, ref, text),
      });
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
