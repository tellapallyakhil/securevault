import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:securevault_app/core/pii_classifier.dart';
import 'package:securevault_app/core/face_detection_service.dart';
import 'package:securevault_app/core/notification_service.dart';
import 'package:securevault_app/core/ocr_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. PIIClassifier & Document Classifier Tests', () {
    test('Correctly identifies and classifies Indian Aadhaar Card', () {
      const sampleAadhaar = '''
      GOVERNMENT OF INDIA
      Unique Identification Authority of India
      To: Rajesh Kumar
      DOB: 12/05/1990
      Gender: Male
      3456 7890 1234
      Mera Aadhaar, Meri Pehchan
      ''';

      final result = PIIClassifier.analyzeText(sampleAadhaar);
      expect(result['category'], equals('Identity'));
      expect(result['sensitivity'], equals('HIGH'));
      expect(result['document_type'], equals('Aadhaar Card'));
      expect(result['counts_by_type']['AADHAAR'], greaterThanOrEqualTo(1));
    });

    test('Correctly identifies and classifies Indian PAN Card', () {
      const samplePan = '''
      INCOME TAX DEPARTMENT
      GOVT. OF INDIA
      Permanent Account Number Card
      ABCDE1234F
      Name: SURESH SHARMA
      Father's Name: RAMESH SHARMA
      Date of Birth: 15/08/1985
      ''';

      final result = PIIClassifier.analyzeText(samplePan);
      expect(result['category'], equals('Identity'));
      expect(result['sensitivity'], equals('HIGH'));
      expect(result['document_type'], equals('PAN Card'));
      expect(result['counts_by_type']['PAN_CARD'], greaterThanOrEqualTo(1));
    });

    test('Correctly identifies and classifies Indian Passport', () {
      const samplePassport = '''
      PASSPORT
      REPUBLIC OF INDIA
      Passport No: K1234567
      Given Name: PRIYA
      Surname: PATEL
      Nationality: INDIAN
      ''';

      final result = PIIClassifier.analyzeText(samplePassport);
      expect(result['category'], equals('Identity'));
      expect(result['sensitivity'], equals('HIGH'));
      expect(result['document_type'], equals('Passport'));
      expect(result['counts_by_type']['PASSPORT'], greaterThanOrEqualTo(1));
    });

    test('Correctly identifies and classifies Driving License', () {
      const sampleDl = '''
      UNION OF INDIA DRIVING LICENCE
      TRANSPORT DEPARTMENT
      DL No: MH12 2018 0054321
      DOB: 01/01/1992
      Valid Upto: 31/12/2038
      ''';

      final result = PIIClassifier.analyzeText(sampleDl);
      expect(result['category'], equals('Identity'));
      expect(result['document_type'], equals('Driving License'));
    });

    test('Correctly identifies and classifies Medical Prescription', () {
      const sampleMedical = '''
      APOLLO HOSPITALS CARDIOLOGY CLINIC
      Dr. Anand Mehta, MD Cardiologist
      Patient: Arvind Verma, Age: 52
      Rx Diagnosis: Hypertension & Coronary Artery Disease
      Medication: Atorvastatin 20mg, Metoprolol 50mg tablets
      Blood Pressure: 140/90 mmHg, Pulse: 78 bpm
      ''';

      final result = PIIClassifier.analyzeText(sampleMedical);
      expect(result['category'], equals('Medical'));
      expect(result['document_type'], equals('Medical Document'));
    });

    test('Correctly identifies and classifies Financial Bank Statement / Invoice', () {
      const sampleFinance = '''
      HDFC BANK ACCOUNT STATEMENT
      Account Number: 50100234567890
      Statement Period: 01-01-2026 to 31-01-2026
      Net Banking UPI Transaction Total: Rs 45,000.00
      Total Balance: Rs 1,24,500.00
      ''';

      final result = PIIClassifier.analyzeText(sampleFinance);
      expect(result['category'], equals('Financial'));
      expect(result['document_type'], equals('Financial Statement'));
    });

    test('Correctly identifies Educational Marksheet with Course Credits and Total Marks without mapping to Financial', () {
      const sampleEducationalMarksheet = '''
      JAWAHARLAL NEHRU TECHNOLOGICAL UNIVERSITY
      GRADE CARD & CONSOLIDATED STATEMENT OF MARKS
      Bachelor of Technology (B.Tech) - Computer Science & Engineering
      Roll Number: 20A91A0501 | Semester: 7 | Academic Year: 2024-2025
      Subject: Cryptography & Network Security | Course Credits: 4 | Grade: A+
      Subject: Distributed Cloud Systems | Course Credits: 3 | Grade: A
      Subject: Machine Learning & Deep Neural Nets | Course Credits: 4 | Grade: O
      Subject: Cyber Forensics Lab | Course Credits: 2 | Grade: A+
      Total Credits Earned: 24 | SGPA: 9.42 | Cumulative CGPA: 9.18
      Grand Total Marks: 685 / 750
      Result: PASSED WITH DISTINCTION
      Controller of Examinations
      ''';

      final result = PIIClassifier.analyzeText(sampleEducationalMarksheet);
      // Must strictly be Educational, NEVER Financial despite "Credits", "Total Marks", and "Statement of Marks"!
      expect(result['category'], equals('Educational'));
      expect(result['document_type'], equals('Educational Record'));
    });

    test('Correctly classifies University Degree Certificate', () {
      const sampleDegree = '''
      INDIAN INSTITUTE OF TECHNOLOGY
      PROVISIONAL DEGREE CERTIFICATE
      This is to certify that Rahul Sharma has satisfied all requirements for the Degree of
      Bachelor of Science in Information Technology.
      Division: First Class with Distinction
      Registrar | Vice Chancellor
      ''';

      final result = PIIClassifier.analyzeText(sampleDegree);
      expect(result['category'], equals('Educational'));
      expect(result['document_type'], equals('Educational Record'));
    });

    test('Correctly redacts sensitive PII from text', () {
      const originalText = 'My Aadhaar is 3456 7890 1234 and my PAN is ABCDE1234F';
      final redacted = PIIClassifier.redactText(originalText);
      expect(redacted, contains('[AADHAAR_REDACTED]'));
      expect(redacted, contains('[PAN_REDACTED]'));
      expect(redacted, isNot(contains('3456 7890 1234')));
      expect(redacted, isNot(contains('ABCDE1234F')));
    });
  });

  group('2. FaceDetectionService Geometric Landmark Matching Tests', () {
    final detector = FaceDetectionService();

    test('Exact match yields 100% similarity (1.0)', () {
      final enrolled = [0.8, 0.35, 0.40, 0.65, 0.40, 0.50, 0.55, 0.30, 0.45];
      final scanned = [0.8, 0.35, 0.40, 0.65, 0.40, 0.50, 0.55, 0.30, 0.45];

      final similarity = detector.calculateSimilarity(enrolled, scanned);
      expect(similarity, equals(1.0));
    });

    test('Minor variations in face posture still yield >85% similarity (Passes Threshold)', () {
      final enrolled = [0.80, 0.35, 0.40, 0.65, 0.40, 0.50, 0.55, 0.30, 0.45];
      // Scanned with realistic micro-variations (lighting, minor angle tilt)
      final scanned = [0.81, 0.36, 0.39, 0.64, 0.41, 0.51, 0.54, 0.31, 0.46];

      final similarity = detector.calculateSimilarity(enrolled, scanned);
      expect(similarity, greaterThan(0.85));
    });

    test('Completely different face profile yields low similarity (Rejection)', () {
      final faceA = [0.80, 0.35, 0.40, 0.65, 0.40, 0.50, 0.55, 0.30, 0.45];
      final faceB = [1.20, 0.10, 0.80, 0.20, 0.90, 0.15, 0.20, 0.85, 0.10];

      final similarity = detector.calculateSimilarity(faceA, faceB);
      expect(similarity, lessThan(0.50));
    });
  });

  group('3. SecurityNotificationService Anomaly Alert Tests', () {
    test('Can record anomaly notifications and resolve them', () async {
      final notifService = SecurityNotificationService();

      // Trigger anomaly
      await notifService.notifyAnomaly(
        severity: 'CRITICAL',
        riskScore: 88,
        reasons: ['Off-hours burst access detected', 'Unrecognized IP address'],
      );

      expect(notifService.notifications.isNotEmpty, isTrue);
      expect(notifService.unresolvedCount, greaterThanOrEqualTo(1));

      final first = notifService.notifications.first;
      expect(first.severity, equals('CRITICAL'));
      expect(first.riskScore, equals(88));
      expect(first.isResolved, isFalse);

      // Resolve alert
      await notifService.resolveNotification(first.id);
      expect(first.isResolved, isTrue);
    });
  });

  group('4. ClientOCRService Text Extraction Tests', () {
    final ocrService = ClientOCRService();

    test('Directly decodes text files', () async {
      final textData = 'CONFIDENTIAL PATIENT RECORD - DIAGNOSIS: ALLERGY';
      final bytes = Uint8List.fromList(utf8.encode(textData));

      final extracted = await ocrService.extractText(bytes, 'record.txt');
      expect(extracted, equals(textData));
    });
  });
}
