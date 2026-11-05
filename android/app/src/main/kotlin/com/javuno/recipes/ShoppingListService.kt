package com.javuno.recipes

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin

/** Rows of the shopping widget's list, one per open item. */
class ShoppingListService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        Factory(
            applicationContext,
            intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID),
        )

    private class Factory(private val context: Context, private val widgetId: Int) :
        RemoteViewsFactory {
        private var rows: List<Pair<String, String>> = emptyList()

        override fun onCreate() {}

        override fun onDataSetChanged() {
            rows = BacoWidgets.shoppingRows(HomeWidgetPlugin.getData(context)).orEmpty()
        }

        override fun onDestroy() {}

        override fun getCount() = rows.size

        override fun getViewAt(position: Int): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_item)
            val (id, text) = rows.getOrNull(position) ?: return views
            val look = BacoWidgets.look(context, widgetId)
            val color = context.getColor(look.colors.items)
            views.setTextViewText(R.id.item_text, text)
            views.setTextColor(R.id.item_text, color)
            views.setInt(R.id.item_check, "setColorFilter", color)
            views.setContentDescription(
                R.id.item_root,
                context.getString(R.string.shopping_widget_check) + ": " + text,
            )
            views.setOnClickFillInIntent(
                R.id.item_root,
                Intent().setData(Uri.parse("baco://check?id=" + Uri.encode(id))),
            )
            return views
        }

        override fun getLoadingView(): RemoteViews? = null

        override fun getViewTypeCount() = 1

        override fun getItemId(position: Int) = rows.getOrNull(position)?.first?.hashCode()?.toLong() ?: position.toLong()

        override fun hasStableIds() = true
    }
}
