import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

enum PermissionSetResult { granted, denied, permanentlyDenied }

class PermissionService {
  PermissionService._();
  static final PermissionService instance = PermissionService._();

  Future<PermissionSetResult> requestNetworkPermissions() async {
    if (!defaultTargetPlatform.isAndroid && !defaultTargetPlatform.isIOS) {
      return PermissionSetResult.granted;
    }

    final permissions = _requiredPermissions;
    final statuses = await permissions.request();

    final anyPermanentlyDenied =
        statuses.values.any((s) => s.isPermanentlyDenied);
    if (anyPermanentlyDenied) return PermissionSetResult.permanentlyDenied;

    final anyDenied = statuses.values.any((s) => s.isDenied);
    if (anyDenied) return PermissionSetResult.denied;

    return PermissionSetResult.granted;
  }

  Future<bool> areNetworkPermissionsGranted() async {
    for (final p in _requiredPermissions) {
      final status = await p.status;
      if (!status.isGranted) return false;
    }
    return true;
  }

  Future<void> openSettings() => openAppSettings();

  List<Permission> get _requiredPermissions {
    if (defaultTargetPlatform.isAndroid) {
      return [
        Permission.location,
        Permission.nearbyWifiDevices,
      ];
    }
    return [
      Permission.localNetworkAuthorization,
    ];
  }
}

extension on TargetPlatform {
  bool get isAndroid => this == TargetPlatform.android;
  bool get isIOS => this == TargetPlatform.iOS;
}
