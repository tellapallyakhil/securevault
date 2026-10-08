import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/notification_service.dart';
import '../providers/auth_provider.dart';
import '../providers/vault_provider.dart';
import '../providers/security_provider.dart';
import 'biometric_setup_screen.dart';
import 'upload_modal.dart';

class HomeTab extends StatelessWidget {
  final Function(int) onNavigateTab;

  const HomeTab({super.key, required this.onNavigateTab});

  void _showNotificationsSheet(BuildContext context) {
    final notifService = context.read<SecurityNotificationService>();
    final notifs = notifService.notifications;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.65,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: const BoxDecoration(
            color: VaultTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: VaultTheme.textMuted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.notifications_active_outlined, color: VaultTheme.primaryCyan, size: 22),
                      SizedBox(width: 10),
                      Text(
                        "Security Anomaly Alerts",
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: VaultTheme.textPrimary),
                      ),
                    ],
                  ),
                  if (notifs.isNotEmpty)
                    Text(
                      "${notifs.where((n) => !n.isResolved).length} Active",
                      style: const TextStyle(color: VaultTheme.statusDanger, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: notifs.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline, color: VaultTheme.statusSafe, size: 48),
                            SizedBox(height: 12),
                            Text("No Anomaly Alerts", style: TextStyle(color: VaultTheme.textPrimary, fontWeight: FontWeight.bold)),
                            SizedBox(height: 4),
                            Text("Your vault environment is running optimally.", style: TextStyle(color: VaultTheme.textMuted, fontSize: 12)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: notifs.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final n = notifs[i];
                          final isCritical = n.severity == 'CRITICAL';
                          final color = isCritical ? VaultTheme.statusDanger : VaultTheme.statusWarning;
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: VaultTheme.surfaceElevated,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: n.isResolved ? VaultTheme.surfaceBorder : color.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      n.isResolved ? Icons.check_circle : (isCritical ? Icons.security_update_warning : Icons.warning_amber),
                                      color: n.isResolved ? VaultTheme.statusSafe : color,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        n.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: n.isResolved ? VaultTheme.textMuted : VaultTheme.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Risk ${n.riskScore}',
                                        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  n.message,
                                  style: const TextStyle(fontSize: 12, color: VaultTheme.textSecondary),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      DateFormat('MMM d, h:mm a').format(n.timestamp),
                                      style: const TextStyle(fontSize: 10, color: VaultTheme.textMuted),
                                    ),
                                    if (!n.isResolved)
                                      TextButton(
                                        onPressed: () {
                                          notifService.resolveNotification(n.id);
                                          setSheetState(() {});
                                        },
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text("Resolve", style: TextStyle(fontSize: 11, color: VaultTheme.primaryCyan)),
                                      )
                                    else
                                      const Text("Resolved", style: TextStyle(fontSize: 11, color: VaultTheme.statusSafe)),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAccountDialog(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VaultTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: VaultTheme.primaryCyan.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: VaultTheme.primaryCyan, size: 22),
            ),
            const SizedBox(width: 10),
            const Text("Account Profile", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("User: ${auth.userName}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text("Email: ${auth.userEmail}", style: const TextStyle(color: VaultTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: VaultTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield, color: VaultTheme.statusSafe, size: 16),
                  SizedBox(width: 8),
                  Text("Zero-Knowledge Isolated Vault", style: TextStyle(color: VaultTheme.statusSafe, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              context.read<VaultProvider>().clear();
              context.read<SecurityProvider>().clear();
              await auth.logout();
            },
            icon: const Icon(Icons.logout, size: 16, color: Colors.white),
            label: const Text("Log Out", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: VaultTheme.statusDanger,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final vault = context.watch<VaultProvider>();
    final security = context.watch<SecurityProvider>();

    final todayStr = DateFormat('EEEE, MMMM d').format(DateTime.now()).toUpperCase();
    final displayName = auth.userName.toUpperCase();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              vault.loadDocuments(),
              security.fetchSecurityStatus(),
            ]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top App Bar row with Vault icon, alert bell, and account logout
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: VaultTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: VaultTheme.surfaceBorder),
                      ),
                      child: const Icon(Icons.shield_outlined, color: VaultTheme.primaryCyan, size: 22),
                    ),
                    Row(
                      children: [
                        Consumer<SecurityNotificationService>(
                          builder: (context, notifService, _) {
                            final count = notifService.unresolvedCount;
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    count > 0 ? Icons.notifications_active : Icons.notifications_none,
                                    color: count > 0 ? VaultTheme.statusDanger : VaultTheme.textSecondary,
                                  ),
                                  tooltip: "Security Anomaly Alerts",
                                  onPressed: () => _showNotificationsSheet(context),
                                ),
                                if (count > 0)
                                  Positioned(
                                    right: 6,
                                    top: 6,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: VaultTheme.statusDanger,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                      child: Text(
                                        '$count',
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.account_circle_outlined, color: VaultTheme.primaryCyan),
                          tooltip: "Account / Logout",
                          onPressed: () => _showAccountDialog(context, auth),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Greeting (Matching Fig 1(a))
                Text(
                  todayStr,
                  style: const TextStyle(
                    color: VaultTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Good morning, $displayName",
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 24),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Your encrypted workspace is healthy and monitoring is active.",
                  style: TextStyle(color: VaultTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 24),

                // Vault Protected Hero Card (Matching Fig 1(a))
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF32281E), Color(0xFF1E1711)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF4D3F32)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x18000000),
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "SECURITY STATUS",
                        style: TextStyle(
                          color: VaultTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        security.threatLevel == "OPTIMAL" ? "Vault Protected" : "Security Alert: ${security.threatLevel}",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: security.threatLevel == "OPTIMAL" ? Colors.white : VaultTheme.statusWarning,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildStatusRow(
                        icon: Icons.check_circle_outline,
                        text: "Encryption Active (AES-256-GCM)",
                        color: VaultTheme.statusSafe,
                      ),
                      const SizedBox(height: 8),
                      _buildStatusRow(
                        icon: Icons.check_circle_outline,
                        text: "Monitoring Active (Isolation Forest)",
                        color: VaultTheme.statusSafe,
                      ),
                      const SizedBox(height: 8),
                      _buildStatusRow(
                        icon: Icons.check_circle_outline,
                        text: "Hardware Keystore Bound",
                        color: VaultTheme.statusSafe,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // FaceLock & Biometrics Quick Card
                InkWell(
                  onTap: () {
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
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: VaultTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: auth.isFaceLockEnrolled ? VaultTheme.statusSafe.withValues(alpha: 0.5) : VaultTheme.primaryCyan.withValues(alpha: 0.5),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: auth.isFaceLockEnrolled
                                ? VaultTheme.statusSafe.withValues(alpha: 0.15)
                                : VaultTheme.primaryCyan.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            auth.isFaceLockEnrolled ? Icons.face : Icons.face_retouching_natural,
                            color: auth.isFaceLockEnrolled ? VaultTheme.statusSafe : VaultTheme.primaryCyan,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    auth.isFaceLockEnrolled ? "FaceLock Active" : "Setup FaceLock & Biometrics",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: VaultTheme.textPrimary),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: auth.isFaceLockEnrolled
                                          ? VaultTheme.statusSafe.withValues(alpha: 0.2)
                                          : VaultTheme.primaryCyan.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      auth.isFaceLockEnrolled ? "ENROLLED" : "SETUP",
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: auth.isFaceLockEnrolled ? VaultTheme.statusSafe : VaultTheme.primaryCyan,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                auth.isFaceLockEnrolled
                                    ? "On-device 128D facial landmark template active."
                                    : "Scan your face or select portrait to activate FaceLock.",
                                style: const TextStyle(color: VaultTheme.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 14, color: VaultTheme.textMuted),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Quick Search Bar (Tapping navigates to Semantic Search tab)
                InkWell(
                  onTap: () => onNavigateTab(2),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: VaultTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: VaultTheme.surfaceBorder),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.search, color: VaultTheme.textMuted, size: 20),
                        SizedBox(width: 12),
                        Text(
                          "Ask your vault anything...",
                          style: TextStyle(color: VaultTheme.textMuted, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Quick Vault Overview Metrics
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: "Encrypted Files",
                        value: "${vault.rawDocuments.length}",
                        icon: Icons.lock_outline,
                        accentColor: VaultTheme.primaryCyan,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        title: "PII Detected",
                        value: "${vault.highSensitivityCount}",
                        icon: Icons.warning_amber_rounded,
                        accentColor: VaultTheme.statusWarning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Recent Documents Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Recent Encrypted Files",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    TextButton(
                      onPressed: () => onNavigateTab(1),
                      child: const Text("View All", style: TextStyle(color: VaultTheme.primaryCyan)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (vault.isLoading)
                  const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                else if (vault.documents.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: VaultTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: VaultTheme.surfaceBorder),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.shield_outlined, size: 36, color: VaultTheme.textMuted),
                        const SizedBox(height: 12),
                        const Text("No documents in vault yet", style: TextStyle(color: VaultTheme.textSecondary)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const UploadModal(),
                            );
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text("Add First Document"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: VaultTheme.primaryCyan,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: vault.documents.take(3).length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final doc = vault.documents[index];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: VaultTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: VaultTheme.surfaceBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: VaultTheme.surfaceElevated,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.insert_drive_file_outlined, color: VaultTheme.primaryCyan, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    doc.originalName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${doc.category} • ${doc.formattedSize}",
                                    style: const TextStyle(color: VaultTheme.textMuted, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: doc.sensitivity == "HIGH"
                                    ? VaultTheme.statusDanger.withValues(alpha: 0.15)
                                    : VaultTheme.statusSafe.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                doc.sensitivity,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: doc.sensitivity == "HIGH" ? VaultTheme.statusDanger : VaultTheme.statusSafe,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow({required IconData icon, required String text, required Color color}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(fontSize: 13, color: VaultTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VaultTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VaultTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 20),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: VaultTheme.textPrimary)),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 12, color: VaultTheme.textMuted)),
        ],
      ),
    );
  }
}
