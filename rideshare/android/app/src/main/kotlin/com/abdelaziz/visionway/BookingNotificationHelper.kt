package com.abdelaziz.visionway

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.media.AudioAttributes
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

object BookingNotificationHelper {
    /** Same id, name and sound as NotificationSound.general on the Dart side. */
    const val CHANNEL_ID = "sound_general"
    private const val CHANNEL_NAME = "إشعارات عامة"

    /**
     * Booking requests post on their own channel. Like ride offers, the
     * channel is silent and [InstantOfferRinger] plays the music, which rings
     * on a silent or vibrating phone where a channel sound stays mute. A
     * channel's sound is fixed once created, hence the new id.
     */
    private const val REQUEST_CHANNEL_ID = "booking_requests_v3"
    private val OLD_REQUEST_CHANNEL_IDS = listOf("booking_requests_v2")
    private val REQUEST_VIBRATION = longArrayOf(0, 400, 250, 400, 900)

    /** How long the music plays; the request itself stays up until answered. */
    private const val RING_MS = 60_000L

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
                    description = "الإشعارات التي ليس لها صوت خاص"
                    setSound(
                        Uri.parse(
                            "${ContentResolver.SCHEME_ANDROID_RESOURCE}://${context.packageName}/raw/sound_general",
                        ),
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build(),
                    )
                },
            )
        }
        if (manager.getNotificationChannel(REQUEST_CHANNEL_ID) == null) {
            OLD_REQUEST_CHANNEL_IDS.forEach { manager.deleteNotificationChannel(it) }
            manager.createNotificationChannel(
                NotificationChannel(
                    REQUEST_CHANNEL_ID,
                    "طلبات الحجز",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "طلبات الركاب للانضمام إلى رحلاتك المشتركة"
                    setSound(null, null)
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
                ?: "اقبل الطلب أو ارفضه"

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

        // The request waits for the driver: no countdown on screen. It only
        // leaves the tray, quietly, once the server's window has closed.
        collapsed.setViewVisibility(R.id.notif_countdown_collapsed, View.GONE)
        expanded.setViewVisibility(R.id.notif_countdown, View.GONE)
        val expiresAtMs = parseIsoMs(data["expiresAt"])
        val nowMs = System.currentTimeMillis()
        if (expiresAtMs != null && expiresAtMs <= nowMs) return

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

        // As with a ride offer: the card over whatever app is open, else a
        // full-screen launch that wakes the phone over the lock screen. With
        // the card up, the tray entry stays quiet so no heads-up covers it.
        val overlaid = InstantOfferOverlay.showBooking(context, data)
        val builder =
            NotificationCompat.Builder(
                context,
                if (overlaid) InstantOfferNotificationHelper.QUIET_CHANNEL_ID else REQUEST_CHANNEL_ID,
            )
                .setSmallIcon(R.drawable.notification_icon)
                .setColor(0xFF7C6AF5.toInt())
                .setContentTitle(title)
                .setContentText(route)
                .setCustomContentView(collapsed)
                .setCustomBigContentView(expanded)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setVibrate(REQUEST_VIBRATION)
                .setOngoing(true)
                .setAutoCancel(false)
                .setOnlyAlertOnce(true)
                .setContentIntent(launchPendingIntent(context, data, bookingKey, null))
        if (!overlaid) {
            builder.setFullScreenIntent(fullScreenPendingIntent(context, data, bookingKey), true)
        }
        if (expiresAtMs != null) {
            builder.setTimeoutAfter((expiresAtMs - nowMs).coerceAtLeast(1000L))
        }

        NotificationManagerCompat.from(context).notify(notificationId, builder.build())

        // A ride offer that is ringing keeps the music: it is gone in seconds.
        val ringing = InstantOfferRinger.ringingId
        if (ringing == null || ringing.startsWith(InstantOfferOverlay.bookingKey(""))) {
            InstantOfferRinger.start(
                context.applicationContext,
                InstantOfferOverlay.bookingKey(bookingKey),
                nowMs + RING_MS,
            )
        }
    }

    /** Opens the app on the request (and the driver's choice), taking it down here. */
    fun open(
        context: Context,
        data: Map<String, String>,
        action: String?,
    ) {
        val bookingKey = data["bookingId"] ?: data["entityId"] ?: return
        cancel(context, bookingKey)
        try {
            context.startActivity(launchIntent(context, data, action))
        } catch (_: Exception) {
        }
    }

    /**
     * The request was answered, cancelled or expired elsewhere. [keepRing] is
     * for the in-app card taking over the same request.
     */
    fun cancel(context: Context, bookingId: String, keepRing: Boolean = false) {
        val key = InstantOfferOverlay.bookingKey(bookingId)
        if (!keepRing) InstantOfferRinger.stop(key)
        InstantOfferOverlay.dismiss(key)
        NotificationManagerCompat.from(context).cancel(notificationId(bookingId))
    }

    private fun notificationId(bookingKey: String): Int = ("booking_request_$bookingKey").hashCode()

    private fun launchPendingIntent(
        context: Context,
        data: Map<String, String>,
        bookingKey: String,
        action: String?,
    ): PendingIntent =
        PendingIntent.getActivity(
            context,
            (bookingKey + (action ?: "open")).hashCode(),
            launchIntent(context, data, action),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    private fun fullScreenPendingIntent(
        context: Context,
        data: Map<String, String>,
        bookingKey: String,
    ): PendingIntent =
        PendingIntent.getActivity(
            context,
            (bookingKey + "fullscreen").hashCode(),
            launchIntent(context, data, null)
                .putExtra(InstantOfferNotificationHelper.EXTRA_OVER_LOCK_SCREEN, true),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    private fun launchIntent(
        context: Context,
        data: Map<String, String>,
        action: String?,
    ): Intent {
        val payload = if (action == null) data else data + (EXTRA_BOOKING_ACTION to action)
        return Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("notification_payload", JSONObject(payload).toString())
        }
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
