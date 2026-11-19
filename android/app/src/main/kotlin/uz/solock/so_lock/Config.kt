package uz.solock.so_lock

import android.content.Context
import org.json.JSONObject

/** Native-side view of the settings the background service needs. Written by Dart. */
object Config {
    private const val PREFS = "solock_native"
    private const val KEY = "cfg"

    @Volatile var enabled = false
    @Volatile var locked: Set<String> = emptySet()
    @Volatile var relock = "exit"          // exit | screen | timeout
    @Volatile var relockMinutes = 1

    // Smart lock
    @Volatile var scheduleOn = false
    @Volatile var scheduleStart = 0        // minute of day
    @Volatile var scheduleEnd = 0
    @Volatile var scheduleDays: Set<Int> = (1..7).toSet() // 1 = Monday
    @Volatile var wifiOn = false
    @Volatile var wifiSsids: Set<String> = emptySet()
    @Volatile var placesOn = false
    @Volatile var places: List<DoubleArray> = emptyList() // lat, lng, radius

    fun load(ctx: Context) {
        val raw = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null) ?: return
        runCatching { apply(JSONObject(raw)) }
    }

    fun save(ctx: Context, raw: String) {
        apply(JSONObject(raw))
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, raw).apply()
        SmartEval.invalidate()
    }

    private fun apply(j: JSONObject) {
        enabled = j.optBoolean("enabled", false)
        locked = j.optJSONArray("locked")?.let { a -> (0 until a.length()).map { a.getString(it) }.toSet() } ?: emptySet()
        relock = j.optString("relock", "exit")
        relockMinutes = j.optInt("relockMinutes", 1)

        val smart = j.optJSONObject("smart") ?: JSONObject()
        smart.optJSONObject("schedule")?.let { s ->
            scheduleOn = s.optBoolean("on")
            scheduleStart = s.optInt("start")
            scheduleEnd = s.optInt("end")
            scheduleDays = s.optJSONArray("days")?.let { a -> (0 until a.length()).map { a.getInt(it) }.toSet() } ?: (1..7).toSet()
        } ?: run { scheduleOn = false }
        smart.optJSONObject("wifi")?.let { w ->
            wifiOn = w.optBoolean("on")
            wifiSsids = w.optJSONArray("ssids")?.let { a -> (0 until a.length()).map { a.getString(it) }.toSet() } ?: emptySet()
        } ?: run { wifiOn = false }
        smart.optJSONObject("places")?.let { p ->
            placesOn = p.optBoolean("on")
            places = p.optJSONArray("list")?.let { a ->
                (0 until a.length()).map {
                    val o = a.getJSONObject(it)
                    doubleArrayOf(o.getDouble("lat"), o.getDouble("lng"), o.optDouble("r", 150.0))
                }
            } ?: emptyList()
        } ?: run { placesOn = false }
    }
}
