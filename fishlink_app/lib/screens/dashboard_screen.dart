import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/catch.dart';
import '../models/market_trend.dart';
import 'catch_form_screen.dart';
import 'market_trends_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Catch> _recentCatches = [];
  List<MarketTrend> _marketTrends = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final catches = await ApiService.getCatches();
      final trends = await ApiService.getMarketTrends();
      
      setState(() {
        _recentCatches = catches.take(5).toList(); // Show only recent 5
        _marketTrends = trends.take(3).toList(); // Show top 3 trends
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.logout();
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${user?.firstName ?? 'User'}'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
          PopupMenuButton(
            icon: const Icon(Icons.account_circle),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text('${user?.fullName}'),
                  subtitle: Text('${user?.role}'),
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Logout'),
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              }
            },
          ),
        ],
      ),
      body: _isLoading
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
                        onPressed: _loadDashboardData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDashboardData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Quick stats cards
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Total Catches',
                                _recentCatches.length.toString(),
                                Icons.waves,
                                Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildStatCard(
                                'Active Trends',
                                _marketTrends.length.toString(),
                                Icons.trending_up,
                                Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Recent Catches section
                        _buildSectionHeader(
                          'Recent Catches',
                          'View All',
                          () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const CatchFormScreen()),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _recentCatches.isEmpty
                            ? _buildEmptyState('No catches found', 'Add your first catch!')
                            : Column(
                                children: _recentCatches
                                    .map((catch) => _buildCatchCard(catch))
                                    .toList(),
                              ),
                        const SizedBox(height: 24),

                        // Market Trends section
                        _buildSectionHeader(
                          'Market Trends',
                          'View All',
                          () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const MarketTrendsScreen()),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _marketTrends.isEmpty
                            ? _buildEmptyState('No trends available', 'Check back later')
                            : Column(
                                children: _marketTrends
                                    .map((trend) => _buildTrendCard(trend))
                                    .toList(),
                              ),
                      ],
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const CatchFormScreen()),
          );
          if (result == true) {
            _loadDashboardData(); // Refresh data
          }
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 32),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String actionText, VoidCallback onPressed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        TextButton(
          onPressed: onPressed,
          child: Text(actionText),
        ),
      ],
    );
  }

  Widget _buildCatchCard(Catch catchData) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue[100],
          child: Icon(Icons.waves, color: Colors.blue[800]),
        ),
        title: Text(catchData.fishType),
        subtitle: Text('${catchData.quantity}kg • ${catchData.location}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${catchData.totalValue.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            Text(
              catchData.status,
              style: TextStyle(
                fontSize: 12,
                color: catchData.status == 'Available' ? Colors.green : Colors.orange,
              ),
            ),
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
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: trendColor.withOpacity(0.1),
          child: Icon(trendIcon, color: trendColor),
        ),
        title: Text(trend.fishType),
        subtitle: Text('\$${trend.currentPrice.toStringAsFixed(2)}/kg'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${trend.percentageChange >= 0 ? '+' : ''}${trend.percentageChange.toStringAsFixed(1)}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: trendColor,
              ),
            ),
            Text(
              trend.trend.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                color: trendColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}