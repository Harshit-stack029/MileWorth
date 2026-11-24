package com.mileworth.mileworth

import android.content.Context
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mileworth/region")
            .setMethodCallHandler { call, result ->
                if (call.method == "countryCode") result.success(detectCountry())
                else result.notImplemented()
            }
    }

    /**
     * Country the phone is in, without location permission or internet:
     * the mobile network's country (follows the user when roaming), then the
     * SIM's country, then the device region setting. Null if none is known.
     */
    private fun detectCountry(): String? {
        val tm = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
        val candidates = listOf(
            runCatching { tm?.networkCountryIso }.getOrNull(),
            runCatching { tm?.simCountryIso }.getOrNull(),
            Locale.getDefault().country,
        )
        return candidates.firstOrNull { !it.isNullOrBlank() && it.length == 2 }
            ?.uppercase(Locale.ROOT)
    }
}
