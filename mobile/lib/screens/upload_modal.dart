import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/vault_provider.dart';

class UploadModal extends StatefulWidget {
  const UploadModal({super.key});

  @override
  State<UploadModal> createState() => _UploadModalState();
}

class _UploadModalState extends State<UploadModal> {
  bool _isPicking = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _uploadBytes(
    VaultProvider vault,
    String filename,
    Uint8List bytes,
    NavigatorState navigator,
    ScaffoldMessengerState scaffoldMessenger, {
    String? filePath,
  }) async {
    final doc = await vault.uploadFile(filename, bytes, filePath: filePath);
    if (mounted) {
      navigator.pop();
      if (doc != null) {
        _showUploadSuccessDialog(context, doc);
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text("Upload failed for '$filename'."),
            backgroundColor: VaultTheme.statusDanger,
          ),
        );
      }
    }
  }

  void _showUploadSuccessDialog(BuildContext context, VaultDocument doc) {
    final docType = doc.piiSummary['document_type'] ?? doc.category;
    final ocrChars = doc.piiSummary['ocr_char_count'] ?? 0;
    final isHigh = doc.sensitivity == 'HIGH';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VaultTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: VaultTheme.statusSafe, size: 24),
            const SizedBox(width: 8),
            const Text(
              "Document Indexed",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: VaultTheme.textPrimary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              doc.originalName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: VaultTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VaultTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isHigh ? VaultTheme.statusDanger.withValues(alpha: 0.5) : VaultTheme.surfaceBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Classified Type:", style: TextStyle(color: VaultTheme.textMuted, fontSize: 12)),
                      Text(
                        docType.toString(),
                        style: TextStyle(
                          color: isHigh ? VaultTheme.statusDanger : VaultTheme.primaryCyan,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Sensitivity:", style: TextStyle(color: VaultTheme.textMuted, fontSize: 12)),
                      Text(
                        doc.sensitivity,
                        style: TextStyle(
                          color: isHigh ? VaultTheme.statusDanger : VaultTheme.statusSafe,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("On-Device OCR:", style: TextStyle(color: VaultTheme.textMuted, fontSize: 12)),
                      Text(
                        ocrChars > 0 ? "$ocrChars characters extracted" : "Encrypted directly",
                        style: const TextStyle(color: VaultTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "🔒 File stored strictly in local device storage. Zero unencrypted bytes sent to cloud.",
              style: TextStyle(fontSize: 11, color: VaultTheme.textMuted),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: VaultTheme.primaryCyan),
            child: const Text("View in Vault", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUpload(BuildContext context, String source) async {
    setState(() => _isPicking = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final vault = context.read<VaultProvider>();

    try {
      if (source == "Camera") {
        if (!kIsWeb) {
          final cameraStatus = await Permission.camera.request();
          if (!cameraStatus.isGranted) {
            if (mounted) {
              scaffoldMessenger.showSnackBar(
                const SnackBar(
                  content: Text("Camera permission is required to take photos."),
                  backgroundColor: VaultTheme.statusDanger,
                ),
              );
            }
            return;
          }
        }

        final XFile? photo = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 90,
        );
        if (photo != null) {
          final bytes = await photo.readAsBytes();
          final filename = photo.name.isNotEmpty
              ? photo.name
              : "Camera_${DateTime.now().millisecondsSinceEpoch}.jpg";
          await _uploadBytes(vault, filename, bytes, navigator, scaffoldMessenger, filePath: photo.path);
        }
      } else if (source == "Photos") {
        final XFile? photo = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 90,
        );
        if (photo != null) {
          final bytes = await photo.readAsBytes();
          final filename = photo.name.isNotEmpty
              ? photo.name
              : "Photo_${DateTime.now().millisecondsSinceEpoch}.jpg";
          await _uploadBytes(vault, filename, bytes, navigator, scaffoldMessenger, filePath: photo.path);
        }
      } else {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'txt', 'csv', 'doc', 'docx'],
          withData: true,
        );

        if (result != null && result.files.isNotEmpty) {
          final file = result.files.first;
          Uint8List? bytes = file.bytes;
          if (bytes == null && file.path != null) {
            try {
              bytes = await File(file.path!).readAsBytes();
            } catch (_) {}
          }
          if (bytes == null) {
            try {
              bytes = await file.xFile.readAsBytes();
            } catch (_) {}
          }

          if (bytes != null) {
            await _uploadBytes(vault, file.name, bytes, navigator, scaffoldMessenger, filePath: file.path);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text("Error acquiring document: $e"), backgroundColor: VaultTheme.statusDanger),
        );
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vault = context.watch<VaultProvider>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: const BoxDecoration(
        color: VaultTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: VaultTheme.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header matching Fig. 3 in paper
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: VaultTheme.primaryCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shield_outlined, color: VaultTheme.primaryCyan, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "SECURE INTAKE",
                    style: TextStyle(
                      color: VaultTheme.primaryCyan,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    "Upload Document",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Files are encrypted before document analysis begins.",
            style: TextStyle(color: VaultTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),

          if (vault.uploadStatus != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: VaultTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: VaultTheme.primaryCyan.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: VaultTheme.primaryCyan),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      vault.uploadStatus!,
                      style: const TextStyle(fontSize: 13, color: VaultTheme.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Choose source container (Matching Fig. 3)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: VaultTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: VaultTheme.surfaceBorder),
            ),
            child: Column(
              children: [
                const Text(
                  "Choose a source",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: VaultTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Select a document or file to preview the secure processing flow",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: VaultTheme.textMuted),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSourceOption(
                      icon: Icons.camera_alt_outlined,
                      label: "Camera",
                      onTap: () => _pickAndUpload(context, "Camera"),
                    ),
                    _buildSourceOption(
                      icon: Icons.photo_library_outlined,
                      label: "Photos",
                      onTap: () => _pickAndUpload(context, "Photos"),
                    ),
                    _buildSourceOption(
                      icon: Icons.folder_open_outlined,
                      label: "Files",
                      onTap: () => _pickAndUpload(context, "Files"),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _isPicking ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 84,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: VaultTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: VaultTheme.surfaceBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: VaultTheme.primaryCyan, size: 28),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12, color: VaultTheme.textPrimary)),
          ],
        ),
      ),
    );
  }
}
