package com.javuno.recipes

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Home screen widget: today's dish and the open shopping list. The texts
 *  are written (already localized) by the Flutter app via home_widget. */
class ShoppingWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.shopping_widget).apply {
                setTextViewText(R.id.widget_title, widgetData.getString("title", "BaCo"))
                val today = widgetData.getString("today", null)
                setTextViewText(R.id.widget_today, today ?: "")
                setViewVisibility(R.id.widget_today, if (today.isNullOrEmpty()) View.GONE else View.VISIBLE)
                setTextViewText(
                    R.id.widget_items,
                    widgetData.getString("items", null)
                        ?: context.getString(R.string.widget_open_app),
                )
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("baco://shopping"),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
