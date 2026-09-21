package com.abdelaziz.visionway

import android.content.Context
import java.util.Locale

/**
 * Resolves the language the Flutter app is currently using (not the OS locale)
 * and provides the localized strings used by the native rich notifications.
 *
 * The Flutter side persists its language via `shared_preferences`, which on
 * Android writes to the `FlutterSharedPreferences` file with a `flutter.` key
 * prefix. Reading it here keeps background notifications in sync with the app
 * without needing the Dart isolate to be alive.
 */
object NotificationLocale {
    private const val PREFS_FILE = "FlutterSharedPreferences"
    private const val PREFS_KEY = "flutter.language"
    const val LANG_AR = "ar"
    const val LANG_EN = "en"

    fun appLanguage(context: Context): String {
        val stored =
            try {
                context.applicationContext
                    .getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
                    .getString(PREFS_KEY, null)
            } catch (_: Exception) {
                null
            }
        return if (stored?.lowercase(Locale.ROOT)?.startsWith(LANG_EN) == true) LANG_EN else LANG_AR
    }

    fun strings(context: Context): NotificationStrings =
        if (appLanguage(context) == LANG_EN) NotificationStrings.EN else NotificationStrings.AR
}

class NotificationStrings private constructor(
    val isRtl: Boolean,
    val now: String,
    val newInstantTrip: String,
    val from: String,
    val to: String,
    val distance: String,
    val estimatedDuration: String,
    val earnings: String,
    val tripType: String,
    val tripTypeDirect: String,
    val reject: String,
    val fromPrefix: String,
    val toPrefix: String,
    val kmUnit: String,
    val minuteUnit: String,
    val hourUnit: String,
    private val passengerWord: String,
    private val acceptWord: String,
    private val secondSuffix: String,
    private val currencySymbols: Map<String, String>,
) {
    fun accept(secondsLeft: Int): String = "$acceptWord ($secondsLeft$secondSuffix)"

    fun passengers(count: Int): String = "$count $passengerWord"

    fun distanceLabel(km: Double): String {
        val rounded = Math.round(km * 10) / 10.0
        val text =
            if (Math.abs(rounded - Math.round(rounded)) < 0.05) {
                Math.round(rounded).toString()
            } else {
                String.format(Locale.US, "%.1f", rounded)
            }
        return "$text $kmUnit"
    }

    fun durationLabel(minutes: Int): String {
        val mins = Math.max(1, minutes)
        if (mins < 60) return "$mins $minuteUnit"
        val hours = mins / 60
        val rem = mins % 60
        if (rem == 0) return "$hours $hourUnit"
        return "$hours $hourUnit $rem $minuteUnit"
    }

    fun earningsLabel(amount: String?, currency: String?): String {
        val numeric = amount?.toDoubleOrNull()
        val formatted =
            if (numeric != null) String.format(Locale.US, "%.2f", numeric) else amount?.ifBlank { null }
        if (formatted == null) return "—"
        val code = currency?.trim().orEmpty()
        val symbol = currencySymbols[code] ?: currencySymbols.entries.firstOrNull { it.value == code }?.value ?: code
        return if (symbol.isBlank()) formatted else "$formatted $symbol"
    }

    fun routeLine(fromName: String, toName: String): String = "$fromPrefix $fromName $toPrefix $toName"

    companion object {
        val AR =
            NotificationStrings(
                isRtl = true,
                now = "الآن",
                newInstantTrip = "رحلة مباشرة جديدة",
                from = "من",
                to = "إلى",
                distance = "المسافة",
                estimatedDuration = "المدة التقديرية",
                earnings = "الأرباح",
                tripType = "نوع الرحلة",
                tripTypeDirect = "مباشرة",
                reject = "رفض",
                fromPrefix = "من",
                toPrefix = "إلى",
                kmUnit = "كم",
                minuteUnit = "د",
                hourUnit = "س",
                passengerWord = "راكب",
                acceptWord = "قبول",
                secondSuffix = "ث",
                currencySymbols = mapOf("JOD" to "د.أ", "د.أ" to "د.أ", "SAR" to "ر.س", "ر.س" to "ر.س"),
            )

        val EN =
            NotificationStrings(
                isRtl = false,
                now = "now",
                newInstantTrip = "New direct trip",
                from = "From",
                to = "To",
                distance = "Distance",
                estimatedDuration = "Est. duration",
                earnings = "Earnings",
                tripType = "Trip type",
                tripTypeDirect = "Direct",
                reject = "Reject",
                fromPrefix = "From",
                toPrefix = "to",
                kmUnit = "km",
                minuteUnit = "min",
                hourUnit = "h",
                passengerWord = "passengers",
                acceptWord = "Accept",
                secondSuffix = "s",
                currencySymbols = mapOf("JOD" to "JOD", "د.أ" to "JOD", "SAR" to "SAR", "ر.س" to "SAR"),
            )
    }
}
