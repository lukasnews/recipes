import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/messenger.dart';
import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/matching/ingredient_matcher.dart';
import '../../../core/units/ingredient_line_parser.dart';
import '../../../core/units/units.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../../../core/widgets/rating_stars.dart';
import '../../../core/widgets/storage_image.dart';
import '../../import/data/photo_picker.dart';
import '../../import/domain/recipe_draft.dart';
import '../../ingredients/domain/ingredient.dart';
import '../../ingredients/domain/ingredient_factory.dart';
import '../../ingredients/presentation/ingredient_picker.dart';
import '../domain/recipe.dart';

/// How one ingredient line will be linked when saving.
class _LinePreview {
  const _LinePreview(this.parsed, {this.ingredient, this.newName, this.match});

  final ParsedIngredientLine parsed;
  final Ingredient? ingredient;
  final String? newName;
  final MatchResult? match;

  bool get isNew => newName != null;
  bool get isUncertain => match?.isUncertain ?? false;
}

class RecipeEditScreen extends ConsumerStatefulWidget {
  const RecipeEditScreen({super.key, this.recipeId, this.draft});

  final String? recipeId;

  /// Imported draft to review (photo / screenshot import).
  final RecipeDraft? draft;

  @override
  ConsumerState<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends ConsumerState<RecipeEditScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _servings = TextEditingController(text: '4');
  final _prep = TextEditingController();
  final _cook = TextEditingController();
  final _tags = TextEditingController();
  final _ingredients = TextEditingController();
  final _steps = TextEditingController();
  final _notes = TextEditingController();
  String _category = RecipeCategories.cooking;
  int _rating = 0;
  Recipe? _original;
  bool _loaded = false;

  /// Photos already stored for this recipe, minus those removed here.
  final _keptPhotos = <String>[];
  final _removedPhotos = <String>[];

  /// New local photos to upload on save.
  final _newPhotos = <String>[];
  bool _keepSourcePhotos = false;

  /// Manual choices per raw line.
  final _overrides = <String, IngredientChoice>{};

  @override
  void dispose() {
    for (final c in [
      _title,
      _servings,
      _prep,
      _cook,
      _tags,
      _ingredients,
      _steps,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _loadDraft(RecipeDraft d) {
    _title.text = d.title;
    if (d.servings != null) _servings.text = '${d.servings}';
    _prep.text = d.prepMinutes?.toString() ?? '';
    _cook.text = d.cookMinutes?.toString() ?? '';
    _ingredients.text = d.ingredientLines.join('\n');
    _steps.text = d.steps.join('\n');
    _notes.text = d.notes;
  }

  void _load(Recipe? r, Map<String, Ingredient> byId) {
    _loaded = true;
    if (r == null) {
      final d = widget.draft;
      if (d != null) _loadDraft(d);
      return;
    }
    _keptPhotos.addAll(r.photoPaths);
    _original = r;
    _title.text = r.title;
    _servings.text = '${r.servings}';
    _prep.text = r.prepMinutes?.toString() ?? '';
    _cook.text = r.cookMinutes?.toString() ?? '';
    _tags.text = r.tags.join(', ');
    _ingredients.text = r.ingredients.map((i) => i.rawText).join('\n');
    _steps.text = r.steps.map((s) => s.text).join('\n');
    _notes.text = r.notes;
    _category = r.category;
    _rating = r.rating;
    for (final line in r.ingredients) {
      final ing = byId[line.ingredientId];
      _overrides[line.rawText] = ing == null
          ? const IngredientChoice.none()
          : IngredientChoice.existing(ing);
    }
  }

  List<String> get _lines => _ingredients.text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  _LinePreview _preview(
    String line,
    IngredientMatcher matcher,
    Map<String, Ingredient> byId,
  ) {
    final parsed = parseIngredientLine(line);
    final choice = _overrides[parsed.rawText];
    if (choice != null) {
      if (choice.unlink) return _LinePreview(parsed);
      if (choice.ingredient != null) {
        return _LinePreview(parsed, ingredient: choice.ingredient);
      }
      return _LinePreview(parsed, newName: choice.newName);
    }
    final m = matcher.match(parsed.name);
    if (m.isMatch && byId[m.id] != null) {
      return _LinePreview(parsed, ingredient: byId[m.id], match: m);
    }
    return _LinePreview(parsed, newName: parsed.name);
  }

  Future<void> _chooseCategory() async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.customCategory),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l10n.customCategoryLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && value.isNotEmpty) setState(() => _category = value);
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final matcher = ref.read(ingredientMatcherProvider);
    final byId = ref.read(ingredientsByIdProvider);
    final ingredientRepo = ref.read(ingredientRepositoryProvider);
    final recipeRepo = ref.read(recipeRepositoryProvider);
    final uid = ref.read(authUserProvider).value?.uid;

    final created = <String, Ingredient>{};
    final lines = <RecipeIngredient>[];
    for (final raw in _lines) {
      final p = _preview(raw, matcher, byId);
      String? id = p.ingredient?.id;
      if (p.isNew) {
        final key = p.newName!.trim().toLowerCase();
        final ing = created.putIfAbsent(
          key,
          () => newIngredient(
            ingredientRepo.newId(),
            p.newName!,
            unit: p.parsed.unit,
          ),
        );
        id = ing.id;
      }
      lines.add(
        RecipeIngredient(
          rawText: p.parsed.rawText,
          ingredientId: id,
          amount: p.parsed.amount,
          unit: p.parsed.unit,
          note: p.parsed.note,
          name: p.parsed.name,
        ),
      );
    }
    for (final ing in created.values) {
      fire(ingredientRepo.save(ing));
    }

    final isNew = _original == null;
    final recipe = Recipe(
      id: _original?.id ?? recipeRepo.newId(),
      title: _title.text.trim(),
      category: _category,
      tags: _tags.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList(),
      servings: int.tryParse(_servings.text.trim()) ?? 4,
      prepMinutes: int.tryParse(_prep.text.trim()),
      cookMinutes: int.tryParse(_cook.text.trim()),
      // Uploads append their paths themselves once they are done.
      photoPaths: List.of(_keptPhotos),
      rating: _rating,
      notes: _notes.text.trim(),
      sourceType:
          _original?.sourceType ?? (widget.draft == null ? 'manual' : 'ocr'),
      sourceUrl: _original?.sourceUrl,
      ingredients: lines,
      steps: _steps.text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .map(RecipeStep.new)
          .toList(),
      createdBy: _original?.createdBy ?? uid,
    );
    fire(recipeRepo.save(recipe, isNew: isNew));
    _syncPhotos(recipe.id);
    if (isNew) {
      context.pushReplacement(Routes.recipe(recipe.id));
    } else {
      context.pop();
    }
  }

  /// Uploads need a connection; they run in the background and report
  /// failures with a global snack bar.
  void _syncPhotos(String recipeId) {
    final repo = ref.read(photoRepositoryProvider);
    final cache = ref.read(photoCacheProvider);
    final l10n = context.l10n;
    for (final path in _removedPhotos) {
      fire(repo.remove(recipeId, path));
    }
    final uploads = [
      ..._newPhotos,
      if (_keepSourcePhotos) ...?widget.draft?.imagePaths,
    ];
    if (uploads.isEmpty) return;
    showGlobalSnack(l10n.photosUploading);
    for (final file in uploads) {
      unawaited(
        repo
            .upload(recipeId, file)
            // Keep the local file so this phone never downloads it again.
            .then<void>((path) => cache.put(path, file).catchError(reportError))
            .catchError((Object e, StackTrace s) {
              reportError(e, s);
              showGlobalSnack(l10n.photoUploadFailed);
            }),
      );
    }
  }

  Future<void> _addPhotos(PhotoSource source) async {
    final paths = await ref.read(photoPickerProvider).pick(source);
    if (paths.isNotEmpty) setState(() => _newPhotos.addAll(paths));
  }

  Widget _photoSection() {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    Widget thumb(Widget image, VoidCallback onRemove) => Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(width: 96, height: 96, child: image),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: IconButton.filledTonal(
            tooltip: l10n.removePhoto,
            iconSize: 18,
            onPressed: onRemove,
            icon: const Icon(Icons.close),
          ),
        ),
      ],
    );
    final draftImages = widget.draft?.imagePaths ?? const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.photosTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in _keptPhotos)
              thumb(
                StorageImage(path: p),
                () => setState(() {
                  _keptPhotos.remove(p);
                  _removedPhotos.add(p);
                }),
              ),
            for (final f in _newPhotos)
              thumb(
                Image.file(File(f), fit: BoxFit.cover),
                () => setState(() => _newPhotos.remove(f)),
              ),
            OutlinedButton.icon(
              onPressed: () => _addPhotos(PhotoSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(l10n.addPhotoCamera),
            ),
            OutlinedButton.icon(
              onPressed: () => _addPhotos(PhotoSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(l10n.addPhotoGallery),
            ),
          ],
        ),
        if (draftImages.isNotEmpty)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.keepSourcePhoto),
            value: _keepSourcePhotos,
            onChanged: (v) => setState(() => _keepSourcePhotos = v),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final byId = ref.watch(ingredientsByIdProvider);
    final matcher = ref.watch(ingredientMatcherProvider);
    final recipes = ref.watch(recipesProvider).value;
    if (!_loaded) {
      if (widget.recipeId != null && recipes == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      _load(recipes?.where((r) => r.id == widget.recipeId).firstOrNull, byId);
    }
    final categories = {
      ...RecipeCategories.builtIn,
      for (final r in recipes ?? const <Recipe>[]) r.category,
      _category,
    }.toList();
    final previews = [for (final l in _lines) _preview(l, matcher, byId)];

    return Scaffold(
      appBar: AppBar(
        title: Text(_original == null ? l10n.newRecipe : l10n.editRecipeTitle),
        actions: [TextButton(onPressed: _save, child: Text(l10n.save))],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.draft != null && _original == null)
              Card(
                color: widget.draft!.recognizedOffline
                    ? theme.colorScheme.errorContainer
                    : theme.colorScheme.secondaryContainer,
                child: ListTile(
                  leading: Icon(
                    widget.draft!.recognizedOffline
                        ? Icons.wifi_off
                        : Icons.auto_awesome,
                  ),
                  title: Text(
                    widget.draft!.recognizedOffline
                        ? l10n.importOfflineHint
                        : l10n.importReviewHint,
                  ),
                  subtitle: widget.draft!.aiError == null
                      ? null
                      : Text(l10n.importAiReason(widget.draft!.aiError!)),
                ),
              ),
            TextFormField(
              controller: _title,
              decoration: InputDecoration(labelText: l10n.titleLabel),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(labelText: l10n.categoryLabel),
              items: [
                for (final c in categories)
                  DropdownMenuItem(value: c, child: Text(l10n.category(c))),
                DropdownMenuItem(value: '', child: Text(l10n.customCategory)),
              ],
              onChanged: (v) {
                if (v == null) return;
                if (v.isEmpty) {
                  _chooseCategory();
                } else {
                  setState(() => _category = v);
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              spacing: 12,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _servings,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l10n.servingsField),
                  ),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _prep,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.prepMinutesLabel,
                    ),
                  ),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _cook,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.cookMinutesLabel,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tags,
              decoration: InputDecoration(
                labelText: l10n.tagsLabel,
                hintText: l10n.tagsHint,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(l10n.ratingLabel),
                const SizedBox(width: 8),
                RatingStars(
                  rating: _rating,
                  onChanged: (v) => setState(() => _rating = v),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ingredients,
              minLines: 4,
              maxLines: null,
              decoration: InputDecoration(
                labelText: l10n.ingredientsField,
                hintText: l10n.ingredientsHint,
                alignLabelWithHint: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (previews.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(l10n.checkIngredients, style: theme.textTheme.titleMedium),
              Text(l10n.checkIngredientsHint, style: theme.textTheme.bodySmall),
              for (final p in previews) _previewTile(p),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _steps,
              minLines: 4,
              maxLines: null,
              decoration: InputDecoration(
                labelText: l10n.stepsField,
                hintText: l10n.stepsHint,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              minLines: 2,
              maxLines: null,
              decoration: InputDecoration(
                labelText: l10n.notesLabel,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            _photoSection(),
            const SizedBox(height: 32),
            FilledButton(onPressed: _save, child: Text(l10n.save)),
          ],
        ),
      ),
    );
  }

  Widget _previewTile(_LinePreview p) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final qty = formatWithUnit(p.parsed.amount, p.parsed.unit);
    final (String target, String? status, Color? color) = p.ingredient != null
        ? (
            p.ingredient!.name,
            p.isUncertain ? l10n.matchUncertain : null,
            p.isUncertain ? Colors.orange : null,
          )
        : p.isNew
        ? (p.newName!, l10n.matchNew, scheme.primary)
        : ('–', l10n.matchNone, scheme.outline);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        p.isUncertain
            ? Icons.help_outline
            : p.isNew
            ? Icons.fiber_new_outlined
            : p.ingredient == null
            ? Icons.link_off
            : Icons.link,
        color: color,
      ),
      title: Text(p.parsed.rawText),
      subtitle: Text(
        [
          '→ ${[if (qty.isNotEmpty) qty, target].join(' ')}',
          ?status,
        ].join(' · '),
        style: color == null ? null : TextStyle(color: color),
      ),
      trailing: const Icon(Icons.edit_outlined, size: 18),
      onTap: () async {
        final choice = await pickIngredient(
          context,
          initialQuery: p.parsed.name,
          allowUnlink: true,
        );
        if (choice != null) {
          setState(() => _overrides[p.parsed.rawText] = choice);
        }
      },
    );
  }
}
