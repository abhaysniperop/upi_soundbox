import Flutter
import UIKit
import Network

@main
@objc class AppDelegate: FlutterAppDelegate {

    private let methodChannelName = "com.example.upi_soundbox/arp_scanner"
    private let eventChannelName  = "com.example.upi_soundbox/arp_scanner_progress"

    private var eventSink: FlutterEventSink?
    private var scanTask: Task<Void, Never>?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        let controller = window?.rootViewController as! FlutterViewController
        let messenger   = controller.binaryMessenger

        FlutterMethodChannel(name: methodChannelName, binaryMessenger: messenger)
            .setMethodCallHandler { [weak self] call, result in
                switch call.method {
                case "getSubnet":
                    if let subnet = self?.getLocalSubnet() {
                        result(subnet)
                    } else {
                        result(FlutterError(code: "NO_WIFI",
                                            message: "Could not detect subnet",
                                            details: nil))
                    }
                case "cancelScan":
                    self?.scanTask?.cancel()
                    self?.scanTask = nil
                    result(nil)
                default:
                    result(FlutterMethodNotImplemented)
                }
            }

        FlutterEventChannel(name: eventChannelName, binaryMessenger: messenger)
            .setStreamHandler(self)

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func getLocalSubnet() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            let flags = Int32(ptr!.pointee.ifa_flags)
            let addr  = ptr!.pointee.ifa_addr.pointee
            guard (flags & (IFF_UP | IFF_RUNNING | IFF_LOOPBACK)) == (IFF_UP | IFF_RUNNING),
                  addr.sa_family == UInt8(AF_INET) else { continue }
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(ptr!.pointee.ifa_addr, socklen_t(addr.sa_len),
                           &hostname, socklen_t(hostname.count),
                           nil, 0, NI_NUMERICHOST) == 0 {
                let ip = String(cString: hostname)
                if ip.hasPrefix("192.") || ip.hasPrefix("10.") || ip.hasPrefix("172.") {
                    address = ip
                    break
                }
            }
        }

        guard let ip = address else { return nil }
        let parts = ip.split(separator: ".")
        guard parts.count == 4 else { return nil }
        return "\(parts[0]).\(parts[1]).\(parts[2])"
    }
}

extension AppDelegate: FlutterStreamHandler {

    func onListen(withArguments arguments: Any?,
                  eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events

        let args       = arguments as? [String: Any]
        let subnet     = (args?["subnet"] as? String) ?? getLocalSubnet() ?? "192.168.1"
        let rangeStart = (args?["rangeStart"] as? Int) ?? 1
        let rangeEnd   = (args?["rangeEnd"]   as? Int) ?? 254

        scanTask = Task {
            await runScan(subnet: subnet, rangeStart: rangeStart, rangeEnd: rangeEnd)
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        scanTask?.cancel()
        scanTask = nil
        eventSink = nil
        return nil
    }

    private func runScan(subnet: String, rangeStart: Int, rangeEnd: Int) async {
        let total   = rangeEnd - rangeStart + 1
        let ports   = [80, 8080, 9000, 3000, 5000]
        let keywords = ["soundbox","paytm","phonepe","gpay","bharatpe","upi","payment"]
        var devices: [[String: Any?]] = []
        var completed = 0
        let batchSize = 20

        let hosts = (rangeStart...rangeEnd).map { $0 }

        for batchStart in stride(from: 0, to: hosts.count, by: batchSize) {
            if Task.isCancelled { break }
            let batch = Array(hosts[batchStart..<min(batchStart + batchSize, hosts.count)])

            await withTaskGroup(of: [String: Any?]?.self) { group in
                for hostNum in batch {
                    group.addTask {
                        let ip = "\(subnet).\(hostNum)"
                        return await self.probeHost(ip: ip, ports: ports, keywords: keywords)
                    }
                }
                for await result in group {
                    if let device = result {
                        devices.append(device)
                    }
                }
            }

            completed += batch.count
            let update: [String: Any] = [
                "type":    "progress",
                "current": completed,
                "total":   total,
                "devices": devices.map { $0.compactMapValues { $0 } }
            ]
            DispatchQueue.main.async { self.eventSink?(update) }
        }

        DispatchQueue.main.async {
            self.eventSink?(["type": "done"])
            self.eventSink?(FlutterEndOfEventStream)
        }
    }

    private func probeHost(ip: String,
                           ports: [Int],
                           keywords: [String]) async -> [String: Any?]? {
        for port in ports {
            guard await isTCPOpen(ip: ip, port: port) else { continue }

            var isSoundbox = false
            var vendorHint: String? = nil

            if let body = await httpProbe(ip: ip, port: port) {
                let lower = body.lowercased()
                isSoundbox = keywords.contains { lower.contains($0) }
                vendorHint = detectVendor(lower)
            }

            return [
                "ip":         ip,
                "hostname":   "",
                "mac":        "",
                "isSoundbox": isSoundbox,
                "openPort":   port,
                "vendorHint": vendorHint
            ]
        }
        return nil
    }

    private func isTCPOpen(ip: String, port: Int) async -> Bool {
        await withCheckedContinuation { cont in
            let queue      = DispatchQueue(label: "tcp.\(ip).\(port)")
            let connection = NWConnection(
                host: NWEndpoint.Host(ip),
                port: NWEndpoint.Port(integerLiteral: UInt16(port)),
                using: .tcp
            )
            var resolved = false
            connection.stateUpdateHandler = { state in
                guard !resolved else { return }
                switch state {
                case .ready:
                    resolved = true
                    connection.cancel()
                    cont.resume(returning: true)
                case .failed, .cancelled:
                    resolved = true
                    cont.resume(returning: false)
                default: break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 0.4) {
                guard !resolved else { return }
                resolved = true
                connection.cancel()
                cont.resume(returning: false)
            }
        }
    }

    private func httpProbe(ip: String, port: Int) async -> String? {
        guard let url = URL(string: "http://\(ip):\(port)/") else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 1.2)
        request.setValue("UPI-Soundbox-Scanner/1.0", forHTTPHeaderField: "User-Agent")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return String(data: data.prefix(512), encoding: .utf8) ?? ""
        } catch {
            return nil
        }
    }

    private func detectVendor(_ body: String) -> String? {
        if body.contains("paytm")    { return "paytm" }
        if body.contains("phonepe")  { return "phonepe" }
        if body.contains("gpay") || body.contains("google pay") { return "gpay" }
        if body.contains("bharatpe") { return "bharatpe" }
        if body.contains("upi") || body.contains("payment") { return "generic" }
        return nil
    }
}
