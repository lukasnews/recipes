import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../app/providers.dart';
import '../../../core/units/display_units.dart';
import '../../../core/units/units.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../domain/recipe.dart';
import '../domain/step_timers.dart';
import 'cook_timers.dart';

/// Full-screen step-by-step view: big text, screen stays on, timers.
/// Pops with `true` when the cook taps "Gekocht" at the end.
class CookModeScreen extends ConsumerStatefulWidget {
  const CookModeScreen({super.key, required this.recipeId, this.servings});

  final String recipeId;
  final int? servings;

  @override
  ConsumerState<CookModeScreen> createState() => _CookModeScreenState();
}

class _CookModeScreenState extends ConsumerState<CookModeScreen> {
  final _pages = PageController();
  Timer? _ticker;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_wakelock(true));
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pages.dispose();
    unawaited(_wakelock(false));
    super.dispose();
  }

  Future<void> _wakelock(bool on) async {
    try {
      await WakelockPlus.toggle(enable: on);
    } catch (_) {
      // Not available in tests / unsupported platforms.
    }
  }

  void _tick() {
    if (!mounted) return;
    final now = DateTime.now();
    final timers = ref.read(cookTimersProvider);
    for (final t in timers) {
      if (!t.alerted && !t.remaining(now).isNegative) continue;
      if (t.alerted) continue;
      ref.read(cookTimersProvider.notifier).markAlerted(t.id);
      unawaited(_alert(t));
    }
    setState(() {});
  }

  Future<void> _alert(CookTimer t) async {
    for (var i = 0; i < 3; i++) {
      unawaited(HapticFeedback.vibrate());
      unawaited(SystemSound.play(SystemSoundType.alert));
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
    if (!mounted) return;
    final l10n = context.l10n;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.alarm, size: 48),
        title: Text(l10n.timerDone),
        content: Text(t.label, style: Theme.of(context).textTheme.titleLarge),
        actions: [
          TextButton(
            onPressed: () {
              ref
                  .read(cookTimersProvider.notifier)
                  .addTime(t.id, const Duration(minutes: 1));
              Navigator.pop(context);
            },
            child: Text(l10n.timerPlusOne),
          ),
          FilledButton(
            onPressed: () {
              ref.read(cookTimersProvider.notifier).cancel(t.id);
              Navigator.pop(context);
            },
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  void _go(int page) => _pages.animateToPage(
    page,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
  );

  void _showIngredients(Recipe recipe, int servings) {
    final l10n = context.l10n;
    final byId = ref.read(ingredientsByIdProvider);
    final display = ref.read(unitDisplayProvider);
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Text(
            '${l10n.ingredientsTitle} · ${l10n.servingsLabel}: $servings',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final line in recipe.ingredients)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                [
                  displayQuantity(
                    line.amount == null
                        ? null
                        : scaleAmount(line.amount!, recipe.servings, servings),
                    line.unit,
                    display,
                  ),
                  byId[line.ingredientId]?.name ?? line.name ?? line.rawText,
                ].where((s) => s.isNotEmpty).join(' '),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: line.note == null ? null : Text(line.note!),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final recipe = ref
        .watch(recipesProvider)
        .value
        ?.where((r) => r.id == widget.recipeId)
        .firstOrNull;
    if (recipe == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final servings = widget.servings ?? recipe.servings;
    final steps = recipe.steps;
    final timers = ref.watch(cookTimersProvider);
    final now = DateTime.now();
    final isLast = _page >= steps.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title),
        actions: [
          IconButton(
            tooltip: l10n.ingredientsTitle,
            onPressed: () => _showIngredients(recipe, servings),
            icon: const Icon(Icons.format_list_bulleted),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            LinearProgressIndicator(
              value: steps.isEmpty ? 1 : (_page + 1) / steps.length,
            ),
            Expanded(
              child: steps.isEmpty
                  ? Center(child: Text(l10n.cookNoSteps))
                  : PageView.builder(
                      controller: _pages,
                      itemCount: steps.length,
                      onPageChanged: (p) => setState(() => _page = p),
                      itemBuilder: (context, i) {
                        final step = steps[i];
                        final durations = [
                          if (step.timerSeconds != null)
                            Duration(seconds: step.timerSeconds!),
                          ...parseStepTimers(step.text),
                        ];
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.cookStepOf(i + 1, steps.length),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                step.text,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  for (final d in durations.toSet())
                                    FilledButton.tonalIcon(
                                      onPressed: () => ref
                                          .read(cookTimersProvider.notifier)
                                          .start(
                                            '${l10n.cookStep(i + 1)}: '
                                            '${timerLabel(d)}',
                                            d,
                                            alarmTitle: l10n.timerDone,
                                          ),
                                      icon: const Icon(Icons.timer_outlined),
                                      label: Text(timerLabel(d)),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            if (timers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in timers)
                      InputChip(
                        avatar: Icon(
                          t.remaining(now).isNegative
                              ? Icons.alarm_on
                              : Icons.timer,
                        ),
                        label: Text(
                          '${t.label} · ${formatTimer(t.remaining(now))}',
                        ),
                        backgroundColor: t.remaining(now).isNegative
                            ? theme.colorScheme.errorContainer
                            : null,
                        onPressed: () => ref
                            .read(cookTimersProvider.notifier)
                            .addTime(t.id, const Duration(minutes: 1)),
                        onDeleted: () =>
                            ref.read(cookTimersProvider.notifier).cancel(t.id),
                        tooltip: l10n.timerPlusOne,
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                spacing: 12,
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _page > 0 ? () => _go(_page - 1) : null,
                      icon: const Icon(Icons.arrow_back),
                      label: Text(l10n.cookBack),
                    ),
                  ),
                  Expanded(
                    child: isLast
                        ? FilledButton.icon(
                            onPressed: () => Navigator.pop(context, true),
                            icon: const Icon(Icons.restaurant),
                            label: Text(l10n.cooked),
                          )
                        : FilledButton.icon(
                            onPressed: () => _go(_page + 1),
                            icon: const Icon(Icons.arrow_forward),
                            label: Text(l10n.cookNext),
                          ),
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
