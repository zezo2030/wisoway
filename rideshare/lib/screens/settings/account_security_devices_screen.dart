// T041 — Trusted devices screen (Phase 3 / account security).
//
// Shows all active devices bound to the current account and lets the user
// revoke any of them via DELETE /auth/devices/:deviceId.

import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/colors.dart';
import '../../../core/ui/error_surface.dart';
import '../../l10n/l10n_extensions.dart';

/// A single trusted-device record from GET /auth/devices.
class _DeviceRecord {
  final String id;
  final String platform;
  final String? label;
  final String? lastSeenAt;
  final bool isCurrent;

  const _DeviceRecord({
    required this.id,
    required this.platform,
    this.label,
    this.lastSeenAt,
    this.isCurrent = false,
  });

  factory _DeviceRecord.fromJson(Map<String, dynamic> json) {
    return _DeviceRecord(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      platform: json['platform'] as String? ?? 'unknown',
      label: json['label'] as String?,
      lastSeenAt: json['lastSeenAt'] as String?,
      isCurrent: json['isCurrent'] as bool? ?? false,
    );
  }
}

class AccountSecurityDevicesScreen extends StatefulWidget {
  const AccountSecurityDevicesScreen({super.key});

  @override
  State<AccountSecurityDevicesScreen> createState() =>
      _AccountSecurityDevicesScreenState();
}

class _AccountSecurityDevicesScreenState
    extends State<AccountSecurityDevicesScreen> {
  final _api = ApiClient();
  List<_DeviceRecord> _devices = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _api.get(ApiEndpoints.devices);
      final list = (response['data'] ?? response) as List<dynamic>;
      setState(() {
        _devices = list
            .map((e) => _DeviceRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      setState(() => _error = ApiClient.mapError(e).displayMessage ?? ApiClient.mapError(e).messageKey);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _revokeDevice(_DeviceRecord device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.revokeDeviceTitle),
        content: Text(ctx.l10n.revokeDeviceMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(ctx.l10n.devicesRevokeButton),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _api.delete(ApiEndpoints.deviceById(device.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.deviceRevokedSuccess),
            backgroundColor: AppColors.success,
          ),
        );
        await _loadDevices();
      }
    } catch (e) {
      if (mounted) {
        ErrorSurface.showFailure(context, ApiClient.mapError(e));
      }
    }
  }

  IconData _platformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'ios':
        return Icons.phone_iphone_rounded;
      case 'android':
        return Icons.phone_android_rounded;
      default:
        return Icons.devices_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.devicesScreenTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.refresh,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadDevices,
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadDevices,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(context.l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (_devices.isEmpty) {
      return Center(
        child: Text(
          context.l10n.noDevicesRegistered,
          style: TextStyle(color: T.onSurfaceVariant(context)),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _devices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final device = _devices[index];
        return Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: T.primary(context).withValues(alpha: 0.1),
              child: Icon(
                _platformIcon(device.platform),
                color: T.primary(context),
              ),
            ),
            title: Text(
              device.label ??
                  (device.isCurrent
                      ? context.l10n.devicesCurrentDevice
                      : device.platform.toUpperCase()),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: device.lastSeenAt != null
                ? Text(
                    context.l10n.deviceLastSeen(
                      _formatDate(device.lastSeenAt!),
                    ),
                    style: TextStyle(
                        fontSize: 12,
                        color: T.onSurfaceVariant(context)),
                  )
                : null,
            trailing: device.isCurrent
                ? Chip(
                    label: Text(
                      context.l10n.deviceCurrentBadge,
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor:
                        AppColors.success.withValues(alpha: 0.15),
                    side: BorderSide.none,
                  )
                : IconButton(
                    tooltip: context.l10n.devicesRevokeButton,
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: AppColors.error,
                    onPressed: () => _revokeDevice(device),
                  ),
          ),
        );
      },
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
          '${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
