package com.abdelaziz.visionway

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

object BookingNotificationHelper {
    const val CHANNEL_ID = "rideshare_notifications"
    private const val CHANNEL_NAME = "إشعارات VisionWay"

    /** Booking requests chime on their own channel (a channel's sound is fixed). */
    private const val REQUEST_CHANNEL_ID = "booking_requests_v1"
    private val REQUEST_VIBRATION = longArrayOf(0, 300, 200, 300)

    const val EXTRA_BOOKING_ACTION = "bookingAction"
    const val ACTION_ACCEPT = "accept"
    const val ACTION_REJECT = "reject"

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "إشعارات الحجوزات والرحلات والمدفوعات والمحادثات"
                },
            )
        }
        if (manager.getNotificationChannel(REQUEST_CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(
                    REQUEST_CHANNEL_ID,
                    "طلبات الحجز",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "طلبات الركاب للانضمام إلى رحلاتك المشتركة"
                    setSound(
                        InstantOfferNotificationHelper.soundUri(context),
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build(),
                    )
                    enableVibration(true)
                    vibrationPattern = REQUEST_VIBRATION
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                },
            )
        }
    }

    fun show(context: Context, data: Map<String, String>) {
        ensureChannel(context)

        val title =
            data["title"]?.takeIf { it.isNotBlank() }
                ?: "طلب حجز جديد في رحلتك المشتركة"
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
                ?: "راكب يطلب الانضمام إلى رحلتك"
        // Who is asking and for what, so the driver can answer from here.
        val requestLine =
            listOfNotNull(
                data["passengerName"]?.takeIf { it.isNotBlank() },
                data["seatCount"]?.takeIf { it.isNotBlank() }?.let { "$it مقعد" },
                data["totalAmount"]?.takeIf { it.isNotBlank() }
                    ?.let { "$it ${data["currency"] ?: ""}".trim() },
            ).joinToString(" · ")
        val footerSubtitle =
            requestLine.takeIf { it.isNotBlank() }
                ?: data["footerSubtitle"]?.takeIf { it.isNotBlank() }
                ?: "اقبل الطلب أو ارفضه قبل انتهاء المهلة"

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

        val bookingKey = data["bookingId"] ?: data["entityId"] ?: title
        val notificationId = notificationId(bookingKey)

        // The request has to be answered, so it sits pinned with the time left
        // until the server's acceptance window closes, then removes itself.
        val expiresAtMs = parseIsoMs(data["expiresAt"])
        val nowMs = System.currentTimeMillis()
        if (expiresAtMs != null && expiresAtMs <= nowMs) return
        if (expiresAtMs != null) {
            // Chronometer base is on the elapsed-realtime clock.
            val base = SystemClock.elapsedRealtime() + (expiresAtMs - nowMs)
            collapsed.setChronometer(R.id.notif_countdown_collapsed, base, "⏱ %s", true)
            collapsed.setChronometerCountDown(R.id.notif_countdown_collapsed, true)
            expanded.setChronometer(R.id.notif_countdown, base, "ينتهي خلال %s", true)
            expanded.setChronometerCountDown(R.id.notif_countdown, true)
        } else {
            collapsed.setViewVisibility(R.id.notif_countdown_collapsed, View.GONE)
            expanded.setViewVisibility(R.id.notif_countdown, View.GONE)
        }

        // Both buttons open the app straight onto the answer, where accept can
        // still fail on wallet balance and be reported properly.
        expanded.setOnClickPendingIntent(
            R.id.notif_btn_accept,
            launchPendingIntent(context, data, bookingKey, ACTION_ACCEPT),
        )
        expanded.setOnClickPendingIntent(
            R.id.notif_btn_reject,
            launchPendingIntent(context, data, bookingKey, ACTION_REJECT),
        )

        val builder =
            NotificationCompat.Builder(context, REQUEST_CHANNEL_ID)
                .setSmallIcon(R.drawable.notification_icon)
                .setColor(0xFF7C6AF5.toInt())
                .setContentTitle(title)
                .setContentText(route)
                .setCustomContentView(collapsed)
                .setCustomBigContentView(expanded)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setSound(InstantOfferNotificationHelper.soundUri(context), AudioManager.STREAM_RING)
                .setVibrate(REQUEST_VIBRATION)
                .setOngoing(true)
                .setAutoCancel(false)
                .setOnlyAlertOnce(true)
                .setContentIntent(launchPendingIntent(context, data, bookingKey, null))
        if (expiresAtMs != null) {
            builder
                .setWhen(expiresAtMs)
                .setTimeoutAfter((expiresAtMs - nowMs).coerceAtLeast(1000L))
        }

        NotificationManagerCompat.from(context).notify(notificationId, builder.build())
    }

    /** The request was answered, cancelled or expired elsewhere. */
    fun cancel(context: Context, bookingId: String) {
        NotificationManagerCompat.from(context).cancel(notificationId(bookingId))
    }

    private fun notificationId(bookingKey: String): Int = ("booking_request_$bookingKey").hashCode()

    private fun launchPendingIntent(
        context: Context,
        data: Map<String, String>,
        bookingKey: String,
        action: String?,
    ): PendingIntent {
        val payload = if (action == null) data else data + (EXTRA_BOOKING_ACTION to action)
        val intent =
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("notification_payload", JSONObject(payload).toString())
            }
        return PendingIntent.getActivity(
            context,
            (bookingKey + (action ?: "open")).hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun parseIsoMs(raw: String?): Long? {
        if (raw.isNullOrBlank()) return null
        for (pattern in listOf("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", "yyyy-MM-dd'T'HH:mm:ss'Z'")) {
            try {
                val parser =
                    SimpleDateFormat(pattern, Locale.US).apply {
                        timeZone = TimeZone.getTimeZone("UTC")
                    }
                parser.parse(raw)?.time?.let { return it }
            } catch (_: Exception) {
            }
        }
        return null
    }
}
