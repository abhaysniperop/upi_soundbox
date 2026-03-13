package com.example.upi_soundbox

import android.content.Context
import android.net.wifi.WifiManager
import kotlinx.coroutines.*
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.InetAddress
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors

class ARPScanner(private val context: Context) {

    companion object {
        private val SOUNDBOX_PORTS = listOf(80, 8080, 9000, 3000, 5000, 8000)
        private val SOUNDBOX_KEYWORDS = listOf(
            "soundbox", "paytm", "phonepe", "gpay", "bharatpe",
            "upi", "payment", "pos", "merchant"
        )
        private const val CONNECT_TIMEOUT_MS = 400
        private const val HTTP_TIMEOUT_MS = 1500
        private const val MAX_PARALLEL = 32
    }

    data class ScannedDevice(
        val ip: String,
        val hostname: String,
        val mac: String,
        val isSoundbox: Boolean,
        val openPort: Int?,
        val vendorHint: String?
    )

    fun getLocalSubnet(): String? {
        val wifiManager =
            context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                ?: return null
        val wifiInfo = wifiManager.connectionInfo ?: return null
        val ipInt = wifiInfo.ipAddress
        if (ipInt == 0) return null
        val ipBytes = byteArrayOf(
            (ipInt and 0xFF).toByte(),
            (ipInt shr 8 and 0xFF).toByte(),
            (ipInt shr 16 and 0xFF).toByte(),
            (ipInt shr 24 and 0xFF).toByte()
        )
        return "${ipBytes[0].toInt() and 0xFF}.${ipBytes[1].toInt() and 0xFF}.${ipBytes[2].toInt() and 0xFF}"
    }

    suspend fun scanNetwork(
        subnet: String,
        rangeStart: Int = 1,
        rangeEnd: Int = 254,
        onProgress: (current: Int, total: Int, found: List<Map<String, Any?>>) -> Unit
    ): List<Map<String, Any?>> = coroutineScope {

        val total = rangeEnd - rangeStart + 1
        val results = mutableListOf<Map<String, Any?>>()
        val dispatcher = Executors.newFixedThreadPool(MAX_PARALLEL).asCoroutineDispatcher()

        try {
            val jobs = (rangeStart..rangeEnd).map { hostNum ->
                async(dispatcher) {
                    val ip = "$subnet.$hostNum"
                    pingAndProbe(ip)
                }
            }

            var completed = 0
            for (job in jobs) {
                val device = job.await()
                completed++
                if (device != null) {
                    results.add(deviceToMap(device))
                }
                if (completed % 5 == 0 || completed == total) {
                    onProgress(completed, total, results.toList())
                }
            }
        } finally {
            dispatcher.close()
        }

        results
    }

    private suspend fun pingAndProbe(ip: String): ScannedDevice? = withContext(Dispatchers.IO) {
        val isReachable = try {
            InetAddress.getByName(ip).isReachable(CONNECT_TIMEOUT_MS)
        } catch (_: Exception) {
            false
        }

        val arpReachable = if (!isReachable) checkArpTable(ip) else true
        if (!isReachable && !arpReachable) return@withContext null

        val hostname = try {
            InetAddress.getByName(ip).canonicalHostName.takeIf { it != ip } ?: ""
        } catch (_: Exception) {
            ""
        }

        val mac = getMacFromArp(ip)

        var openPort: Int? = null
        var isSoundbox = false
        var vendorHint: String? = null

        for (port in SOUNDBOX_PORTS) {
            if (isPortOpen(ip, port)) {
                openPort = port
                val probe = httpProbe(ip, port)
                if (probe != null) {
                    val lower = probe.lowercase()
                    isSoundbox = SOUNDBOX_KEYWORDS.any { lower.contains(it) }
                    vendorHint = detectVendor(lower)
                }
                break
            }
        }

        if (!isReachable && !arpReachable && openPort == null) return@withContext null

        ScannedDevice(
            ip = ip,
            hostname = hostname,
            mac = mac ?: "",
            isSoundbox = isSoundbox,
            openPort = openPort,
            vendorHint = vendorHint
        )
    }

    private fun checkArpTable(ip: String): Boolean {
        return try {
            val arpFile = File("/proc/net/arp")
            if (!arpFile.exists()) return false
            arpFile.readLines().any { line ->
                line.startsWith(ip) && !line.contains("00:00:00:00:00:00")
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun getMacFromArp(ip: String): String? {
        return try {
            val arpFile = File("/proc/net/arp")
            if (!arpFile.exists()) return null
            arpFile.readLines().firstOrNull { it.startsWith(ip) }
                ?.split("\\s+".toRegex())
                ?.getOrNull(3)
                ?.takeIf { it != "00:00:00:00:00:00" }
        } catch (_: Exception) {
            null
        }
    }

    private fun isPortOpen(ip: String, port: Int): Boolean {
        return try {
            val socket = java.net.Socket()
            socket.connect(
                java.net.InetSocketAddress(ip, port),
                CONNECT_TIMEOUT_MS
            )
            socket.close()
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun httpProbe(ip: String, port: Int): String? {
        return try {
            val url = URL("http://$ip:$port/")
            val conn = url.openConnection() as HttpURLConnection
            conn.connectTimeout = HTTP_TIMEOUT_MS
            conn.readTimeout = HTTP_TIMEOUT_MS
            conn.requestMethod = "GET"
            conn.setRequestProperty("User-Agent", "UPI-Soundbox-Scanner/1.0")
            val code = conn.responseCode
            val body = try {
                BufferedReader(InputStreamReader(conn.inputStream))
                    .use { it.readText().take(512) }
            } catch (_: Exception) {
                ""
            }
            conn.disconnect()
            "$code $body"
        } catch (_: Exception) {
            null
        }
    }

    private fun detectVendor(body: String): String? = when {
        body.contains("paytm") -> "paytm"
        body.contains("phonepe") -> "phonepe"
        body.contains("gpay") || body.contains("google pay") -> "gpay"
        body.contains("bharatpe") -> "bharatpe"
        body.contains("upi") || body.contains("payment") -> "generic"
        else -> null
    }

    private fun deviceToMap(device: ScannedDevice): Map<String, Any?> = mapOf(
        "ip" to device.ip,
        "hostname" to device.hostname,
        "mac" to device.mac,
        "isSoundbox" to device.isSoundbox,
        "openPort" to device.openPort,
        "vendorHint" to device.vendorHint
    )
}
