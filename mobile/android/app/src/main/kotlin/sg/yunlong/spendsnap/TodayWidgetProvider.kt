package sg.yunlong.spendsnap

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * The Home Screen widget: today's next three things to do, how many are
 * done and the streak. The app sends the words through MainActivity each
 * time something changes; the widget only shows the last ones it got.
 */
class TodayWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        manager.updateAppWidget(ids, views(context))
    }

    companion object {
        private const val PREFS = "today_widget"
        private const val KEY = "json"

        /** Keeps what the app sent and redraws every widget on the Home Screen. */
        fun save(context: Context, json: String) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY, json)
                .apply()
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, TodayWidgetProvider::class.java))
            if (ids.isNotEmpty()) manager.updateAppWidget(ids, views(context))
        }

        private fun JSONObject.text(name: String): String? = if (isNull(name)) null else optString(name)

        private fun views(context: Context): RemoteViews {
            val v = RemoteViews(context.packageName, R.layout.today_widget)
            // A tap anywhere opens the app.
            context.packageManager.getLaunchIntentForPackage(context.packageName)?.let {
                val open = PendingIntent.getActivity(
                    context,
                    0,
                    it,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                )
                v.setOnClickPendingIntent(R.id.today_root, open)
            }

            val rows = intArrayOf(R.id.today_task1, R.id.today_task2, R.id.today_task3)
            for (row in rows) v.setViewVisibility(row, View.GONE)
            v.setViewVisibility(R.id.today_more, View.GONE)
            v.setViewVisibility(R.id.today_done, View.GONE)
            v.setViewVisibility(R.id.today_streak, View.GONE)

            val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null)
            val data = raw?.let { runCatching { JSONObject(it) }.getOrNull() }
            if (data == null) {
                // Not opened since the widget was added.
                v.setTextViewText(R.id.today_title, context.getString(R.string.today_widget_name))
                v.setTextViewText(R.id.today_empty, context.getString(R.string.today_widget_open))
                v.setViewVisibility(R.id.today_empty, View.VISIBLE)
                return v
            }

            v.setTextViewText(R.id.today_title, data.text("title") ?: context.getString(R.string.today_widget_name))
            val streak = data.optInt("streak", 0)
            if (streak > 0) {
                v.setTextViewText(R.id.today_streak, "🔥 " + (data.text("streakText") ?: streak.toString()))
                v.setViewVisibility(R.id.today_streak, View.VISIBLE)
            }

            // Words from another day: ask her to open the app rather than show old tasks.
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
            if (data.text("day") != today) {
                v.setTextViewText(R.id.today_empty, data.text("stale") ?: context.getString(R.string.today_widget_open))
                v.setViewVisibility(R.id.today_empty, View.VISIBLE)
                return v
            }

            val tasks = data.optJSONArray("tasks")
            val count = minOf(tasks?.length() ?: 0, rows.size)
            for (i in 0 until count) {
                val task = tasks!!.optJSONObject(i) ?: continue
                val time = task.text("time")
                val title = task.text("title") ?: ""
                v.setTextViewText(rows[i], if (time != null) "$time  $title" else "•  $title")
                v.setViewVisibility(rows[i], View.VISIBLE)
            }
            if (count == 0) {
                v.setTextViewText(R.id.today_empty, data.text("empty") ?: "")
                v.setViewVisibility(R.id.today_empty, View.VISIBLE)
            } else {
                v.setViewVisibility(R.id.today_empty, View.GONE)
            }
            data.text("more")?.let {
                v.setTextViewText(R.id.today_more, it)
                v.setViewVisibility(R.id.today_more, View.VISIBLE)
            }
            data.text("done")?.let {
                v.setTextViewText(R.id.today_done, it)
                v.setViewVisibility(R.id.today_done, View.VISIBLE)
            }
            return v
        }
    }
}
