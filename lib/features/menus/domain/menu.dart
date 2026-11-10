import '../../../core/firebase/map_utils.dart';

/// Course of a menu, in serving order.
enum Course {
  starter,
  main,
  side,
  dessert,
  other;

  static Course parse(String? s) =>
      values.where((c) => c.name == s).firstOrNull ?? Course.other;
}

class MenuCourse {
  const MenuCourse(this.recipeId, this.course);

  factory MenuCourse.fromMap(Map<String, dynamic> m) =>
      MenuCourse(m.str('recipeId'), Course.parse(m.strOrNull('course')));

  final String recipeId;
  final Course course;

  Map<String, dynamic> toMap() => {'recipeId': recipeId, 'course': course.name};
}

/// Several recipes for guests (households/{hid}/menus/{id}): one shopping
/// trip and a timetable towards the time the meal is served.
class Menu {
  const Menu({
    required this.id,
    required this.title,
    this.servings = 4,
    this.date,
    this.serveAt,
    this.courses = const [],
  });

  factory Menu.fromMap(String id, Map<String, dynamic> m) => Menu(
    id: id,
    title: m.str('title'),
    servings: m.integer('servings') ?? 4,
    date: m.strOrNull('date'),
    serveAt: m.strOrNull('serveAt'),
    courses: m.maps('courses').map(MenuCourse.fromMap).toList(),
  );

  final String id;
  final String title;

  /// Guests incl. the household; recipes are scaled to this.
  final int servings;

  /// yyyy-MM-dd (mealplan key) or null.
  final String? date;

  /// When the first course is served, "HH:mm".
  final String? serveAt;
  final List<MenuCourse> courses;

  /// Courses in serving order (stable within a course).
  List<MenuCourse> get ordered => [
    for (final c in Course.values) ...courses.where((m) => m.course == c),
  ];

  Map<String, dynamic> toMap() => {
    'title': title,
    'servings': servings,
    // Explicit null so clearing the date/time in the app removes it.
    'date': date,
    'serveAt': serveAt,
    'courses': courses.map((c) => c.toMap()).toList(),
  };

  Menu copyWith({
    String? title,
    int? servings,
    String? Function()? date,
    String? Function()? serveAt,
    List<MenuCourse>? courses,
  }) => Menu(
    id: id,
    title: title ?? this.title,
    servings: servings ?? this.servings,
    date: date == null ? this.date : date(),
    serveAt: serveAt == null ? this.serveAt : serveAt(),
    courses: courses ?? this.courses,
  );
}
