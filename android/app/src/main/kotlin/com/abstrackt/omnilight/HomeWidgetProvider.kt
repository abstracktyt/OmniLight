package com.abstrackt.omnilight

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetProvider

class HomeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                val statusText = widgetData.getString("widget_status", "Disconnected")
                setTextViewText(R.id.tv_status, statusText)

                // Quick Color Deep Links
                val pendingIntentRed = HomeWidgetBackgroundIntent.getBroadcast(
                    context, 
                    android.net.Uri.parse("omnilight://color?hex=FF0000")
                )
                setOnClickPendingIntent(R.id.btn_red, pendingIntentRed)

                val pendingIntentGreen = HomeWidgetBackgroundIntent.getBroadcast(
                    context, 
                    android.net.Uri.parse("omnilight://color?hex=00FF00")
                )
                setOnClickPendingIntent(R.id.btn_green, pendingIntentGreen)

                val pendingIntentBlue = HomeWidgetBackgroundIntent.getBroadcast(
                    context, 
                    android.net.Uri.parse("omnilight://color?hex=0000FF")
                )
                setOnClickPendingIntent(R.id.btn_blue, pendingIntentBlue)

                val pendingIntentWhite = HomeWidgetBackgroundIntent.getBroadcast(
                    context, 
                    android.net.Uri.parse("omnilight://color?hex=FFFFFF")
                )
                setOnClickPendingIntent(R.id.btn_white, pendingIntentWhite)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
