import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Texts for the Android home screen widgets (already localized).
class WidgetContent {
  const WidgetContent({
    required this.title,
    required this.items,
    this.today,
    this.plan = const {},
  });

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
      mapEquals(other.plan, plan);

  @override
  int get hashCode => Object.hash(
    title,
    today,
    items,
    Object.hashAllUnordered(plan.entries.map((e) => '${e.key}=${e.value}')),
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

  @override
  Future<void> update(WidgetContent content) async {
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
