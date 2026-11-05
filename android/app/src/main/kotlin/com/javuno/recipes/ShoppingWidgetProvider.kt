package com.javuno.recipes

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Bundle
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

/** Home screen widget: today's dish and the open shopping list; more list
 *  lines the bigger it is. */
class ShoppingWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val options = appWidgetManager.getAppWidgetOptions(id)
            appWidgetManager.updateAppWidget(
                id,
                BacoWidgets.views(context, BacoWidgets.SHOPPING, id, widgetData, options),
            )
        }
        // Rows come from ShoppingListService; reload them as well.
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.widget_list)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId), HomeWidgetPlugin.getData(context))
    }
}
