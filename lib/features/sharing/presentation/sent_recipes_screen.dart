import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../../../core/widgets/url_opener.dart';
import '../domain/shared_recipe.dart';
import 'share_actions.dart';

/// Einstellungen → "Gesendete Rezepte": what you sent, until when it can be
/// opened; send the link again or stop sharing.
class SentRecipesScreen extends ConsumerWidget {
  const SentRecipesScreen({super.key});

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    SharedRecipe r,
  ) async {
    final l10n = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l10n.sentDeleteTitle,
      message: l10n.sentDeleteMessage(r.title),
      confirmLabel: l10n.sentDeleteConfirm,
    );
    if (!ok) return;
    fire(ref.read(sharedRecipeRepositoryProvider).delete(r.code));
    final photo = r.photoPath;
    if (photo != null) {
      fire(ref.read(photoRepositoryProvider).deleteFiles([photo]));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final now = DateTime.now();
    String until(SharedRecipe r) {
      final e = r.expiresAt;
      if (e == null) return l10n.sentNoExpiry;
      if (r.isExpired(now)) return l10n.sentExpired;
      return l10n.sentValidUntil(
        MaterialLocalizations.of(context).formatShortDate(e),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.sentTitle)),
      body: AsyncView(
        value: ref.watch(sentRecipesProvider),
        data: (list) => list.isEmpty
            ? EmptyState(icon: Icons.send_outlined, message: l10n.sentEmpty)
            : ListView(
                children: [
                  for (final r in list)
                    ListTile(
                      title: Text(r.title),
                      subtitle: Text(
                        '${formatShareCode(r.code)} · ${until(r)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: l10n.sentShareAgain,
                            icon: const Icon(Icons.share_outlined),
                            onPressed: () => fire(
                              ref
                                  .read(sharerProvider)
                                  .shareText(
                                    shareMessageText(
                                      intro: l10n.sendRecipeIntro(
                                        r.senderName,
                                        r.title,
                                      ),
                                      message: r.message,
                                      linkLine: l10n.sendRecipeLink(
                                        Links.sharedRecipe(r.code).toString(),
                                        formatShareCode(r.code),
                                      ),
                                    ),
                                    subject: r.title,
                                  ),
                            ),
                          ),
                          IconButton(
                            tooltip: l10n.sentDeleteConfirm,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(context, ref, r),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
