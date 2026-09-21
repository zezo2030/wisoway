package com.abdelaziz.visionway

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.ConcurrentHashMap

object InstantOfferNotificationHelper {
    const val ACTION_ACCEPT = "accept"
    const val ACTION_DECLINE = "decline"
    const val ACTION_OPEN = "open"
    const val EXTRA_OFFER_ACTION = "instant_offer_action"
    const val EXTRA_OFFER_ID = "instant_offer_id"
    const val EXTRA_PAYLOAD = "notification_payload"

    private val handler = Handler(Looper.getMainLooper())
    private val tickers = ConcurrentHashMap<String, Runnable>()

    fun show(context: Context, data: Map<String, String>) {
        BookingNotificationHelper.ensureChannel(context)

        val offerId = data["offerId"]?.takeIf { it.isNotBlank() } ?: return
        val expiresAtMs = parseExpiresAtMs(data["expiresAt"])
        val secondsLeft = ((expiresAtMs - System.currentTimeMillis()) / 1000).toInt()
        if (secondsLeft <= 0) {
            cancel(context, offerId)
            return
        }

        postNotification(context, data, secondsLeft)
        startTicker(context, data, offerId, expiresAtMs)
    }

    fun cancel(context: Context, offerId: String) {
        stopTicker(offerId)
        NotificationManagerCompat.from(context).cancel(notificationId(offerId))
    }

    private fun startTicker(
        context: Context,
        data: Map<String, String>,
        offerId: String,
        expiresAtMs: Long,
    ) {
        stopTicker(offerId)
        val appContext = context.applicationContext
        val runnable =
            object : Runnable {
                override fun run() {
                    val left =
                        ((expiresAtMs - System.currentTimeMillis()) / 1000).toInt()
                    if (left <= 0) {
                        cancel(appContext, offerId)
                        return
                    }
                    postNotification(appContext, data, left)
                    handler.postDelayed(this, 1000L)
                }
            }
        tickers[offerId] = runnable
        handler.postDelayed(runnable, 1000L)
    }

    private fun stopTicker(offerId: String) {
        tickers.remove(offerId)?.let { handler.removeCallbacks(it) }
    }

    private fun postNotification(
        context: Context,
        data: Map<String, String>,
        secondsLeft: Int,
    ) {
        val offerId = data["offerId"] ?: return
        val fromName = data["fromName"]?.takeIf { it.isNotBlank() } ?: "—"
        val toName = data["toName"]?.takeIf { it.isNotBlank() } ?: "—"
        val distance =
            data["distanceLabel"]?.takeIf { it.isNotBlank() }
                ?: data["distanceKm"]?.let { "$it كم" }
                ?: "—"
        val duration =
            data["durationLabel"]?.takeIf { it.isNotBlank() }
                ?: data["durationMinutes"]?.let { "$it د" }
                ?: "—"
        val earnings =
            data["earningsLabel"]?.takeIf { it.isNotBlank() }
                ?: listOfNotNull(
                        data["passengerFare"] ?: data["fareEstimate"],
                        data["currency"],
                    ).joinToString(" ")
                    .ifBlank { "—" }
        val seats =
            data["seatCountLabel"]?.takeIf { it.isNotBlank() }
                ?: data["seatCount"]?.takeIf { it.isNotBlank() }?.let { "$it راكب" }
                ?: "1 راكب"

        val collapsed =
            RemoteViews(context.packageName, R.layout.notification_instant_collapsed).apply {
                setTextViewText(R.id.instant_from_collapsed, "من $fromName")
                setTextViewText(R.id.instant_to_collapsed, "إلى $toName")
                setTextViewText(R.id.instant_earnings_collapsed, earnings)
            }

        val expanded =
            RemoteViews(context.packageName, R.layout.notification_instant_expanded).apply {
                setTextViewText(R.id.instant_from, fromName)
                setTextViewText(R.id.instant_to, toName)
                setTextViewText(R.id.instant_distance, distance)
                setTextViewText(R.id.instant_duration, duration)
                setTextViewText(R.id.instant_earnings, earnings)
                setTextViewText(R.id.instant_trip_type, seats)
                setTextViewText(R.id.instant_btn_reject, "تجاهل")
                setTextViewText(R.id.instant_btn_accept, "قبول الرحلة (${secondsLeft}ث)")
                setOnClickPendingIntent(
                    R.id.instant_btn_accept,
                    actionPendingIntent(context, offerId, ACTION_ACCEPT, data),
                )
                setOnClickPendingIntent(
                    R.id.instant_btn_reject,
                    actionPendingIntent(context, offerId, ACTION_DECLINE, data),
                )
            }

        val openIntent =
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra(EXTRA_OFFER_ACTION, ACTION_OPEN)
                putExtra(EXTRA_OFFER_ID, offerId)
                putExtra(EXTRA_PAYLOAD, JSONObject(data).toString())
            }
        val contentPending =
            PendingIntent.getActivity(
                context,
                notificationId(offerId),
                openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

        val notification =
            NotificationCompat.Builder(context, BookingNotificationHelper.CHANNEL_ID)
                .setSmallIcon(R.drawable.notification_icon)
                .setColor(0xFF007D69.toInt())
                .setContentTitle("طلب رحلة جديدة")
                .setContentText("رحلة مباشرة بدون توقف")
                .setStyle(
                    NotificationCompat.BigTextStyle()
                        .bigText(
                            "رحلة مباشرة بدون توقف\nمن $fromName إلى $toName\n$earnings · $seats",
                        )
                        .setBigContentTitle("طلب رحلة جديدة"),
                )
                .setCustomContentView(collapsed)
                .setCustomBigContentView(expanded)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setOngoing(true)
                .setAutoCancel(false)
                .setOnlyAlertOnce(true)
                .setContentIntent(contentPending)
                .setTimeoutAfter(
                    (secondsLeft * 1000L).coerceAtLeast(1000L),
                )
                .build()

        NotificationManagerCompat.from(context).notify(notificationId(offerId), notification)
    }

    private fun actionPendingIntent(
        context: Context,
        offerId: String,
        action: String,
        data: Map<String, String>,
    ): PendingIntent {
        val intent =
            Intent(context, InstantOfferActionReceiver::class.java).apply {
                this.action = "com.abdelaziz.visionway.INSTANT_OFFER_$action"
                putExtra(EXTRA_OFFER_ACTION, action)
                putExtra(EXTRA_OFFER_ID, offerId)
                putExtra(EXTRA_PAYLOAD, JSONObject(data).toString())
            }
        return PendingIntent.getBroadcast(
            context,
            (offerId + action).hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    fun notificationId(offerId: String): Int = ("instant_offer_$offerId").hashCode()

    private fun parseExpiresAtMs(raw: String?): Long {
        if (raw.isNullOrBlank()) {
            return System.currentTimeMillis() + 12_000L
        }
        return try {
            val parser =
                SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
                    timeZone = TimeZone.getTimeZone("UTC")
                }
            parser.parse(raw)?.time
                ?: SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
                    .apply { timeZone = TimeZone.getTimeZone("UTC") }
                    .parse(raw)
                    ?.time
                ?: (System.currentTimeMillis() + 12_000L)
        } catch (_: Exception) {
            System.currentTimeMillis() + 12_000L
        }
    }
}
