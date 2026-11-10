import 'dart:async';

import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../domain/web_recipe.dart';

/// Something shared into the app ("Teilen" → BaCo).
sealed class SharedItem {
  const SharedItem();
}

/// A link from a browser or other app.
class SharedLink extends SharedItem {
  const SharedLink(this.url);

  final Uri url;
}

/// Text that is a recipe itself (e.g. copied from ChatGPT).
class SharedText extends SharedItem {
  const SharedText(this.text);

  final String text;
}

/// A file (e.g. a backup) shared or opened with BaCo; local path.
class SharedFile extends SharedItem {
  const SharedFile(this.path);

  final String path;
}

abstract class SharedLinkSource {
  Stream<SharedItem> items();
}

class ReceiveSharingIntentLinks implements SharedLinkSource {
  @override
  Stream<SharedItem> items() {
    final intent = ReceiveSharingIntent.instance;
    final controller = StreamController<SharedItem>();
    void emit(List<SharedMediaFile> files) {
      for (final f in files) {
        if (f.type == SharedMediaType.file) {
          controller.add(SharedFile(f.path));
          continue;
        }
        if (f.type != SharedMediaType.text && f.type != SharedMediaType.url) {
          continue;
        }
        final text = [f.path, ?f.message].join('\n').trim();
        final url = findUrl(text);
        if (isRecipeText(text)) {
          controller.add(SharedText(text));
        } else if (url != null) {
          controller.add(SharedLink(url));
        }
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
