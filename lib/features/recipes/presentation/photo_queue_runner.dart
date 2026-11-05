import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';

/// Starts the photo upload queue and retries it whenever the app returns
/// to the foreground.
class PhotoQueueRunner extends ConsumerStatefulWidget {
  const PhotoQueueRunner({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PhotoQueueRunner> createState() => _PhotoQueueRunnerState();
}

class _PhotoQueueRunnerState extends ConsumerState<PhotoQueueRunner> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Reading the provider loads the stored queue and starts it.
    ref
      ..read(photoUploadQueueProvider)
      ..read(importQueueProvider);
    _lifecycle = AppLifecycleListener(
      onResume: () {
        unawaited(ref.read(photoUploadQueueProvider.notifier).process());
        unawaited(ref.read(importQueueProvider.notifier).process());
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the queue alive for the whole session.
    ref
      ..watch(photoUploadQueueProvider)
      ..watch(importQueueProvider);
    return widget.child;
  }
}
