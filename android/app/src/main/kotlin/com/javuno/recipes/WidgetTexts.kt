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

    /** Per-widget look, like Samsung's widget settings. */
    data class Look(
        val background: Boolean = true,
        /** Background opacity in percent (100 = solid). */
        val opacity: Int = 60,
        val colors: Colors = Colors.AUTO,
    )

    /** AUTO follows the phone's dark mode (values-night resources). */
    enum class Colors(
        val bg: Int,
        val title: Int,
        val today: Int,
        val items: Int,
    ) {
        AUTO(R.drawable.widget_bg_auto, R.color.widget_title, R.color.widget_today, R.color.widget_items),
        LIGHT(R.drawable.widget_bg_light, R.color.widget_title_light, R.color.widget_today_light, R.color.widget_items_light),
        DARK(R.drawable.widget_bg_dark, R.color.widget_title_dark, R.color.widget_today_dark, R.color.widget_items_dark),
        GREEN(R.drawable.widget_background, R.color.widget_title_green, R.color.widget_today_green, R.color.widget_items_green),
    }

    fun look(context: Context, id: Int): Look {
        val p = context.getSharedPreferences(SETTINGS, Context.MODE_PRIVATE)
        val d = Look()
        return Look(
            background = p.getBoolean("bg_$id", d.background),
            opacity = p.getInt("opacity_$id", d.opacity),
            colors = Colors.values().firstOrNull { it.name == p.getString("colors_$id", null) }
                ?: d.colors,
        )
    }

    fun saveLook(context: Context, id: Int, look: Look) {
        context.getSharedPreferences(SETTINGS, Context.MODE_PRIVATE).edit()
            .putBoolean("bg_$id", look.background)
            .putInt("opacity_$id", look.opacity)
            .putString("colors_$id", look.colors.name)
            .apply()
    }

    /** List lines that fit the widget's height (0 = only the top lines). */
    fun linesFor(options: Bundle?): Int {
        val h = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT) ?: 0
        if (h <= 0) return 6
        // padding 32 + title 26 + today 26 + gaps, then ~24dp per line
        return ((h - 92) / 24).coerceIn(0, 12)
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

    /** Open shopping rows (id, text) minus the ones just checked off in
     *  the widget; null before the app wrote any. */
    fun shoppingRows(data: SharedPreferences): List<Pair<String, String>>? {
        val json = data.getString("shopping_rows", null) ?: return null
        val pending = data.getString("checked_pending", "").orEmpty()
            .split(",").filter { it.isNotEmpty() }.toSet()
        return try {
            val array = org.json.JSONArray(json)
            (0 until array.length()).map { array.getJSONObject(it) }
                .map { it.getString("id") to it.getString("t") }
                .filter { it.first !in pending }
        } catch (e: org.json.JSONException) {
            null
        }
    }

    /** Broadcast for taps on list items; each item fills in its own URI. */
    fun checkTemplate(context: Context): android.app.PendingIntent {
        var flags = android.app.PendingIntent.FLAG_UPDATE_CURRENT
        if (android.os.Build.VERSION.SDK_INT >= 31) flags = flags or android.app.PendingIntent.FLAG_MUTABLE
        return android.app.PendingIntent.getBroadcast(
            context,
            7,
            Intent(context, BacoCheckReceiver::class.java),
            flags,
        )
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
        val shopping = provider != PLAN
        val layout = if (shopping) R.layout.shopping_list_widget else R.layout.shopping_widget
        return RemoteViews(context.packageName, layout).apply {
            setTextViewText(R.id.widget_title, t.title)
            setTextViewText(R.id.widget_today, t.today ?: "")
            setViewVisibility(R.id.widget_today, if (t.today.isNullOrEmpty()) View.GONE else View.VISIBLE)
            if (shopping) {
                // Scrollable list with check-off; the text view is its empty view.
                val rows = shoppingRows(data)
                if (rows != null) {
                    setTextViewText(R.id.widget_title, context.getString(R.string.shopping_widget_title, rows.size))
                }
                setTextViewText(
                    R.id.widget_items,
                    context.getString(if (rows == null) R.string.widget_open_app else R.string.shopping_widget_empty),
                )
                val adapter = Intent(context, ShoppingListService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                    // Unique per widget, or Android reuses another one's factory.
                    setData(Uri.parse(toUri(Intent.URI_INTENT_SCHEME)))
                }
                @Suppress("DEPRECATION")
                setRemoteAdapter(R.id.widget_list, adapter)
                setEmptyView(R.id.widget_list, R.id.widget_items)
                setPendingIntentTemplate(R.id.widget_list, checkTemplate(context))
                setViewVisibility(R.id.widget_list_frame, if (lines == 0) View.GONE else View.VISIBLE)
            } else {
                setTextViewText(R.id.widget_items, t.lines.joinToString("\n"))
                setViewVisibility(R.id.widget_items, if (lines == 0 || t.lines.isEmpty()) View.GONE else View.VISIBLE)
                setInt(R.id.widget_items, "setMaxLines", lines.coerceAtLeast(1))
            }
            val look = look(context, id)
            setImageViewResource(R.id.widget_bg, look.colors.bg)
            setInt(R.id.widget_bg, "setImageAlpha", look.opacity * 255 / 100)
            setViewVisibility(R.id.widget_bg, if (look.background) View.VISIBLE else View.GONE)
            // AUTO keeps the layout's colours, which follow dark mode.
            if (look.colors != Colors.AUTO) {
                setTextColor(R.id.widget_title, context.getColor(look.colors.title))
                setTextColor(R.id.widget_today, context.getColor(look.colors.today))
                setTextColor(R.id.widget_items, context.getColor(look.colors.items))
            }
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

    /** Same look on normal views (preview in the settings screen). */
    fun style(root: View, look: Look) {
        val c = root.context
        root.findViewById<android.widget.ImageView>(R.id.widget_bg).apply {
            setImageResource(look.colors.bg)
            imageAlpha = look.opacity * 255 / 100
            visibility = if (look.background) View.VISIBLE else View.GONE
        }
        root.findViewById<TextView>(R.id.widget_title).setTextColor(c.getColor(look.colors.title))
        root.findViewById<TextView>(R.id.widget_today).setTextColor(c.getColor(look.colors.today))
        root.findViewById<TextView>(R.id.widget_items).setTextColor(c.getColor(look.colors.items))
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
