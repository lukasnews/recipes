import 'package:share_plus/share_plus.dart';

/// Opens the system share sheet. Behind an interface so tests can fake it.
abstract interface class Sharer {
  Future<void> shareText(String text, {String? subject});

  Future<void> shareFile(String path, {String? mimeType, String? subject});
}

class SystemSharer implements Sharer {
  const SystemSharer();

  @override
  Future<void> shareText(String text, {String? subject}) =>
      SharePlus.instance.share(ShareParams(text: text, subject: subject));

  @override
  Future<void> shareFile(String path, {String? mimeType, String? subject}) =>
      SharePlus.instance.share(
        ShareParams(
          files: [XFile(path, mimeType: mimeType)],
          subject: subject,
        ),
      );
}
