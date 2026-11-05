import 'package:flutter/material.dart';

import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/l10n_ext.dart';

/// Pick the collections of a recipe; new ones can be created here.
/// Pops the chosen names, or null when closed.
class CollectionsSheet extends StatefulWidget {
  const CollectionsSheet({
    super.key,
    required this.all,
    required this.selected,
  });

  final List<String> all;
  final Set<String> selected;

  @override
  State<CollectionsSheet> createState() => _CollectionsSheetState();
}

class _CollectionsSheetState extends State<CollectionsSheet> {
  late final _all = [...widget.all];
  late final _selected = {...widget.selected};

  Future<void> _create() async {
    final l10n = context.l10n;
    final name = (await showTextInputDialog(
      context,
      title: l10n.collectionNew,
      label: l10n.collectionNameLabel,
      hint: l10n.collectionNameHint,
      capitalization: TextCapitalization.sentences,
    ))?.trim();
    if (name == null || name.isEmpty) return;
    setState(() {
      if (!_all.contains(name)) _all.add(name);
      _selected.add(name);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text(
              l10n.collectionsEdit,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            subtitle: Text(l10n.collectionsHint),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final c in _all)
                  CheckboxListTile(
                    value: _selected.contains(c),
                    title: Text(c),
                    onChanged: (v) => setState(
                      () => v == true ? _selected.add(c) : _selected.remove(c),
                    ),
                  ),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: Text(l10n.collectionNew),
                  onTap: _create,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _selected.toList()),
              child: Text(l10n.save),
            ),
          ),
        ],
      ),
    );
  }
}
