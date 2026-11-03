import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

/// Shows a recipe photo by its Storage path, from the local cache when
/// possible. [thumbnailWidth] decodes small images for lists.
class StorageImage extends ConsumerWidget {
  const StorageImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.thumbnailWidth,
  });

  final String path;
  final BoxFit fit;
  final double? thumbnailWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(photoFileProvider(path)).value;
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.image_outlined)),
    );
    if (file == null) return placeholder;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Image.file(
      file,
      fit: fit,
      cacheWidth: thumbnailWidth == null
          ? null
          : (thumbnailWidth! * dpr).round(),
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => placeholder,
    );
  }
}
