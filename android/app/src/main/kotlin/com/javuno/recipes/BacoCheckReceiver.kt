package com.javuno.recipes

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import es.antonborri.home_widget.HomeWidgetBackgroundReceiver
import es.antonborri.home_widget.HomeWidgetPlugin

/** A shopping item tapped in the widget: hide it right away, then let the
 *  app's Dart callback (widgetInteraction) check it off in Firestore. */
class BacoCheckReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val uri = intent.data ?: return
        val id = uri.getQueryParameter("id") ?: return

        val data = HomeWidgetPlugin.getData(context)
        val pending = data.getString("checked_pending", "").orEmpty()
            .split(",").filter { it.isNotEmpty() }.toMutableSet()
        pending.add(id)
        data.edit().putString("checked_pending", pending.joinToString(",")).commit()

        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, ShoppingWidgetProvider::class.java))
        ShoppingWidgetProvider().onUpdate(context, manager, ids, data)

        val forward = Intent(context, HomeWidgetBackgroundReceiver::class.java)
            .setAction("es.antonborri.home_widget.action.BACKGROUND")
            .setData(uri)
        HomeWidgetBackgroundReceiver().onReceive(context, forward)
    }
}
