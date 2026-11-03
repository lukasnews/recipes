/// Route paths used across the app.
abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const setup = '/setup';
  static const recipes = '/recipes';
  static const newRecipe = '/recipes/new';
  static String recipe(String id) => '/recipes/$id';
  static String editRecipe(String id) => '/recipes/$id/edit';
  static const mealPlan = '/mealplan';
  static const shopping = '/shopping';
  static const pantry = '/pantry';
  static const settings = '/settings';
  static const ingredients = '/settings/ingredients';
  static String ingredient(String id) => '/settings/ingredients/$id';
}
