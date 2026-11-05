package com.javuno.recipes

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import android.widget.TextView
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/** Texts shown by a widget: title, highlighted line, list lines. */
data class WidgetTexts(val title: String, val today: String?, val lines: List<String>)

/** Rendering shared by both widgets and the settings screen. The app writes
 *  the (already localized) data via home_widget; this decides what fits. */
object BacoWidgets {
    const val SHOPPING = "com.javuno.recipes.ShoppingWidgetProvider"
    const val PLAN = "com.javuno.recipes.MealPlanWidgetProvider"

    private const val SETTINGS = "baco_widget_settings"
    const val DEFAULT_OPACITY = 100

    /** Background opacity in percent (100 = solid), per widget. */
    fun opacity(context: Context, id: Int): Int =
        context.getSharedPreferences(SETTINGS, Context.MODE_PRIVATE)
            .getInt("opacity_$id", DEFAULT_OPACITY)

    fun setOpacity(context: Context, id: Int, percent: Int) {
        context.getSharedPreferences(SETTINGS, Context.MODE_PRIVATE)
            .edit().putInt("opacity_$id", percent).apply()
    }

    /** List lines that fit the widget's height (0 = only the top lines). */
    fun linesFor(options: Bundle?): Int {
        val h = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT) ?: 0
        if (h <= 0) return 6
        // padding 32 + title 22 + today 24 + gaps, then ~20dp per line
        return ((h - 84) / 20).coerceIn(0, 12)
    }

    fun shopping(context: Context, data: SharedPreferences): WidgetTexts {
        val items = data.getString("items", null)
        return WidgetTexts(
            title = data.getString("title", null) ?: context.getString(R.string.widget_label),
            today = data.getString("today", null),
            lines = items?.split("\n") ?: listOf(context.getString(R.string.widget_open_app)),
        )
    }

    fun plan(context: Context, data: SharedPreferences, days: Int): WidgetTexts {
        val key = SimpleDateFormat("yyyy-MM-dd", Locale.ROOT)
        val label = SimpleDateFormat("EE d.M.", Locale.GERMAN)
        val day = Calendar.getInstance()
        val nothing = context.getString(R.string.plan_widget_nothing)
        val title = context.getString(R.string.plan_widget_title)

        val todayTitles = data.getString("plan_" + key.format(day.time), null)
            ?: return WidgetTexts(title, null, listOf(context.getString(R.string.plan_widget_open_app)))
        val today = context.getString(
            R.string.plan_widget_today,
            if (todayTitles.isEmpty()) nothing else todayTitles,
        )
        val lines = mutableListOf<String>()
        for (i in 1..days.coerceAtMost(13)) {
            day.add(Calendar.DAY_OF_YEAR, 1)
            val titles = data.getString("plan_" + key.format(day.time), null) ?: break
            val name = if (i == 1) context.getString(R.string.plan_widget_tomorrow)
                else label.format(day.time)
            lines.add("$name: " + titles.ifEmpty { "–" })
        }
        return WidgetTexts(title, today, lines)
    }

    /** Texts for one widget at its current size. */
    fun texts(context: Context, provider: String, data: SharedPreferences, lines: Int): WidgetTexts =
        if (provider == PLAN) plan(context, data, lines) else shopping(context, data)

    fun views(
        context: Context,
        provider: String,
        id: Int,
        data: SharedPreferences,
        options: Bundle?,
    ): RemoteViews {
        val lines = linesFor(options)
        val t = texts(context, provider, data, lines)
        return RemoteViews(context.packageName, R.layout.shopping_widget).apply {
            setTextViewText(R.id.widget_title, t.title)
            setTextViewText(R.id.widget_today, t.today ?: "")
            setViewVisibility(R.id.widget_today, if (t.today.isNullOrEmpty()) View.GONE else View.VISIBLE)
            setTextViewText(R.id.widget_items, t.lines.joinToString("\n"))
            setViewVisibility(R.id.widget_items, if (lines == 0 || t.lines.isEmpty()) View.GONE else View.VISIBLE)
            setInt(R.id.widget_items, "setMaxLines", lines.coerceAtLeast(1))
            setInt(R.id.widget_bg, "setImageAlpha", opacity(context, id) * 255 / 100)
            setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse(if (provider == PLAN) "baco://mealplan" else "baco://shopping"),
                ),
            )
        }
    }

    /** Same texts on normal views (preview in the settings screen). */
    fun fill(root: View, t: WidgetTexts, lines: Int) {
        root.findViewById<TextView>(R.id.widget_title).text = t.title
        root.findViewById<TextView>(R.id.widget_today).apply {
            text = t.today ?: ""
            visibility = if (t.today.isNullOrEmpty()) View.GONE else View.VISIBLE
        }
        root.findViewById<TextView>(R.id.widget_items).apply {
            text = t.lines.joinToString("\n")
            maxLines = lines.coerceAtLeast(1)
            visibility = if (lines == 0 || t.lines.isEmpty()) View.GONE else View.VISIBLE
        }
    }

    /** Redraws one widget, e.g. after its settings changed. */
    fun refresh(context: Context, provider: String, id: Int) {
        val intent = Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE).apply {
            component = ComponentName(context.packageName, provider)
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(id))
        }
        context.sendBroadcast(intent)
    }
}
