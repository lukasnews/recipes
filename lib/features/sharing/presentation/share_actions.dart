import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../../../core/widgets/url_opener.dart';
import '../../recipes/domain/recipe.dart';
import '../domain/shared_recipe.dart';

/// Text sent along with the link, e.g. via WhatsApp.
String shareMessageText({
  required String intro,
  required String message,
  required String linkLine,
}) => [
  intro,
  if (message.trim().isNotEmpty) '„${message.trim()}“',
  linkLine,
].join('\n\n');

/// Recipe detail → ⋮ → "An anderen Haushalt senden": a copy under a code,
/// shared as link (opens BaCo, or a web page without the app).
Future<void> sendRecipeToHousehold(
  BuildContext context,
  WidgetRef ref,
  Recipe recipe,
) async {
  final l10n = context.l10n;
  final input = await showDialog<(String, ShareValidity)>(
    context: context,
    builder: (_) => const _SendDialog(),
  );
  if (input == null || !context.mounted) return;
  final user = ref.read(authUserProvider).value;
  if (user == null) return;
  final name = ref.read(appUserProvider).value?.displayName.trim();
  final sender = (name == null || name.isEmpty) ? user.bestName : name;
  final code = newShareCode();
  final shared = SharedRecipe.fromRecipe(
    recipe,
    code: code,
    uid: user.uid,
    senderName: sender,
    message: input.$1,
    validity: input.$2,
  );
  final repo = ref.read(sharedRecipeRepositoryProvider);
  fire(repo.send(shared));
  if (recipe.photoPaths.isNotEmpty) {
    fire(_sendPhoto(ref, user.uid, code, recipe.photoPaths.first));
  }
  await ref
      .read(sharerProvider)
      .shareText(
        shareMessageText(
          intro: l10n.sendRecipeIntro(sender, recipe.title),
          message: shared.message,
          linkLine: l10n.sendRecipeLink(
            Links.sharedRecipe(code).toString(),
            formatShareCode(code),
          ),
        ),
        subject: recipe.title,
      );
}

/// The first photo goes along (needs network; without it the copy simply
/// has no photo).
Future<void> _sendPhoto(
  WidgetRef ref,
  String uid,
  String code,
  String photoPath,
) async {
  final file = await ref.read(photoFileProvider(photoPath).future);
  final path = await ref
      .read(photoRepositoryProvider)
      .uploadShared(uid, code, file.path);
  await ref.read(sharedRecipeRepositoryProvider).setPhoto(code, path);
}

/// "+" → "Rezept-Code eingeben" (clipboard prefilled when it holds one).
Future<void> askForShareCode(BuildContext context) async {
  final l10n = context.l10n;
  final clip = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
  if (!context.mounted) return;
  final fromClip = parseShareCode(clip);
  final text = await showTextInputDialog(
    context,
    title: l10n.receiveCodeTitle,
    label: l10n.receiveCodeLabel,
    hint: 'K7MQ-X4PA',
    initial: fromClip == null ? '' : formatShareCode(fromClip),
    capitalization: TextCapitalization.characters,
    confirmLabel: l10n.receiveCodeOpen,
  );
  if (text == null || !context.mounted) return;
  final code = parseShareCode(text);
  if (code == null) {
    showSnack(context, l10n.receiveCodeInvalid);
    return;
  }
  await context.push(Routes.sharedRecipe(code));
}

class _SendDialog extends StatefulWidget {
  const _SendDialog();

  @override
  State<_SendDialog> createState() => _SendDialogState();
}

class _SendDialogState extends State<_SendDialog> {
  final _message = TextEditingController();
  var _validity = ShareValidity.never;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.sendRecipeTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.sendRecipeHint),
            const SizedBox(height: 16),
            TextField(
              controller: _message,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                labelText: l10n.sendRecipeMessage,
                hintText: l10n.sendRecipeMessageHint,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ShareValidity>(
              initialValue: _validity,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.sendRecipeValidity),
              items: [
                for (final v in ShareValidity.values)
                  DropdownMenuItem(
                    value: v,
                    child: Text(l10n.shareValidity(v)),
                  ),
              ],
              onChanged: (v) => setState(() => _validity = v ?? _validity),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (_message.text, _validity)),
          child: Text(l10n.sendRecipeConfirm),
        ),
      ],
    );
  }
}
