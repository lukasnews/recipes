import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/messenger.dart';
import '../../../app/providers.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../../import/data/photo_picker.dart';
import '../../import/data/recipe_import_service.dart';
import '../domain/shopping_scan.dart';
import 'shopping_add.dart';

/// Photo of a paper list or a screenshot (e.g. from WhatsApp) → AI reads
/// the items → review with check boxes → onto the shopping list.
Future<void> scanShoppingList(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final source = await showModalBottomSheet<PhotoSource>(
    context: context,
    useSafeArea: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(l10n.scanListCamera),
            subtitle: Text(l10n.scanListCameraHint),
            onTap: () => Navigator.pop(context, PhotoSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.scanListGallery),
            subtitle: Text(l10n.scanListGalleryHint),
            onTap: () => Navigator.pop(context, PhotoSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return;
  final paths = await ref.read(photoPickerProvider).pick(source);
  if (paths.isEmpty || !context.mounted) return;

  final navigator = Navigator.of(context, rootNavigator: true);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 24),
              Expanded(child: Text(l10n.scanListReading)),
            ],
          ),
        ),
      ),
    ),
  );
  final ShoppingScan scan;
  try {
    final service = await ref.read(recipeImportServiceProvider.future);
    scan = await service.readShoppingList(paths);
  } catch (e) {
    navigator.pop();
    showGlobalSnack(l10n.importFailed('$e'));
    return;
  }
  navigator.pop();
  if (!context.mounted) return;
  if (scan.lines.isEmpty) {
    showGlobalSnack(l10n.scanListEmpty);
    return;
  }
  final added = await showModalBottomSheet<int>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => _ScanReviewSheet(scan: scan),
  );
  if (added != null && added > 0) showGlobalSnack(l10n.scanListAdded(added));
}

class _ScanReviewSheet extends ConsumerStatefulWidget {
  const _ScanReviewSheet({required this.scan});

  final ShoppingScan scan;

  @override
  ConsumerState<_ScanReviewSheet> createState() => _ScanReviewSheetState();
}

class _ScanReviewSheetState extends ConsumerState<_ScanReviewSheet> {
  late final _lines = [...widget.scan.lines];
  late final _selected = List.filled(_lines.length, true);

  Future<void> _edit(int i) async {
    final l10n = context.l10n;
    final text = (await showTextInputDialog(
      context,
      title: l10n.scanListEdit,
      label: l10n.scanListItem,
      initial: _lines[i],
      capitalization: TextCapitalization.sentences,
    ))?.trim();
    if (text == null || !mounted) return;
    setState(() {
      if (text.isEmpty) {
        _selected[i] = false;
      } else {
        _lines[i] = text;
        _selected[i] = true;
      }
    });
  }

  void _add() {
    var count = 0;
    for (var i = 0; i < _lines.length; i++) {
      if (!_selected[i]) continue;
      addShoppingLine(ref, _lines[i]);
      count++;
    }
    Navigator.pop(context, count);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final items = ref.watch(shoppingProvider).value ?? const [];
    final count = _selected.where((s) => s).length;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.scanListTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(
                    () => _selected.fillRange(0, _selected.length, count == 0),
                  ),
                  child: Text(count == 0 ? l10n.selectAll : l10n.selectNone),
                ),
              ],
            ),
          ),
          if (widget.scan.offline)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: theme.colorScheme.tertiaryContainer,
              child: ListTile(
                leading: const Icon(Icons.cloud_off),
                title: Text(l10n.scanListOffline),
                subtitle: widget.scan.aiError == null
                    ? null
                    : Text(l10n.importAiReason(widget.scan.aiError!)),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              itemCount: _lines.length,
              itemBuilder: (context, i) {
                final (:parsed, :ingredient) = resolveShoppingLine(
                  ref,
                  _lines[i],
                );
                final open = openItemFor(ingredient, items);
                final hint = open != null
                    ? l10n.scanListMerge
                    : ingredient != null &&
                          ingredient.name.toLowerCase() !=
                              parsed.name.toLowerCase()
                    ? '→ ${ingredient.name}'
                    : null;
                return CheckboxListTile(
                  value: _selected[i],
                  onChanged: (v) => setState(() => _selected[i] = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(_lines[i]),
                  subtitle: hint == null ? null : Text(hint),
                  secondary: IconButton(
                    tooltip: l10n.edit,
                    onPressed: () => _edit(i),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: count == 0 ? null : _add,
                  icon: const Icon(Icons.add_shopping_cart),
                  label: Text(l10n.scanListAdd(count)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
