import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Access API base url defined in main.dart
String get _apiBase =>
    const String.fromEnvironment('FISHLINK_API_URL').isNotEmpty
        ? const String.fromEnvironment('FISHLINK_API_URL')
        : (kIsWeb ? 'http://localhost:5157/api' : 'http://10.0.2.2:5157/api');

// ════════════════════════════════════════════════════════════════════════════════
// 15. 📦 ORDERS SCREEN (Features 15, 16, 17, 18, 19, 20, 21)
// ════════════════════════════════════════════════════════════════════════════════

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({required this.role, super.key});

  final String role; // 'Fisherman' or 'Buyer'

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _orders = [];
  String _selectedFilter = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => _loading = true);
    try {
      final token = await const FlutterSecureStorage().read(key: 'token');
      final res = await http.get(
        Uri.parse('$_apiBase/Orders?role=${widget.role}'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List) {
          setState(() {
            _orders = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            _loading = false;
          });
          return;
        }
      }
    } catch (_) {}

    // Fallback sample data if API offline
    setState(() {
      _orders = _defaultSampleOrders;
      _loading = false;
    });
  }

  Future<void> _advanceOrderStatus(Map<String, dynamic> order) async {
    final currentStatus = (order['status'] ?? 'CONFIRMED').toString().toUpperCase();
    final lifecycle = ['CONFIRMED', 'SCHEDULED', 'PICKED UP', 'IN TRANSIT', 'DELIVERED'];
    final idx = lifecycle.indexOf(currentStatus);
    final nextStatus = idx < lifecycle.length - 1 ? lifecycle[idx + 1] : lifecycle.first;

    try {
      final token = await const FlutterSecureStorage().read(key: 'token');
      await http.patch(
        Uri.parse('$_apiBase/Orders/${order['id']}/status'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': nextStatus}),
      );
    } catch (_) {}

    setState(() {
      order['status'] = nextStatus;
      order['currentStep'] = lifecycle.indexOf(nextStatus) + 1;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order #${order['orderNumber']} status updated to $nextStatus'),
          backgroundColor: const Color(0xff005b96),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    return _orders.where((o) {
      final status = (o['status'] ?? '').toString().toUpperCase();
      final num = (o['orderNumber'] ?? '').toString().toLowerCase();
      final species = (o['species'] ?? '').toString().toLowerCase();
      final seller = (o['sellerName'] ?? '').toString().toLowerCase();

      final matchesSearch = _searchQuery.isEmpty ||
          num.contains(_searchQuery.toLowerCase()) ||
          species.contains(_searchQuery.toLowerCase()) ||
          seller.contains(_searchQuery.toLowerCase());

      final matchesFilter = _selectedFilter == 'All' ||
          (_selectedFilter == 'Active' && status != 'DELIVERED') ||
          (_selectedFilter == 'Delivered' && status == 'DELIVERED') ||
          status == _selectedFilter.toUpperCase();

      return matchesSearch && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff0f4f8),
      body: RefreshIndicator(
        onRefresh: _fetchOrders,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            // ── Top Header Banner ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xff003b5c), Color(0xff006994)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xff003b5c).withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.inventory_2, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.role == 'Fisherman' ? 'Order Fulfillment' : 'My Orders & Deliveries',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.role == 'Fisherman'
                              ? 'Cold storage, logistics & buyer payments'
                              : 'Real-time cold-chain tracking & verification',
                          style: const TextStyle(color: Color(0xffd9f2ff), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Search & Filter ────────────────────────────────────────────
            TextField(
              decoration: InputDecoration(
                hintText: 'Search order #, species, or seller...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),

            const SizedBox(height: 10),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Active', 'Confirmed', 'In Transit', 'Delivered']
                    .map((f) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(f),
                            selected: _selectedFilter == f,
                            selectedColor: const Color(0xff005b96).withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                              color: _selectedFilter == f ? const Color(0xff005b96) : Colors.black87,
                              fontWeight: _selectedFilter == f ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                            onSelected: (val) => setState(() => _selectedFilter = f),
                          ),
                        ))
                    .toList(),
              ),
            ),

            const SizedBox(height: 12),

            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_filteredOrders.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: Column(
                  children: const [
                    Icon(Icons.inbox, size: 48, color: Colors.grey),
                    SizedBox(height: 10),
                    Text('No orders found matching your search.'),
                  ],
                ),
              )
            else
              ..._filteredOrders.map((order) => _buildOrderCard(order)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = (order['status'] ?? 'CONFIRMED').toString().toUpperCase();
    final isDelivered = status == 'DELIVERED';
    final orderNum = order['orderNumber'] ?? 'O102';
    final species = order['species'] ?? 'Tuna';
    final qty = order['quantityKg'] ?? 100;
    final price = order['pricePerKg'] ?? 1600;
    final total = order['totalAmount'] ?? 160000;
    final seller = order['sellerName'] ?? 'ABC Fisherman';
    final paymentStatus = (order['paymentStatus'] ?? 'PENDING').toString().toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: orderNum == 'O102' ? const Color(0xff005b96).withValues(alpha: 0.35) : Colors.grey.shade200,
          width: orderNum == 'O102' ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card Header ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xfff8fafc),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xff005b96).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.inventory_2, color: Color(0xff005b96), size: 18),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Order #$orderNum',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                _buildStatusPill(status),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Species & Price Row ────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(child: Text('🐟', style: TextStyle(fontSize: 24))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$species',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$qty kg • Rs. $price/kg',
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Seller: $seller',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Total Amount', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text(
                          'Rs. ${_formatCurrency(total)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Color(0xff005b96),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: paymentStatus == 'PAID' ? Colors.green.shade50 : Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            paymentStatus == 'PAID' ? 'PAID ✅' : 'PAYMENT PENDING',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: paymentStatus == 'PAID' ? Colors.green.shade800 : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── 15. Status Lifecycle Stepper ────────────────────────────
                const Text(
                  'Order Lifecycle Status',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xff475569)),
                ),
                const SizedBox(height: 8),
                _buildLifecycleTracker(status),

                const SizedBox(height: 12),

                // Demo Advance Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _advanceOrderStatus(order),
                      icon: const Icon(Icons.fast_forward, size: 14),
                      label: Text(
                        isDelivered ? 'Reset Cycle' : 'Advance Next Status',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),

                const Divider(height: 20),

                // ── Action Buttons for Features 16, 17, 18, 19, 20, 21 ─────────
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFeatureButton(
                      icon: Icons.local_shipping,
                      label: '16. 🚚 Logistics',
                      color: const Color(0xff005b96),
                      onTap: () => showLogisticsDetailsModal(context, order),
                    ),
                    _buildFeatureButton(
                      icon: Icons.map,
                      label: '17. 🗺️ Live Map',
                      color: const Color(0xff0284c7),
                      onTap: () => showLiveTrackingModal(context, order),
                    ),
                    _buildFeatureButton(
                      icon: Icons.ac_unit,
                      label: '18. 🧊 Cold Storage',
                      color: const Color(0xff0d9488),
                      onTap: () => showColdStorageModal(context, order),
                    ),
                    _buildFeatureButton(
                      icon: Icons.verified,
                      label: '19. 🔍 Quality Check',
                      color: const Color(0xff7c3aed),
                      onTap: () => showQualityVerificationModal(context, order),
                    ),
                    _buildFeatureButton(
                      icon: Icons.payment,
                      label: paymentStatus == 'PAID' ? '20. 💳 Paid' : '20. 💳 Pay Now',
                      color: paymentStatus == 'PAID' ? const Color(0xff16a34a) : const Color(0xffea580c),
                      onTap: () => showPaymentModal(
                        context,
                        order,
                        onPaymentSuccess: () {
                          setState(() {
                            order['paymentStatus'] = 'PAID';
                            order['transactionId'] = 'TXN10293';
                          });
                        },
                      ),
                    ),
                    _buildFeatureButton(
                      icon: Icons.receipt_long,
                      label: '21. 🧾 Invoice',
                      color: const Color(0xff475569),
                      onTap: () => showInvoiceModal(context, order),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'CONFIRMED':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        break;
      case 'SCHEDULED':
        bg = Colors.purple.shade50;
        fg = Colors.purple.shade800;
        break;
      case 'PICKED UP':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade900;
        break;
      case 'IN TRANSIT':
        bg = Colors.indigo.shade50;
        fg = Colors.indigo.shade800;
        break;
      case 'DELIVERED':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildLifecycleTracker(String currentStatus) {
    final steps = ['CONFIRMED', 'SCHEDULED', 'PICKED UP', 'IN TRANSIT', 'DELIVERED'];
    final currentIndex = steps.indexOf(currentStatus);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: List.generate(steps.length * 2 - 1, (index) {
            if (index.isOdd) {
              final stepBefore = index ~/ 2;
              final isPassed = stepBefore < currentIndex;
              return Expanded(
                child: Container(
                  height: 3,
                  color: isPassed ? const Color(0xff005b96) : Colors.grey.shade300,
                ),
              );
            } else {
              final stepIndex = index ~/ 2;
              final isDone = stepIndex <= currentIndex;
              final isCurrent = stepIndex == currentIndex;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone ? const Color(0xff005b96) : Colors.white,
                      border: Border.all(
                        color: isDone ? const Color(0xff005b96) : Colors.grey.shade400,
                        width: isCurrent ? 3 : 2,
                      ),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: const Color(0xff005b96).withValues(alpha: 0.3),
                                blurRadius: 6,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                    child: Center(
                      child: isDone
                          ? const Icon(Icons.check, size: 13, color: Colors.white)
                          : Text(
                              '${stepIndex + 1}',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    steps[stepIndex] == 'IN TRANSIT'
                        ? 'TRANSIT'
                        : (steps[stepIndex] == 'PICKED UP' ? 'PICKUP' : steps[stepIndex]),
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isDone ? const Color(0xff003b5c) : Colors.grey.shade600,
                    ),
                  ),
                ],
              );
            }
          }),
        );
      },
    );
  }

  Widget _buildFeatureButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0';
    final n = num.tryParse(amount.toString()) ?? 0;
    return n.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// 16. 🚚 LOGISTICS DETAILS MODAL
// ════════════════════════════════════════════════════════════════════════════════

void showLogisticsDetailsModal(BuildContext context, Map<String, dynamic> order) {
  final logistics = (order['logistics'] as Map<String, dynamic>?) ?? {};
  final orderNum = order['orderNumber'] ?? 'O102';
  final vehicle = logistics['vehicleCode'] ?? 'V02';
  final driver = logistics['driverName'] ?? 'Driver 01';
  final phone = logistics['driverPhone'] ?? '+94 77 123 4567';
  final pickup = logistics['pickupTime'] ?? '10:00 AM';
  final eta = logistics['eta'] ?? '11:35 AM';
  final route = logistics['route'] ?? 'Negombo → Colombo';
  final status = logistics['routeStatus'] ?? 'APPROVED';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Text('🚚 Delivery Plan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Logistics Agent Plan for Order #$orderNum', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),

          // Automated Agent assignment card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.smart_toy, color: Color(0xff005b96)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Autonomous Logistics Agent',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xff003b5c)),
                      ),
                      Text(
                        'Route optimized, vehicle & cold vault automatically allocated upon bid acceptance.',
                        style: TextStyle(fontSize: 11, color: Color(0xff003b5c)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          _buildDetailRow('Vehicle Code:', vehicle, highlight: true),
          _buildDetailRow('Driver Name:', '$driver ($phone)'),
          _buildDetailRow('Scheduled Pickup:', pickup),
          _buildDetailRow('Estimated Delivery (ETA):', eta),
          _buildDetailRow('Selected Route:', route),
          _buildDetailRow('Status:', '$status ✅', isBadge: true),

          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.green, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Admin Approval verified via Operations Control (React Web Dashboard).',
                    style: TextStyle(fontSize: 11, color: Color(0xff14532d), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Calling $driver at $phone...')),
                    );
                  },
                  icon: const Icon(Icons.call),
                  label: const Text('Call Driver'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xff005b96)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    showLiveTrackingModal(context, order);
                  },
                  icon: const Icon(Icons.location_on),
                  label: const Text('Live Track'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════════
// 17. 🗺️ LIVE DELIVERY TRACKING MODAL (DEVICE FEATURE)
// ════════════════════════════════════════════════════════════════════════════════

void showLiveTrackingModal(BuildContext context, Map<String, dynamic> order) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _LiveTrackingSheet(order: order),
  );
}

class _LiveTrackingSheet extends StatefulWidget {
  const _LiveTrackingSheet({required this.order});

  final Map<String, dynamic> order;

  @override
  State<_LiveTrackingSheet> createState() => _LiveTrackingSheetState();
}

class _LiveTrackingSheetState extends State<_LiveTrackingSheet> {
  String _deviceLocation = 'Determining GPS Location...';
  bool _fetchingGps = true;
  double _vehicleProgress = 0.52;

  @override
  void initState() {
    super.initState();
    _checkDeviceGps();
  }

  Future<void> _checkDeviceGps() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      if (mounted) {
        setState(() {
          _deviceLocation = 'Lat: ${pos.latitude.toStringAsFixed(4)}, Lon: ${pos.longitude.toStringAsFixed(4)}';
          _fetchingGps = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _deviceLocation = 'Negombo Coastal Pier (7.2084° N, 79.8358° E)';
          _fetchingGps = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final logistics = (widget.order['logistics'] as Map<String, dynamic>?) ?? {};
    final orderNum = widget.order['orderNumber'] ?? 'O102';
    final vehicle = logistics['vehicleCode'] ?? 'V02';
    final eta = logistics['eta'] ?? '11:35 AM';
    final distance = logistics['distanceKm'] ?? 38.5;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.satellite_alt, color: Color(0xff005b96)),
                  SizedBox(width: 8),
                  Text('17. 🗺️ Live Delivery Tracking', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          Text('Order #$orderNum • Refrigerator Vehicle $vehicle', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 14),

          // ── Visual Map Representation ──────────────────────────────
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff0f172a), Color(0xff1e293b)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.blue.shade900),
            ),
            child: Stack(
              children: [
                // Stylized map grid lines
                Positioned.fill(
                  child: CustomPaint(
                    painter: _MapRoutePainter(progress: _vehicleProgress),
                  ),
                ),

                // Top Floating Status Chip
                Positioned(
                  top: 12,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.fiber_manual_record, color: Colors.greenAccent, size: 8),
                        SizedBox(width: 5),
                        Text('GPS Live • 52 km/h • 3.0°C', style: TextStyle(color: Colors.white, fontSize: 10)),
                      ],
                    ),
                  ),
                ),

                // Origin Label
                Positioned(
                  top: 40,
                  left: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('📍 Negombo Harbor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      Text('Pickup: 10:00 AM', style: TextStyle(color: Color(0xff94a3b8), fontSize: 10)),
                    ],
                  ),
                ),

                // Destination Label
                Positioned(
                  bottom: 30,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('📍 Colombo Central Market', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      Text('ETA: $eta (25m remaining)', style: const TextStyle(color: Color(0xff38bdf8), fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Telemetry Specs
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _buildTrackingMetric(
                  icon: Icons.my_location,
                  title: 'Current Location',
                  value: 'Ja-Ela Expressway Junction (Km 18.2)',
                ),
                const Divider(height: 14),
                _buildTrackingMetric(
                  icon: Icons.flag,
                  title: 'Destination',
                  value: 'Peliyagoda Central Fish Market, Colombo',
                ),
                const Divider(height: 14),
                _buildTrackingMetric(
                  icon: Icons.alt_route,
                  title: 'Total Route',
                  value: '$distance km via Colombo - Katunayake Expy',
                ),
                const Divider(height: 14),
                _buildTrackingMetric(
                  icon: Icons.phone_android,
                  title: 'Device GPS Telemetry',
                  value: _fetchingGps ? 'Locating device...' : _deviceLocation,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _vehicleProgress = (_vehicleProgress + 0.15) % 0.95;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('GPS Telemetry refreshed with latest satellite ping.')),
                    );
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh GPS'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xff005b96)),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close Tracking'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingMetric({required IconData icon, required String title, required String value}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xff005b96)),
        const SizedBox(width: 10),
        Text('$title: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 11, color: Color(0xff334155)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _MapRoutePainter extends CustomPainter {
  _MapRoutePainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(30, 70);
    final end = Offset(size.width - 40, size.height - 55);

    // Route line
    final routePaint = Paint()
      ..color = const Color(0xff38bdf8)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(size.width * 0.35, start.dy + 30, size.width * 0.65, end.dy - 30, end.dx, end.dy);

    canvas.drawPath(path, routePaint);

    // Animated truck position along path
    final metric = path.computeMetrics().first;
    final tangent = metric.getTangentForOffset(metric.length * progress);
    if (tangent != null) {
      final truckPos = tangent.position;

      // Glow circle
      final glowPaint = Paint()
        ..color = const Color(0xff38bdf8).withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(truckPos, 18, glowPaint);

      // White inner
      final innerPaint = Paint()
        ..color = const Color(0xff0284c7)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(truckPos, 10, innerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MapRoutePainter oldDelegate) => oldDelegate.progress != progress;
}

// ════════════════════════════════════════════════════════════════════════════════
// 18. 🧊 COLD STORAGE MODAL
// ════════════════════════════════════════════════════════════════════════════════

void showColdStorageModal(BuildContext context, Map<String, dynamic> order) {
  final cold = (order['coldStorage'] as Map<String, dynamic>?) ?? {};
  final orderNum = order['orderNumber'] ?? 'O102';
  final storage = cold['storageCode'] ?? 'C02';
  final temp = cold['temperature'] ?? '3°C';
  final capacity = cold['capacityKg'] ?? 150;
  final catchWeight = cold['yourCatchKg'] ?? 100;
  final status = cold['status'] ?? 'SAFE';

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.ac_unit, color: Color(0xff0d9488)),
                  SizedBox(width: 8),
                  Text('18. 🧊 Cold Storage', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
            ],
          ),
          Text('Telemetry Information for Order #$orderNum', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),

          // Big Temperature Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff0f766e), Color(0xff14b8a6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Vault Temperature', style: TextStyle(color: Color(0xffccfbf1), fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      temp,
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    const Text('Safe Range: 0°C – 4°C', style: TextStyle(color: Color(0xffccfbf1), fontSize: 11)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        status,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xff0f766e), fontSize: 14),
                      ),
                      const SizedBox(width: 4),
                      const Text('✅'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          _buildDetailRow('Storage Unit:', storage, highlight: true),
          _buildDetailRow('Unit Total Capacity:', '$capacity kg'),
          _buildDetailRow('Your Catch Allocation:', '$catchWeight kg'),
          _buildDetailRow('Telemetry Status:', '$status ✅', isBadge: true),

          const SizedBox(height: 10),
          const Text('Storage Capacity Utilization', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (num.tryParse(catchWeight.toString()) ?? 100) / (num.tryParse(capacity.toString()) ?? 150),
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation(Color(0xff0d9488)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(((num.tryParse(catchWeight.toString()) ?? 100) / (num.tryParse(capacity.toString()) ?? 150)) * 100).toStringAsFixed(0)}% space utilized by your catch',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xff0d9488)),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close Details'),
            ),
          ),
        ],
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════════
// 19. 🔍 QUALITY / VERIFICATION STATUS MODAL
// ════════════════════════════════════════════════════════════════════════════════

void showQualityVerificationModal(BuildContext context, Map<String, dynamic> order) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _QualityModalContent(order: order),
  );
}

class _QualityModalContent extends StatefulWidget {
  const _QualityModalContent({required this.order});
  final Map<String, dynamic> order;

  @override
  State<_QualityModalContent> createState() => _QualityModalContentState();
}

class _QualityModalContentState extends State<_QualityModalContent> {
  bool _showSuspiciousExample = false;

  @override
  Widget build(BuildContext context) {
    final quality = (widget.order['quality'] as Map<String, dynamic>?) ?? {};
    final catchCode = quality['catchCode'] ?? 'C103';

    // Normal Verified Data
    final declared = quality['declaredWeightKg'] ?? 100.0;
    final verified = quality['verifiedWeightKg'] ?? 98.0;
    final grade = quality['grade'] ?? 'A';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.verified, color: Color(0xff7c3aed)),
                  SizedBox(width: 8),
                  Text('19. 🔍 Quality Verification', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _showSuspiciousExample ? 'Catch: C104 (Flagged Suspicious Example)' : 'Catch: $catchCode (Standard Verified)',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 14),

          // Toggle for Normal vs Suspicious Example
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _showSuspiciousExample = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: !_showSuspiciousExample ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Standard: VERIFIED ✅',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: !_showSuspiciousExample ? Colors.green.shade800 : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _showSuspiciousExample = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _showSuspiciousExample ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '⚠ Suspicious Audit Flag',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _showSuspiciousExample ? Colors.red.shade800 : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          if (!_showSuspiciousExample) ...[
            // Normal Passed Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: const [
                          Text('VERIFIED', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
                          SizedBox(width: 4),
                          Text('✅'),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  _buildDetailRow('Catch Lot:', '$catchCode'),
                  _buildDetailRow('Declared Weight:', '$declared kg'),
                  _buildDetailRow('Verified Weight:', '$verified kg'),
                  _buildDetailRow('Quality Grade:', '$grade'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Reason: 2% variance is acceptable natural drip loss during storage. Passed Grade A hygiene criteria.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
          ] else ...[
            // Suspicious Fraud Flag Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('ADMIN REVIEW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  _buildDetailRow('Declared Weight:', '100 kg'),
                  _buildDetailRow('Verified Weight:', '62 kg (Discrepancy: -38%)'),
                  _buildDetailRow('Quality Grade:', 'C'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Fraud Agent: Discrepancy exceeds 15% threshold. Does not make a final accusation — flagged for Admin Pier Officer audit.',
                      style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _showSuspiciousExample ? Colors.red.shade700 : const Color(0xff7c3aed),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Dismiss'),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// 20. 💳 PAYMENTS MODAL (SANDBOX INTEGRATION)
// ════════════════════════════════════════════════════════════════════════════════

void showPaymentModal(BuildContext context, Map<String, dynamic> order, {VoidCallback? onPaymentSuccess}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _PaymentSheet(order: order, onSuccess: onPaymentSuccess),
  );
}

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({required this.order, this.onSuccess});

  final Map<String, dynamic> order;
  final VoidCallback? onSuccess;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  String _selectedMethod = 'LankaQR';
  bool _processing = false;
  bool _isPaid = false;
  String? _txnId;

  @override
  void initState() {
    super.initState();
    _isPaid = (widget.order['paymentStatus'] ?? '').toString().toUpperCase() == 'PAID';
    _txnId = widget.order['transactionId'];
  }

  Future<void> _processPayment() async {
    setState(() => _processing = true);
    await Future.delayed(const Duration(milliseconds: 1400)); // Sandbox simulation

    try {
      final token = await const FlutterSecureStorage().read(key: 'token');
      await http.post(
        Uri.parse('$_apiBase/Orders/${widget.order['id']}/pay'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'amount': widget.order['totalAmount'] ?? 162000.0,
          'method': _selectedMethod,
        }),
      );
    } catch (_) {}

    if (mounted) {
      setState(() {
        _processing = false;
        _isPaid = true;
        _txnId = 'TXN10293';
      });
      widget.onSuccess?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderNum = widget.order['orderNumber'] ?? 'O102';
    final total = widget.order['totalAmount'] ?? 160000;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.payment, color: Color(0xffea580c)),
                  SizedBox(width: 8),
                  Text('20. 💳 Payment Gateway', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          Text('Order: #$orderNum • Sandbox Payment Gateway', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),

          if (_isPaid) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 54),
                  const SizedBox(height: 10),
                  const Text('Payment: PAID ✅', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                  const SizedBox(height: 6),
                  Text('Transaction ID: ${_txnId ?? 'TXN10293'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Amount Settled: Rs. $total', style: TextStyle(color: Colors.grey.shade700)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Amount Payable', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text('Rs. $total', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xffea580c))),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(8)),
                    child: const Text('PENDING', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            const Text('Select Payment Option', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),

            RadioListTile<String>(
              value: 'LankaQR',
              groupValue: _selectedMethod,
              onChanged: (v) => setState(() => _selectedMethod = v!),
              title: const Text('📱 LankaQR Fast Pay (LankaPay Sandbox)'),
              subtitle: const Text('Scan & pay via any Sri Lankan banking app'),
            ),
            RadioListTile<String>(
              value: 'Card',
              groupValue: _selectedMethod,
              onChanged: (v) => setState(() => _selectedMethod = v!),
              title: const Text('💳 VISA / Mastercard / UnionPay'),
              subtitle: const Text('3D-Secure sandbox payment gateway'),
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xffea580c)),
                onPressed: _processing ? null : _processPayment,
                child: _processing
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('[ Pay Now ]', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// 21. 🧾 INVOICE MODAL
// ════════════════════════════════════════════════════════════════════════════════

void showInvoiceModal(BuildContext context, Map<String, dynamic> order) {
  final invoice = (order['invoice'] as Map<String, dynamic>?) ?? {};
  final invNum = invoice['invoiceNumber'] ?? 'INV102';
  final species = invoice['species'] ?? 'Tuna';
  final qty = invoice['quantityKg'] ?? 100;
  final price = invoice['pricePerKg'] ?? 1600;
  final subtotal = invoice['subtotal'] ?? 160000;
  final delivery = invoice['deliveryFee'] ?? 2000;
  final total = invoice['total'] ?? 162000;
  final payment = invoice['paymentStatus'] ?? 'PAID';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.receipt_long, color: Color(0xff475569)),
                  SizedBox(width: 8),
                  Text('21. 🧾 Official Tax Invoice', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
            ],
          ),
          Text('Invoice #$invNum', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xff005b96))),
          const SizedBox(height: 16),

          // Invoice paper sheet
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xfff8fafc),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$species', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('$qty kg', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Unit Price'),
                    Text('Rs. $price / kg'),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal'),
                    Text('Rs. $subtotal'),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Cold Chain Delivery'),
                    Text('Rs. $delivery'),
                  ],
                ),
                const Divider(height: 20, thickness: 1.2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Payable', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('Rs. $total', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xff005b96))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Payment Status: '),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(6)),
                      child: Text(payment, style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Viewing full invoice #$invNum in high-resolution viewer.')),
                    );
                  },
                  icon: const Icon(Icons.visibility),
                  label: const Text('[ View Invoice ]'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xff005b96)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Invoice_$invNum.pdf downloaded to device storage.'),
                        backgroundColor: Colors.green.shade800,
                      ),
                    );
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('[ Download PDF ]'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════════
// 22. 🔔 NOTIFICATIONS / ALERTS SCREEN (DEVICE FEATURE)
// ════════════════════════════════════════════════════════════════════════════════

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({this.role = 'Fisherman', super.key});

  final String role;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _filter = 'All';
  List<Map<String, dynamic>> _alerts = [
    {
      'id': 1,
      'title': '🔔 New Bid Received',
      'message': 'Buyer ABC bid Rs.1600/kg for your Tuna catch.',
      'time': '2 mins ago',
      'category': 'Bids',
      'isRead': false,
      'color': Colors.blue,
      'icon': Icons.gavel,
    },
    {
      'id': 2,
      'title': '🔔 Bid Accepted',
      'message': 'Your bid for Tuna was accepted by ABC Fisherman.',
      'time': '15 mins ago',
      'category': 'Bids',
      'isRead': false,
      'color': Colors.green,
      'icon': Icons.check_circle,
    },
    {
      'id': 3,
      'title': '🔔 Delivery Scheduled',
      'message': 'Order O102 pickup: 10:00 AM. Driver 01 assigned with Vehicle V02.',
      'time': '1 hour ago',
      'category': 'Deliveries',
      'isRead': true,
      'color': Colors.purple,
      'icon': Icons.local_shipping,
    },
    {
      'id': 4,
      'title': '💳 Payment Confirmed',
      'message': 'Payment of Rs.160,000 received for Order #O102 (TXN10293).',
      'time': '2 hours ago',
      'category': 'Payments',
      'isRead': true,
      'color': Colors.orange,
      'icon': Icons.payment,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _alerts.where((a) => _filter == 'All' || a['category'] == _filter).toList();

    return Scaffold(
      backgroundColor: const Color(0xfff0f4f8),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Device Alerts & Push Notifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  setState(() {
                    for (var a in _alerts) {
                      a['isRead'] = true;
                    }
                  });
                },
                child: const Text('Mark all read'),
              ),
            ],
          ),
          const SizedBox(height: 6),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Bids', 'Deliveries', 'Payments']
                  .map((f) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                      ))
                  .toList(),
            ),
          ),

          const SizedBox(height: 14),

          ...filtered.map((item) {
            final isRead = item['isRead'] as bool;
            final color = item['color'] as Color;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isRead ? Colors.grey.shade200 : color.withValues(alpha: 0.3),
                  width: isRead ? 1 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(item['icon'] as IconData, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item['title'] as String,
                              style: TextStyle(
                                fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                fontSize: 14,
                                color: isRead ? Colors.black87 : const Color(0xff003b5c),
                              ),
                            ),
                            if (!isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['message'] as String,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item['time'] as String,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// 23 & 24. 👤 PROFILE & HISTORY SCREEN
// ════════════════════════════════════════════════════════════════════════════════

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({required this.role, required this.onSignOut, super.key});

  final String role; // 'Fisherman' or 'Buyer'
  final VoidCallback onSignOut;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = 'Captain Kaveesha Perera';
  String _phone = '+94 77 123 4567';
  String _email = 'kaveesha@fishlink.lk';
  String _address = 'Harbour Road, Negombo, Sri Lanka';
  String _business = 'Ocean Star Marine & Fisheries';

  @override
  void initState() {
    super.initState();
    if (widget.role == 'Buyer') {
      _name = 'Colombo Seafood Wholesalers';
      _phone = '+94 11 234 5678';
      _email = 'buyer@colomboseafood.lk';
      _address = 'Pettah Fish Market, Colombo 11';
      _business = 'Colombo Seafood Direct Ltd';
    }
  }

  void _showEditProfile() {
    final nameCtrl = TextEditingController(text: _name);
    final phoneCtrl = TextEditingController(text: _phone);
    final addressCtrl = TextEditingController(text: _address);
    final bizCtrl = TextEditingController(text: _business);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 10),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 10),
              TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address')),
              const SizedBox(height: 10),
              TextField(controller: bizCtrl, decoration: const InputDecoration(labelText: 'Business Name')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              setState(() {
                _name = nameCtrl.text;
                _phone = phoneCtrl.text;
                _address = addressCtrl.text;
                _business = bizCtrl.text;
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!')));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showChangePassword() {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: oldCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Current Password')),
            const SizedBox(height: 10),
            TextField(controller: newCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'New Password')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully!')));
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff0f4f8),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // ── Profile Header ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff003b5c), Color(0xff00628a)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Text(
                    _name.isNotEmpty ? _name[0] : 'U',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xff003b5c)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _business,
                        style: const TextStyle(color: Color(0xffd9f2ff), fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.shade700,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.role,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── My Profile Info ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Divider(height: 18),
                _buildProfileItem(Icons.person, 'Full Name', _name),
                _buildProfileItem(Icons.phone, 'Phone Number', _phone),
                _buildProfileItem(Icons.email, 'Email Address', _email),
                _buildProfileItem(Icons.location_on, 'Address', _address),
                _buildProfileItem(Icons.business, 'Business Name', _business),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showEditProfile,
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('[ Edit Profile ]'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showChangePassword,
                        icon: const Icon(Icons.lock_reset, size: 16),
                        label: const Text('[ Change Password ]'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── 23. 📜 History (Sales History or Purchase History) ──────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history, color: Color(0xff005b96)),
                    const SizedBox(width: 8),
                    Text(
                      widget.role == 'Fisherman' ? '23. 📜 Sales History' : '23. 📜 Purchase History',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const Divider(height: 18),
                if (widget.role == 'Fisherman') ...[
                  _buildHistoryRow('O101', 'Tuna', 'Rs. 150,000', 'Delivered'),
                  const Divider(height: 14),
                  _buildHistoryRow('O098', 'Mackerel', 'Rs. 85,000', 'Delivered'),
                ] else ...[
                  _buildHistoryRow('O102', 'Tuna', 'Rs. 160,000', 'Confirmed'),
                  const Divider(height: 14),
                  _buildHistoryRow('O097', 'Mackerel', 'Rs. 90,000', 'Delivered'),
                ],
              ],
            ),
          ),

          const SizedBox(height: 18),

          // ── Logout Button ──────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xffd90429),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Confirm Logout'),
                    content: const Text('Are you sure you want to log out of FishLink AI?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xffd90429)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          widget.onSignOut();
                        },
                        child: const Text('[ Logout ]'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.logout),
              label: const Text('[ Logout ]', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(String id, String species, String amount, String status) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order #$id • $species', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(status, style: TextStyle(color: Colors.green.shade700, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
        Text(amount, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xff005b96))),
      ],
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

Widget _buildDetailRow(String label, String value, {bool highlight = false, bool isBadge = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.black87)),
        if (isBadge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(6)),
            child: Text(value, style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.bold, fontSize: 11)),
          )
        else
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
              color: highlight ? const Color(0xff005b96) : Colors.black87,
            ),
          ),
      ],
    ),
  );
}

final List<Map<String, dynamic>> _defaultSampleOrders = [
  {
    'id': 102,
    'orderNumber': 'O102',
    'species': 'Tuna',
    'quantityKg': 100.0,
    'pricePerKg': 1600.0,
    'subtotal': 160000.0,
    'deliveryFee': 2000.0,
    'totalAmount': 162000.0,
    'sellerName': 'ABC Fisherman',
    'status': 'CONFIRMED',
    'paymentStatus': 'PAID',
    'transactionId': 'TXN10293',
    'currentStep': 1,
    'logistics': {
      'vehicleCode': 'V02',
      'driverName': 'Driver 01',
      'driverPhone': '+94 77 123 4567',
      'pickupTime': '10:00 AM',
      'eta': '11:35 AM',
      'route': 'Negombo → Colombo',
      'routeStatus': 'APPROVED',
      'distanceKm': 38.5,
    },
    'coldStorage': {
      'storageCode': 'C02',
      'temperature': '3°C',
      'capacityKg': 150.0,
      'yourCatchKg': 100.0,
      'status': 'SAFE',
    },
    'quality': {
      'catchCode': 'C103',
      'declaredWeightKg': 100.0,
      'verifiedWeightKg': 98.0,
      'grade': 'A',
      'status': 'VERIFIED',
    },
    'invoice': {
      'invoiceNumber': 'INV102',
      'species': 'Tuna',
      'quantityKg': 100.0,
      'pricePerKg': 1600.0,
      'subtotal': 160000.0,
      'deliveryFee': 2000.0,
      'total': 162000.0,
      'paymentStatus': 'PAID',
    }
  },
  {
    'id': 101,
    'orderNumber': 'O101',
    'species': 'Tuna',
    'quantityKg': 100.0,
    'pricePerKg': 1500.0,
    'totalAmount': 150000.0,
    'sellerName': 'Ocean Star Fishery',
    'status': 'DELIVERED',
    'paymentStatus': 'PAID',
    'transactionId': 'TXN10188',
    'currentStep': 5,
    'logistics': {'vehicleCode': 'V01', 'driverName': 'Driver Sunil', 'pickupTime': '06:00 AM', 'eta': '08:15 AM', 'route': 'Negombo → Colombo', 'routeStatus': 'DELIVERED', 'distanceKm': 38.5},
    'coldStorage': {'storageCode': 'C01', 'temperature': '2.8°C', 'capacityKg': 200.0, 'yourCatchKg': 100.0, 'status': 'SAFE'},
    'quality': {'catchCode': 'C101', 'declaredWeightKg': 100.0, 'verifiedWeightKg': 100.0, 'grade': 'A+', 'status': 'VERIFIED'},
    'invoice': {'invoiceNumber': 'INV101', 'species': 'Tuna', 'quantityKg': 100.0, 'pricePerKg': 1500.0, 'subtotal': 150000.0, 'deliveryFee': 2000.0, 'total': 152000.0, 'paymentStatus': 'PAID'}
  },
  {
    'id': 98,
    'orderNumber': 'O098',
    'species': 'Mackerel',
    'quantityKg': 70.0,
    'pricePerKg': 1214.0,
    'totalAmount': 85000.0,
    'sellerName': 'Captain Kaveesha',
    'status': 'DELIVERED',
    'paymentStatus': 'PAID',
    'transactionId': 'TXN09841',
    'currentStep': 5,
    'logistics': {'vehicleCode': 'V03', 'driverName': 'Driver 02', 'pickupTime': '07:30 AM', 'eta': '10:45 AM', 'route': 'Negombo → Kandy', 'routeStatus': 'DELIVERED', 'distanceKm': 105.0},
    'coldStorage': {'storageCode': 'C03', 'temperature': '3.2°C', 'capacityKg': 180.0, 'yourCatchKg': 70.0, 'status': 'SAFE'},
    'quality': {'catchCode': 'C098', 'declaredWeightKg': 70.0, 'verifiedWeightKg': 70.2, 'grade': 'A', 'status': 'VERIFIED'},
    'invoice': {'invoiceNumber': 'INV098', 'species': 'Mackerel', 'quantityKg': 70.0, 'pricePerKg': 1214.0, 'subtotal': 85000.0, 'deliveryFee': 1500.0, 'total': 86500.0, 'paymentStatus': 'PAID'}
  },
];
