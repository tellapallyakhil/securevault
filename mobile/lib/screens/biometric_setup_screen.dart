import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/theme.dart';
import '../core/biometric_service.dart';

class BiometricSetupScreen extends StatefulWidget {
  final VoidCallback onSetupComplete;

  const BiometricSetupScreen({super.key, required this.onSetupComplete});

  @override
  State<BiometricSetupScreen> createState() => _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends State<BiometricSetupScreen> with SingleTickerProviderStateMixin {
  final BiometricService _bioService = BiometricService();
  final ImagePicker _picker = ImagePicker();
  
  int _currentStep = 1; // 1: Fingerprint, 2: FaceLock, 3: Completed
  bool _isFingerprintEnrolled = false;
  bool _isFaceLockEnrolled = false;
  bool _isScanningFace = false;
  Uint8List? _capturedFaceBytes;

  late AnimationController _scanController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_scanController);
    _checkExisting();
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _checkExisting() async {
    final fp = await _bioService.isFingerprintEnrolled();
    final fl = await _bioService.isFaceLockEnrolled();
    setState(() {
      _isFingerprintEnrolled = fp;
      _isFaceLockEnrolled = fl;
      if (fp && !fl) _currentStep = 2;
      if (fp && fl) _currentStep = 3;
    });
  }

  Future<void> _enrollFingerprint() async {
    final success = await _bioService.registerFingerprint();
    if (success) {
      setState(() {
        _isFingerprintEnrolled = true;
        _currentStep = 2; // Advance to FaceLock setup
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Fingerprint successfully registered!"),
            backgroundColor: VaultTheme.statusSafe,
          ),
        );
      }
    }
  }

  Future<void> _deleteFaceLock() async {
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

    if (confirmed == true) {
      await _bioService.deleteFaceLock();
      setState(() {
        _isFaceLockEnrolled = false;
        _capturedFaceBytes = null;
        _currentStep = 2;
      });
      widget.onSetupComplete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("FaceLock data deleted. You can now enroll a new face."),
            backgroundColor: VaultTheme.statusWarning,
          ),
        );
      }
    }
  }

  Future<void> _deleteFingerprint() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VaultTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: VaultTheme.statusDanger),
            SizedBox(width: 8),
            Text("Delete Fingerprint Data?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          "This will remove the fingerprint biometric association for this vault.",
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

    if (confirmed == true) {
      await _bioService.deleteFingerprint();
      setState(() {
        _isFingerprintEnrolled = false;
        _currentStep = 1;
      });
      widget.onSetupComplete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Fingerprint data deleted. You can enroll a new fingerprint."),
            backgroundColor: VaultTheme.statusWarning,
          ),
        );
      }
    }
  }

  Future<void> _resetAllBiometrics() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VaultTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: VaultTheme.statusDanger),
            SizedBox(width: 8),
            Text("Reset All Biometrics?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          "Both Fingerprint and FaceLock credentials will be permanently erased from this phone and Supabase Cloud.",
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
            child: const Text("Reset All", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _bioService.resetBiometrics();
      setState(() {
        _isFingerprintEnrolled = false;
        _isFaceLockEnrolled = false;
        _capturedFaceBytes = null;
        _currentStep = 1;
      });
      widget.onSetupComplete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("All biometric data cleared. You can start fresh."),
            backgroundColor: VaultTheme.statusWarning,
          ),
        );
      }
    }
  }

  Future<void> _enrollFaceLock({bool fromGallery = false}) async {
    try {
      if (!fromGallery && !kIsWeb) {
        final cameraStatus = await Permission.camera.request();
        if (!cameraStatus.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Camera permission is required for FaceLock enrollment."),
                backgroundColor: VaultTheme.statusDanger,
              ),
            );
          }
          return;
        }
      }

      final XFile? photo = await _picker.pickImage(
        source: fromGallery ? ImageSource.gallery : ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 90,
      );

      if (photo == null) {
        return; // User dismissed
      }

      final bytes = await photo.readAsBytes();

      setState(() {
        _isScanningFace = true;
        _capturedFaceBytes = bytes;
      });

      // Analyze real facial landmarks with Google ML Kit and register to Cloud
      final res = await _bioService.registerFaceLockFromBytes(
        bytes,
        imagePath: photo.path,
      );

      if (!mounted) return;

      setState(() => _isScanningFace = false);

      if (res['success'] == true) {
        setState(() {
          _isFaceLockEnrolled = true;
          _currentStep = 3;
        });
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: VaultTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.verified, color: VaultTheme.statusSafe, size: 24),
                SizedBox(width: 8),
                Text("FaceLock Enrolled!", style: TextStyle(color: VaultTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Facial landmarks extracted successfully using Google ML Kit on-device computer vision.",
                  style: TextStyle(color: VaultTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: VaultTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: VaultTheme.surfaceBorder),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("• Single Human Face Verified", style: TextStyle(color: VaultTheme.statusSafe, fontSize: 12, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text("• 128D Invariant Geometry Vector Generated", style: TextStyle(color: VaultTheme.primaryCyan, fontSize: 12)),
                      SizedBox(height: 4),
                      Text("• Biometric Hash Synchronized with Supabase", style: TextStyle(color: VaultTheme.textPrimary, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.onSetupComplete();
                },
                style: ElevatedButton.styleFrom(backgroundColor: VaultTheme.primaryCyan),
                child: const Text("Continue", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: VaultTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: VaultTheme.statusDanger),
                SizedBox(width: 8),
                Text("Face Not Detected", style: TextStyle(color: VaultTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              res['message']?.toString() ?? "Could not detect a clear human face in the image. Please position your face directly within the frame in good lighting and try again.",
              style: const TextStyle(color: VaultTheme.textSecondary, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Try Again", style: TextStyle(color: VaultTheme.primaryCyan, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isScanningFace = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("FaceLock enrollment error: $e"),
            backgroundColor: VaultTheme.statusDanger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Biometric Security Setup", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: VaultTheme.textPrimary),
            color: VaultTheme.surfaceElevated,
            tooltip: "Biometric Options",
            onSelected: (value) {
              if (value == 'delete_face') {
                _deleteFaceLock();
              } else if (value == 'delete_fp') {
                _deleteFingerprint();
              } else if (value == 'reset_all') {
                _resetAllBiometrics();
              }
            },
            itemBuilder: (context) => [
              if (_isFaceLockEnrolled)
                const PopupMenuItem(
                  value: 'delete_face',
                  child: Row(
                    children: [
                      Icon(Icons.face_retouching_off, color: VaultTheme.statusDanger, size: 20),
                      SizedBox(width: 10),
                      Text("Delete Face Data", style: TextStyle(color: VaultTheme.statusDanger, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              if (_isFingerprintEnrolled)
                const PopupMenuItem(
                  value: 'delete_fp',
                  child: Row(
                    children: [
                      Icon(Icons.fingerprint, color: VaultTheme.statusDanger, size: 20),
                      SizedBox(width: 10),
                      Text("Delete Fingerprint", style: TextStyle(color: VaultTheme.statusDanger, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'reset_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: VaultTheme.textMuted, size: 20),
                    SizedBox(width: 10),
                    Text("Reset All Biometrics", style: TextStyle(color: VaultTheme.textPrimary, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Step Indicators
              Row(
                children: [
                  _buildStepIndicator(step: 1, label: "Fingerprint", isDone: _isFingerprintEnrolled, isCurrent: _currentStep == 1),
                  Expanded(child: Container(height: 2, color: _isFingerprintEnrolled ? VaultTheme.statusSafe : VaultTheme.surfaceBorder)),
                  _buildStepIndicator(step: 2, label: "FaceLock", isDone: _isFaceLockEnrolled, isCurrent: _currentStep == 2),
                ],
              ),
              const SizedBox(height: 24),

              // Content based on step
              Expanded(
                child: _currentStep == 1
                    ? _buildFingerprintStep()
                    : (_currentStep == 2 ? _buildFaceLockStep() : _buildCompletedStep()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator({required int step, required String label, required bool isDone, required bool isCurrent}) {
    return InkWell(
      onTap: () => setState(() => _currentStep = step),
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone
                  ? VaultTheme.statusSafe
                  : (isCurrent ? VaultTheme.primaryCyan : VaultTheme.surfaceElevated),
              border: Border.all(
                color: isCurrent ? VaultTheme.primaryCyan : VaultTheme.surfaceBorder,
                width: 2,
              ),
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check, color: Colors.black, size: 20)
                  : Text(
                      "$step",
                      style: TextStyle(
                        color: isCurrent ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isCurrent ? VaultTheme.primaryCyan : VaultTheme.textMuted,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFingerprintStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: VaultTheme.surface,
            border: Border.all(
              color: _isFingerprintEnrolled ? VaultTheme.statusSafe : VaultTheme.primaryCyan.withValues(alpha: 0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: (_isFingerprintEnrolled ? VaultTheme.statusSafe : VaultTheme.primaryCyan).withValues(alpha: 0.2),
                blurRadius: 30,
                spreadRadius: 5,
              )
            ],
          ),
          child: Icon(
            Icons.fingerprint,
            size: 72,
            color: _isFingerprintEnrolled ? VaultTheme.statusSafe : VaultTheme.primaryCyan,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _isFingerprintEnrolled ? "Fingerprint Registered" : "Register Your Fingerprint",
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: VaultTheme.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          _isFingerprintEnrolled
              ? "Your hardware sensor biometric credentials are registered to this device."
              : "Touch your device's fingerprint sensor to bind your biometric credentials to the secure enclave.",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: VaultTheme.textSecondary),
        ),
        if (_isFingerprintEnrolled) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: VaultTheme.statusSafe.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: VaultTheme.statusSafe.withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: VaultTheme.statusSafe, size: 16),
                SizedBox(width: 8),
                Text("Fingerprint Active & Verified", style: TextStyle(color: VaultTheme.statusSafe, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _enrollFingerprint,
          icon: Icon(_isFingerprintEnrolled ? Icons.refresh : Icons.touch_app, color: Colors.black),
          label: Text(
            _isFingerprintEnrolled ? "RE-SCAN FINGERPRINT" : "SCAN FINGERPRINT TO REGISTER",
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: VaultTheme.primaryCyan,
            padding: const EdgeInsets.symmetric(vertical: 14),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        if (_isFingerprintEnrolled) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _deleteFingerprint,
            icon: const Icon(Icons.delete_outline, color: VaultTheme.statusDanger),
            label: const Text("DELETE FINGERPRINT DATA", style: TextStyle(color: VaultTheme.statusDanger, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: VaultTheme.statusDanger),
              padding: const EdgeInsets.symmetric(vertical: 14),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: () => setState(() => _currentStep = 2),
          icon: const Icon(Icons.face, color: VaultTheme.primaryCyan),
          label: const Text("Go to FaceLock Enrollment →", style: TextStyle(color: VaultTheme.primaryCyan, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildFaceLockStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Face Scanner Frame with Animated Reticle
        SizedBox(
          width: 190,
          height: 190,
          child: Stack(
            children: [
              Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: VaultTheme.surface,
                  border: Border.all(
                    color: _isFaceLockEnrolled ? VaultTheme.statusSafe : VaultTheme.primaryCyan,
                    width: 2.5,
                  ),
                ),
                child: _capturedFaceBytes != null
                    ? ClipOval(
                        child: Image.memory(
                          _capturedFaceBytes!,
                          width: 190,
                          height: 190,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(
                        _isFaceLockEnrolled ? Icons.face_retouching_natural : Icons.face,
                        size: 80,
                        color: _isFaceLockEnrolled ? VaultTheme.statusSafe : VaultTheme.textMuted,
                      ),
              ),
              if (_isScanningFace)
                AnimatedBuilder(
                  animation: _scanAnimation,
                  builder: (context, child) {
                    return Positioned(
                      top: 15 + (_scanAnimation.value * 155),
                      left: 15,
                      child: Container(
                        width: 160,
                        height: 3,
                        decoration: BoxDecoration(
                          color: VaultTheme.accentNeon,
                          boxShadow: [
                            BoxShadow(
                              color: VaultTheme.accentNeon.withValues(alpha: 0.8),
                              blurRadius: 10,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _isScanningFace
              ? "Extracting Facial Landmarks..."
              : (_isFaceLockEnrolled ? "FaceLock Template Enrolled" : "FaceLock Recognition Enrollment"),
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: VaultTheme.textPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          _isScanningFace
              ? "Mapping geometric facial contour points into a 128-dimensional biometric template."
              : (_isFaceLockEnrolled
                  ? "Facial geometry vector is stored locally and synced to Supabase Cloud."
                  : "Capture your face via the front camera or choose a clear portrait photo from your gallery."),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: VaultTheme.textSecondary),
        ),
        if (_isFaceLockEnrolled) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: VaultTheme.statusSafe.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: VaultTheme.statusSafe.withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: VaultTheme.statusSafe, size: 16),
                SizedBox(width: 8),
                Text("FaceLock AI Model Ready", style: TextStyle(color: VaultTheme.statusSafe, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _isScanningFace ? null : () => _enrollFaceLock(fromGallery: false),
          icon: const Icon(Icons.camera_front, color: Colors.black),
          label: Text(
            _isScanningFace
                ? "ANALYZING FACE PHOTO..."
                : (_isFaceLockEnrolled ? "RE-SCAN FACE (FRONT CAMERA)" : "TAKE SELFIE (FRONT CAMERA)"),
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: VaultTheme.primaryCyan,
            padding: const EdgeInsets.symmetric(vertical: 14),
            minimumSize: const Size.fromHeight(46),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _isScanningFace ? null : () => _enrollFaceLock(fromGallery: true),
          icon: const Icon(Icons.photo_library_outlined, color: VaultTheme.primaryCyan),
          label: const Text(
            "SELECT FACE PHOTO FROM GALLERY",
            style: TextStyle(color: VaultTheme.primaryCyan, fontWeight: FontWeight.bold),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: VaultTheme.primaryCyan),
            padding: const EdgeInsets.symmetric(vertical: 14),
            minimumSize: const Size.fromHeight(46),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        if (_isFaceLockEnrolled) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _isScanningFace ? null : _deleteFaceLock,
            icon: const Icon(Icons.delete_outline, color: VaultTheme.statusDanger),
            label: const Text("DELETE FACE DATA", style: TextStyle(color: VaultTheme.statusDanger, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: VaultTheme.statusDanger),
              padding: const EdgeInsets.symmetric(vertical: 14),
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompletedStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: VaultTheme.statusSafe.withValues(alpha: 0.15),
            border: Border.all(color: VaultTheme.statusSafe, width: 2),
          ),
          child: const Icon(Icons.verified_user, size: 56, color: VaultTheme.statusSafe),
        ),
        const SizedBox(height: 20),
        const Text(
          "Biometrics Activated!",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: VaultTheme.textPrimary),
        ),
        const SizedBox(height: 8),
        const Text(
          "Manage, delete, or re-enroll your Fingerprint and FaceLock credentials below.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: VaultTheme.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: VaultTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: VaultTheme.surfaceBorder),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    _isFingerprintEnrolled ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: _isFingerprintEnrolled ? VaultTheme.statusSafe : VaultTheme.textMuted,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isFingerprintEnrolled ? "Hardware Fingerprint Sensor Enrolled" : "Fingerprint Not Enrolled",
                      style: TextStyle(
                        fontSize: 13,
                        color: _isFingerprintEnrolled ? VaultTheme.textPrimary : VaultTheme.textMuted,
                      ),
                    ),
                  ),
                  if (_isFingerprintEnrolled)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: VaultTheme.statusDanger, size: 20),
                      tooltip: "Delete Fingerprint",
                      onPressed: _deleteFingerprint,
                    ),
                ],
              ),
              const Divider(height: 16, color: VaultTheme.surfaceBorder),
              Row(
                children: [
                  Icon(
                    _isFaceLockEnrolled ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: _isFaceLockEnrolled ? VaultTheme.statusSafe : VaultTheme.textMuted,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isFaceLockEnrolled ? "FaceLock AI Facial Template Enrolled" : "FaceLock Not Enrolled",
                      style: TextStyle(
                        fontSize: 13,
                        color: _isFaceLockEnrolled ? VaultTheme.textPrimary : VaultTheme.textMuted,
                      ),
                    ),
                  ),
                  if (_isFaceLockEnrolled)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: VaultTheme.statusDanger, size: 20),
                      tooltip: "Delete Face Data",
                      onPressed: _deleteFaceLock,
                    ),
                ],
              ),
            ],
          ),
        ),
        const Spacer(),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep = 1),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: VaultTheme.surfaceBorder),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("RE-ENROLL", style: TextStyle(color: VaultTheme.primaryCyan, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: _resetAllBiometrics,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: VaultTheme.statusDanger),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("RESET ALL", style: TextStyle(color: VaultTheme.statusDanger, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: () {
            widget.onSetupComplete();
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: VaultTheme.primaryCyan,
            padding: const EdgeInsets.symmetric(vertical: 16),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text("CONTINUE TO SECURE VAULT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
