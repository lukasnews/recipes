import 'dart:async';

import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../domain/web_recipe.dart';

/// Links shared into the app ("Teilen" → BaCo) from a browser or other app.
abstract class SharedLinkSource {
  Stream<Uri> links();
}

class ReceiveSharingIntentLinks implements SharedLinkSource {
  @override
  Stream<Uri> links() {
    final intent = ReceiveSharingIntent.instance;
    final controller = StreamController<Uri>();
    void emit(List<SharedMediaFile> files) {
      for (final f in files) {
        if (f.type != SharedMediaType.text && f.type != SharedMediaType.url) {
          continue;
        }
        final url = findUrl('${f.path} ${f.message ?? ''}');
        if (url != null) controller.add(url);
      }
    }

    // Shared while the app was closed.
    unawaited(
      intent.getInitialMedia().then((files) {
        emit(files);
        return intent.reset();
      }),
    );
    // Shared while the app was running.
    final sub = intent.getMediaStream().listen(emit);
    controller.onCancel = () async {
      await sub.cancel();
      await controller.close();
    };
    return controller.stream;
  }
}
