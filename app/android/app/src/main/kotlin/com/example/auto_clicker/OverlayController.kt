package com.sarmatcz.tapmacro

import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.provider.Settings
import android.util.DisplayMetrics
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import io.flutter.plugin.common.EventChannel
import kotlin.math.abs
import kotlin.math.roundToInt

class OverlayController private constructor(private val context: Context) {
    private val windowManager =
        context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

    private var bubbleView: View? = null
    private var emergencyStopView: View? = null
    private var panelView: View? = null
    private var markerViews: MutableList<View> = mutableListOf()
    private var pointPickerView: View? = null
    private var markerEditorControlView: View? = null
    private var markerEditorItems: MutableList<MarkerEditorItem> = mutableListOf()
    private var panelVisible = false
    private var markersVisible = true
    private var onStartRun: (() -> Unit)? = null
    private var onPauseRun: (() -> Unit)? = null
    private var onStopRun: (() -> Unit)? = null
    private var eventSink: EventChannel.EventSink? = null

    fun setRunCallbacks(
        onStart: (() -> Unit)?,
        onPause: (() -> Unit)?,
        onStop: (() -> Unit)?
    ) {
        onStartRun = onStart
        onPauseRun = onPause
        onStopRun = onStop
    }

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    fun start(): Boolean {
        if (isRunning()) {
            return true
        }
        if (!Settings.canDrawOverlays(context)) {
            return false
        }

        createBubble()
        createEmergencyStop()
        createPanel()
        return true
    }

    fun stop() {
        removeView(bubbleView)
        removeView(emergencyStopView)
        removeView(panelView)
        markerViews.forEach { removeView(it) }
        stopPointPickerInternal()
        stopMarkerEditorInternal()
        bubbleView = null
        emergencyStopView = null
        panelView = null
        markerViews = mutableListOf()
        panelVisible = false
        markersVisible = true
    }

    fun isRunning(): Boolean {
        return bubbleView != null
    }

    fun updateRunMarkersFromScript(payload: Map<*, *>) {
        if (!isRunning()) {
            return
        }
        val rawSteps = payload["steps"] as? List<*> ?: return
        val points = rawSteps.mapNotNull { raw ->
            val step = raw as? Map<*, *> ?: return@mapNotNull null
            if (step["enabled"] != true) {
                return@mapNotNull null
            }
            val x = (step["x"] as? Number)?.toDouble() ?: return@mapNotNull null
            val y = (step["y"] as? Number)?.toDouble() ?: return@mapNotNull null
            OverlayPoint(
                id = step["id"]?.toString() ?: "step",
                x = x.coerceIn(0.0, 1.0),
                y = y.coerceIn(0.0, 1.0)
            )
        }
        if (points.isEmpty()) {
            return
        }
        markerViews.forEach { removeView(it) }
        markerViews = mutableListOf()
        createRunMarkers(points)
    }

    fun startPointPicker(): Boolean {
        if (!Settings.canDrawOverlays(context)) {
            emitError("OVERLAY_PERMISSION_REQUIRED", "Overlay permission is required.")
            return false
        }
        if (pointPickerView != null) {
            return true
        }

        val metrics = getDisplayMetrics()
        val maxX = (metrics.widthPixels - 1).coerceAtLeast(1)
        val maxY = (metrics.heightPixels - 1).coerceAtLeast(1)
        var centerX = (maxX / 2f)
        var centerY = (maxY / 2f)

        val root = FrameLayout(context).apply {
            setBackgroundColor(Color.parseColor("#33000000"))
        }

        val title = TextView(context).apply {
            text = "Pick Point"
            setTextColor(Color.WHITE)
            textSize = 18f
            setPadding(dp(16), dp(24), dp(16), dp(8))
        }
        root.addView(
            title,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.TOP or Gravity.START,
            )
        )

        val hint = TextView(context).apply {
            text = "Tap or drag target, then press Confirm"
            setTextColor(Color.WHITE)
            textSize = 14f
            setPadding(dp(16), dp(52), dp(16), dp(8))
        }
        root.addView(
            hint,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.TOP or Gravity.START,
            )
        )

        val target = TextView(context).apply {
            text = "+"
            textSize = 32f
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#AA106B5A"))
                setStroke(dp(2), Color.WHITE)
            }
        }
        val targetSize = dp(48)
        val targetLp = FrameLayout.LayoutParams(targetSize, targetSize).apply {
            leftMargin = (centerX - targetSize / 2f).roundToInt().coerceIn(0, maxX - targetSize)
            topMargin = (centerY - targetSize / 2f).roundToInt().coerceIn(0, maxY - targetSize)
        }
        root.addView(target, targetLp)

        fun moveTarget(x: Float, y: Float) {
            centerX = x.coerceIn((targetSize / 2f), (maxX - targetSize / 2f))
            centerY = y.coerceIn((targetSize / 2f), (maxY - targetSize / 2f))
            targetLp.leftMargin = (centerX - targetSize / 2f).roundToInt()
            targetLp.topMargin = (centerY - targetSize / 2f).roundToInt()
            target.layoutParams = targetLp
        }

        root.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN,
                MotionEvent.ACTION_MOVE -> {
                    moveTarget(event.rawX, event.rawY)
                    true
                }
                else -> false
            }
        }

        val controls = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END
            setPadding(dp(12), dp(12), dp(12), dp(24))
        }
        val cancel = Button(context).apply {
            text = "Cancel"
            setOnClickListener {
                emitEvent(mapOf("type" to "pick_cancel"))
                stopPointPickerInternal()
            }
        }
        val confirm = Button(context).apply {
            text = "Confirm"
            setOnClickListener {
                val normalizedX = (centerX / maxX).toDouble().coerceIn(0.0, 1.0)
                val normalizedY = (centerY / maxY).toDouble().coerceIn(0.0, 1.0)
                emitEvent(
                    mapOf(
                        "type" to "pick_result",
                        "x" to normalizedX,
                        "y" to normalizedY
                    )
                )
                stopPointPickerInternal()
            }
        }
        controls.addView(cancel)
        controls.addView(confirm)
        root.addView(
            controls,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM,
            )
        )

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            overlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 0
            y = 0
        }

        windowManager.addView(root, params)
        pointPickerView = root
        return true
    }

    fun startMarkerEditor(rawPoints: List<Map<*, *>>): Boolean {
        if (!Settings.canDrawOverlays(context)) {
            emitError("OVERLAY_PERMISSION_REQUIRED", "Overlay permission is required.")
            return false
        }
        val points = rawPoints.mapNotNull { raw ->
            val id = raw["id"]?.toString() ?: return@mapNotNull null
            val x = (raw["x"] as? Number)?.toDouble() ?: return@mapNotNull null
            val y = (raw["y"] as? Number)?.toDouble() ?: return@mapNotNull null
            OverlayPoint(id = id, x = x.coerceIn(0.0, 1.0), y = y.coerceIn(0.0, 1.0))
        }
        if (points.isEmpty()) {
            emitError("MARKER_EDITOR_EMPTY", "No points available to edit.")
            return false
        }

        stopMarkerEditorInternal()
        createMarkerEditorMarkers(points)
        createMarkerEditorControls()
        return true
    }

    fun stopMarkerEditor(): Boolean {
        if (markerEditorControlView == null && markerEditorItems.isEmpty()) {
            return false
        }
        stopMarkerEditorInternal()
        return true
    }

    private fun createBubble() {
        val bubble = TextView(context).apply {
            text = "AC"
            textSize = 15f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#0F766E"))
                setStroke(dp(1), Color.parseColor("#064E3B"))
            }
            val size = dp(54)
            layoutParams = LinearLayout.LayoutParams(size, size)
            elevation = 6f
        }

        val params = WindowManager.LayoutParams(
            dp(54),
            dp(54),
            overlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = dp(16)
            y = dp(128)
        }

        var touchX = 0f
        var touchY = 0f
        var startX = 0
        var startY = 0
        var dragged = false
        val touchSlop = ViewConfiguration.get(context).scaledTouchSlop

        bubble.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    touchX = event.rawX
                    touchY = event.rawY
                    startX = params.x
                    startY = params.y
                    dragged = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - touchX
                    val dy = event.rawY - touchY
                    if (!dragged && (abs(dx) > touchSlop || abs(dy) > touchSlop)) {
                        dragged = true
                    }
                    if (dragged) {
                        params.x = startX + dx.toInt()
                        params.y = startY + dy.toInt()
                        windowManager.updateViewLayout(bubble, params)
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!dragged) {
                        togglePanel()
                    }
                    true
                }
                MotionEvent.ACTION_CANCEL -> true
                else -> false
            }
        }

        windowManager.addView(bubble, params)
        bubbleView = bubble
    }

    private fun createPanel() {
        val container = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(12), dp(10), dp(12), dp(12))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(14).toFloat()
                setColor(Color.parseColor("#FAFCFF"))
                setStroke(dp(1), Color.parseColor("#D8E2EA"))
            }
            elevation = 7f
        }

        val header = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val title = TextView(context).apply {
            text = "Quick Controls"
            setTextColor(Color.parseColor("#0F172A"))
            textSize = 14f
            setPadding(0, 0, dp(8), 0)
        }

        val subtitle = TextView(context).apply {
            text = "Tap AC to hide panel"
            setTextColor(Color.parseColor("#64748B"))
            textSize = 12f
        }

        val collapse = TextView(context).apply {
            text = "×"
            textSize = 18f
            setTextColor(Color.parseColor("#475569"))
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#E2E8F0"))
            }
            setPadding(dp(8), dp(2), dp(8), dp(2))
            setOnClickListener { togglePanel() }
        }

        val titleWrap = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            addView(title)
            addView(subtitle)
        }

        header.addView(titleWrap)
        header.addView(collapse)

        val controls = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, dp(10), 0, 0)
        }

        val startButton = createActionButton(
            label = "Resume",
            backgroundColor = "#0F766E",
            textColor = Color.WHITE,
        ).apply {
            setOnClickListener { onStartRun?.invoke() }
        }
        val pauseButton = createActionButton(
            label = "Pause",
            backgroundColor = "#F59E0B",
            textColor = Color.WHITE,
        ).apply {
            text = "Pause"
            setOnClickListener { onPauseRun?.invoke() }
        }
        val stopButton = createActionButton(
            label = "Stop",
            backgroundColor = "#DC2626",
            textColor = Color.WHITE,
        ).apply {
            setOnClickListener {
                onStopRun?.invoke()
                stop()
            }
        }

        val markerButton = createActionButton(
            label = markerButtonLabel(),
            backgroundColor = "#E2E8F0",
            textColor = Color.parseColor("#0F172A"),
        ).apply {
            setOnClickListener {
                toggleMarkers()
                text = markerButtonLabel()
            }
        }

        controls.addView(startButton, createActionButtonLayoutParams(0))
        controls.addView(pauseButton, createActionButtonLayoutParams(dp(8)))
        controls.addView(stopButton, createActionButtonLayoutParams(dp(8)))
        controls.addView(markerButton, createActionButtonLayoutParams(dp(8)))
        container.addView(header)
        container.addView(controls)

        val params = WindowManager.LayoutParams(
            dp(228),
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = dp(16)
            y = dp(198)
        }

        container.visibility = View.GONE
        windowManager.addView(container, params)
        panelView = container
    }

    private fun createEmergencyStop() {
        val emergencyButton = TextView(context).apply {
            text = "STOP"
            textSize = 13f
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            setPadding(dp(16), dp(10), dp(16), dp(10))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(22).toFloat()
                setColor(Color.parseColor("#DC2626"))
                setStroke(dp(1), Color.parseColor("#991B1B"))
            }
            elevation = 6f
            setOnClickListener {
                onStopRun?.invoke()
                this@OverlayController.stop()
            }
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.END
            x = dp(12)
            y = dp(108)
        }

        windowManager.addView(emergencyButton, params)
        emergencyStopView = emergencyButton
    }

    private fun createRunMarkers(points: List<OverlayPoint>) {
        val metrics = getDisplayMetrics()
        val maxX = (metrics.widthPixels - 1).coerceAtLeast(1)
        val maxY = (metrics.heightPixels - 1).coerceAtLeast(1)
        val markers = mutableListOf<View>()
        points.forEachIndexed { index, point ->
            val marker = TextView(context).apply {
                text = (index + 1).toString()
                textSize = 14f
                setTextColor(Color.WHITE)
                gravity = Gravity.CENTER
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(Color.parseColor("#1A9B84"))
                }
            }
            val params = WindowManager.LayoutParams(
                dp(36),
                dp(36),
                overlayType(),
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
                PixelFormat.TRANSLUCENT,
            ).apply {
                gravity = Gravity.TOP or Gravity.START
                x = (point.x * maxX).roundToInt().coerceIn(0, maxX)
                y = (point.y * maxY).roundToInt().coerceIn(0, maxY)
            }

            var touchX = 0f
            var touchY = 0f
            var startX = 0
            var startY = 0
            marker.setOnTouchListener { _, event ->
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        touchX = event.rawX
                        touchY = event.rawY
                        startX = params.x
                        startY = params.y
                        true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        params.x = (startX + (event.rawX - touchX).toInt()).coerceIn(0, maxX)
                        params.y = (startY + (event.rawY - touchY).toInt()).coerceIn(0, maxY)
                        windowManager.updateViewLayout(marker, params)
                        true
                    }
                    else -> false
                }
            }

            windowManager.addView(marker, params)
            markers.add(marker)
        }
        markerViews = markers
    }

    private fun createMarkerEditorMarkers(points: List<OverlayPoint>) {
        val metrics = getDisplayMetrics()
        val maxX = (metrics.widthPixels - 1).coerceAtLeast(1)
        val maxY = (metrics.heightPixels - 1).coerceAtLeast(1)
        val items = mutableListOf<MarkerEditorItem>()

        points.forEachIndexed { index, point ->
            val marker = TextView(context).apply {
                text = (index + 1).toString()
                textSize = 14f
                setTextColor(Color.WHITE)
                gravity = Gravity.CENTER
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(Color.parseColor("#2E7D32"))
                    setStroke(dp(2), Color.WHITE)
                }
            }

            val params = WindowManager.LayoutParams(
                dp(42),
                dp(42),
                overlayType(),
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
                PixelFormat.TRANSLUCENT,
            ).apply {
                gravity = Gravity.TOP or Gravity.START
                x = (point.x * maxX).roundToInt().coerceIn(0, maxX)
                y = (point.y * maxY).roundToInt().coerceIn(0, maxY)
            }

            var touchX = 0f
            var touchY = 0f
            var startX = 0
            var startY = 0
            marker.setOnTouchListener { _, event ->
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        touchX = event.rawX
                        touchY = event.rawY
                        startX = params.x
                        startY = params.y
                        true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        params.x = (startX + (event.rawX - touchX).toInt()).coerceIn(0, maxX)
                        params.y = (startY + (event.rawY - touchY).toInt()).coerceIn(0, maxY)
                        windowManager.updateViewLayout(marker, params)
                        true
                    }
                    else -> false
                }
            }

            windowManager.addView(marker, params)
            items.add(MarkerEditorItem(point.id, marker, params))
        }

        markerEditorItems = items
    }

    private fun createMarkerEditorControls() {
        val controls = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END
            setPadding(dp(12), dp(12), dp(12), dp(12))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(12).toFloat()
                setColor(Color.parseColor("#F6FFFC"))
                setStroke(dp(1), Color.parseColor("#B7DFD6"))
            }
            elevation = 8f
        }

        val cancel = Button(context).apply {
            text = "Cancel"
            setOnClickListener {
                emitEvent(mapOf("type" to "markers_cancelled"))
                stopMarkerEditorInternal()
            }
        }
        val save = Button(context).apply {
            text = "Save"
            setOnClickListener {
                emitEvent(
                    mapOf(
                        "type" to "markers_updated",
                        "points" to buildMarkerEditorPoints()
                    )
                )
                stopMarkerEditorInternal()
            }
        }

        controls.addView(cancel)
        controls.addView(save)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.END
            x = dp(16)
            y = dp(32)
        }

        windowManager.addView(controls, params)
        markerEditorControlView = controls
    }

    private fun buildMarkerEditorPoints(): List<Map<String, Any>> {
        val metrics = getDisplayMetrics()
        val maxX = (metrics.widthPixels - 1).coerceAtLeast(1)
        val maxY = (metrics.heightPixels - 1).coerceAtLeast(1)
        return markerEditorItems.map { item ->
            val x = (item.params.x.toDouble() / maxX).coerceIn(0.0, 1.0)
            val y = (item.params.y.toDouble() / maxY).coerceIn(0.0, 1.0)
            mapOf(
                "id" to item.id,
                "x" to x,
                "y" to y
            )
        }
    }

    private fun togglePanel() {
        val panel = panelView ?: return
        panelVisible = !panelVisible
        panel.visibility = if (panelVisible) View.VISIBLE else View.GONE
    }

    private fun markerButtonLabel(): String {
        return if (markersVisible) "Hide Markers" else "Show Markers"
    }

    private fun toggleMarkers() {
        markersVisible = !markersVisible
        markerViews.forEach { marker ->
            marker.visibility = if (markersVisible) View.VISIBLE else View.GONE
        }
    }

    private fun stopPointPickerInternal() {
        removeView(pointPickerView)
        pointPickerView = null
    }

    private fun stopMarkerEditorInternal() {
        markerEditorItems.forEach { item -> removeView(item.view) }
        markerEditorItems = mutableListOf()
        removeView(markerEditorControlView)
        markerEditorControlView = null
    }

    private fun emitEvent(event: Map<String, Any>) {
        eventSink?.success(event)
    }

    private fun emitError(code: String, message: String) {
        emitEvent(
            mapOf(
                "type" to "error",
                "code" to code,
                "message" to message,
            )
        )
    }

    private fun removeView(view: View?) {
        if (view == null) {
            return
        }
        try {
            windowManager.removeView(view)
        } catch (_: Exception) {
            // Ignore view removal exceptions during cleanup.
        }
    }

    private fun createActionButton(
        label: String,
        backgroundColor: String,
        textColor: Int,
    ): Button {
        return Button(context).apply {
            text = label
            isAllCaps = false
            setTextColor(textColor)
            textSize = 14f
            minHeight = dp(42)
            minimumHeight = dp(42)
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(10).toFloat()
                setColor(Color.parseColor(backgroundColor))
            }
        }
    }

    private fun createActionButtonLayoutParams(topMargin: Int): LinearLayout.LayoutParams {
        return LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT,
        ).apply {
            this.topMargin = topMargin
        }
    }

    private fun overlayType(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            WindowManager.LayoutParams.TYPE_PHONE
        }
    }

    private fun dp(value: Int): Int {
        val density = context.resources.displayMetrics.density
        return (value * density).roundToInt()
    }

    private fun getDisplayMetrics(): DisplayMetrics {
        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        windowManager.defaultDisplay.getRealMetrics(metrics)
        return metrics
    }

    companion object {
        @Volatile
        private var instance: OverlayController? = null

        fun getInstance(context: Context): OverlayController {
            return instance ?: synchronized(this) {
                instance ?: OverlayController(context.applicationContext).also { instance = it }
            }
        }
    }
}

private data class OverlayPoint(
    val id: String,
    val x: Double,
    val y: Double,
)

private data class MarkerEditorItem(
    val id: String,
    val view: View,
    val params: WindowManager.LayoutParams,
)

