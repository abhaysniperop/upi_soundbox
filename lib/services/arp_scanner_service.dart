import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ScannedDevice {
  final String ip;
  final String hostname;
  final String mac;
  final bool isSoundbox;
  final int? openPort;
  final String? vendorHint;

  const ScannedDevice({
    required this.ip,
    required this.hostname,
    required this.mac,
    required this.isSoundbox,
    this.openPort,
    this.vendorHint,
  });

  String get address => openPort != null ? '$ip:$openPort' : ip;

  factory ScannedDevice.fromMap(Map<Object?, Object?> map) {
    return ScannedDevice(
      ip: map['ip'] as String? ?? '',
      hostname: map['hostname'] as String? ?? '',
      mac: map['mac'] as String? ?? '',
      isSoundbox: map['isSoundbox'] as bool? ?? false,
      openPort: map['openPort'] as int?,
      vendorHint: map['vendorHint'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'ip': ip,
        'hostname': hostname,
        'mac': mac,
        'isSoundbox': isSoundbox,
        'openPort': openPort,
        'vendorHint': vendorHint,
      };

  @override
  String toString() =>
      'ScannedDevice(ip: $ip, hostname: $hostname, isSoundbox: $isSoundbox, port: $openPort)';
}

class ScanProgress {
  final int current;
  final int total;
  final List<ScannedDevice> devices;
  final bool isDone;
  final bool isCancelled;

  const ScanProgress({
    required this.current,
    required this.total,
    required this.devices,
    this.isDone = false,
    this.isCancelled = false,
  });

  double get percent => total == 0 ? 0.0 : current / total;
}

class ARPScannerService {
  static const _methodChannel =
      MethodChannel('com.example.upi_soundbox/arp_scanner');
  static const _eventChannel =
      EventChannel('com.example.upi_soundbox/arp_scanner_progress');

  StreamSubscription? _subscription;
  bool _isAndroid = Platform.isAndroid;

  Future<String?> getSubnet() async {
    if (!_isAndroid) return _detectSubnetFallback();
    try {
      return await _methodChannel.invokeMethod<String>('getSubnet');
    } on PlatformException catch (e) {
      debugPrint('[ARPScanner] getSubnet error: ${e.message}');
      return null;
    }
  }

  Stream<ScanProgress> startScan({
    String? subnet,
    int rangeStart = 1,
    int rangeEnd = 254,
  }) {
    if (_isAndroid) {
      return _startAndroidScan(
        subnet: subnet,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );
    } else {
      return _startIosFallbackScan(
        subnet: subnet ?? '192.168.1',
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );
    }
  }

  Stream<ScanProgress> _startAndroidScan({
    String? subnet,
    int rangeStart = 1,
    int rangeEnd = 254,
  }) async* {
    final args = <String, dynamic>{
      'rangeStart': rangeStart,
      'rangeEnd': rangeEnd,
      if (subnet != null) 'subnet': subnet,
    };

    final devices = <ScannedDevice>[];
    final controller = StreamController<ScanProgress>();

    _subscription = _eventChannel.receiveBroadcastStream(args).listen(
      (event) {
        final map = event as Map<Object?, Object?>;
        final type = map['type'] as String?;

        if (type == 'progress') {
          final current = map['current'] as int? ?? 0;
          final total = map['total'] as int? ?? 254;
          final rawDevices = map['devices'] as List<Object?>? ?? [];

          devices
            ..clear()
            ..addAll(rawDevices
                .whereType<Map<Object?, Object?>>()
                .map(ScannedDevice.fromMap));

          controller.add(ScanProgress(
            current: current,
            total: total,
            devices: List.unmodifiable(devices),
          ));
        } else if (type == 'done') {
          controller.add(ScanProgress(
            current: rangeEnd - rangeStart + 1,
            total: rangeEnd - rangeStart + 1,
            devices: List.unmodifiable(devices),
            isDone: true,
          ));
          controller.close();
        } else if (type == 'cancelled') {
          controller.add(ScanProgress(
            current: 0,
            total: rangeEnd - rangeStart + 1,
            devices: List.unmodifiable(devices),
            isCancelled: true,
          ));
          controller.close();
        }
      },
      onError: (e) => controller.addError(e),
      onDone: () {
        if (!controller.isClosed) controller.close();
      },
    );

    yield* controller.stream;
  }

  Stream<ScanProgress> _startIosFallbackScan({
    required String subnet,
    required int rangeStart,
    required int rangeEnd,
  }) async* {
    const ports = [80, 8080, 9000, 3000, 5000];
    const soundboxKeywords = [
      'soundbox', 'paytm', 'phonepe', 'gpay', 'bharatpe', 'upi', 'payment'
    ];

    final total = rangeEnd - rangeStart + 1;
    final devices = <ScannedDevice>[];
    int completed = 0;

    const batchSize = 16;
    final hosts = List.generate(total, (i) => rangeStart + i);

    for (int batchStart = 0; batchStart < hosts.length; batchStart += batchSize) {
      final batch =
          hosts.skip(batchStart).take(batchSize).toList();

      final futures = batch.map((hostNum) async {
        final ip = '$subnet.$hostNum';
        int? openPort;
        bool isSoundbox = false;
        String? vendorHint;
        String hostname = '';

        for (final port in ports) {
          try {
            final socket = await Socket.connect(
              ip,
              port,
              timeout: const Duration(milliseconds: 400),
            );
            socket.destroy();
            openPort = port;

            final probe = await _httpProbe(ip, port);
            if (probe != null) {
              final lower = probe.toLowerCase();
              isSoundbox = soundboxKeywords.any(lower.contains);
              vendorHint = _detectVendor(lower);
            }
            break;
          } catch (_) {}
        }

        if (openPort == null) return null;

        return ScannedDevice(
          ip: ip,
          hostname: hostname,
          mac: '',
          isSoundbox: isSoundbox,
          openPort: openPort,
          vendorHint: vendorHint,
        );
      });

      final results = await Future.wait(futures);
      completed += batch.length;

      for (final d in results) {
        if (d != null) devices.add(d);
      }

      yield ScanProgress(
        current: completed,
        total: total,
        devices: List.unmodifiable(devices),
        isDone: completed >= total,
      );
    }
  }

  Future<String?> _httpProbe(String ip, int port) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(milliseconds: 1200);
      final req = await client.getUrl(Uri.parse('http://$ip:$port/'));
      req.headers.set('User-Agent', 'UPI-Soundbox-Scanner/1.0');
      final res = await req.close().timeout(const Duration(milliseconds: 1200));
      final body = await res
          .transform(const SystemEncoding().decoder)
          .join()
          .then((s) => s.substring(0, s.length.clamp(0, 512)));
      client.close();
      return '${res.statusCode} $body';
    } catch (_) {
      return null;
    }
  }

  String? _detectVendor(String body) {
    if (body.contains('paytm')) return 'paytm';
    if (body.contains('phonepe')) return 'phonepe';
    if (body.contains('gpay') || body.contains('google pay')) return 'gpay';
    if (body.contains('bharatpe')) return 'bharatpe';
    if (body.contains('upi') || body.contains('payment')) return 'generic';
    return null;
  }

  String? _detectSubnetFallback() => '192.168.1';

  Future<void> cancelScan() async {
    _subscription?.cancel();
    _subscription = null;
    if (_isAndroid) {
      try {
        await _methodChannel.invokeMethod('cancelScan');
      } catch (_) {}
    }
  }

  void dispose() {
    cancelScan();
  }
}
