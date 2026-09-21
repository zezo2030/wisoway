package com.abdelaziz.visionway

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONObject

object BookingNotificationHelper {
    const val CHANNEL_ID = "rideshare_notifications"
    private const val CHANNEL_NAME = "إشعارات VisionWay"

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val existing = manager.getNotificationChannel(CHANNEL_ID)
        if (existing != null) return
        val channel =
            NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "إشعارات الحجوزات والرحلات والمدفوعات والمحادثات"
            }
        manager.createNotificationChannel(channel)
    }

    fun show(context: Context, data: Map<String, String>) {
        ensureChannel(context)

        val title =
            data["title"]?.takeIf { it.isNotBlank() }
                ?: "تم حجز مقعد في رحلتك المشتركة"
        val route =
            data["route"]?.takeIf { it.isNotBlank() }
                ?: listOfNotNull(data["fromName"], data["toName"])
                    .joinToString(" - ")
                    .ifBlank { "—" }
        val departure = data["departureLabel"]?.takeIf { it.isNotBlank() } ?: "—"
        val distance =
            data["distanceLabel"]?.takeIf { it.isNotBlank() }
                ?: data["distanceKm"]?.let { "$it كم" }
                ?: "—"
        val meeting =
            data["meetingPoint"]?.takeIf { it.isNotBlank() }
                ?: data["fromAddress"]?.takeIf { it.isNotBlank() }
                ?: data["fromName"]?.takeIf { it.isNotBlank() }
                ?: "—"
        val seats =
            data["seatsLabel"]?.takeIf { it.isNotBlank() }
                ?: data["availableSeats"]?.let { "$it مقاعد" }
                ?: "—"
        val footerTitle =
            data["footerTitle"]?.takeIf { it.isNotBlank() }
                ?: "انضم راكب جديد إلى رحلتك المشتركة"
        val footerSubtitle =
            data["footerSubtitle"]?.takeIf { it.isNotBlank() }
                ?: "سيتم إعلامك عند انضمام أي راكب آخر"

        val collapsed =
            RemoteViews(context.packageName, R.layout.notification_booking_collapsed).apply {
                setTextViewText(R.id.notif_title_collapsed, title)
                setTextViewText(R.id.notif_route_collapsed, route)
            }

        val expanded =
            RemoteViews(context.packageName, R.layout.notification_booking_expanded).apply {
                setTextViewText(R.id.notif_title, title)
                setTextViewText(R.id.notif_route, route)
                setTextViewText(R.id.notif_departure, departure)
                setTextViewText(R.id.notif_distance, distance)
                setTextViewText(R.id.notif_meeting, meeting)
                setTextViewText(R.id.notif_seats, seats)
                setTextViewText(R.id.notif_footer_title, footerTitle)
                setTextViewText(R.id.notif_footer_subtitle, footerSubtitle)
            }

        val launchIntent =
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("notification_payload", JSONObject(data).toString())
            }
        val pendingIntent =
            PendingIntent.getActivity(
                context,
                (data["bookingId"] ?: data["entityId"] ?: title).hashCode(),
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

        val notificationId =
            (data["bookingId"] ?: data["entityId"] ?: System.currentTimeMillis().toString())
                .hashCode()

        val notification =
            NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.notification_icon)
                .setColor(0xFF7C6AF5.toInt())
                .setContentTitle(title)
                .setContentText(route)
                .setCustomContentView(collapsed)
                .setCustomBigContentView(expanded)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_MESSAGE)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .build()

        NotificationManagerCompat.from(context).notify(notificationId, notification)
    }
}
