import 'package:flutter/foundation.dart';
import '../core/api_service.dart';
import '../models/models.dart';

class VaultProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<VaultDocument> _documents = [];
  List<SearchResult> _searchResults = [];
  String _selectedCategory = "All";
  bool _isLoading = false;
  bool _isSearching = false;
  String? _uploadStatus;

  List<VaultDocument> get documents {
    if (_selectedCategory == "All") return _documents;
    return _documents.where((d) => d.category.toLowerCase() == _selectedCategory.toLowerCase()).toList();
  }

  List<VaultDocument> get rawDocuments => _documents;
  List<SearchResult> get searchResults => _searchResults;
  String get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String? get uploadStatus => _uploadStatus;

  int get highSensitivityCount => _documents.where((d) => d.sensitivity == "HIGH").length;

  Future<void> loadDocuments() async {
    _isLoading = true;
    notifyListeners();

    try {
      _documents = await _api.getDocuments();
    } catch (e) {
      debugPrint("Error loading documents: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  VaultDocument? _lastUploadedDoc;
  VaultDocument? get lastUploadedDoc => _lastUploadedDoc;

  Future<VaultDocument?> uploadFile(
    String filename,
    List<int> bytes, {
    String? filePath,
  }) async {
    _uploadStatus = "Encrypting with AES-256-GCM & analyzing PII via On-Device OCR...";
    notifyListeners();

    try {
      final doc = await _api.uploadDocument(filename, bytes, filePath: filePath);
      _documents.insert(0, doc);
      _lastUploadedDoc = doc;
      _uploadStatus = "Document successfully secured in vault!";
      notifyListeners();
      await Future.delayed(const Duration(seconds: 1));
      _uploadStatus = null;
      notifyListeners();
      return doc;
    } catch (e) {
      _uploadStatus = "Upload error: ${e.toString()}";
      notifyListeners();
      await Future.delayed(const Duration(seconds: 2));
      _uploadStatus = null;
      notifyListeners();
      return null;
    }
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      _searchResults = await _api.searchVault(query);
    } catch (e) {
      debugPrint("Search error: $e");
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }

  void clear() {
    _documents = [];
    _searchResults = [];
    _selectedCategory = "All";
    _uploadStatus = null;
    notifyListeners();
  }
}
