import 'package:flutter/material.dart';
import '../../services/review_service.dart';
import '../../services/auth_service.dart';
import '../../utils/theme.dart';

class ReviewsScreen extends StatefulWidget {
  final String shopSlug;

  const ReviewsScreen({super.key, required this.shopSlug});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final _authService = AuthService();
  final _scrollController = ScrollController();
  String? _userId;
  List<dynamic> _reviews = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  int _totalReviews = 0;
  int _totalPages = 1;
  static const int _perPage = 20;
  String? _selectedProductFilter;
  List<String> _productNames = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadData() async {
    final user = await _authService.getCurrentUser();
    if (user == null) return;
    _userId = user.id;

    setState(() {
      _isLoading = true;
      _currentPage = 1;
    });

    try {
      final result = await ReviewService.getShopReviews(user.id, widget.shopSlug, page: 1, perPage: _perPage);
      if (mounted) {
        setState(() {
          _reviews = result['reviews'] ?? [];
          _totalReviews = result['total'] ?? 0;
          _totalPages = result['total_pages'] ?? 1;
          final names = <String>{};
          for (final r in _reviews) {
            final name = r['product_name'] ?? 'Unknown';
            if (name is String && name.isNotEmpty) names.add(name);
          }
          _productNames = names.toList()..sort();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _currentPage >= _totalPages || _userId == null) return;

    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _currentPage + 1;
      final result = await ReviewService.getShopReviews(_userId!, widget.shopSlug, page: nextPage, perPage: _perPage);
      if (mounted) {
        setState(() {
          _reviews.addAll(result['reviews'] ?? []);
          _currentPage = nextPage;
          // Update product names from all loaded reviews
          final names = <String>{};
          for (final r in _reviews) {
            final name = r['product_name'] ?? 'Unknown';
            if (name is String && name.isNotEmpty) names.add(name);
          }
          _productNames = names.toList()..sort();
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _deleteReview(String reviewId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Review'),
        content: const Text('Delete this review? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || _userId == null) return;
    await ReviewService.deleteReview(_userId!, reviewId);
    _loadData();
  }

  String _formatDate(String isoStr) {
    try {
      final dt = DateTime.parse(isoStr + 'Z');
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('No reviews yet', style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            const Text(
              'Customers can review products after their order is delivered',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final filteredReviews = _selectedProductFilter == null
        ? _reviews
        : _reviews.where((r) => (r['product_name'] ?? 'Unknown') == _selectedProductFilter).toList();

    return Column(
      children: [
        // Summary bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppTheme.surface,
          child: Row(
            children: [
              Text(
                '$_totalReviews review${_totalReviews != 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
              ),
              const Spacer(),
              if (_totalPages > 1)
                Text(
                  'Page $_currentPage/$_totalPages',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
            ],
          ),
        ),
        // Product filter dropdown
        if (_productNames.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DropdownButton<String>(
              value: _selectedProductFilter,
              hint: const Text('All products', style: TextStyle(fontSize: 13)),
              isExpanded: true,
              underline: const SizedBox(),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('All products', style: TextStyle(fontSize: 13)),
                ),
                ..._productNames.map((name) => DropdownMenuItem<String>(
                  value: name,
                  child: Text(name, style: const TextStyle(fontSize: 13)),
                )),
              ],
              onChanged: (value) {
                setState(() => _selectedProductFilter = value);
              },
            ),
          ),
        // Reviews list with infinite scroll
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: filteredReviews.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == filteredReviews.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }
                final rev = filteredReviews[index];
                final rating = rev['rating'] ?? 5;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                rev['customer_name'] ?? 'Anonymous',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              onPressed: () => _deleteReview(rev['id']),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: List.generate(
                            5,
                            (i) => Icon(
                              i < rating ? Icons.star : Icons.star_border,
                              size: 16,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Product: ${rev['product_name'] ?? 'Unknown'}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        if (rev['comment'] != null && rev['comment'].isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(rev['comment'], style: const TextStyle(fontSize: 13)),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(rev['created_at'] ?? ''),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
