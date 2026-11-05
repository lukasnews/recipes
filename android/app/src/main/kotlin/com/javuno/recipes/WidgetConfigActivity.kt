package com.javuno.recipes

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.ImageView
import android.widget.SeekBar
import android.widget.TextView
import es.antonborri.home_widget.HomeWidgetPlugin

/** Widget settings (long press → Einstellungen, like Samsung's widgets):
 *  background transparency with a live preview. */
class WidgetConfigActivity : Activity() {
    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        widgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        // Closing without "Fertig" while placing the widget cancels it.
        setResult(RESULT_CANCELED, result())
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }
        setContentView(R.layout.widget_config)

        val manager = AppWidgetManager.getInstance(this)
        val provider = manager.getAppWidgetInfo(widgetId)?.provider?.className
            ?: BacoWidgets.SHOPPING
        val preview = findViewById<android.view.View>(R.id.preview)
        val lines = BacoWidgets.linesFor(manager.getAppWidgetOptions(widgetId)).coerceAtMost(4)
        BacoWidgets.fill(
            preview,
            BacoWidgets.texts(this, provider, HomeWidgetPlugin.getData(this), lines),
            lines,
        )
        val background = preview.findViewById<ImageView>(R.id.widget_bg)
        val label = findViewById<TextView>(R.id.opacity_label)
        val slider = findViewById<SeekBar>(R.id.opacity)

        // The slider shows transparency (0 % = solid), stored as opacity.
        fun show(transparency: Int) {
            label.text = getString(R.string.widget_settings_transparency, transparency)
            background.imageAlpha = (100 - transparency) * 255 / 100
        }
        val start = 100 - BacoWidgets.opacity(this, widgetId)
        slider.progress = start
        show(start)
        slider.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(bar: SeekBar, value: Int, fromUser: Boolean) = show(value)
            override fun onStartTrackingTouch(bar: SeekBar) {}
            override fun onStopTrackingTouch(bar: SeekBar) {}
        })

        findViewById<Button>(R.id.done).setOnClickListener {
            BacoWidgets.setOpacity(this, widgetId, 100 - slider.progress)
            BacoWidgets.refresh(this, provider, widgetId)
            setResult(RESULT_OK, result())
            finish()
        }
    }

    private fun result() = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
}
