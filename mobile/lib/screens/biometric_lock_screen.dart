import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/theme.dart';
import '../core/biometric_service.dart';

class BiometricLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  final VoidCallback onFallbackToPassword;

  const BiometricLockScreen({
    super.key,
    required this.onUnlocked,
    required this.onFallbackToPassword,
  });

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> with SingleTickerProviderStateMixin {
  final BiometricService _bioService = BiometricService();
  final ImagePicker _picker = ImagePicker();
  
  bool _hasFingerprint = false;
  bool _hasFaceLock = false;
  bool _isScanningFace = false;
  bool _faceVerified = false;
  bool _fingerprintVerified = false;
  String _statusMessage = "Select biometric verification method";

  late AnimationController _scanController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_scanController);

    _initBiometrics();
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _initBiometrics() async {
    final fp = await _bioService.isFingerprintEnrolled();
    final fl = await _bioService.isFaceLockEnrolled();
    if (mounted) {
      setState(() {
        _hasFingerprint = fp;
        _hasFaceLock = fl;
      });
    }

    // Automatically prompt fingerprint if available
    if (fp) {
      _verifyFingerprint();
    }
  }

  Future<void> _verifyFingerprint() async {
    setState(() => _statusMessage = "Touch the fingerprint sensor...");
    final success = await _bioService.verifyFingerprint();
    if (mounted) {
      if (success) {
        setState(() {
          _fingerprintVerified = true;
          _statusMessage = "Fingerprint verified!";
        });
        _checkUnlockCriteria();
      } else {
        setState(() => _statusMessage = "Fingerprint not recognized. Try again or use FaceLock.");
      }
    }
  }

  Future<void> _verifyFaceLock({bool fromGallery = false}) async {
    try {
      if (!fromGallery && !kIsWeb) {
        final cameraStatus = await Permission.camera.request();
        if (!cameraStatus.isGranted) {
          if (mounted) {
            setState(() => _statusMessage = "Camera permission is required for FaceLock.");
          }
          return;
        }
      }

      final photo = await _picker.pickImage(
        source: fromGallery ? ImageSource.gallery : ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 90,
      );

      if (photo == null) {
        if (mounted) {
          setState(() => _statusMessage = "Face verification cancelled. Try again or enter password.");
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isScanningFace = true;
          _statusMessage = "Matching facial contour signature...";
        });
      }

      final bytes = await photo.readAsBytes();

      final result = await _bioService.verifyFaceLockFromBytes(bytes, imagePath: photo.path);
      final bool success = result['success'] == true;
      final String msg = result['message']?.toString() ?? (success ? "FaceLock match confirmed!" : "Face template does not match.");

      if (mounted) {
        setState(() {
          _isScanningFace = false;
          if (success) {
            _faceVerified = true;
            _statusMessage = msg;
          } else {
            _statusMessage = msg;
          }
        });
        if (success) _checkUnlockCriteria();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanningFace = false;
          _statusMessage = "Face verification error: $e";
        });
      }
    }
  }

  void _checkUnlockCriteria() {
    // Either biometric unlocks the app
    if (_fingerprintVerified || _faceVerified) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) widget.onUnlocked();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VaultTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Lock Icon Header
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: VaultTheme.surface,
                    border: Border.all(color: VaultTheme.primaryCyan.withValues(alpha: 0.4), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: VaultTheme.primaryCyan.withValues(alpha: 0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                      )
                    ],
                  ),
                  child: const Icon(Icons.lock_person_outlined, size: 56, color: VaultTheme.primaryCyan),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                "SECUREVAULT AI",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: VaultTheme.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                "Biometric Verification Required",
                textAlign: TextAlign.center,
                style: TextStyle(color: VaultTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),

              // Face Scanner Visualizer if Scanning
              if (_isScanningFace) ...[
                Center(
                  child: SizedBox(
                    width: 160,
                    height: 160,
                    child: Stack(
                      children: [
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: VaultTheme.surface,
                            border: Border.all(color: VaultTheme.accentNeon, width: 2),
                          ),
                          child: const Icon(Icons.face, size: 70, color: VaultTheme.textMuted),
                        ),
                        AnimatedBuilder(
                          animation: _scanAnimation,
                          builder: (context, child) {
                            return Positioned(
                              top: 15 + (_scanAnimation.value * 130),
                              left: 10,
                              child: Container(
                                width: 140,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: VaultTheme.accentNeon,
                                  boxShadow: [
                                    BoxShadow(
                                      color: VaultTheme.accentNeon.withValues(alpha: 0.9),
                                      blurRadius: 8,
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
                ),
                const SizedBox(height: 20),
              ],

              // Status Message Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: VaultTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: VaultTheme.surfaceBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      (_fingerprintVerified || _faceVerified)
                          ? Icons.check_circle
                          : Icons.security,
                      color: (_fingerprintVerified || _faceVerified)
                          ? VaultTheme.statusSafe
                          : VaultTheme.primaryCyan,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _statusMessage,
                        style: const TextStyle(fontSize: 12, color: VaultTheme.textPrimary),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Biometric Action Buttons
              if (_hasFingerprint) ...[
                ElevatedButton.icon(
                  onPressed: _verifyFingerprint,
                  icon: const Icon(Icons.fingerprint, color: Colors.black, size: 24),
                  label: const Text("UNLOCK WITH FINGERPRINT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VaultTheme.primaryCyan,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // FaceLock - always show (guide to enroll if not enrolled)
              OutlinedButton.icon(
                onPressed: _isScanningFace
                    ? null
                    : () {
                        if (_hasFaceLock) {
                          _verifyFaceLock(fromGallery: false);
                        } else {
                          setState(() => _statusMessage = "FaceLock not enrolled yet. Opening camera for quick verification...");
                          _verifyFaceLock(fromGallery: false);
                        }
                      },
                icon: Icon(
                  Icons.face_retouching_natural,
                  color: _hasFaceLock ? VaultTheme.accentNeon : VaultTheme.textMuted,
                  size: 24,
                ),
                label: Text(
                  _hasFaceLock ? "UNLOCK WITH FACELOCK (CAMERA)" : "SETUP & UNLOCK FACELOCK",
                  style: TextStyle(
                    color: _hasFaceLock ? VaultTheme.accentNeon : VaultTheme.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: _hasFaceLock ? VaultTheme.accentNeon : VaultTheme.textMuted,
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),

              TextButton.icon(
                onPressed: _isScanningFace ? null : () => _verifyFaceLock(fromGallery: true),
                icon: const Icon(Icons.photo_library_outlined, size: 18, color: VaultTheme.primaryCyan),
                label: const Text(
                  "Or select face portrait from Gallery",
                  style: TextStyle(color: VaultTheme.primaryCyan, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 14),

              const Spacer(),

              // Password Fallback
              TextButton.icon(
                onPressed: widget.onFallbackToPassword,
                icon: const Icon(Icons.password, size: 16, color: VaultTheme.textMuted),
                label: const Text(
                  "Use Master Vault Password instead",
                  style: TextStyle(color: VaultTheme.textMuted, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
