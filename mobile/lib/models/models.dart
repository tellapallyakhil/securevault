class VaultDocument {
  final String id;
  final String userId;
  final String originalName;
  final int fileSize;
  final String mimeType;
  final String category;
  final String sensitivity;
  final Map<String, dynamic> piiSummary;
  final DateTime createdAt;
  final String? summaryPreview;
  final String? contentHash;

  VaultDocument({
    required this.id,
    required this.userId,
    required this.originalName,
    required this.fileSize,
    required this.mimeType,
    required this.category,
    required this.sensitivity,
    required this.piiSummary,
    required this.createdAt,
    this.summaryPreview,
    this.contentHash,
  });

  factory VaultDocument.fromJson(Map<String, dynamic> json) {
    return VaultDocument(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      originalName: json['original_name'] ?? 'Untitled',
      fileSize: json['file_size'] ?? 0,
      mimeType: json['mime_type'] ?? 'application/octet-stream',
      category: json['category'] ?? 'General',
      sensitivity: json['sensitivity'] ?? 'LOW',
      piiSummary: json['pii_summary'] ?? {},
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      summaryPreview: json['summary_preview'],
      contentHash: json['content_hash'],
    );
  }

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class SearchResult {
  final String docId;
  final double score;
  final String originalName;
  final String category;
  final String sensitivity;
  final String? snippet;

  SearchResult({
    required this.docId,
    required this.score,
    required this.originalName,
    required this.category,
    required this.sensitivity,
    this.snippet,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      docId: json['doc_id'] ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      originalName: json['original_name'] ?? 'Unknown',
      category: json['category'] ?? 'General',
      sensitivity: json['sensitivity'] ?? 'LOW',
      snippet: json['snippet'],
    );
  }
}

class SecurityStats {
  final int totalDocuments;
  final int highSensitivityCount;
  final String activeThreatLevel;
  final int latestAnomalyScore;
  final List<dynamic> recentAlerts;

  SecurityStats({
    required this.totalDocuments,
    required this.highSensitivityCount,
    required this.activeThreatLevel,
    required this.latestAnomalyScore,
    required this.recentAlerts,
  });

  factory SecurityStats.fromJson(Map<String, dynamic> json) {
    return SecurityStats(
      totalDocuments: json['total_documents'] ?? 0,
      highSensitivityCount: json['high_sensitivity_count'] ?? 0,
      activeThreatLevel: json['active_threat_level'] ?? 'OPTIMAL',
      latestAnomalyScore: json['latest_anomaly_score'] ?? 0,
      recentAlerts: json['recent_alerts'] ?? [],
    );
  }
}
