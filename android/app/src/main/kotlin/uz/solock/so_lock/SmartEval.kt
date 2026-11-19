package uz.solock.so_lock

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.net.wifi.WifiManager
import android.os.SystemClock
import java.util.Calendar

/**
 * Decides whether locking is active right now (time window, trusted Wi-Fi, trusted places).
 * Result is cached briefly so app switches stay instant.
 */
object SmartEval {
    private var cachedAt = 0L
    private var cached = true

    fun invalidate() { cachedAt = 0L }

    fun shouldLock(ctx: Context): Boolean {
        if (!Config.scheduleOn && !Config.wifiOn && !Config.placesOn) return true
        val now = SystemClock.elapsedRealtime()
        if (now - cachedAt < 8_000) return cached
        cached = evaluate(ctx)
        cachedAt = now
        return cached
    }

    private fun evaluate(ctx: Context): Boolean {
        if (Config.scheduleOn && !inSchedule()) return false
        if (Config.wifiOn) {
            val ssid = currentSsid(ctx)
            if (ssid != null && Config.wifiSsids.contains(ssid)) return false
        }
        if (Config.placesOn && Config.places.isNotEmpty()) {
            val loc = lastLocation(ctx)
            if (loc != null) {
                val out = FloatArray(1)
                for (p in Config.places) {
                    Location.distanceBetween(loc.latitude, loc.longitude, p[0], p[1], out)
                    if (out[0] <= p[2]) return false
                }
            }
        }
        return true
    }

    private fun inSchedule(): Boolean {
        val c = Calendar.getInstance()
        val dow = ((c.get(Calendar.DAY_OF_WEEK) + 5) % 7) + 1 // Monday = 1
        val m = c.get(Calendar.HOUR_OF_DAY) * 60 + c.get(Calendar.MINUTE)
        val s = Config.scheduleStart
        val e = Config.scheduleEnd
        return if (s <= e) {
            Config.scheduleDays.contains(dow) && m in s until e
        } else {
            // window crosses midnight: the part after midnight belongs to the previous day
            if (m >= s) Config.scheduleDays.contains(dow)
            else if (m < e) Config.scheduleDays.contains(if (dow == 1) 7 else dow - 1)
            else false
        }
    }

    private fun hasLocation(ctx: Context) =
        ctx.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            ctx.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

    @Suppress("DEPRECATION")
    @SuppressLint("MissingPermission")
    fun currentSsid(ctx: Context): String? {
        if (!hasLocation(ctx)) return null
        val wm = ctx.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager ?: return null
        val raw = wm.connectionInfo?.ssid ?: return null
        val ssid = raw.trim('"')
        return if (ssid.isEmpty() || ssid == "<unknown ssid>") null else ssid
    }

    @SuppressLint("MissingPermission")
    fun lastLocation(ctx: Context): Location? {
        if (!hasLocation(ctx)) return null
        val lm = ctx.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return null
        var best: Location? = null
        for (p in runCatching { lm.getProviders(true) }.getOrDefault(emptyList())) {
            val l = runCatching { lm.getLastKnownLocation(p) }.getOrNull() ?: continue
            if (best == null || l.time > best.time) best = l
        }
        return best
    }
}
