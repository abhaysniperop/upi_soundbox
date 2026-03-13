package com.example.upi_soundbox

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

class MainActivity : FlutterActivity() {

    companion object {
        const val METHOD_CHANNEL = "com.example.upi_soundbox/arp_scanner"
        const val EVENT_CHANNEL = "com.example.upi_soundbox/arp_scanner_progress"
    }

    private val mainScope = MainScope()
    private var activeScanJob: Job? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val scanner = ARPScanner(this)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSubnet" -> {
                    val subnet = scanner.getLocalSubnet()
                    if (subnet != null) result.success(subnet)
                    else result.error("NO_WIFI", "Not connected to WiFi", null)
                }

                "cancelScan" -> {
                    activeScanJob?.cancel()
                    activeScanJob = null
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EVENT_CHANNEL
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                val args = arguments as? Map<*, *>
                val subnet = args?.get("subnet") as? String
                    ?: scanner.getLocalSubnet()
                    ?: run {
                        events.error("NO_WIFI", "Not connected to WiFi", null)
                        return
                    }
                val rangeStart = (args?.get("rangeStart") as? Int) ?: 1
                val rangeEnd = (args?.get("rangeEnd") as? Int) ?: 254

                activeScanJob = mainScope.launch {
                    try {
                        scanner.scanNetwork(
                            subnet = subnet,
                            rangeStart = rangeStart,
                            rangeEnd = rangeEnd,
                            onProgress = { current, total, found ->
                                val update = mapOf(
                                    "type" to "progress",
                                    "current" to current,
                                    "total" to total,
                                    "devices" to found
                                )
                                events.success(update)
                            }
                        )
                        events.success(mapOf("type" to "done"))
                        events.endOfStream()
                    } catch (e: CancellationException) {
                        events.success(mapOf("type" to "cancelled"))
                        events.endOfStream()
                    } catch (e: Exception) {
                        events.error("SCAN_ERROR", e.message, null)
                    }
                }
            }

            override fun onCancel(arguments: Any?) {
                activeScanJob?.cancel()
                activeScanJob = null
            }
        })
    }

    override fun onDestroy() {
        mainScope.cancel()
        super.onDestroy()
    }
}
