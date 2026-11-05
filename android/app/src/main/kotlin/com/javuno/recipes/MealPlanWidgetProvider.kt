package com.javuno.recipes

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/** Home screen widget: today's dishes and the next days of the meal plan.
 *  The app writes dish titles per day ("plan_yyyy-MM-dd", two weeks ahead);
 *  the widget picks today itself, so it moves on at midnight while the app
 *  is closed (refresh via updatePeriodMillis). */
class MealPlanWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val key = SimpleDateFormat("yyyy-MM-dd", Locale.ROOT)
        val label = SimpleDateFormat("EE d.M.", Locale.GERMAN)
        val day = Calendar.getInstance()
        val nothing = context.getString(R.string.plan_widget_nothing)

        val todayTitles = widgetData.getString("plan_" + key.format(day.time), null)
        val today = context.getString(
            R.string.plan_widget_today,
            if (todayTitles.isNullOrEmpty()) nothing else todayTitles,
        )
        val lines = mutableListOf<String>()
        var known = todayTitles != null
        for (i in 1..6) {
            day.add(Calendar.DAY_OF_YEAR, 1)
            val titles = widgetData.getString("plan_" + key.format(day.time), null)
            if (titles != null) known = true
            val name = if (i == 1) context.getString(R.string.plan_widget_tomorrow)
                else label.format(day.time)
            lines.add("$name: " + if (titles.isNullOrEmpty()) "–" else titles)
        }

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.shopping_widget).apply {
                setTextViewText(R.id.widget_title, context.getString(R.string.plan_widget_title))
                setTextViewText(R.id.widget_today, if (known) today else "")
                setTextViewText(
                    R.id.widget_items,
                    if (known) lines.joinToString("\n")
                    else context.getString(R.string.plan_widget_open_app),
                )
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("baco://mealplan"),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
