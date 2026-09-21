package com.abdelaziz.visionway

import android.app.ActivityManager
import android.content.Context
import android.os.Process
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

/**
 * Intercepts rich FCM data messages (shared booking + instant offer) while
 * delegating everything else to FlutterFire.
 */
class VisionWayMessagingService : FlutterFirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        val type = data["type"]
        if (!isAppInForeground()) {
            when (type) {
                "booking_created" ->
                    BookingNotificationHelper.show(applicationContext, data)
                "instant_offer" ->
                    InstantOfferNotificationHelper.show(applicationContext, data)
            }
        }
        super.onMessageReceived(message)
    }

    private fun isAppInForeground(): Boolean {
        val activityManager =
            getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
                ?: return false
        val appProcesses = activityManager.runningAppProcesses ?: return false
        val packageName = applicationContext.packageName
        val myPid = Process.myPid()
        return appProcesses.any {
            it.pid == myPid &&
                it.processName == packageName &&
                it.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND
        }
    }
}
