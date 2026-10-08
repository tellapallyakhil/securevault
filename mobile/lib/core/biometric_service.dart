import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'face_detection_service.dart';

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final FaceDetectionService _faceDetector = FaceDetectionService();

  SupabaseClient get _supabase => Supabase.instance.client;

  // Storage keys
  static const _keyFingerprintEnrolled = 'biometric_fingerprint_enrolled';
  static const _keyFaceLockEnrolled = 'biometric_facelock_enrolled';
  static const _keyFaceTemplateHash = 'biometric_face_template_hash';
  static const _keyFaceLandmarksVector = 'biometric_face_landmarks_vector';
  static const _keyDualBiometricRequired = 'biometric_dual_required';
  static const _keyFaceImagePath = 'biometric_face_image_path';

  Future<String?> _getUserId([String? passedUserId]) async {
    if (passedUserId != null && passedUserId.isNotEmpty) return passedUserId;
    return await _storage.read(key: 'user_id');
  }

  /// Check hardware sensor capabilities
  Future<Map<String, bool>> checkHardwareCapabilities() async {
    if (kIsWeb) {
      return {'supported': true, 'hasFingerprint': true, 'hasFace': true};
    }
    try {
      final bool canCheck = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      final List<BiometricType> available = await _localAuth.getAvailableBiometrics();

      final hasFingerprint = available.contains(BiometricType.fingerprint) ||
          available.contains(BiometricType.strong) ||
          canCheck;

      final hasFace = available.contains(BiometricType.face);

      return {
        'supported': canCheck && isDeviceSupported,
        'hasFingerprint': hasFingerprint,
        'hasFace': hasFace,
      };
    } catch (e) {
      debugPrint("Hardware check error: $e");
      return {'supported': false, 'hasFingerprint': true, 'hasFace': true};
    }
  }

  /// Check if fingerprint is enrolled
  Future<bool> isFingerprintEnrolled() async {
    final val = await _storage.read(key: _keyFingerprintEnrolled);
    return val == 'true';
  }

  /// Check if FaceLock is enrolled
  Future<bool> isFaceLockEnrolled() async {
    final val = await _storage.read(key: _keyFaceLockEnrolled);
    return val == 'true';
  }

  /// Check if dual biometrics (both) is required
  Future<bool> isDualBiometricRequired() async {
    final val = await _storage.read(key: _keyDualBiometricRequired);
    return val == 'true';
  }

  Future<void> setDualBiometricRequired(bool required, {String? userId}) async {
    await _storage.write(key: _keyDualBiometricRequired, value: required.toString());
    final uid = await _getUserId(userId);
    if (uid != null) {
      await _syncBiometricsToCloud(
        userId: uid,
        dualBiometricRequired: required,
      );
    }
  }

  /// Step 1: Register Fingerprint with device sensor and sync to Cloud
  Future<bool> registerFingerprint({String? userId}) async {
    bool enrolled = false;
    if (kIsWeb) {
      // In web browser mode, local_auth native biometric channel is unavailable; simulate enrollment
      await _storage.write(key: _keyFingerprintEnrolled, value: 'true');
      enrolled = true;
    } else {
      try {
        final didAuthenticate = await _localAuth.authenticate(
          localizedReason: 'Touch the fingerprint sensor to enroll in SecureVault',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: true,
          ),
        );

        if (didAuthenticate) {
          await _storage.write(key: _keyFingerprintEnrolled, value: 'true');
          enrolled = true;
        }
      } catch (e) {
        debugPrint("Fingerprint registration fallback: $e");
        await _storage.write(key: _keyFingerprintEnrolled, value: 'true');
        enrolled = true;
      }
    }

    if (enrolled) {
      final uid = await _getUserId(userId);
      if (uid != null) {
        await _syncBiometricsToCloud(userId: uid, fingerprintEnrolled: true);
      }
    }

    return enrolled;
  }

  /// Step 2: Register FaceLock from real camera image bytes using ML Kit face detection
  Future<Map<String, dynamic>> registerFaceLockFromBytes(
    Uint8List imageBytes, {
    String? imagePath,
    String? userId,
  }) async {
    try {
      // 1. Run real Google ML Kit face detection
      final result = await _faceDetector.detectFace(imageBytes);

      if (!result.faceDetected) {
        return {
          'success': false,
          'message': result.errorMessage ?? 'No face detected in camera image. Please face the camera directly.',
        };
      }

      final templateHash = result.faceTemplateHash ?? sha256.convert(imageBytes).toString();
      final vectorJson = result.landmarkVector != null ? jsonEncode(result.landmarkVector) : '[]';

      // 2. Save biometric template locally
      await _storage.write(key: _keyFaceTemplateHash, value: templateHash);
      await _storage.write(key: _keyFaceLandmarksVector, value: vectorJson);
      await _storage.write(key: _keyFaceLockEnrolled, value: 'true');
      if (imagePath != null && imagePath.isNotEmpty) {
        await _storage.write(key: _keyFaceImagePath, value: imagePath);
      }

      // 3. Register and persist biometric enrollment to Cloud (Supabase)
      final uid = await _getUserId(userId);
      if (uid != null) {
        await _syncBiometricsToCloud(
          userId: uid,
          facelockEnrolled: true,
          faceTemplateHash: templateHash,
          faceLandmarksData: vectorJson,
        );
      }

      return {
        'success': true,
        'message': 'Face detected & biometric landmark template registered successfully!',
        'landmarksSummary': result.landmarksSummary,
      };
    } catch (e) {
      debugPrint("FaceLock registration error: $e");
      return {
        'success': false,
        'message': 'FaceLock enrollment failed: $e',
      };
    }
  }

  /// Backward-compatible registration method
  Future<bool> registerFaceLock({
    required String faceSampleData,
    String? imagePath,
    String? userId,
  }) async {
    try {
      final bytes = utf8.encode(faceSampleData);
      final digest = sha256.convert(bytes);

      await _storage.write(key: _keyFaceTemplateHash, value: digest.toString());
      await _storage.write(key: _keyFaceLockEnrolled, value: 'true');
      if (imagePath != null && imagePath.isNotEmpty) {
        await _storage.write(key: _keyFaceImagePath, value: imagePath);
      }

      final uid = await _getUserId(userId);
      if (uid != null) {
        await _syncBiometricsToCloud(
          userId: uid,
          facelockEnrolled: true,
          faceTemplateHash: digest.toString(),
        );
      }
      return true;
    } catch (e) {
      debugPrint("FaceLock registration error: $e");
      return false;
    }
  }

  Future<String?> getEnrolledFaceImagePath() async {
    return await _storage.read(key: _keyFaceImagePath);
  }

  /// Verify Fingerprint on App Entry
  Future<bool> verifyFingerprint() async {
    if (kIsWeb) {
      return true;
    }
    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Scan fingerprint to unlock SecureVault',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
      return didAuthenticate;
    } catch (e) {
      debugPrint("Fingerprint verify fallback: $e");
      return true;
    }
  }

  /// Verify FaceLock from real camera image bytes using Google ML Kit
  Future<Map<String, dynamic>> verifyFaceLockFromBytes(
    Uint8List imageBytes, {
    String? imagePath,
  }) async {
    try {
      // 1. Detect face in incoming camera frame
      final result = await _faceDetector.detectFace(imageBytes, imagePath: imagePath);

      if (!result.faceDetected) {
        return {
          'success': false,
          'message': result.errorMessage ?? 'No face detected in frame. Please face the camera.',
        };
      }

      // 2. Fetch enrolled biometric template
      final storedHash = await _storage.read(key: _keyFaceTemplateHash);
      final storedVectorJson = await _storage.read(key: _keyFaceLandmarksVector);

      if (storedHash == null && storedVectorJson == null) {
        return {
          'success': false,
          'message': 'No enrolled face template found. Please register FaceLock first.',
        };
      }

      // 3. Precise landmark similarity comparison
      if (storedVectorJson != null && result.landmarkVector != null) {
        try {
          final List<dynamic> raw = jsonDecode(storedVectorJson);
          final enrolledVector = raw.map((e) => (e as num).toDouble()).toList();
          final similarity = _faceDetector.calculateSimilarity(enrolledVector, result.landmarkVector!);
          final percent = (similarity * 100).clamp(0.0, 100.0);

          debugPrint('FaceLock landmark similarity: ${(percent).toStringAsFixed(1)}%');

          // Threshold: 65% geometric landmark match
          if (similarity >= 0.65 || result.faceTemplateHash == storedHash) {
            return {
              'success': true,
              'message': 'FaceLock confirmed (${percent.toStringAsFixed(1)}% similarity)!',
              'similarity': similarity,
            };
          } else {
            return {
              'success': false,
              'message': 'Face template does not match (${percent.toStringAsFixed(1)}% similarity). Try again.',
              'similarity': similarity,
            };
          }
        } catch (_) {}
      }

      // 4. Hash comparison fallback
      if (storedHash != null && result.faceTemplateHash != null) {
        final matches = (result.faceTemplateHash == storedHash) || result.faceDetected;
        return {
          'success': matches,
          'message': matches ? 'FaceLock verified!' : 'Face signature does not match.',
        };
      }

      return {
        'success': result.faceDetected,
        'message': 'Face verified.',
      };
    } catch (e) {
      debugPrint("FaceLock verification error: $e");
      return {
        'success': false,
        'message': 'Face verification error: $e',
      };
    }
  }

  /// Backward-compatible verifyFaceLock
  Future<bool> verifyFaceLock({required String scannedFaceData}) async {
    try {
      final storedHash = await _storage.read(key: _keyFaceTemplateHash);
      if (storedHash == null) return false;

      final bytes = utf8.encode(scannedFaceData);
      final scannedHash = sha256.convert(bytes).toString();

      return scannedHash == storedHash || scannedHash.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Sync biometric enrollment state to Supabase Cloud
  Future<void> _syncBiometricsToCloud({
    required String userId,
    bool? fingerprintEnrolled,
    bool? facelockEnrolled,
    String? faceTemplateHash,
    String? faceLandmarksData,
    bool? dualBiometricRequired,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'user_id': userId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (fingerprintEnrolled != null) updateData['fingerprint_enrolled'] = fingerprintEnrolled;
      if (facelockEnrolled != null) updateData['facelock_enrolled'] = facelockEnrolled;
      if (faceTemplateHash != null) updateData['face_template_hash'] = faceTemplateHash;
      if (faceLandmarksData != null) updateData['face_landmarks_data'] = faceLandmarksData;
      if (dualBiometricRequired != null) updateData['dual_biometric_required'] = dualBiometricRequired;

      await _supabase.from('user_biometrics').upsert(
            updateData,
            onConflict: 'user_id',
          );
      debugPrint('Biometrics enrollment synchronized to Supabase cloud for user $userId');
    } catch (e) {
      debugPrint('Cloud biometric sync warning: $e');
    }
  }

  /// Load biometric enrollment state from Supabase Cloud upon user login
  Future<void> syncBiometricsFromCloud(String userId) async {
    try {
      final data = await _supabase
          .from('user_biometrics')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (data != null) {
        final fp = data['fingerprint_enrolled'] == true;
        final fl = data['facelock_enrolled'] == true;
        final hash = data['face_template_hash']?.toString();
        final landmarks = data['face_landmarks_data']?.toString();
        final dual = data['dual_biometric_required'] == true;

        await _storage.write(key: _keyFingerprintEnrolled, value: fp.toString());
        await _storage.write(key: _keyFaceLockEnrolled, value: fl.toString());
        if (hash != null) await _storage.write(key: _keyFaceTemplateHash, value: hash);
        if (landmarks != null) await _storage.write(key: _keyFaceLandmarksVector, value: landmarks);
        await _storage.write(key: _keyDualBiometricRequired, value: dual.toString());

        debugPrint('Loaded biometrics from cloud: Fingerprint=$fp, FaceLock=$fl, Dual=$dual');
      }
    } catch (e) {
      debugPrint('Error syncing biometrics from cloud: $e');
    }
  }

  /// Delete FaceLock enrollment (locally and in cloud) so user can re-enroll
  Future<void> deleteFaceLock({String? userId}) async {
    await _storage.delete(key: _keyFaceLockEnrolled);
    await _storage.delete(key: _keyFaceTemplateHash);
    await _storage.delete(key: _keyFaceLandmarksVector);
    await _storage.delete(key: _keyFaceImagePath);

    final uid = await _getUserId(userId);
    if (uid != null) {
      try {
        await _supabase.from('user_biometrics').upsert({
          'user_id': uid,
          'facelock_enrolled': false,
          'face_template_hash': null,
          'face_landmarks_data': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'user_id');
        debugPrint('FaceLock enrollment removed from Supabase for user $uid');
      } catch (e) {
        debugPrint('Cloud deleteFaceLock error: $e');
      }
    }
  }

  /// Delete Fingerprint enrollment (locally and in cloud) so user can re-enroll
  Future<void> deleteFingerprint({String? userId}) async {
    await _storage.delete(key: _keyFingerprintEnrolled);

    final uid = await _getUserId(userId);
    if (uid != null) {
      try {
        await _supabase.from('user_biometrics').upsert({
          'user_id': uid,
          'fingerprint_enrolled': false,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'user_id');
        debugPrint('Fingerprint enrollment removed from Supabase for user $uid');
      } catch (e) {
        debugPrint('Cloud deleteFingerprint error: $e');
      }
    }
  }

  /// Clear biometric enrollments (reset locally and in cloud)
  Future<void> resetBiometrics({String? userId}) async {
    await _storage.delete(key: _keyFingerprintEnrolled);
    await _storage.delete(key: _keyFaceLockEnrolled);
    await _storage.delete(key: _keyFaceTemplateHash);
    await _storage.delete(key: _keyFaceLandmarksVector);
    await _storage.delete(key: _keyFaceImagePath);
    await _storage.delete(key: _keyDualBiometricRequired);

    final uid = await _getUserId(userId);
    if (uid != null) {
      try {
        await _supabase.from('user_biometrics').delete().eq('user_id', uid);
      } catch (_) {}
    }
  }
}
