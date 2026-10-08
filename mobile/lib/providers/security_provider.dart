import 'package:flutter/foundation.dart';
import '../core/api_service.dart';
import '../core/notification_service.dart';
import '../models/models.dart';

class SecurityProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  SecurityStats? _stats;
  bool _isLoading = false;
  Map<String, dynamic>? _lastTelemetryResult;

  SecurityStats? get stats => _stats;
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get lastTelemetryResult => _lastTelemetryResult;

  int get riskScore {
    if (_lastTelemetryResult != null && _lastTelemetryResult!['risk_score'] != null) {
      return (_lastTelemetryResult!['risk_score'] as num).toInt();
    }
    return _stats?.latestAnomalyScore ?? 8;
  }

  String get threatLevel {
    if (_lastTelemetryResult != null && _lastTelemetryResult!['risk_level'] != null) {
      return _lastTelemetryResult!['risk_level'].toString();
    }
    return _stats?.activeThreatLevel ?? "OPTIMAL";
  }

  void clear() {
    _stats = null;
    _lastTelemetryResult = null;
    notifyListeners();
  }

  Future<void> fetchSecurityStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      _stats = await _api.getSecurityStatus();
    } catch (e) {
      debugPrint("Security status fetch error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> simulateBehavioralCheck({
    required double hour,
    required double frequency,
    required bool ipChanged,
    required int failedAttempts,
    required int highSensCount,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _api.sendTelemetry({
        "hour": hour,
        "access_frequency": frequency,
        "ip_changed": ipChanged,
        "failed_attempts": failedAttempts,
        "high_sens_count": highSensCount,
      });
      _lastTelemetryResult = res;

      // If anomaly detected, trigger real-time notification
      if (res['is_anomaly'] == true) {
        final severity = res['risk_level']?.toString() ?? 'WARNING';
        final score = (res['risk_score'] as num?)?.toInt() ?? 75;
        final reasons = (res['reasons'] is List)
            ? List<String>.from(res['reasons'].map((e) => e.toString()))
            : <String>['Unusual behavioral telemetry detected'];

        SecurityNotificationService().notifyAnomaly(
          severity: severity,
          riskScore: score,
          reasons: reasons,
        );
      }

      await fetchSecurityStatus();
    } catch (e) {
      debugPrint("Telemetry simulation error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
