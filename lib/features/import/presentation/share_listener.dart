import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import 'import_actions.dart';

/// Starts a link import whenever a link is shared into the app.
class ShareListener extends ConsumerStatefulWidget {
  const ShareListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ShareListener> createState() => _ShareListenerState();
}

class _ShareListenerState extends ConsumerState<ShareListener> {
  StreamSubscription<Uri>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(sharedLinkSourceProvider).links().listen((url) {
      if (mounted) unawaited(importFromLink(context, ref, url));
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
