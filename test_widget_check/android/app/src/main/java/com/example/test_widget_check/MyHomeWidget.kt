package com.example.test_widget_check

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.AsyncTask
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Implementation of App Widget functionality.
 */
class MyHomeWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            FetchPM25Task(context, appWidgetManager, appWidgetId).execute()

            // Schedule periodic updates every 1 minute
            val intent = Intent(context, MyHomeWidget::class.java)
            intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)

            val pendingIntent = PendingIntent.getBroadcast(
                context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.setRepeating(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis(),
                60000, // 1 minute
                pendingIntent
            )
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val appWidgetIds = intent.getIntArrayExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS)
            if (appWidgetIds != null) {
                onUpdate(context, appWidgetManager, appWidgetIds)
            }
        }
    }

    private class FetchPM25Task(
        val context: Context,
        val appWidgetManager: AppWidgetManager,
        val appWidgetId: Int
    ) : AsyncTask<Void, Void, String?>() {

        override fun doInBackground(vararg params: Void?): String? {
            return try {
                val widgetData = HomeWidgetPlugin.getData(context)
                val textFromFlutterApp = widgetData.getString("locationData_from_flutter", null)
                val parts = textFromFlutterApp?.split(",")
                val latitude = parts?.get(0)?.toDouble()
                val longitude = parts?.get(1)?.toDouble()
                val url = URL("https://pm25.gistda.or.th/rest/getPm25byLocation?lat=$latitude&lng=$longitude")
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                connection.connect()

                if (connection.responseCode == 200) {
                    val response = connection.inputStream.bufferedReader().use { it.readText() }
                    val jsonObject = JSONObject(response)
                    jsonObject.getJSONObject("data").getDouble("pm25").toString()
                } else {
                    null
                }
            } catch (e: Exception) {
                e.printStackTrace()
                null
            }
        }

        override fun onPostExecute(pm25Value: String?) {
            val dateNow = Date()
            val formatter = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
            val formattedDate = formatter.format(dateNow)

            val views = RemoteViews(context.packageName, R.layout.my_home_widget).apply {
                val pm25ValueDate = (pm25Value ?: "No data") + " Date: " + formattedDate
                setTextViewText(R.id.text_id, pm25ValueDate)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
