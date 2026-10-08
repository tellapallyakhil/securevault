/// Client-side PII (Personally Identifiable Information) Detection & Document Classification.
/// Scans extracted text for sensitive entities (Aadhaar, PAN, Credit Cards, etc.)
/// and classifies documents accurately into categories (Identity, Educational, Financial, Medical, Career, Legal).
/// Runs entirely on-device — zero server dependency.
class PIIClassifier {
  // ==================== PII REGEX PATTERNS ====================

  /// Indian Aadhaar Card: strictly 12 digits (3 groups of 4 digits, first digit 2-9)
  static final _aadhaarPattern = RegExp(r'\b[2-9]\d{3}[\s-]?\d{4}[\s-]?\d{4}\b');

  /// Indian PAN Card: 5 letters + 4 digits + 1 letter (e.g., ABCDE1234F)
  static final _panPattern = RegExp(r'\b[A-Z]{5}\s?\d{4}\s?[A-Z]\b');

  /// Credit/Debit Card: 13-19 digit sequences (with optional spaces/dashes)
  static final _creditCardPattern = RegExp(r'\b(?:\d{4}[\s-]?){3,4}\d{1,4}\b');

  /// Email Address
  static final _emailPattern =
      RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,7}\b');

  /// Phone Number (Indian and international formats)
  static final _phonePattern = RegExp(
      r'\b(?:\+?91[\s-]?)?(?:[6-9]\d{4}[\s-]?\d{5}|\d{5}[\s-]?\d{5}|\(?\d{3}\)?[\s-]?\d{3}[\s-]?\d{4})\b');

  /// Passport Number (1 letter + 7-8 digits)
  static final _passportPattern = RegExp(r'\b[A-PR-WYa-pr-wy][1-9]\d\s?\d{4}[1-9]\b|\b[A-Z]\d{7,8}\b');

  /// Date of Birth patterns
  static final _dobPattern = RegExp(
      r'\b(?:DOB|Date of Birth|D\.O\.B|Birth\s*Date)[:\s]+(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\b',
      caseSensitive: false);

  /// Indian Voter ID
  static final _voterIdPattern = RegExp(r'\b[A-Z]{3}\d{7}\b');

  /// Indian Driving License
  static final _dlPattern = RegExp(
      r'\b[A-Z]{2}[-\s]?\d{2}[-\s]?(?:19|20)\d{2}[-\s]?\d{7}\b|\b[A-Z]{2}\d{2}\s?\d{4}\s?\d{7}\b');

  // ==================== CATEGORY KEYWORD MAPS ====================

  static final Map<String, List<String>> _categoryKeywords = {
    'Identity': [
      'aadhaar', 'aadhar', 'adhaar', 'uidai', 'unique identification',
      'pan card', 'permanent account number', 'income tax department',
      'passport', 'republic of india', 'government of india',
      'driving licence', 'driving license', 'dl no', 'motor vehicles department',
      'voter', 'election commission', 'epic no', 'epic',
      'identity card', 'id card', 'citizenship', 'id proof', 'national id',
      'date of birth', 'dob', 'father name', 'mother name',
    ],
    'Educational': [
      'university', 'college', 'school', 'academy', 'institute', 'polytechnic',
      'marksheet', 'mark sheet', 'grade sheet', 'grade card', 'gradesheet',
      'transcript', 'academic transcript', 'academic record', 'grade report',
      'statement of marks', 'statement of grades', 'consolidated statement',
      'provisional certificate', 'degree certificate', 'diploma certificate',
      'semester', 'academic year', 'semester examination', 'examination result',
      'cgpa', 'sgpa', 'gpa', 'credits earned', 'course credits', 'credit points',
      'total credits', 'total marks', 'maximum marks', 'marks obtained',
      'roll number', 'roll no', 'registration number', 'reg no', 'hall ticket',
      'admit card', 'enrollment no', 'prn', 'student id',
      'bachelor of technology', 'btech', 'b.tech', 'mtech', 'm.tech',
      'bachelor of engineering', 'b.e', 'm.e', 'bsc', 'b.sc', 'msc', 'm.sc',
      'bca', 'mca', 'bba', 'mba', 'bcom', 'b.com', 'mcom', 'm.com',
      'phd', 'ph.d', 'diploma', 'higher secondary', 'intermediate',
      'cbse', 'icse', 'ssc', 'hsc', 'board of intermediate', 'state board',
      'passed with distinction', 'first class', 'second class', 'controller of examinations',
      'registrar', 'vice chancellor', 'curriculum', 'syllabus',
    ],
    'Financial': [
      'invoice', 'tax invoice', 'proforma invoice', 'bill of supply',
      'bank statement', 'account statement', 'passbook', 'banking',
      'salary slip', 'payslip', 'payroll', 'ctc', 'gross salary', 'net salary',
      'form 16', 'income tax return', 'itr', 'tds certificate',
      'gstin', 'gst invoice', 'cgst', 'sgst', 'igst',
      'net banking', 'upi transaction', 'neft', 'rtgs', 'imps', 'cheque',
      'credit card statement', 'debit card statement', 'card ending in',
      'loan account', 'emi due', 'principal amount', 'interest rate',
      'mutual fund', 'portfolio', 'demat', 'dividend', 'fixed deposit',
      'billing statement', 'amount payable', 'amount paid', 'subtotal',
    ],
    'Medical': [
      'prescription', 'rx', 'diagnosis', 'hospital', 'patient',
      'clinical', 'medication', 'blood report', 'lab report', 'pathology',
      'cardiology', 'tablets', 'capsule', 'clinic', 'treatment',
      'pharmacy', 'doctor', 'dr.', 'physician', 'surgeon',
      'blood pressure', 'hemoglobin', 'sugar level', 'x-ray', 'mri scan',
      'ct scan', 'ecg', 'ultrasound', 'discharge summary', 'opd', 'ipd',
    ],
    'Career': [
      'resume', 'curriculum vitae', 'cv', 'experience summary', 'work history',
      'employment history', 'job experience', 'professional summary',
      'skills summary', 'certifications', 'internship', 'designation',
      'qualification', 'recommendation letter', 'offer letter', 'relieving letter',
    ],
    'Legal': [
      'agreement', 'contract', 'non-disclosure', 'nda', 'affidavit',
      'power of attorney', 'lease deed', 'sale deed', 'court order',
      'stamp paper', 'notary public', 'arbitration', 'indemnity',
      'memorandum of understanding', 'mou', 'terms and conditions',
    ],
  };

  // ==================== ANALYSIS METHODS ====================

  /// Analyze text for PII entities and classify the document.
  /// Returns a map with sensitivity, PII counts, entities, and category.
  static Map<String, dynamic> analyzeText(String text) {
    if (text.trim().isEmpty) {
      return {
        'sensitivity': 'LOW',
        'total_pii_count': 0,
        'counts_by_type': <String, int>{},
        'entities': <Map<String, dynamic>>[],
        'category': 'General',
        'document_type': 'General Document',
      };
    }

    final entities = <Map<String, dynamic>>[];
    final countsByType = <String, int>{};

    // Run all PII pattern checks
    _checkPattern('AADHAAR', _aadhaarPattern, text, entities, countsByType);
    _checkPattern('PAN_CARD', _panPattern, text, entities, countsByType);
    _checkPattern('CREDIT_CARD', _creditCardPattern, text, entities, countsByType);
    _checkPattern('EMAIL', _emailPattern, text, entities, countsByType);
    _checkPattern('PHONE', _phonePattern, text, entities, countsByType);
    _checkPattern('PASSPORT', _passportPattern, text, entities, countsByType);
    _checkPattern('DATE_OF_BIRTH', _dobPattern, text, entities, countsByType);
    _checkPattern('VOTER_ID', _voterIdPattern, text, entities, countsByType);
    _checkPattern('DRIVING_LICENSE', _dlPattern, text, entities, countsByType);

    final totalPii = countsByType.values.fold(0, (a, b) => a + b);

    // Determine sensitivity level
    String sensitivity = 'LOW';
    if (countsByType.containsKey('AADHAAR') ||
        countsByType.containsKey('PAN_CARD') ||
        countsByType.containsKey('CREDIT_CARD') ||
        countsByType.containsKey('PASSPORT') ||
        countsByType.containsKey('DRIVING_LICENSE')) {
      sensitivity = 'HIGH';
    } else if (totalPii > 0) {
      sensitivity = 'MEDIUM';
    }

    // Determine specific document type (Aadhaar, Educational Record, PAN, etc.)
    final documentType = detectSpecificDocumentType(text, countsByType);

    // Classify document category based on content and detected context
    final category = classifyDocument(text, countsByType);

    return {
      'sensitivity': sensitivity,
      'total_pii_count': totalPii,
      'counts_by_type': countsByType,
      'entities': entities,
      'category': category,
      'document_type': documentType,
    };
  }

  /// Check if the text has strong educational markers to avoid false Financial mapping
  static bool hasEducationalContext(String textLower) {
    return textLower.contains('marksheet') ||
        textLower.contains('mark sheet') ||
        textLower.contains('transcript') ||
        textLower.contains('grade card') ||
        textLower.contains('gradesheet') ||
        textLower.contains('grade sheet') ||
        textLower.contains('statement of marks') ||
        textLower.contains('statement of grades') ||
        textLower.contains('degree certificate') ||
        textLower.contains('provisional certificate') ||
        textLower.contains('academic transcript') ||
        textLower.contains('hall ticket') ||
        textLower.contains('admit card') ||
        textLower.contains('b.tech') ||
        textLower.contains('btech') ||
        textLower.contains('m.tech') ||
        textLower.contains('mtech') ||
        textLower.contains('semester examination') ||
        (textLower.contains('university') &&
            (textLower.contains('semester') ||
                textLower.contains('cgpa') ||
                textLower.contains('sgpa') ||
                textLower.contains('grade') ||
                textLower.contains('credits') ||
                textLower.contains('credit') ||
                textLower.contains('marks') ||
                textLower.contains('roll no') ||
                textLower.contains('student'))) ||
        (textLower.contains('college') &&
            (textLower.contains('semester') ||
                textLower.contains('cgpa') ||
                textLower.contains('marks') ||
                textLower.contains('examination') ||
                textLower.contains('grade')));
  }

  /// Detect the specific document type (Aadhaar Card, Educational Record, PAN Card, etc.)
  static String detectSpecificDocumentType(String text, [Map<String, int>? piiCounts]) {
    final textLower = text.toLowerCase();
    final counts = piiCounts ?? {};
    final isEdu = hasEducationalContext(textLower);

    // 1. Check Educational Record FIRST if educational context is present
    // This guarantees educational marksheets are never hijacked by incidental Aadhaar/PAN numbers or "Statement of Marks"
    if (isEdu) {
      return 'Educational Record';
    }

    // 2. Aadhaar Card
    final hasAadhaarKeywords = textLower.contains('aadhaar') ||
        textLower.contains('aadhar') ||
        textLower.contains('adhaar') ||
        textLower.contains('uidai') ||
        textLower.contains('unique identification authority of india');

    if (hasAadhaarKeywords || counts.containsKey('AADHAAR')) {
      return 'Aadhaar Card';
    }

    // 3. PAN Card
    final hasPanKeywords = textLower.contains('income tax department') ||
        textLower.contains('permanent account number') ||
        textLower.contains('pan card');

    if (hasPanKeywords || counts.containsKey('PAN_CARD')) {
      return 'PAN Card';
    }

    // 4. Passport
    if (counts.containsKey('PASSPORT') ||
        textLower.contains('passport') ||
        textLower.contains('republic of india passport')) {
      return 'Passport';
    }

    // 5. Voter ID
    if (counts.containsKey('VOTER_ID') ||
        textLower.contains('election commission') ||
        textLower.contains('voter id') ||
        textLower.contains('epic no')) {
      return 'Voter ID';
    }

    // 6. Driving License
    if (counts.containsKey('DRIVING_LICENSE') ||
        textLower.contains('driving licence') ||
        textLower.contains('driving license') ||
        textLower.contains('motor vehicles department')) {
      return 'Driving License';
    }

    // 7. Medical Document
    final medicalKeywords = _categoryKeywords['Medical']!;
    final medHits = medicalKeywords.where((kw) => textLower.contains(kw)).length;
    if (medHits >= 2 ||
        textLower.contains('prescription') ||
        textLower.contains('diagnosis') ||
        textLower.contains('hospital')) {
      return 'Medical Document';
    }

    // 8. Financial Statement / Invoice
    final finKeywords = _categoryKeywords['Financial']!;
    final finHits = finKeywords.where((kw) => textLower.contains(kw)).length;
    final isTrueFinancial = textLower.contains('invoice') ||
        textLower.contains('bank statement') ||
        textLower.contains('account statement') ||
        textLower.contains('salary slip') ||
        textLower.contains('payslip') ||
        textLower.contains('tax invoice') ||
        textLower.contains('gstin');

    if (isTrueFinancial || finHits >= 2) {
      return 'Financial Statement';
    }

    // 9. Credit / Debit Card
    if (counts.containsKey('CREDIT_CARD') ||
        textLower.contains('credit card') ||
        textLower.contains('debit card') ||
        textLower.contains('visa card') ||
        textLower.contains('mastercard')) {
      return 'Credit/Debit Card';
    }

    // 10. Legal Document
    final legalKeywords = _categoryKeywords['Legal']!;
    final legalHits = legalKeywords.where((kw) => textLower.contains(kw)).length;
    if (legalHits >= 2 ||
        textLower.contains('agreement') ||
        textLower.contains('contract') ||
        textLower.contains('nda')) {
      return 'Legal Document';
    }

    // 11. Career Document (Resume / CV)
    if (textLower.contains('resume') ||
        textLower.contains('curriculum vitae') ||
        (textLower.contains('experience') && textLower.contains('skills') && textLower.contains('projects'))) {
      return 'Resume / CV';
    }

    return 'General Document';
  }

  /// Internal helper to check a single regex pattern against text
  static void _checkPattern(
    String type,
    RegExp pattern,
    String text,
    List<Map<String, dynamic>> entities,
    Map<String, int> counts,
  ) {
    final matches = pattern.allMatches(text).toList();
    if (matches.isNotEmpty) {
      counts[type] = matches.length;
      for (final m in matches) {
        final val = m.group(0) ?? '';
        entities.add({
          'type': type,
          'text': val.length > 4 ? '${val.substring(0, 4)}***' : '***',
          'start': m.start,
          'end': m.end,
        });
      }
    }
  }

  /// Count word-boundary occurrences to prevent partial substrings from triggering false positives
  static int _countKeywordMatches(String textLower, String keyword) {
    if (keyword.contains(' ') || keyword.contains('.')) {
      // Multi-word phrase or dotted acronym: match substring
      int count = 0;
      int idx = 0;
      while (true) {
        idx = textLower.indexOf(keyword, idx);
        if (idx == -1) break;
        count++;
        idx += keyword.length;
      }
      return count;
    } else {
      // Single word: use word boundary regex to avoid partial substring false positives
      final pattern = RegExp(r'\b' + RegExp.escape(keyword) + r'\b');
      return pattern.allMatches(textLower).length;
    }
  }

  /// Classify document into a category based on content keywords and detected PII.
  /// Priority:
  /// 1. Educational context -> Educational (guaranteed protection from financial collision)
  /// 2. Government IDs (Aadhaar/PAN/Passport) -> Identity
  /// 3. Word-boundary scoring across all categories
  static String classifyDocument(String text, [Map<String, int>? piiCounts]) {
    final textLower = text.toLowerCase();
    final isEdu = hasEducationalContext(textLower);

    // If strong educational context is present, prioritize Educational
    if (isEdu) {
      return 'Educational';
    }

    // Government ID patterns found
    final hasPii = piiCounts ?? {};
    final hasGovtId = hasPii.containsKey('AADHAAR') ||
        hasPii.containsKey('PAN_CARD') ||
        hasPii.containsKey('PASSPORT') ||
        hasPii.containsKey('VOTER_ID') ||
        hasPii.containsKey('DRIVING_LICENSE');

    if (hasGovtId) {
      final identityKeywords = _categoryKeywords['Identity']!;
      final identityHits = identityKeywords.where((kw) => textLower.contains(kw)).length;
      if (identityHits >= 1) {
        return 'Identity';
      }
    }

    // Score all categories using word-boundary matching
    final scores = <String, int>{};
    for (final entry in _categoryKeywords.entries) {
      int score = 0;
      for (final keyword in entry.value) {
        score += _countKeywordMatches(textLower, keyword);
      }
      scores[entry.key] = score;
    }

    // Boost Identity score if government IDs detected
    if (hasGovtId) {
      scores['Identity'] = (scores['Identity'] ?? 0) + 12;
    }

    // Find the category with the highest score
    String bestCategory = 'General';
    int bestScore = 0;
    for (final entry in scores.entries) {
      if (entry.value > bestScore) {
        bestScore = entry.value;
        bestCategory = entry.key;
      }
    }

    return bestScore > 0 ? bestCategory : 'General';
  }

  /// Redact sensitive PII from text (replace with masked tokens)
  static String redactText(String text) {
    String redacted = text;
    redacted = _aadhaarPattern.stringNormalizeReplace(redacted, '[AADHAAR_REDACTED]');
    redacted = _panPattern.stringNormalizeReplace(redacted, '[PAN_REDACTED]');
    redacted = _creditCardPattern.stringNormalizeReplace(redacted, '[CARD_REDACTED]');
    redacted = _passportPattern.stringNormalizeReplace(redacted, '[PASSPORT_REDACTED]');
    redacted = _dlPattern.stringNormalizeReplace(redacted, '[DL_REDACTED]');
    return redacted;
  }
}

/// Extension for clean regex replacement
extension _RegExpReplace on RegExp {
  String stringNormalizeReplace(String input, String replacement) {
    return input.replaceAll(this, replacement);
  }
}
