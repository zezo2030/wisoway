package com.abdelaziz.visionway

import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.ProgressBar
import android.widget.TextView
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

/**
 * The ride-offer card drawn over whatever app the driver is in, like the
 * in-app InstantOfferDialog — a tray notification can't be more than a small
 * heads-up. Needs "Display over other apps"; without it the notification is
 * all the driver gets.
 *
 * Accept opens the app, which accepts and takes the driver into the ride.
 * Ignore declines from here, so the driver stays where they were.
 */
object InstantOfferOverlay {
    private val handler = Handler(Looper.getMainLooper())
    private var view: View? = null
    private var shownOfferId: String? = null
    private var ticker: Runnable? = null

    /**
     * The signed-in driver's API access, handed over by the app
     * (`setOfferApiAuth`). In memory only: if the process was restarted
     * without the app, Ignore falls back to opening the app to decline.
     */
    @Volatile var apiBaseUrl: String? = null

    @Volatile var accessToken: String? = null

    val isShowing: Boolean get() = view != null

    /** Shows the card; false when the permission is missing or it failed. */
    fun show(
        context: Context,
        data: Map<String, String>,
        expiresAtMs: Long,
    ): Boolean {
        if (!InstantOfferNotificationHelper.canDrawOverApps(context)) return false
        val offerId = data["offerId"] ?: return false
        val app = context.applicationContext
        if (Looper.myLooper() != Looper.getMainLooper()) {
            // FCM delivers on a worker thread; windows belong on the main one.
            handler.post { show(app, data, expiresAtMs) }
            return true
        }
        if (shownOfferId == offerId && view != null) return true
        dismiss(null)

        val s = NotificationLocale.strings(app)
        val root =
            try {
                LayoutInflater.from(app).inflate(R.layout.overlay_instant_offer, null)
            } catch (_: Exception) {
                return false
            }
        root.layoutDirection =
            if (s.isRtl) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR
        bind(root, s, data)

        val totalSeconds =
            ((expiresAtMs - System.currentTimeMillis()) / 1000).toInt().coerceAtLeast(1)
        val progress = root.findViewById<ProgressBar>(R.id.overlay_progress)
        progress.max = totalSeconds * 10
        val countdown = root.findViewById<TextView>(R.id.overlay_countdown)

        root.findViewById<View>(R.id.overlay_accept).setOnClickListener {
            answer(app, data, offerId, InstantOfferNotificationHelper.ACTION_ACCEPT)
        }
        root.findViewById<View>(R.id.overlay_ignore).setOnClickListener {
            ignore(app, data, offerId)
        }
        // The rest of the job (map, passenger, full addresses) is in the app.
        root.findViewById<View>(R.id.overlay_details).setOnClickListener {
            answer(app, data, offerId, InstantOfferNotificationHelper.ACTION_OPEN)
        }

        val params =
            WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE
                },
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_DIM_BEHIND,
                PixelFormat.TRANSLUCENT,
            ).apply {
                gravity = Gravity.CENTER
                dimAmount = 0.45f
            }
        try {
            windowManager(app).addView(root, params)
        } catch (_: Exception) {
            return false
        }
        view = root
        shownOfferId = offerId

        val tick =
            object : Runnable {
                override fun run() {
                    val leftMs = expiresAtMs - System.currentTimeMillis()
                    if (leftMs <= 0) {
                        dismiss(offerId)
                        return
                    }
                    progress.progress = (leftMs / 100).toInt()
                    countdown.text = s.countdown(((leftMs + 999) / 1000).toInt())
                    handler.postDelayed(this, 100L)
                }
            }
        ticker = tick
        tick.run()
        return true
    }

    /** Takes the card down; with an [offerId], only if it is that offer's. */
    fun dismiss(offerId: String?) {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            handler.post { dismiss(offerId) }
            return
        }
        if (offerId != null && shownOfferId != null && offerId != shownOfferId) return
        ticker?.let { handler.removeCallbacks(it) }
        ticker = null
        view?.let { v ->
            try {
                windowManager(v.context).removeView(v)
            } catch (_: Exception) {
            }
        }
        view = null
        shownOfferId = null
    }

    private fun bind(
        root: View,
        s: NotificationStrings,
        data: Map<String, String>,
    ) {
        fun text(
            id: Int,
            value: String,
        ) {
            root.findViewById<TextView>(id).text = value
        }
        val fare = data["passengerFare"]?.takeIf { it.isNotBlank() } ?: data["fareEstimate"]
        val fareLabel =
            if (fare != null) {
                s.earningsLabel(fare, data["currency"])
            } else {
                data["earningsLabel"]?.takeIf { it.isNotBlank() } ?: "—"
            }
        val pickup =
            data["pickupDistanceKm"]?.toDoubleOrNull()?.let { s.distanceLabel(it) }
                ?: data["pickupDistanceLabel"]?.takeIf { it.isNotBlank() }
        val distance =
            data["distanceKm"]?.toDoubleOrNull()?.let { s.distanceLabel(it) }
                ?: data["distanceLabel"]?.takeIf { it.isNotBlank() }
                ?: "—"
        val duration =
            data["durationMinutes"]?.toDoubleOrNull()?.let { s.durationLabel(it.toInt()) }
                ?: data["durationLabel"]?.takeIf { it.isNotBlank() }
                ?: "—"

        text(R.id.overlay_title, s.cardTitle)
        text(R.id.overlay_badge, s.tripTypeDirect)
        text(R.id.overlay_earnings_label, s.expectedEarnings)
        text(R.id.overlay_fare, fareLabel)
        text(R.id.overlay_payment_note, if (data["paymentMethod"] == "cliq") s.cliqNote else s.cashNote)
        text(R.id.overlay_from_label, s.from)
        text(R.id.overlay_from, data["fromName"]?.takeIf { it.isNotBlank() } ?: "—")
        text(R.id.overlay_to_label, s.to)
        text(R.id.overlay_to, data["toName"]?.takeIf { it.isNotBlank() } ?: "—")
        text(R.id.overlay_pickup_label, s.pickupDistance)
        if (pickup != null) {
            text(R.id.overlay_pickup, pickup)
        } else {
            root.findViewById<View>(R.id.overlay_pickup_cell).visibility = View.GONE
        }
        text(R.id.overlay_distance_label, s.tripDistance)
        text(R.id.overlay_distance, distance)
        text(R.id.overlay_duration_label, s.estimatedDuration)
        text(R.id.overlay_duration, duration)
        text(R.id.overlay_details, s.openDetails)
        text(R.id.overlay_ignore, s.ignore)
        text(R.id.overlay_accept, s.acceptTrip)
    }

    /** Hands the answer to the app, which opens on it (accept / details). */
    private fun answer(
        context: Context,
        data: Map<String, String>,
        offerId: String,
        action: String,
    ) {
        if (action == InstantOfferNotificationHelper.ACTION_OPEN) {
            // The in-app card takes over the same offer and keeps its music.
            dismiss(offerId)
        } else {
            InstantOfferNotificationHelper.cancel(context, offerId)
        }
        val intent =
            Intent(context, MainActivity::class.java).apply {
                flags =
                    Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra(InstantOfferNotificationHelper.EXTRA_OFFER_ACTION, action)
                putExtra(InstantOfferNotificationHelper.EXTRA_OFFER_ID, offerId)
                putExtra(InstantOfferNotificationHelper.EXTRA_PAYLOAD, JSONObject(data).toString())
            }
        try {
            context.startActivity(intent)
        } catch (_: Exception) {
        }
    }

    /** Declines without leaving the app the driver is in, when we can. */
    private fun ignore(
        context: Context,
        data: Map<String, String>,
        offerId: String,
    ) {
        InstantOfferNotificationHelper.cancel(context, offerId)
        val base = apiBaseUrl
        val token = accessToken
        if (base.isNullOrBlank() || token.isNullOrBlank()) {
            answer(context, data, offerId, InstantOfferNotificationHelper.ACTION_DECLINE)
            return
        }
        thread(name = "offer-decline") {
            val ok =
                try {
                    val conn =
                        URL("$base/instant-rides/offers/$offerId/decline").openConnection()
                            as HttpURLConnection
                    conn.requestMethod = "POST"
                    conn.connectTimeout = 8000
                    conn.readTimeout = 8000
                    conn.setRequestProperty("Authorization", "Bearer $token")
                    conn.setRequestProperty("Content-Type", "application/json")
                    conn.doOutput = true
                    conn.outputStream.use { it.write("{}".toByteArray()) }
                    val code = conn.responseCode
                    conn.disconnect()
                    // 404/409: the offer is already gone — nothing left to decline.
                    code in 200..299 || code == 404 || code == 409
                } catch (_: Exception) {
                    false
                }
            if (!ok) {
                // Expired token or no network: let the app decline it.
                handler.post {
                    answer(context, data, offerId, InstantOfferNotificationHelper.ACTION_DECLINE)
                }
            }
        }
    }

    private fun windowManager(context: Context): WindowManager =
        context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
}
