import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/api_service.dart';
import '../models/models.dart';
import '../providers/vault_provider.dart';
import 'upload_modal.dart';

class VaultTab extends StatelessWidget {
  const VaultTab({super.key});

  @override
  Widget build(BuildContext context) {
    final vault = context.watch<VaultProvider>();
    final categories = ["All", "Identity", "Financial", "Medical", "Educational", "Legal"];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Encrypted Vault", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: VaultTheme.textSecondary),
            onPressed: () => vault.loadDocuments(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: VaultTheme.primaryCyan,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, size: 28),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const UploadModal(),
          );
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Category Filter Chips
            Container(
              height: 48,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final isSelected = vault.selectedCategory.toLowerCase() == cat.toLowerCase();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      selectedColor: VaultTheme.primaryCyan,
                      backgroundColor: VaultTheme.surface,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.black : VaultTheme.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? VaultTheme.primaryCyan : VaultTheme.surfaceBorder,
                        ),
                      ),
                      onSelected: (_) => vault.setCategory(cat),
                    ),
                  );
                },
              ),
            ),

            // Documents List
            Expanded(
              child: vault.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : vault.documents.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.folder_open, size: 56, color: VaultTheme.textMuted),
                              const SizedBox(height: 16),
                              Text(
                                "No ${vault.selectedCategory} files",
                                style: const TextStyle(color: VaultTheme.textSecondary, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "Tap '+' below to securely encrypt and upload documents",
                                style: TextStyle(color: VaultTheme.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: vault.documents.length,
                          separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final doc = vault.documents[index];
                            return _buildDocumentCard(context, doc);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard(BuildContext context, VaultDocument doc) {
    final dateStr = DateFormat('MMM d, yyyy').format(doc.createdAt);
    final isHighSens = doc.sensitivity == "HIGH";

    return InkWell(
      onTap: () => _showDocumentDetailsModal(context, doc),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VaultTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isHighSens ? VaultTheme.statusDanger.withValues(alpha: 0.4) : VaultTheme.surfaceBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: VaultTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getCategoryIcon(doc.category),
                    color: isHighSens ? VaultTheme.statusDanger : VaultTheme.primaryCyan,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.originalName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: VaultTheme.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: VaultTheme.primaryCyan.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              (doc.piiSummary['document_type'] ?? doc.category).toString(),
                              style: const TextStyle(
                                color: VaultTheme.primaryCyan,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "${doc.formattedSize} • $dateStr",
                              style: const TextStyle(color: VaultTheme.textMuted, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isHighSens
                        ? VaultTheme.statusDanger.withValues(alpha: 0.15)
                        : VaultTheme.statusSafe.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isHighSens ? VaultTheme.statusDanger : VaultTheme.statusSafe,
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    doc.sensitivity,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isHighSens ? VaultTheme.statusDanger : VaultTheme.statusSafe,
                    ),
                  ),
                ),
              ],
            ),
            if (doc.summaryPreview != null && doc.summaryPreview!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: VaultTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  doc.summaryPreview!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: VaultTheme.textSecondary, fontStyle: FontStyle.italic),
                ),
              ),
            ],
            const SizedBox(height: 10),
            // Security guarantee tag
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: VaultTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock, size: 11, color: VaultTheme.primaryCyan),
                      SizedBox(width: 4),
                      Text(
                        "AES-256-GCM Encrypted Blob",
                        style: TextStyle(fontSize: 10, color: VaultTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if ((doc.piiSummary['ocr_char_count'] as num?)?.toInt() case final chars? when chars > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: VaultTheme.statusSafe.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.document_scanner, size: 11, color: VaultTheme.statusSafe),
                        const SizedBox(width: 4),
                        Text(
                          "OCR Indexed ($chars chars)",
                          style: const TextStyle(fontSize: 10, color: VaultTheme.statusSafe, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDocumentDetailsModal(BuildContext context, VaultDocument doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        bool isDecrypting = false;
        final docType = doc.piiSummary['document_type'] ?? doc.category;
        final ocrChars = (doc.piiSummary['ocr_char_count'] as num?)?.toInt() ?? 0;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: VaultTheme.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_user, color: VaultTheme.primaryCyan),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            doc.originalName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: VaultTheme.textPrimary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow("Document Type", "$docType"),
                    _buildDetailRow("Category", doc.category),
                    _buildDetailRow("Sensitivity Level", doc.sensitivity),
                    _buildDetailRow("File Size", doc.formattedSize),
                    _buildDetailRow("Storage Location", "Device Local Storage (Strictly Offline)"),
                    _buildDetailRow("Encryption Standard", "AES-256-GCM (Argon2id KDF)"),
                    _buildDetailRow("OCR Extracted Chars", ocrChars > 0 ? "$ocrChars characters" : "N/A"),
                    _buildDetailRow("PII Entities Flagged", "${doc.piiSummary['total_pii_count'] ?? 0}"),
                    if (doc.summaryPreview != null && doc.summaryPreview!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text("Extracted PII Preview:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: VaultTheme.textSecondary)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: VaultTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: VaultTheme.surfaceBorder),
                        ),
                        child: Text(
                          doc.summaryPreview!,
                          style: const TextStyle(fontSize: 12, color: VaultTheme.textPrimary),
                        ),
                      ),
                    ],
                    if (doc.contentHash != null)
                      _buildDetailRow("SHA-256 Seal", "${doc.contentHash!.substring(0, doc.contentHash!.length > 16 ? 16 : doc.contentHash!.length)}..."),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: isDecrypting
                        ? null
                        : () async {
                            setModalState(() => isDecrypting = true);
                            try {
                              final result = await ApiService().downloadAndDecryptDocument(doc);
                              if (context.mounted) {
                                Navigator.pop(modalCtx);
                                _showDecryptedSuccessDialog(context, result, doc);
                              }
                            } catch (e) {
                              setModalState(() => isDecrypting = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Decryption error: $e"),
                                    backgroundColor: VaultTheme.statusDanger,
                                  ),
                                );
                              }
                            }
                          },
                    icon: isDecrypting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.download, color: Colors.white),
                    label: Text(
                      isDecrypting ? "DECRYPTING STREAM (AES-256)..." : "Decrypt & Download Document",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VaultTheme.primaryCyan,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          );
          },
        );
      },
    );
  }

  void _showDecryptedSuccessDialog(BuildContext context, Map<String, dynamic> result, VaultDocument doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VaultTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_open_rounded, color: VaultTheme.statusSafe, size: 24),
            SizedBox(width: 8),
            Text("Decrypted & Verified", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: VaultTheme.textPrimary)),
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
                border: Border.all(color: VaultTheme.surfaceBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("File: ${result['filename']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: VaultTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Text("Size: ${doc.formattedSize}", style: const TextStyle(fontSize: 12, color: VaultTheme.textSecondary)),
                  const SizedBox(height: 4),
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: VaultTheme.statusSafe, size: 14),
                      SizedBox(width: 4),
                      Text("AES-256-GCM Decryption: Verified", style: TextStyle(fontSize: 12, color: VaultTheme.statusSafe, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text("Saved to device:\n${result['path']}", style: const TextStyle(fontSize: 11, color: VaultTheme.textMuted)),
                ],
              ),
            ),
            if (result['preview'] != null && result['preview'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text("Document Preview:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: VaultTheme.textSecondary)),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 140),
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: VaultTheme.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: VaultTheme.surfaceBorder),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    result['preview'].toString(),
                    style: const TextStyle(fontSize: 11.5, color: VaultTheme.textPrimary, height: 1.3),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () async {
              final path = result['path']?.toString();
              if (path != null && path.isNotEmpty) {
                try {
                  await OpenFilex.open(path);
                } catch (e) {
                  debugPrint("OpenFilex error: $e");
                }
              }
            },
            icon: const Icon(Icons.open_in_new, size: 16, color: VaultTheme.primaryCyan),
            label: const Text("Open File", style: TextStyle(color: VaultTheme.primaryCyan, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: VaultTheme.primaryCyan),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: VaultTheme.primaryCyan),
            child: const Text("Done", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: VaultTheme.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: VaultTheme.textPrimary)),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'financial':
        return Icons.account_balance_wallet_outlined;
      case 'identity':
        return Icons.badge_outlined;
      case 'medical':
        return Icons.local_hospital_outlined;
      case 'educational':
        return Icons.school_outlined;
      case 'legal':
        return Icons.gavel_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }
}
