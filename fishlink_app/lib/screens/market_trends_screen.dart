import 'package:flutter/material.dart';
import '../models/market_trend.dart';
import '../services/api_service.dart';

class MarketTrendsScreen extends StatefulWidget {
  const MarketTrendsScreen({Key? key}) : super(key: key);

  @override
  State<MarketTrendsScreen> createState() => _MarketTrendsScreenState();
}

class _MarketTrendsScreenState extends State<MarketTrendsScreen> {
  List<MarketTrend> _trends = [];
  List<MarketTrend> _filteredTrends = [];
  bool _isLoading = true;
  String _error = '';
  String _searchQuery = '';
  String _sortBy = 'fishType'; // fishType, currentPrice, percentageChange
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadMarketTrends();
  }

  Future<void> _loadMarketTrends() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final trends = await ApiService.getMarketTrends();
      setState(() {
        _trends = trends;
        _filteredTrends = trends;
        _isLoading = false;
      });
      _applyFiltersAndSort();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFiltersAndSort() {
    List<MarketTrend> filtered = _trends;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((trend) =>
          trend.fishType.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (trend.location?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
      ).toList();
    }

    // Apply sorting
    filtered.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'fishType':
          comparison = a.fishType.compareTo(b.fishType);
          break;
        case 'currentPrice':
          comparison = a.currentPrice.compareTo(b.currentPrice);
          break;
        case 'percentageChange':
          comparison = a.percentageChange.compareTo(b.percentageChange);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    setState(() {
      _filteredTrends = filtered;
    });
  }

  void _onSearchChanged(String query) {
    _searchQuery = query;
    _applyFiltersAndSort();
  }

  void _onSortChanged(String sortBy) {
    if (_sortBy == sortBy) {
      _sortAscending = !_sortAscending;
    } else {
      _sortBy = sortBy;
      _sortAscending = true;
    }
    _applyFiltersAndSort();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Market Trends'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMarketTrends,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filters
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                // Search bar
                TextField(
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search fish types or locations...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Sort options
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSortButton('Fish Type', 'fishType'),
                    _buildSortButton('Price', 'currentPrice'),
                    _buildSortButton('Change %', 'percentageChange'),
                  ],
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error, size: 64, color: Colors.red[300]),
                            const SizedBox(height: 16),
                            Text('Error: $_error'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadMarketTrends,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _filteredTrends.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.trending_flat, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  'No market trends found',
                                  style: TextStyle(fontSize: 18, color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadMarketTrends,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredTrends.length,
                              itemBuilder: (context, index) {
                                final trend = _filteredTrends[index];
                                return _buildTrendCard(trend);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortButton(String label, String sortBy) {
    final isSelected = _sortBy == sortBy;
    return GestureDetector(
      onTap: () => _onSortChanged(sortBy),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 16,
                color: Colors.white,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrendCard(MarketTrend trend) {
    Color trendColor = trend.trend == 'up' 
        ? Colors.green 
        : trend.trend == 'down' 
            ? Colors.red 
            : Colors.grey;
    
    IconData trendIcon = trend.trend == 'up' 
        ? Icons.trending_up 
        : trend.trend == 'down' 
            ? Icons.trending_down 
            : Icons.trending_flat;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  trend.fishType,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: trendColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(trendIcon, size: 16, color: trendColor),
                      const SizedBox(width: 4),
                      Text(
                        trend.trend.toUpperCase(),
                        style: TextStyle(
                          color: trendColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Price information
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Price',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '\$${trend.currentPrice.toStringAsFixed(2)}/kg',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Change',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${trend.percentageChange >= 0 ? '+' : ''}${trend.percentageChange.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: trendColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Additional information
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Previous Price',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '\$${trend.previousPrice.toStringAsFixed(2)}/kg',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Price Change',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${trend.priceChange >= 0 ? '+' : ''}\$${trend.priceChange.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: trendColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            if (trend.location != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    trend.location!,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Updated: ${trend.date.day}/${trend.date.month}/${trend.date.year}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}