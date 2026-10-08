import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme.dart';

/// Model representing a behavioral anomaly or security notification
class SecurityNotification {
  final String id;
  final String title;
  final String message;
  final String severity; // CRITICAL, WARNING, INFO
  final int riskScore;
  final List<String> reasons;
  final DateTime timestamp;
  bool isResolved;

  SecurityNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.riskScore,
    required this.reasons,
    required this.timestamp,
    this.isResolved = false,
  });

  factory SecurityNotification.fromMap(Map<String, dynamic> map) {
    return SecurityNotification(
      id: map['id']?.toString() ?? UniqueKey().toString(),
      title: map['severity'] == 'CRITICAL' ? 'CRITICAL SECURITY ANOMALY' : 'Security Anomaly Detected',
      message: (map['reasons'] is List && (map['reasons'] as List).isNotEmpty)
          ? (map['reasons'] as List).first.toString()
          : 'Suspicious behavioral telemetry flagged by Isolation Forest',
      severity: map['severity']?.toString() ?? 'WARNING',
      riskScore: (map['risk_score'] as num?)?.toInt() ?? 60,
      reasons: (map['reasons'] is List) ? List<String>.from(map['reasons'].map((e) => e.toString())) : [],
      timestamp: map['timestamp'] != null ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now() : DateTime.now(),
      isResolved: map['is_resolved'] == true,
    );
  }
}

/// Central Security Notification Service
/// Handles real-time anomaly alerts, in-app heads-up banners, haptic audio triggers,
/// and cloud persistence in Supabase `anomaly_alerts` table.
class SecurityNotificationService extends ChangeNotifier {
  static final SecurityNotificationService _instance = SecurityNotificationService._internal();
  factory SecurityNotificationService() => _instance;
  SecurityNotificationService._internal();

  /// Global navigator key for presenting notifications from any service
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final List<SecurityNotification> _notifications = [];
  List<SecurityNotification> get notifications => List.unmodifiable(_notifications);

  int get unresolvedCount => _notifications.where((n) => !n.isResolved).length;

  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Trigger an anomaly notification when suspicious behavior or threats are detected
  Future<void> notifyAnomaly({
    required String severity,
    required int riskScore,
    required List<String> reasons,
    String? title,
    String? userId,
  }) async {
    final alertId = 'alert_${DateTime.now().millisecondsSinceEpoch}';
    final alertTitle = title ?? (severity == 'CRITICAL' ? 'CRITICAL SECURITY ANOMALY' : 'Security Anomaly Flagged');
    final alertMessage = reasons.isNotEmpty
        ? reasons.first
        : 'Isolation Forest flagged abnormal behavioral pattern (Risk Score: $riskScore/100)';

    final notification = SecurityNotification(
      id: alertId,
      title: alertTitle,
      message: alertMessage,
      severity: severity,
      riskScore: riskScore,
      reasons: reasons,
      timestamp: DateTime.now(),
      isResolved: false,
    );

    _notifications.insert(0, notification);
    notifyListeners();

    // 1. Audio and Haptic alerts
    try {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}

    // 2. Persist anomaly alert in Supabase cloud database
    try {
      final client = _supabase;
      if (client != null && userId != null && userId.isNotEmpty) {
        await client.from('anomaly_alerts').insert({
          'user_id': userId,
          'severity': severity,
          'risk_score': riskScore,
          'reasons': reasons,
          'is_resolved': false,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        });
        debugPrint('Anomaly alert persisted to Supabase cloud anomaly_alerts table');
      }
    } catch (dbErr) {
      debugPrint('Cloud anomaly alert save error: $dbErr');
    }

    // 3. Display heads-up in-app notification banner
    try {
      _showInAppAnomalyBanner(notification);
    } catch (_) {}
  }

  /// Show a high-visibility heads-up banner at the top of the screen
  void _showInAppAnomalyBanner(SecurityNotification notification) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final isCritical = notification.severity == 'CRITICAL';
    final bannerColor = isCritical ? VaultTheme.statusDanger : VaultTheme.statusWarning;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: VaultTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: bannerColor, width: 1.5),
        ),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bannerColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCritical ? Icons.security_update_warning_rounded : Icons.warning_amber_rounded,
                color: bannerColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        notification.title,
                        style: TextStyle(
                          color: bannerColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: bannerColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${notification.riskScore}/100',
                          style: TextStyle(
                            color: bannerColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: const TextStyle(
                      color: VaultTheme.textPrimary,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'DETAILS',
          textColor: VaultTheme.primaryCyan,
          onPressed: () {
            showNotificationDetailsDialog(context, notification);
          },
        ),
      ),
    );
  }

  /// Mark an alert as resolved
  Future<void> resolveNotification(String id) async {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx].isResolved = true;
      notifyListeners();
    }

    try {
      await _supabase?.from('anomaly_alerts').update({'is_resolved': true}).eq('id', id);
    } catch (_) {}
  }

  /// Fetch existing alerts from Supabase Cloud
  Future<void> fetchAlertsFromCloud(String userId) async {
    try {
      final client = _supabase;
      if (client == null) return;
      final data = await client
          .from('anomaly_alerts')
          .select()
          .eq('user_id', userId)
          .order('timestamp', ascending: false)
          .limit(20);

      final List list = data as List;
      _notifications.clear();
      for (final item in list) {
        _notifications.add(SecurityNotification.fromMap(item));
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching cloud anomaly alerts: $e');
    }
  }

  /// Open full details modal for an anomaly alert
  static void showNotificationDetailsDialog(BuildContext context, SecurityNotification notification) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VaultTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              notification.severity == 'CRITICAL' ? Icons.dangerous_rounded : Icons.warning_amber_rounded,
              color: notification.severity == 'CRITICAL' ? VaultTheme.statusDanger : VaultTheme.statusWarning,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                notification.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VaultTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Risk Severity Score:", style: TextStyle(color: VaultTheme.textSecondary, fontSize: 13)),
                  Text(
                    "${notification.riskScore}/100 (${notification.severity})",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: notification.severity == 'CRITICAL' ? VaultTheme.statusDanger : VaultTheme.statusWarning,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text("Trigger Reasons (Isolation Forest ML):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            if (notification.reasons.isEmpty)
              Text("• ${notification.message}", style: const TextStyle(color: VaultTheme.textSecondary, fontSize: 12))
            else
              ...notification.reasons.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text("• $r", style: const TextStyle(color: VaultTheme.textSecondary, fontSize: 12)),
                  )),
            const SizedBox(height: 12),
            Text(
              "Detected: ${notification.timestamp.toLocal().toString().split('.').first}",
              style: const TextStyle(color: VaultTheme.textMuted, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Dismiss", style: TextStyle(color: VaultTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              SecurityNotificationService().resolveNotification(notification.id);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: VaultTheme.primaryCyan),
            child: const Text("Mark Resolved", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
