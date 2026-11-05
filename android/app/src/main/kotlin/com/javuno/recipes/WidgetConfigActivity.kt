package com.javuno.recipes

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.Button
import android.widget.RadioGroup
import android.widget.SeekBar
import android.widget.Switch
import android.widget.TextView
import es.antonborri.home_widget.HomeWidgetPlugin

/** Widget settings (long press → Einstellungen), laid out like Samsung's:
 *  live preview on the real wallpaper, background on/off, opacity, colours. */
class WidgetConfigActivity : Activity() {
    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    private val colorButtons = mapOf(
        R.id.colors_auto to BacoWidgets.Colors.AUTO,
        R.id.colors_light to BacoWidgets.Colors.LIGHT,
        R.id.colors_dark to BacoWidgets.Colors.DARK,
        R.id.colors_green to BacoWidgets.Colors.GREEN,
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        widgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        // Leaving without "Speichern" while placing the widget cancels it.
        setResult(RESULT_CANCELED, result())
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }
        setContentView(R.layout.widget_config)

        val manager = AppWidgetManager.getInstance(this)
        val provider = manager.getAppWidgetInfo(widgetId)?.provider?.className
            ?: BacoWidgets.SHOPPING
        val preview = findViewById<View>(R.id.preview)
        val lines = BacoWidgets.linesFor(manager.getAppWidgetOptions(widgetId)).coerceIn(1, 4)
        BacoWidgets.fill(
            preview,
            BacoWidgets.texts(this, provider, HomeWidgetPlugin.getData(this), lines),
            lines,
        )

        val background = findViewById<Switch>(R.id.background)
        val opacityLabel = findViewById<TextView>(R.id.opacity_label)
        val opacity = findViewById<SeekBar>(R.id.opacity)
        val colors = findViewById<RadioGroup>(R.id.colors)

        var look = BacoWidgets.look(this, widgetId)
        fun show() {
            opacityLabel.text = getString(R.string.widget_settings_opacity, look.opacity)
            opacity.isEnabled = look.background
            opacityLabel.alpha = if (look.background) 1f else 0.4f
            BacoWidgets.style(preview, look)
        }
        background.isChecked = look.background
        opacity.progress = look.opacity
        colors.check(colorButtons.entries.first { it.value == look.colors }.key)
        show()

        background.setOnCheckedChangeListener { _, on ->
            look = look.copy(background = on)
            show()
        }
        opacity.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(bar: SeekBar, value: Int, fromUser: Boolean) {
                look = look.copy(opacity = value)
                show()
            }
            override fun onStartTrackingTouch(bar: SeekBar) {}
            override fun onStopTrackingTouch(bar: SeekBar) {}
        })
        colors.setOnCheckedChangeListener { _, checkedId ->
            look = look.copy(colors = colorButtons[checkedId] ?: BacoWidgets.Colors.AUTO)
            show()
        }

        findViewById<Button>(R.id.cancel).setOnClickListener { finish() }
        findViewById<Button>(R.id.done).setOnClickListener {
            BacoWidgets.saveLook(this, widgetId, look)
            BacoWidgets.refresh(this, provider, widgetId)
            setResult(RESULT_OK, result())
            finish()
        }
    }

    private fun result() = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
}
