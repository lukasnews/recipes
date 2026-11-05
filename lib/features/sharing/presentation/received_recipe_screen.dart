import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../../../core/widgets/storage_image.dart';
import '../domain/shared_recipe.dart';

/// A recipe someone sent (link or code): preview, then "In meine Rezepte
/// übernehmen" opens the review screen like any import.
class ReceivedRecipeScreen extends ConsumerStatefulWidget {
  const ReceivedRecipeScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<ReceivedRecipeScreen> createState() =>
      _ReceivedRecipeScreenState();
}

class _ReceivedRecipeScreenState extends ConsumerState<ReceivedRecipeScreen> {
  late Future<SharedRecipe?> _load = _fetch();
  bool _busy = false;

  Future<SharedRecipe?> _fetch() =>
      ref.read(sharedRecipeRepositoryProvider).fetch(widget.code);

  Future<void> _take(SharedRecipe r) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    var images = const <String>[];
    final photo = r.photoPath;
    if (photo != null) {
      try {
        final file = await ref.read(photoFileProvider(photo).future);
        images = [file.path];
      } on Object {
        // Photo not reachable (offline): the recipe comes without it.
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    final from = r.message.isEmpty
        ? l10n.receivedFrom(r.senderName)
        : '${l10n.receivedFrom(r.senderName)}: „${r.message}“';
    await context.push(
      Routes.newRecipe,
      extra: r.toDraft(notes: from, imagePaths: images),
    );
    if (mounted) context.go(Routes.recipes);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.receivedTitle)),
      body: FutureBuilder<SharedRecipe?>(
        future: _load,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _Message(
              icon: Icons.cloud_off,
              text: l10n.receivedOffline,
              action: FilledButton(
                onPressed: () => setState(() => _load = _fetch()),
                child: Text(l10n.retry),
              ),
            );
          }
          final r = snap.data;
          if (r == null) {
            return _Message(
              icon: Icons.search_off,
              text: l10n.receivedNotFound(formatShareCode(widget.code)),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (r.photoPath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: StorageImage(path: r.photoPath!),
                  ),
                ),
              const SizedBox(height: 16),
              Text(r.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                l10n.receivedFrom(r.senderName),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              if (r.message.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '„${r.message}“',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(l10n.ingredientsTitle, style: theme.textTheme.titleMedium),
              for (final line in r.ingredientLines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('• $line'),
                ),
              if (r.steps.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(l10n.stepsTitle, style: theme.textTheme.titleMedium),
                for (final (i, s) in r.steps.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('${i + 1}. $s'),
                  ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : () => _take(r),
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: Text(l10n.receivedTake),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.receivedTakeHint,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          Icon(icon, size: 48),
          Text(text, textAlign: TextAlign.center),
          ?action,
        ],
      ),
    ),
  );
}
