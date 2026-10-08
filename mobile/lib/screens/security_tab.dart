import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/security_provider.dart';
import '../providers/auth_provider.dart';
import 'biometric_setup_screen.dart';

class SecurityTab extends StatefulWidget {
  const SecurityTab({super.key});

  @override
  State<SecurityTab> createState() => _SecurityTabState();
}

class _SecurityTabState extends State<SecurityTab> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<SecurityProvider>().fetchSecurityStatus();
    });
  }

  void _runAnomalyTest({required bool isAttack}) async {
    final sec = context.read<SecurityProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      if (isAttack) {
        // Simulate malicious off-hours burst login from unknown IP with 5 failed attempts
        await sec.simulateBehavioralCheck(
          hour: 3.2,
          frequency: 24.0,
          ipChanged: true,
          failedAttempts: 4,
          highSensCount: 5,
        );
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text("⚠️ Anomaly Simulated — Isolation Forest flagged CRITICAL threat."),
            backgroundColor: VaultTheme.statusDanger,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        // Simulate normal daytime user access
        await sec.simulateBehavioralCheck(
          hour: 14.5,
          frequency: 2.0,
          ipChanged: false,
          failedAttempts: 0,
          highSensCount: 1,
        );
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text("✅ Normal behavior detected — Threat level normalized to OPTIMAL."),
            backgroundColor: VaultTheme.statusSafe,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text("Security check error: $e"),
          backgroundColor: VaultTheme.statusDanger,
        ),
      );
    }
  }

  Future<void> _confirmDeleteFace() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VaultTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: VaultTheme.statusDanger),
            SizedBox(width: 8),
            Text("Delete Face Data?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          "This will delete your registered facial landmark template from this device and Supabase Cloud. You can enroll a new face anytime.",
          style: TextStyle(color: VaultTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: VaultTheme.statusDanger),
            child: const Text("Delete Face Data", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await context.read<AuthProvider>().deleteFaceData();
    messenger.showSnackBar(
      const SnackBar(
        content: Text("Face data successfully deleted. You can enroll a new face."),
        backgroundColor: VaultTheme.statusWarning,
      ),
    );
  }

  Future<void> _confirmDeleteFingerprint() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VaultTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: VaultTheme.statusDanger),
            SizedBox(width: 8),
            Text("Delete Fingerprint?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          "This will remove the fingerprint biometric credentials for this vault.",
          style: TextStyle(color: VaultTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: VaultTheme.statusDanger),
            child: const Text("Delete Fingerprint", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await context.read<AuthProvider>().deleteFingerprintData();
    messenger.showSnackBar(
      const SnackBar(
        content: Text("Fingerprint data successfully deleted."),
        backgroundColor: VaultTheme.statusWarning,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sec = context.watch<SecurityProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => sec.fetchSecurityStatus(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header matching Fig 2(a)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: VaultTheme.primaryCyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.security, color: VaultTheme.primaryCyan, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "SECURITY CENTER",
                          style: TextStyle(
                            color: VaultTheme.primaryCyan,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          sec.threatLevel == "OPTIMAL" ? "Protected" : "Threat Alert",
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: sec.threatLevel == "OPTIMAL" ? VaultTheme.textPrimary : VaultTheme.statusDanger,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  "Security indicators help you review unusual behavior.\nThey are not proof of compromise.",
                  style: TextStyle(color: VaultTheme.textSecondary, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 24),

                // Vault Protected Hero Card (Matching Fig 2(a))
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: VaultTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sec.threatLevel == "OPTIMAL" ? VaultTheme.surfaceBorder : VaultTheme.statusDanger,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            sec.threatLevel == "OPTIMAL" ? Icons.verified_user_outlined : Icons.warning_amber_rounded,
                            color: sec.threatLevel == "OPTIMAL" ? VaultTheme.statusSafe : VaultTheme.statusDanger,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sec.threatLevel == "OPTIMAL" ? "Vault Protected" : "Threat Level: ${sec.threatLevel}",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                "Last checked just now",
                                style: TextStyle(color: VaultTheme.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 30, color: VaultTheme.surfaceBorder),
                      _buildSecurityItem(
                        icon: Icons.lock_outline,
                        title: "Encryption",
                        subtitle: "AES-256-GCM Active (Argon2id KDF)",
                      ),
                      const SizedBox(height: 14),
                      _buildSecurityItem(
                        icon: Icons.fingerprint,
                        title: "Authentication",
                        subtitle: "Hardware Keystore & Biometrics Bound",
                      ),
                      const SizedBox(height: 10),
                      // Biometric Status Indicators
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: VaultTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: VaultTheme.surfaceBorder),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  auth.isFingerprintEnrolled ? Icons.check_circle : Icons.cancel_outlined,
                                  size: 16,
                                  color: auth.isFingerprintEnrolled ? VaultTheme.statusSafe : VaultTheme.textMuted,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    auth.isFingerprintEnrolled ? "Fingerprint: Enrolled" : "Fingerprint: Not enrolled",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: auth.isFingerprintEnrolled ? VaultTheme.textPrimary : VaultTheme.textMuted,
                                      fontWeight: auth.isFingerprintEnrolled ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (auth.isFingerprintEnrolled)
                                  InkWell(
                                    onTap: _confirmDeleteFingerprint,
                                    borderRadius: BorderRadius.circular(4),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      child: Text("Delete", style: TextStyle(color: VaultTheme.statusDanger, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  auth.isFaceLockEnrolled ? Icons.check_circle : Icons.cancel_outlined,
                                  size: 16,
                                  color: auth.isFaceLockEnrolled ? VaultTheme.statusSafe : VaultTheme.textMuted,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    auth.isFaceLockEnrolled ? "FaceLock: Active" : "FaceLock: Not enrolled",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: auth.isFaceLockEnrolled ? VaultTheme.textPrimary : VaultTheme.textMuted,
                                      fontWeight: auth.isFaceLockEnrolled ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (auth.isFaceLockEnrolled)
                                  InkWell(
                                    onTap: _confirmDeleteFace,
                                    borderRadius: BorderRadius.circular(4),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      child: Text("Delete Face Data", style: TextStyle(color: VaultTheme.statusDanger, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BiometricSetupScreen(
                                onSetupComplete: () {
                                  context.read<AuthProvider>().refreshBiometrics();
                                },
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.settings_suggest_outlined, size: 16, color: VaultTheme.primaryCyan),
                        label: const Text("Enroll or Manage Biometrics", style: TextStyle(fontSize: 12, color: VaultTheme.primaryCyan, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: VaultTheme.primaryCyan),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildSecurityItem(
                        icon: Icons.auto_graph,
                        title: "Anomaly Detection",
                        subtitle: "Isolation Forest Model (Unsupervised ML)",
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Isolation Forest Telemetry Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: VaultTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: VaultTheme.surfaceBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "ISOLATION FOREST TELEMETRY",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: VaultTheme.primaryCyan,
                              letterSpacing: 1.1,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: sec.threatLevel == "OPTIMAL"
                                  ? VaultTheme.statusSafe.withValues(alpha: 0.15)
                                  : VaultTheme.statusDanger.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "Risk: ${sec.riskScore}/100",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: sec.threatLevel == "OPTIMAL" ? VaultTheme.statusSafe : VaultTheme.statusDanger,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: (sec.riskScore / 100.0).clamp(0.0, 1.0),
                        backgroundColor: VaultTheme.surface,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          sec.riskScore > 60
                              ? VaultTheme.statusDanger
                              : (sec.riskScore > 30 ? VaultTheme.statusWarning : VaultTheme.statusSafe),
                        ),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 14),

                      if (sec.lastTelemetryResult != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: VaultTheme.surface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Evaluated Decision: ${sec.lastTelemetryResult!['risk_level'] ?? 'OPTIMAL'}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: sec.lastTelemetryResult!['risk_level'] == 'CRITICAL'
                                      ? VaultTheme.statusDanger
                                      : VaultTheme.statusSafe,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Anomaly Score: ${sec.lastTelemetryResult!['anomaly_score'] ?? '0.0'}",
                                style: const TextStyle(color: VaultTheme.textSecondary, fontSize: 12),
                              ),
                              if (sec.lastTelemetryResult!['reasons'] is List &&
                                  (sec.lastTelemetryResult!['reasons'] as List).isNotEmpty) ...[
                                const SizedBox(height: 6),
                                for (var r in (sec.lastTelemetryResult!['reasons'] as List))
                                  Text("• $r", style: const TextStyle(color: VaultTheme.statusDanger, fontSize: 11)),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      const Text(
                        "Test Behavioral Security Engine:",
                        style: TextStyle(fontSize: 12, color: VaultTheme.textMuted),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _runAnomalyTest(isAttack: false),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: VaultTheme.statusSafe),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: const Text("Normal Usage", style: TextStyle(color: VaultTheme.statusSafe, fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _runAnomalyTest(isAttack: true),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: VaultTheme.statusDanger),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: const Text("Simulate Anomaly", style: TextStyle(color: VaultTheme.statusDanger, fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: VaultTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: VaultTheme.primaryCyan, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: VaultTheme.textMuted, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}
