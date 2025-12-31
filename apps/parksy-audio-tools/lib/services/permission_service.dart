import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/result/result.dart';

/// Unified permission management
/// - Microphone for recording
/// - Storage for file operations
/// - System Alert Window for overlay (future)
class PermissionService {
  static final PermissionService _instance = PermissionService._();
  static PermissionService get instance => _instance;
  PermissionService._();

  /// Required permissions for audio capture
  static const _capturePermissions = [
    Permission.microphone,
  ];

  /// Required permissions for file operations
  static const _storagePermissions = [
    Permission.storage,
  ];

  /// Check and request capture permissions
  Future<Result<void>> requestCapturePermissions() async {
    return _requestPermissions(_capturePermissions, '마이크');
  }

  /// Check and request storage permissions
  Future<Result<void>> requestStoragePermissions() async {
    return _requestPermissions(_storagePermissions, '저장소');
  }

  /// Check all permissions without requesting
  Future<bool> hasCapturePermissions() async {
    for (final permission in _capturePermissions) {
      if (!await permission.isGranted) return false;
    }
    return true;
  }

  /// Request permissions with proper error handling
  Future<Result<void>> _requestPermissions(
    List<Permission> permissions,
    String permissionName,
  ) async {
    for (final permission in permissions) {
      final status = await permission.request();

      if (status.isDenied) {
        return Failure(
          '$permissionName 권한이 필요합니다',
          code: ErrorCode.permissionDenied,
        );
      }

      if (status.isPermanentlyDenied) {
        return Failure(
          '설정에서 $permissionName 권한을 허용해주세요',
          code: ErrorCode.permissionPermanentlyDenied,
        );
      }
    }

    return const Success(null);
  }

  /// Show dialog to guide user to settings
  Future<bool> showPermissionSettingsDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('권한 필요'),
        content: const Text(
          '앱 설정에서 필요한 권한을 허용해주세요.\n'
          '설정 화면으로 이동하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('설정으로 이동'),
          ),
        ],
      ),
    );

    if (result == true) {
      await openAppSettings();
      return true;
    }
    return false;
  }

  /// Handle permission result with UI feedback
  Future<bool> handlePermissionResult(
    BuildContext context,
    Result<void> result,
  ) async {
    return result.fold(
      onSuccess: (_) => true,
      onFailure: (error, code) async {
        if (code == ErrorCode.permissionPermanentlyDenied) {
          await showPermissionSettingsDialog(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error)),
          );
        }
        return false;
      },
    );
  }
}
