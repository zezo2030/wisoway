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

    private const val DEFAULT_OFFER_TTL_MS = 25_000L

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
        // Follow the language the Flutter app is using, not the OS locale.
        val s = NotificationLocale.strings(context)
        val fromName = data["fromName"]?.takeIf { it.isNotBlank() } ?: "—"
        val toName = data["toName"]?.takeIf { it.isNotBlank() } ?: "—"
        // Prefer formatting the raw numbers locally so the units follow the
        // app language; server-side labels are only a fallback.
        val distance =
            data["distanceKm"]?.toDoubleOrNull()?.let { s.distanceLabel(it) }
                ?: data["distanceLabel"]?.takeIf { it.isNotBlank() }
                ?: "—"
        val duration =
            data["durationMinutes"]?.toDoubleOrNull()?.let { s.durationLabel(it.toInt()) }
                ?: data["durationLabel"]?.takeIf { it.isNotBlank() }
                ?: "—"
        val fare = data["passengerFare"]?.takeIf { it.isNotBlank() } ?: data["fareEstimate"]
        val earnings =
            if (fare != null) {
                s.earningsLabel(fare, data["currency"])
            } else {
                data["earningsLabel"]?.takeIf { it.isNotBlank() } ?: "—"
            }
        val tripType = s.tripTypeDirect
        val seats =
            data["seatCount"]?.toDoubleOrNull()?.let { s.passengers(it.toInt()) }
                ?: data["seatCountLabel"]?.takeIf { it.isNotBlank() }
                ?: s.passengers(1)

        val collapsedLayout =
            if (s.isRtl) R.layout.notification_instant_collapsed
            else R.layout.notification_instant_collapsed_ltr
        val expandedLayout =
            if (s.isRtl) R.layout.notification_instant_expanded
            else R.layout.notification_instant_expanded_ltr

        val collapsed =
            RemoteViews(context.packageName, collapsedLayout).apply {
                setTextViewText(R.id.instant_hdr_now_collapsed, s.now)
                setTextViewText(R.id.instant_badge_collapsed, s.newInstantTrip)
                setTextViewText(R.id.instant_from_collapsed, "${s.fromPrefix} $fromName")
                setTextViewText(R.id.instant_to_collapsed, "${s.toPrefix} $toName")
                setTextViewText(R.id.instant_earnings_collapsed, earnings)
            }

        val expanded =
            RemoteViews(context.packageName, expandedLayout).apply {
                setTextViewText(R.id.instant_hdr_now, s.now)
                setTextViewText(R.id.instant_badge, s.newInstantTrip)
                setTextViewText(R.id.instant_lbl_from, s.from)
                setTextViewText(R.id.instant_lbl_to, s.to)
                setTextViewText(R.id.instant_lbl_distance, s.distance)
                setTextViewText(R.id.instant_lbl_duration, s.estimatedDuration)
                setTextViewText(R.id.instant_lbl_earnings, s.earnings)
                setTextViewText(R.id.instant_lbl_trip_type, s.tripType)
                setTextViewText(R.id.instant_from, fromName)
                setTextViewText(R.id.instant_to, toName)
                setTextViewText(R.id.instant_distance, distance)
                setTextViewText(R.id.instant_duration, duration)
                setTextViewText(R.id.instant_earnings, earnings)
                setTextViewText(R.id.instant_trip_type, tripType)
                setTextViewText(R.id.instant_btn_reject, s.reject)
                setTextViewText(R.id.instant_btn_accept, s.accept(secondsLeft))
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
                .setColor(0xFF2DD4BF.toInt())
                .setContentTitle(s.newInstantTrip)
                .setContentText(s.routeLine(fromName, toName))
                .setStyle(
                    NotificationCompat.BigTextStyle()
                        .bigText(
                            "${s.routeLine(fromName, toName)}\n$distance · $duration · $earnings · $tripType · $seats",
                        )
                        .setBigContentTitle(s.newInstantTrip),
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
            return System.currentTimeMillis() + DEFAULT_OFFER_TTL_MS
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
                ?: (System.currentTimeMillis() + DEFAULT_OFFER_TTL_MS)
        } catch (_: Exception) {
            System.currentTimeMillis() + DEFAULT_OFFER_TTL_MS
        }
    }
}
