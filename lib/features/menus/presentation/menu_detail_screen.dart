import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/matching/normalize.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../../../l10n/app_localizations.dart';
import '../../mealplan/domain/meal_plan_day.dart';
import '../../mealplan/presentation/needs_dialog.dart';
import '../../recipes/domain/recipe.dart';
import '../domain/menu.dart';
import '../domain/menu_plan.dart';

String courseName(AppLocalizations l10n, Course c) => switch (c) {
  Course.starter => l10n.courseStarter,
  Course.main => l10n.courseMain,
  Course.side => l10n.courseSide,
  Course.dessert => l10n.courseDessert,
  Course.other => l10n.courseOther,
};

class MenuDetailScreen extends ConsumerWidget {
  const MenuDetailScreen({super.key, required this.menuId});

  final String menuId;

  void _save(WidgetRef ref, Menu menu) =>
      fire(ref.read(menuRepositoryProvider).save(menu));

  Future<void> _rename(BuildContext context, WidgetRef ref, Menu menu) async {
    final l10n = context.l10n;
    final title = (await showTextInputDialog(
      context,
      title: l10n.menuRename,
      label: l10n.menuTitleLabel,
      initial: menu.title,
      capitalization: TextCapitalization.sentences,
    ))?.trim();
    if (title == null || title.isEmpty) return;
    _save(ref, menu.copyWith(title: title));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Menu menu) async {
    final l10n = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l10n.confirmDeleteTitle,
      message: l10n.menuDeleteConfirm(menu.title),
      confirmLabel: l10n.delete,
    );
    if (!ok || !context.mounted) return;
    fire(ref.read(menuRepositoryProvider).delete(menu.id));
    context.pop();
  }

  Future<void> _addCourse(
    BuildContext context,
    WidgetRef ref,
    Menu menu,
  ) async {
    final l10n = context.l10n;
    final course = await showDialog<Course>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.menuWhichCourse),
        children: [
          for (final c in Course.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, c),
              child: Text(courseName(l10n, c)),
            ),
        ],
      ),
    );
    if (course == null || !context.mounted) return;
    final recipe = await showModalBottomSheet<Recipe>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) =>
          _RecipePicker(recipes: ref.read(recipesProvider).value ?? const []),
    );
    if (recipe == null) return;
    _save(
      ref,
      menu.copyWith(courses: [...menu.courses, MenuCourse(recipe.id, course)]),
    );
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref, Menu menu) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(menu.date ?? '') ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked == null) return;
    _save(ref, menu.copyWith(date: () => dayKey(picked)));
  }

  Future<void> _pickTime(BuildContext context, WidgetRef ref, Menu menu) async {
    final at = menuServeTime(menu, DateTime.now());
    final picked = await showTimePicker(
      context: context,
      initialTime: at == null
          ? const TimeOfDay(hour: 19, minute: 0)
          : TimeOfDay.fromDateTime(at),
    );
    if (picked == null) return;
    String two(int v) => v.toString().padLeft(2, '0');
    _save(
      ref,
      menu.copyWith(serveAt: () => '${two(picked.hour)}:${two(picked.minute)}'),
    );
  }

  Future<void> _shop(
    BuildContext context,
    WidgetRef ref,
    Menu menu,
    Map<String, Recipe> recipes,
  ) async {
    final l10n = context.l10n;
    final needs = menuShoppingNeeds(
      menu,
      recipes,
      ref.read(ingredientsByIdProvider),
      ref.read(pantryProvider).value ?? const {},
    );
    if (needs.isEmpty) {
      showSnack(context, l10n.weekAllInStock);
      return;
    }
    await shopNeeds(
      context,
      ref,
      needs,
      title: l10n.menuShopTitle,
      hint: l10n.menuShopHint(menu.servings),
    );
  }

  void _plan(BuildContext context, WidgetRef ref, Menu menu) {
    final repo = ref.read(mealPlanRepositoryProvider);
    for (final c in menu.ordered) {
      fire(repo.add(menu.date!, c.recipeId));
    }
    showSnack(context, context.l10n.menuPlanned);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final menus = ref.watch(menusProvider).value;
    final menu = menus?.where((m) => m.id == menuId).firstOrNull;
    if (menu == null) {
      return Scaffold(
        appBar: AppBar(),
        body: menus == null
            ? const Center(child: CircularProgressIndicator())
            : EmptyState(icon: Icons.search_off, message: l10n.noSearchResults),
      );
    }
    final recipes = {
      for (final r in ref.watch(recipesProvider).value ?? const <Recipe>[])
        r.id: r,
    };
    final date = DateTime.tryParse(menu.date ?? '');
    final serveAt = menuServeTime(menu, DateTime.now());
    final timeline = serveAt == null
        ? null
        : menuTimeline(menu, recipes, serveAt);
    final time = DateFormat.Hm('de');

    return Scaffold(
      appBar: AppBar(
        title: Text(menu.title),
        actions: [
          IconButton(
            tooltip: l10n.menuRename,
            onPressed: () => _rename(context, ref, menu),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: l10n.delete,
            onPressed: () => _delete(context, ref, menu),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(
            children: [
              Text(l10n.menuGuests, style: theme.textTheme.titleMedium),
              const Spacer(),
              IconButton.filledTonal(
                onPressed: menu.servings > 1
                    ? () =>
                          _save(ref, menu.copyWith(servings: menu.servings - 1))
                    : null,
                icon: Icon(Icons.remove, semanticLabel: l10n.decrease),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${menu.servings}',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              IconButton.filledTonal(
                onPressed: () =>
                    _save(ref, menu.copyWith(servings: menu.servings + 1)),
                icon: Icon(Icons.add, semanticLabel: l10n.increase),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              InputChip(
                avatar: const Icon(Icons.event_outlined),
                label: Text(
                  date == null
                      ? l10n.menuSetDate
                      : DateFormat('EEEE, d. MMMM', 'de').format(date),
                ),
                onPressed: () => _pickDate(context, ref, menu),
                onDeleted: date == null
                    ? null
                    : () => _save(ref, menu.copyWith(date: () => null)),
              ),
              InputChip(
                avatar: const Icon(Icons.schedule),
                label: Text(
                  serveAt == null
                      ? l10n.menuSetTime
                      : l10n.menuServeAt(time.format(serveAt)),
                ),
                onPressed: () => _pickTime(context, ref, menu),
                onDeleted: serveAt == null
                    ? null
                    : () => _save(ref, menu.copyWith(serveAt: () => null)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final course in Course.values)
            if (menu.courses.any((c) => c.course == course)) ...[
              Text(
                courseName(l10n, course),
                style: theme.textTheme.titleMedium,
              ),
              for (final (i, c) in menu.courses.indexed)
                if (c.course == course)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.restaurant),
                    title: Text(recipes[c.recipeId]?.title ?? '…'),
                    subtitle: switch (recipes[c.recipeId]?.totalMinutes) {
                      final m? => Text(l10n.minutesShort(m)),
                      null => null,
                    },
                    onTap: recipes[c.recipeId] == null
                        ? null
                        : () => context.push(Routes.recipe(c.recipeId)),
                    trailing: IconButton(
                      tooltip: l10n.menuRemoveCourse,
                      onPressed: () => _save(
                        ref,
                        menu.copyWith(courses: [...menu.courses]..removeAt(i)),
                      ),
                      icon: const Icon(Icons.close),
                    ),
                  ),
              const SizedBox(height: 8),
            ],
          if (menu.courses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(l10n.menuNoCourses),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _addCourse(context, ref, menu),
              icon: const Icon(Icons.add),
              label: Text(l10n.menuAddCourse),
            ),
          ),
          if (menu.courses.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => _shop(context, ref, menu, recipes),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: Text(l10n.menuShop),
                ),
                if (menu.date != null)
                  FilledButton.tonalIcon(
                    onPressed: () => _plan(context, ref, menu),
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(l10n.menuPlan),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text(l10n.menuTimeline, style: theme.textTheme.titleLarge),
            if (timeline == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l10n.menuTimelineNeedsTime),
              )
            else ...[
              for (final s in timeline.steps)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Text(
                    time.format(s.at),
                    style: theme.textTheme.titleMedium,
                  ),
                  title: Text(switch (s.kind) {
                    StepKind.prepare => l10n.stepPrepare(s.recipe.title),
                    StepKind.cook => l10n.stepCook(s.recipe.title),
                    StepKind.serve => l10n.stepServe(s.recipe.title),
                  }),
                  subtitle: s.minutes > 0
                      ? Text(l10n.minutesShort(s.minutes))
                      : null,
                ),
              if (timeline.untimed.isNotEmpty)
                Text(
                  l10n.menuUntimed(
                    timeline.untimed.map((r) => r.title).join(', '),
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              Text(l10n.menuTimelineHint, style: theme.textTheme.bodySmall),
            ],
          ],
        ],
      ),
    );
  }
}

class _RecipePicker extends StatefulWidget {
  const _RecipePicker({required this.recipes});

  final List<Recipe> recipes;

  @override
  State<_RecipePicker> createState() => _RecipePickerState();
}

class _RecipePickerState extends State<_RecipePicker> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final q = foldText(_query);
    final list = widget.recipes
        .where((r) => q.isEmpty || foldText(r.title).contains(q))
        .toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SearchBar(
              hintText: l10n.searchRecipesHint,
              leading: const Icon(Icons.search),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView(
              controller: scroll,
              children: [
                for (final r in list)
                  ListTile(
                    title: Text(r.title),
                    subtitle: Text(l10n.category(r.category)),
                    onTap: () => Navigator.pop(context, r),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
