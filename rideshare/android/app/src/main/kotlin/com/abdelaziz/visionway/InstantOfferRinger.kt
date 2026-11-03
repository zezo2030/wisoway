package com.abdelaziz.visionway

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Handler
import android.os.Looper

/**
 * Loops the new-ride music for an offer, from the tray notification and the
 * in-app card alike. It plays on the alarm stream, so it rings on a silent or
 * vibrating phone (the owner's call) and isn't muted or throttled the way
 * back-to-back notification sounds are. Always armed with a deadline, so an
 * offer that never says "stop" can't leave the phone ringing.
 */
object InstantOfferRinger {
    private val handler = Handler(Looper.getMainLooper())
    private var player: MediaPlayer? = null
    private var ringingOfferId: String? = null
    private val stopAtDeadline = Runnable { stop(null) }

    /** What is ringing now (an offer id or a booking key), or null. */
    val ringingId: String? get() = ringingOfferId

    fun start(context: Context, offerId: String, untilMs: Long) {
        val remainingMs = untilMs - System.currentTimeMillis()
        if (remainingMs <= 0) return
        if (ringingOfferId == offerId && player != null) {
            rearm(remainingMs)
            return
        }
        stop(null)

        val mp =
            MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                val afd =
                    context.resources.openRawResourceFd(R.raw.instant_offer_ring)
                        ?: return
                afd.use { setDataSource(it.fileDescriptor, it.startOffset, it.length) }
                isLooping = true
                setOnErrorListener { _, _, _ ->
                    stop(null)
                    true
                }
            }
        try {
            mp.prepare()
            mp.start()
        } catch (_: Exception) {
            mp.release()
            return
        }
        player = mp
        ringingOfferId = offerId
        rearm(remainingMs)
    }

    /** Stops the ring; with an [offerId], only if that offer is the one ringing. */
    fun stop(offerId: String?) {
        if (offerId != null && ringingOfferId != null && offerId != ringingOfferId) return
        handler.removeCallbacks(stopAtDeadline)
        player?.let {
            try {
                if (it.isPlaying) it.stop()
            } catch (_: Exception) {
            }
            it.release()
        }
        player = null
        ringingOfferId = null
    }

    private fun rearm(remainingMs: Long) {
        handler.removeCallbacks(stopAtDeadline)
        handler.postDelayed(stopAtDeadline, remainingMs)
    }
}
