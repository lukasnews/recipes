import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// One open shopping item in the widget; tapping it checks it off.
typedef WidgetRow = ({String id, String text});

/// Texts for the Android home screen widgets (already localized).
class WidgetContent {
  const WidgetContent({
    required this.title,
    required this.items,
    this.today,
    this.plan = const {},
    this.rows = const [],
    this.householdId,
  });

  /// Shopping widget list (open items, already in display order).
  final List<WidgetRow> rows;

  /// Where a check-off from the widget is written.
  final String? householdId;

  final String title;
  final String? today;

  /// One line per open item.
  final String items;

  /// Meal plan widget: dish titles per day key (yyyy-MM-dd), "" for a free
  /// day. Covers two weeks so the widget can move on to the next day by
  /// itself while the app is closed.
  final Map<String, String> plan;

  @override
  bool operator ==(Object other) =>
      other is WidgetContent &&
      other.title == title &&
      other.today == today &&
      other.items == items &&
      mapEquals(other.plan, plan) &&
      listEquals(other.rows, rows) &&
      other.householdId == householdId;

  @override
  int get hashCode => Object.hash(
    title,
    today,
    items,
    Object.hashAllUnordered(plan.entries.map((e) => '${e.key}=${e.value}')),
    Object.hashAll(rows),
    householdId,
  );
}

/// Behind an interface so tests and web use a no-op.
abstract class HomeScreenWidget {
  Future<void> update(WidgetContent content);

  /// Taps on the widget: the one that started the app, then later ones.
  Future<Uri?> initialClick();
  Stream<Uri?> clicks();
}

class NoHomeScreenWidget implements HomeScreenWidget {
  const NoHomeScreenWidget();

  @override
  Future<void> update(WidgetContent content) async {}

  @override
  Future<Uri?> initialClick() async => null;

  @override
  Stream<Uri?> clicks() => const Stream.empty();
}

class AndroidHomeScreenWidget implements HomeScreenWidget {
  const AndroidHomeScreenWidget();

  static const _provider = 'com.javuno.recipes.ShoppingWidgetProvider';
  static const _planProvider = 'com.javuno.recipes.MealPlanWidgetProvider';

  static bool _callbackRegistered = false;

  @override
  Future<void> update(WidgetContent content) async {
    if (!_callbackRegistered) {
      _callbackRegistered = true;
      await HomeWidget.registerInteractivityCallback(widgetInteraction);
    }
    await HomeWidget.saveWidgetData<String>(
      'household_id',
      content.householdId,
    );
    await HomeWidget.saveWidgetData<String>(
      'shopping_rows',
      encodeWidgetRows(content.rows),
    );
    // Fresh rows from the app replace the widget's optimistic check-offs.
    await HomeWidget.saveWidgetData<String>('checked_pending', '');
    await HomeWidget.saveWidgetData<String>('title', content.title);
    await HomeWidget.saveWidgetData<String>('today', content.today);
    await HomeWidget.saveWidgetData<String>('items', content.items);
    for (final e in content.plan.entries) {
      await HomeWidget.saveWidgetData<String>('plan_${e.key}', e.value);
    }
    await HomeWidget.updateWidget(qualifiedAndroidName: _provider);
    await HomeWidget.updateWidget(qualifiedAndroidName: _planProvider);
  }

  @override
  Future<Uri?> initialClick() => HomeWidget.initiallyLaunchedFromHomeWidget();

  @override
  Stream<Uri?> clicks() => HomeWidget.widgetClicked;
}

HomeScreenWidget platformHomeScreenWidget() =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android
    ? const AndroidHomeScreenWidget()
    : const NoHomeScreenWidget();

String encodeWidgetRows(List<WidgetRow> rows) => jsonEncode([
  for (final r in rows) {'id': r.id, 't': r.text},
]);

List<WidgetRow> decodeWidgetRows(String? json) {
  if (json == null || json.isEmpty) return const [];
  try {
    return [
      for (final m in (jsonDecode(json) as List).cast<Map<String, dynamic>>())
        (id: m['id'] as String, text: m['t'] as String),
    ];
  } on Object {
    return const [];
  }
}

/// A tap on a shopping item in the home screen widget, run in the
/// background (also while the app is closed): checks the item off. The
/// widget already hides it (BacoCheckReceiver); offline the write waits in
/// Firestore's local queue like any other.
@pragma('vm:entry-point')
Future<void> widgetInteraction(Uri? uri) async {
  final id = uri?.queryParameters['id'];
  if (uri?.host != 'check' || id == null) return;
  final hid = await HomeWidget.getWidgetData<String>('household_id');
  if (hid == null || hid.isEmpty) return;
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    final write = FirebaseFirestore.instance
        .doc('households/$hid/shopping/$id')
        .update({'checked': true});
    // Don't wait for the server: offline the write stays queued locally.
    await write.timeout(const Duration(seconds: 5), onTimeout: () {});
  } on Object catch (e) {
    debugPrint('Widget check-off failed: $e');
    return;
  }
  final rows = decodeWidgetRows(
    await HomeWidget.getWidgetData<String>('shopping_rows'),
  ).where((r) => r.id != id).toList();
  await HomeWidget.saveWidgetData<String>(
    'shopping_rows',
    encodeWidgetRows(rows),
  );
  await HomeWidget.updateWidget(
    qualifiedAndroidName: AndroidHomeScreenWidget._provider,
  );
}
