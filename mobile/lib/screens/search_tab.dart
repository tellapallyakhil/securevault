import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/vault_provider.dart';

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final _searchController = TextEditingController();

  final List<String> _suggestedQueries = [
    "Educational certificates and test papers",
    "Coding questions and exam assignments",
    "Find my recent payment documents",
    "Show high sensitivity identity files",
    "Documents from this month",
    "Tax returns and financial invoices",
    "Aadhaar and PAN card records",
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _executeSearch(String query) {
    if (query.trim().isNotEmpty) {
      _searchController.text = query;
      context.read<VaultProvider>().search(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vault = context.watch<VaultProvider>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header matching Fig 1(b) / 2(b)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: VaultTheme.primaryCyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.psychology_outlined, color: VaultTheme.primaryCyan, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "SEMANTIC DISCOVERY",
                        style: TextStyle(
                          color: VaultTheme.primaryCyan,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        "Ask your vault",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                "Search by meaning, not only keywords.",
                style: TextStyle(color: VaultTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),

              // Search Bar with neon action button (Matching Fig 1(b))
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onSubmitted: _executeSearch,
                      decoration: InputDecoration(
                        hintText: "Find my recent payment documents...",
                        hintStyle: const TextStyle(color: VaultTheme.textMuted, fontSize: 14),
                        prefixIcon: const Icon(Icons.search, color: VaultTheme.textMuted),
                        filled: true,
                        fillColor: VaultTheme.surface,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: VaultTheme.surfaceBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: VaultTheme.surfaceBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: VaultTheme.primaryCyan),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: VaultTheme.primaryCyan,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_forward, color: Colors.black),
                      onPressed: () => _executeSearch(_searchController.text),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Suggested queries / Prompt chips (Matching Fig 1(b))
              if (vault.searchResults.isEmpty && !vault.isSearching) ...[
                const Text(
                  "Recent / Suggested queries",
                  style: TextStyle(color: VaultTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _suggestedQueries.map((q) {
                    return InkWell(
                      onTap: () => _executeSearch(q),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: VaultTheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: VaultTheme.surfaceBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.history, size: 14, color: VaultTheme.textMuted),
                            const SizedBox(width: 8),
                            Text(
                              q,
                              style: const TextStyle(fontSize: 12, color: VaultTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              // Search Results
              if (vault.isSearching)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: VaultTheme.primaryCyan),
                        SizedBox(height: 16),
                        Text(
                          "Encoding query & calculating FAISS vector cosine similarities...",
                          style: TextStyle(color: VaultTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              else if (vault.searchResults.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Semantic Matches (${vault.searchResults.length})",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    TextButton(
                      onPressed: () {
                        _searchController.clear();
                        vault.clearSearch();
                      },
                      child: const Text("Clear", style: TextStyle(color: VaultTheme.textMuted, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: vault.searchResults.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = vault.searchResults[index];
                      return _buildResultCard(item);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(SearchResult item) {
    final matchPercentage = (item.score * 100).toInt().clamp(50, 99);

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.originalName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: VaultTheme.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: VaultTheme.primaryCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "$matchPercentage% Semantic Match",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: VaultTheme.primaryCyan,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Category: ${item.category} • PII Sensitivity: ${item.sensitivity}",
            style: const TextStyle(color: VaultTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
