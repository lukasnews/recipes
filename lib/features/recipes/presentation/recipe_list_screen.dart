import 'package:flutter/material.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/profile_button.dart';
import '../../../l10n/app_localizations.dart';

/// Built-in recipe categories, shown as filter chips.
enum RecipeCategory { cooking, cake, cookies }

class RecipeListScreen extends StatefulWidget {
  const RecipeListScreen({super.key});

  @override
  State<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends State<RecipeListScreen> {
  RecipeCategory? _selected;

  String _label(AppLocalizations l10n, RecipeCategory category) =>
      switch (category) {
        RecipeCategory.cooking => l10n.categoryCooking,
        RecipeCategory.cake => l10n.categoryCake,
        RecipeCategory.cookies => l10n.categoryCookies,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navRecipes),
        actions: const [ProfileButton()],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(l10n.categoryAll),
                  selected: _selected == null,
                  onSelected: (_) => setState(() => _selected = null),
                ),
                for (final category in RecipeCategory.values)
                  ChoiceChip(
                    label: Text(_label(l10n, category)),
                    selected: _selected == category,
                    onSelected: (_) => setState(() => _selected = category),
                  ),
              ],
            ),
          ),
          Expanded(
            child: EmptyState(
              icon: Icons.menu_book_outlined,
              message: l10n.recipesEmpty,
            ),
          ),
        ],
      ),
    );
  }
}
