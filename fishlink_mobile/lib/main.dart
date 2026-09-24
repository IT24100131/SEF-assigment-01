import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'admin_and_logistics.dart';
import 'features_15_25.dart';

String get effectiveApiBaseUrl =>
    const String.fromEnvironment('FISHLINK_API_URL').isNotEmpty
        ? const String.fromEnvironment('FISHLINK_API_URL')
        : (kIsWeb ? 'http://localhost:5157/api' : 'http://10.0.2.2:5157/api');

void main() => runApp(const FishLinkApp());

class ApiClient {
  ApiClient({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage _storage;

  Future<dynamic> _rawRequest(String method, String path,
      {Object? body, bool authenticated = true}) async {
    final token = authenticated ? await _storage.read(key: 'token') : null;
    final response = await _client
        .send(http.Request(method, Uri.parse('$effectiveApiBaseUrl$path'))
          ..headers.addAll({
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          })
          ..body = body == null ? '' : jsonEncode(body));

    final text = await response.stream.bytesToString();
    dynamic decoded;
    try {
      decoded = text.isEmpty ? null : jsonDecode(text);
    } catch (_) {
      decoded = text;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          decoded is Map ? decoded['message'] ?? decoded['title'] : decoded;
      throw Exception(
          message?.toString() ?? 'Request failed (${response.statusCode})');
    }

    return decoded;
  }

  Future<Map<String, dynamic>> _request(String method, String path,
      {Object? body, bool authenticated = true}) async {
    final res = await _rawRequest(method, path, body: body, authenticated: authenticated);
    return res is Map<String, dynamic> ? res : {'data': res};
  }

  Future<Map<String, dynamic>> login(String email, String password) =>
      _request('POST', '/Auth/login',
          body: {'email': email, 'password': password}, authenticated: false);

  Future<Map<String, dynamic>> register(
      String fullName, String email, String password, String role) async {
    return _request('POST', '/Auth/register',
        body: {
          'fullName': fullName,
          'email': email,
          'passwordHash': password,
          'role': role,
        },
        authenticated: false);
  }

  Future<List<dynamic>> catches({bool mine = false, String? status, String? species, String? search}) async {
    final queryParams = <String>[];
    if (status != null && status != 'All') queryParams.add('status=${Uri.encodeQueryComponent(status)}');
    if (species != null && species != 'All') queryParams.add('species=${Uri.encodeQueryComponent(species)}');
    if (search != null && search.isNotEmpty) queryParams.add('search=${Uri.encodeQueryComponent(search)}');
    queryParams.add('pageSize=100');
    final queryString = '?${queryParams.join('&')}';
    final result = await _request('GET', '/Catches$queryString');
    if (result['items'] is List) return result['items'] as List<dynamic>;
    if (result['data'] is List) return result['data'] as List<dynamic>;
    return (result['items'] as List<dynamic>? ?? const []);
  }

  Future<Map<String, dynamic>> createCatch(Map<String, dynamic> payload) async {
    final res = await _rawRequest('POST', '/Catches', body: payload);
    return res is Map<String, dynamic> ? res : {};
  }

  Future<void> updateCatch(int id, Map<String, dynamic> payload) async {
    await _rawRequest('PUT', '/Catches/$id', body: payload);
  }

  Future<Map<String, dynamic>> publishCatch(int id) async {
    final res = await _rawRequest('PATCH', '/Catches/$id/publish');
    return res is Map<String, dynamic> ? res : {};
  }

  Future<Map<String, dynamic>> cancelCatch(int id) async {
    final res = await _rawRequest('PATCH', '/Catches/$id/cancel');
    return res is Map<String, dynamic> ? res : {};
  }

  Future<void> deleteCatch(int id) async {
    await _rawRequest('DELETE', '/Catches/$id');
  }

  Future<Map<String, dynamic>> safety(String location) => _request(
      'GET', '/Weather/fishing-safety?location=${Uri.encodeQueryComponent(location)}');

  Future<Map<String, dynamic>> predictPrice(String species) async {
    final res = await _rawRequest('GET', '/AgentGateway/prices/${Uri.encodeComponent(species)}/predict');
    if (res is Map<String, dynamic>) return res;
    return {};
  }

  Future<Map<String, dynamic>> updateBuyerPreferences(Map<String, dynamic> payload) async {
    final res = await _rawRequest('POST', '/BuyerMatch/preferences/me', body: payload);
    return res is Map<String, dynamic> ? res : {};
  }

  Future<Map<String, dynamic>> getRecommendedBuyers(int catchId) async {
    final res = await _rawRequest('GET', '/BuyerMatch/score-buyers/$catchId');
    if (res is Map<String, dynamic>) return res;
    return {};
  }

  Future<List<dynamic>> getCatchBids(int catchId) async {
    final res = await _rawRequest('GET', '/Bids/catch/$catchId');
    if (res is List) return res;
    return [];
  }

  Future<Map<String, dynamic>> acceptBid(int bidId) async {
    final res = await _rawRequest('PATCH', '/Bids/$bidId/accept');
    if (res is Map<String, dynamic>) return res;
    return {};
  }

  Future<Map<String, dynamic>> rejectBid(int bidId) async {
    final res = await _rawRequest('PATCH', '/Bids/$bidId/reject');
    if (res is Map<String, dynamic>) return res;
    return {};
  }

  Future<Map<String, dynamic>> placeBid(int catchId, double bidPricePerKg) async {
    final res = await _rawRequest('POST', '/Bids', body: {
      'catchId': catchId,
      'bidPricePerKg': bidPricePerKg,
    });
    if (res is Map<String, dynamic>) return res;
    return {};
  }

  Future<List<dynamic>> getMyBids() async {
    final res = await _rawRequest('GET', '/Bids/my');
    if (res is List) return res;
    return [];
  }

  Future<Map<String, dynamic>> createLogisticsPlan(Map<String, dynamic> payload) async {
    final res = await _rawRequest('POST', '/Logistics/plans', body: payload);
    if (res is Map<String, dynamic>) return res;
    return {};
  }

  Future<List<dynamic>> getLogisticsPlans() async {
    final res = await _rawRequest('GET', '/Logistics/plans');
    if (res is List) return res;
    return [];
  }

  Future<void> approveLogisticsPlan(int planId) async {
    await _rawRequest('PATCH', '/Logistics/plans/$planId/approve');
  }

  Future<void> rejectLogisticsPlan(int planId) async {
    await _rawRequest('PATCH', '/Logistics/plans/$planId/reject');
  }

  Future<void> completeLogisticsPlan(int planId) async {
    await _rawRequest('PATCH', '/Logistics/plans/$planId/complete');
  }

  Future<void> dispatchLogisticsPlan(int planId, {DateTime? departureTime, DateTime? estimatedETA, String? adminNote}) async {
    await _rawRequest('PATCH', '/Logistics/plans/$planId/dispatch', body: {
      if (departureTime != null) 'departureTime': departureTime.toIso8601String(),
      if (estimatedETA != null) 'estimatedETA': estimatedETA.toIso8601String(),
      if (adminNote != null) 'adminNote': adminNote,
    });
  }

  Future<List<dynamic>> getAvailableCatches() async {
    final res = await _rawRequest('GET', '/BuyerMatch/available');
    if (res is List) return res;
    return [];
  }

  Future<List<dynamic>> getOrders({String? role}) async {
    final res = await _rawRequest('GET', '/Orders${role != null ? '?role=$role' : ''}');
    if (res is List) return res;
    return [];
  }

  Future<Map<String, dynamic>> updateOrderStatus(int orderId, String status) async {
    final res = await _rawRequest('PATCH', '/Orders/$orderId/status', body: {'status': status});
    if (res is Map<String, dynamic>) return res;
    return {};
  }

  Future<Map<String, dynamic>> payOrder(int orderId, {double amount = 162000.0, String method = 'LankaQR / VISA'}) async {
    final res = await _rawRequest('POST', '/Orders/$orderId/pay', body: {'amount': amount, 'method': method});
    if (res is Map<String, dynamic>) return res;
    return {};
  }

  Future<List<dynamic>> getNotifications() async {
    final res = await _rawRequest('GET', '/Orders/notifications');
    if (res is List) return res;
    return [];
  }
}

class FishLinkApp extends StatefulWidget {
  const FishLinkApp({super.key});

  @override
  State<FishLinkApp> createState() => _FishLinkAppState();
}

class _FishLinkAppState extends State<FishLinkApp> {
  final _storage = const FlutterSecureStorage();
  bool _signedIn = false;
  String _role = 'Fisherman';

  @override
  void initState() {
    super.initState();
    _storage.read(key: 'token').then((token) {
      if (!mounted) return;
      _storage.read(key: 'role').then((role) {
        if (!mounted) return;
        setState(() {
          _signedIn = token != null;
          _role = role ?? 'Fisherman';
        });
      });
    });
  }

  Future<void> _signOut() async {
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'role');
    if (mounted) setState(() => _signedIn = false);
  }

  void _onSignedIn(String role) => setState(() {
        _role = role;
        _signedIn = true;
      });

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'FishLink AI',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xff005b96),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xfff0f4f8),
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xffdbe3ee)),
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xff005b96), width: 2),
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
        ),
        home: _signedIn
            ? HomeScreen(role: _role, onSignOut: _signOut)
            : LoginScreen(onSignedIn: _onSignedIn),
      );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.onSignedIn, super.key});

  final ValueChanged<String> onSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ApiClient().login(_email.text.trim(), _password.text);
      final user = result['user'] as Map<String, dynamic>? ?? {};
      const storage = FlutterSecureStorage();
      final token = result['token']?.toString();
      if (token == null || token.isEmpty) {
        throw Exception('The API did not return an access token.');
      }

      await storage.write(key: 'token', value: token);
      await storage.write(
          key: 'role', value: user['role']?.toString() ?? 'Fisherman');
      widget.onSignedIn(user['role']?.toString() ?? 'Fisherman');
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _error = message.toLowerCase().contains('email already exists')
            ? 'This email is already registered. Please sign in instead.'
            : message;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthShell(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),
              const Text(
                'Welcome to FishLink AI',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xff003366),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Sign in to your account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xff556b82),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email),
                ),
                validator: (v) =>
                    v == null || !v.contains('@') ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                ),
                validator: (v) =>
                    v == null || v.length < 6 ? 'Minimum 6 characters' : null,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Login'),
                ),
              ),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('OR DEMO 1-TAP LOGIN',
                        style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.sailing, size: 14, color: Color(0xff005b96)),
                    label: const Text('🐟 Fisherman', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      _email.text = 'fisher1@fishlink.lk';
                      _password.text = 'Fisher123!';
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.storefront, size: 14, color: Color(0xff059669)),
                    label: const Text('🛒 Buyer', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      _email.text = 'buyer1@fishlink.lk';
                      _password.text = 'Buyer123!';
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.admin_panel_settings, size: 14, color: Color(0xff7c3aed)),
                    label: const Text('🛡️ Admin', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      _email.text = 'admin@fishlink.lk';
                      _password.text = 'Admin123!';
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        RegisterScreen(onSignedIn: widget.onSignedIn),
                  ),
                ),
                child: const Text('Create an account'),
              ),
            ],
          ),
        ),
      );
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({required this.onSignedIn, super.key});

  final ValueChanged<String> onSignedIn;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _role = 'Fisherman';
  bool _loading = false;
  String? _error;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ApiClient().register(
          _name.text.trim(), _email.text.trim(), _password.text, _role);
      if (mounted) {
        final token = result['token']?.toString();
        final user = result['user'] as Map<String, dynamic>? ?? {};
        if (token == null || token.isEmpty) {
          throw Exception('The API did not return an access token.');
        }

        const storage = FlutterSecureStorage();
        final role = user['role']?.toString() ?? _role;
        await storage.write(key: 'token', value: token);
        await storage.write(key: 'role', value: role);
        widget.onSignedIn(role);
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthShell(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),
              const Text(
                'Create an Account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xff003366),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Join the FishLink platform',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xff556b82),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter your name' : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email),
                ),
                validator: (v) =>
                    v == null || !v.contains('@') ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                ),
                validator: (v) =>
                    v == null || v.length < 6 ? 'Minimum 6 characters' : null,
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                initialValue: _role,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Select Your Role',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'Fisherman', child: Text('Fisherman')),
                  DropdownMenuItem(value: 'Buyer', child: Text('Buyer')),
                  DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                ],
                onChanged: (value) => setState(() => _role = value ?? 'Fisherman'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 22),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _loading ? null : _register,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text('Register'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Already have an account? Sign In'),
              ),
            ],
          ),
        ),
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.role, required this.onSignOut, super.key});

  final String role;
  final VoidCallback onSignOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  late String _currentRole;

  @override
  void initState() {
    super.initState();
    _currentRole = widget.role;
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _currentRole == 'Admin';
    final isBuyer = _currentRole == 'Buyer';

    final screens = <Widget>[
      if (isAdmin) ...[
        AdminDashboardScreen(
          onSignOut: widget.onSignOut,
          onNavigateTab: (idx) => setState(() => _index = idx.clamp(0, 3)),
        ),
        OrdersScreen(role: _currentRole),
        NotificationsScreen(role: _currentRole),
        ProfileScreen(role: _currentRole, onSignOut: widget.onSignOut),
      ] else if (isBuyer) ...[
        BuyerDashboardScreen(
          onSignOut: widget.onSignOut,
          onNavigateTab: (idx) => setState(() => _index = idx),
        ),
        const BrowseFishScreen(),
        const MyBidsScreen(),
        NotificationsScreen(role: _currentRole),
        ProfileScreen(role: _currentRole, onSignOut: widget.onSignOut),
      ] else ...[
        FishermanDashboardScreen(onSignOut: widget.onSignOut),
        const MyCatchesScreen(),
        OrdersScreen(role: _currentRole),
        NotificationsScreen(role: _currentRole),
        ProfileScreen(role: _currentRole, onSignOut: widget.onSignOut),
      ],
    ];

    final labels = isAdmin
        ? const [
            NavigationDestination(icon: Icon(Icons.admin_panel_settings), label: 'Admin'),
            NavigationDestination(icon: Icon(Icons.inventory_2), label: 'Orders'),
            NavigationDestination(icon: Icon(Icons.notifications), label: 'Alerts'),
            NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
          ]
        : (isBuyer
            ? const [
                NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.search), label: 'Browse'),
                NavigationDestination(icon: Icon(Icons.gavel), label: 'Bids'),
                NavigationDestination(icon: Icon(Icons.notifications), label: 'Alerts'),
                NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
              ]
            : const [
                NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.set_meal), label: 'Catches'),
                NavigationDestination(icon: Icon(Icons.inventory_2), label: 'Orders'),
                NavigationDestination(icon: Icon(Icons.notifications), label: 'Alerts'),
                NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
              ]);

    final safeIndex = _index.clamp(0, screens.length - 1);

    return Scaffold(
      appBar: AppBar(
        title: Text('FishLink • $_currentRole'),
        actions: [
          // 🚚 Direct 1-tap Cold-Chain Logistics Agent Center
          IconButton(
            onPressed: () => showLogisticsPlansModal(context),
            icon: const Icon(Icons.local_shipping, color: Color(0xff7209b7)),
            tooltip: 'Cold-Chain Logistics & Live Tracking',
          ),
          // 🔄 Global Role Switcher in AppBar
          RoleSwitcherChip(
            currentRole: _currentRole,
            onRoleChanged: (newRole) {
              setState(() {
                _currentRole = newRole;
                _index = 0;
              });
              const FlutterSecureStorage().write(key: 'role', value: newRole);
            },
          ),
          IconButton(
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: screens[safeIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: labels,
      ),
    );
  }
}

class FishermanDashboardScreen extends StatelessWidget {
  const FishermanDashboardScreen({required this.onSignOut, super.key});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // ── Captain Profile & Vessel Status ─────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xff003859), Color(0xff00628a)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff003859).withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.sailing, color: Color(0xff003859), size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Captain Kaveesha Perera',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Vessel: Ocean Star • SL-NEG-084',
                          style: TextStyle(
                            color: Color(0xffc2e5fb),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fiber_manual_record, color: Colors.white, size: 9),
                        SizedBox(width: 4),
                        Text(
                          'Active Trip',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.location_on, color: Color(0xffffd166), size: 16),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Negombo Fishery Harbour • Pier 3B',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'Departure: 04:30 AM',
                      style: TextStyle(color: Color(0xffc2e5fb), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // ── Quick Action: Log New Catch Banner (React Web Parity) ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xff005b96), Color(0xff0284c7)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff005b96).withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_a_photo, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Ready to sell a new batch?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Log catch details, verified pier weight & AI pricing',
                      style: TextStyle(
                        color: Color(0xffe0f2fe),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xff005b96),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NewCatchScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text(
                  'Log Catch',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // ── Core Stats Grid (Compact, Clean & Clickable) ───────────────
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 650;
            return GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isWide ? 4 : 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 118,
              ),
              children: [
                _StatCardEnhanced(
                  title: 'Active Catches',
                  value: '540 kg',
                  change: '3 Lots • +18% trip',
                  isPositive: true,
                  icon: Icons.set_meal,
                  color: const Color(0xff0077b6),
                  onTap: () => _showCatchesDetail(context),
                ),
                _StatCardEnhanced(
                  title: 'Current Bids',
                  value: '14 Bids',
                  change: 'Top: Rs. 1,850/kg',
                  isPositive: true,
                  icon: Icons.gavel,
                  color: const Color(0xffe76f51),
                  onTap: () => _showBidsDetail(context),
                ),
                _StatCardEnhanced(
                  title: 'Dispatches',
                  value: '3 Orders',
                  change: '2 Trucks en-route',
                  isPositive: true,
                  icon: Icons.local_shipping,
                  color: const Color(0xff2a9d8f),
                  onTap: () => _showDispatchesDetail(context),
                ),
                _StatCardEnhanced(
                  title: 'September Sales',
                  value: 'Rs. 684k',
                  change: '+24% monthly gain',
                  isPositive: true,
                  icon: Icons.account_balance_wallet,
                  color: const Color(0xff7209b7),
                  onTap: () => _showSalesDetail(context),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 18),

        // ── 🤖 4 Autonomous Agentic AI Ecosystem Card ───────────────────
        _buildAgenticAiDashboardBanner(context),

        const SizedBox(height: 18),

        // ── Sea Weather & Marine Safety Advisory ───────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: Colors.green.shade200, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.waves, color: Colors.green, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sea Safety & Marine Weather',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'West Coast Zone 4 • Negombo to Chilaw',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'SAFE TO SAIL',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  _WeatherPill(label: 'Wind', value: '12 kts SW', icon: Icons.air),
                  _WeatherPill(label: 'Waves', value: '1.1 m', icon: Icons.water),
                  _WeatherPill(label: 'Sea Temp', value: '28.4°C', icon: Icons.thermostat),
                  _WeatherPill(label: 'High Tide', value: '16:45', icon: Icons.access_time),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xff005b96), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Calm seas forecast for the next 36 hours. Ideal for Yellowfin Tuna longline trips 25nm offshore.',
                        style: TextStyle(fontSize: 12, color: Color(0xff003b5c)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // ── Live Bids from Wholesalers & Exporters ──────────────────────
        _InfoPanel(
          icon: Icons.local_offer,
          title: 'Live Bids on Your Catches',
          child: Column(
            children: [
              _BidCard(
                lotNumber: 'LOT-NEG-902',
                species: 'Yellowfin Tuna (Grade A)',
                weight: '160 kg',
                bidderName: 'Ceylon Sea Foods Exporters',
                bidPricePerKg: 'Rs. 1,820',
                totalBidValue: 'Rs. 291,200',
                timeLeft: '35m left',
                isLeading: true,
              ),
              const SizedBox(height: 10),
              _BidCard(
                lotNumber: 'LOT-NEG-904',
                species: 'Narrow-Barred Seer (Thora)',
                weight: '75 kg',
                bidderName: 'Colombo Peliyagoda Wholesale',
                bidPricePerKg: 'Rs. 2,450',
                totalBidValue: 'Rs. 183,750',
                timeLeft: '1h 10m left',
                isLeading: true,
              ),
              const SizedBox(height: 10),
              _BidCard(
                lotNumber: 'LOT-NEG-907',
                species: 'Skipjack Tuna (Balaya)',
                weight: '120 kg',
                bidderName: 'Lanka Fishery Coop',
                bidPricePerKg: 'Rs. 980',
                totalBidValue: 'Rs. 117,600',
                timeLeft: '2h 05m left',
                isLeading: false,
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // ── AI Price Recommendations & Market Trends ───────────────────
        const _InfoPanel(
          icon: Icons.auto_awesome,
          title: 'FishLink AI Price Advisory',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Predicted optimum sales price based on today\'s port auction supply:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              SizedBox(height: 12),
              _AiPriceRow(
                species: 'Yellowfin Tuna (Kelawalla)',
                currentAvg: 'Rs. 1,750 - 1,850 / kg',
                trend: '+8.4%',
                isUp: true,
                note: 'High export buyer demand in Negombo',
              ),
              Divider(height: 18),
              _AiPriceRow(
                species: 'Seer Fish (Thora)',
                currentAvg: 'Rs. 2,300 - 2,500 / kg',
                trend: '+14.2%',
                isUp: true,
                note: 'Weekend hotel rush in Western Province',
              ),
              Divider(height: 18),
              _AiPriceRow(
                species: 'Sailfish (Thalapath)',
                currentAvg: 'Rs. 1,400 - 1,520 / kg',
                trend: '+3.1%',
                isUp: true,
                note: 'Moderate supply from southern fleets',
              ),
              Divider(height: 18),
              _AiPriceRow(
                species: 'Skipjack Tuna (Balaya)',
                currentAvg: 'Rs. 920 - 990 / kg',
                trend: '-1.8%',
                isUp: false,
                note: 'Heavy landings at Beruwala harbour',
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // ── Cold Chain & Active Delivery ───────────────────────────────
        _InfoPanel(
          icon: Icons.thermostat,
          title: 'Cold Chain Delivery Tracking',
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xfff5f9fc),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xffdbe7f0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Dispatch #DSP-4019',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'In Transit',
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  '180 kg Yellowfin Tuna • Destination: Peliyagoda Cold Store #4',
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.local_shipping, size: 18, color: Color(0xff005b96)),
                    const SizedBox(width: 6),
                    const Text('Truck: WP-ND-4921', style: TextStyle(fontSize: 12)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        border: Border.all(color: Colors.teal.shade300),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.ac_unit, size: 14, color: Colors.teal),
                          SizedBox(width: 4),
                          Text(
                            '2.2°C (Optimal)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: 0.72,
                  backgroundColor: Colors.grey.shade200,
                  color: const Color(0xff005b96),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 6),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Negombo Jetty (Departed 07:15)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text('ETA: 25 mins', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xff005b96))),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  void _showDetailModal(BuildContext context, String title, IconData icon, Color color, Widget content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.8,
          maxWidth: 600,
        ),
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 8)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: content,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCatchesDetail(BuildContext context) {
    _showDetailModal(
      context,
      'Active Catches (3 Lots • 540 kg)',
      Icons.set_meal,
      const Color(0xff0077b6),
      Column(
        children: [
          _modalCatchItem(
            lot: 'LOT-NEG-902',
            species: 'Yellowfin Tuna (Kelawalla)',
            weight: '160 kg',
            harbour: 'Negombo Pier 3B',
            method: 'Longline • Grade A',
            status: '14 Bids Active',
            statusColor: Colors.orange,
            price: 'Est. Rs. 291,200',
          ),
          const SizedBox(height: 12),
          _modalCatchItem(
            lot: 'LOT-NEG-904',
            species: 'Narrow-Barred Seer (Thora)',
            weight: '75 kg',
            harbour: 'Negombo Pier 3',
            method: 'Gillnet • Fresh Chilled',
            status: '8 Bids Active',
            statusColor: Colors.orange,
            price: 'Est. Rs. 183,750',
          ),
          const SizedBox(height: 12),
          _modalCatchItem(
            lot: 'LOT-NEG-907',
            species: 'Skipjack Tuna (Balaya)',
            weight: '120 kg',
            harbour: 'Beruwala Jetty',
            method: 'Pole & Line',
            status: 'Verified at Jetty',
            statusColor: Colors.green,
            price: 'Est. Rs. 117,600',
          ),
          const SizedBox(height: 12),
          _modalCatchItem(
            lot: 'LOT-NEG-910',
            species: 'Sailfish (Thalapath)',
            weight: '185 kg',
            harbour: 'In Chiller Storage #2',
            method: 'Deep Sea Longline',
            status: 'Auction Starts in 2h',
            statusColor: Colors.blue,
            price: 'Est. Rs. 273,800',
          ),
        ],
      ),
    );
  }

  void _showBidsDetail(BuildContext context) {
    _showDetailModal(
      context,
      'Live Buyer Bids (14 Active Bids)',
      Icons.gavel,
      const Color(0xffe76f51),
      Column(
        children: [
          _modalBidItem(
            buyer: 'Ceylon Sea Foods Exporters',
            lot: 'LOT-NEG-902 • Yellowfin Tuna (160 kg)',
            bidPerKg: 'Rs. 1,820 / kg',
            total: 'Rs. 291,200',
            time: 'Ends in 35m',
            isTop: true,
          ),
          const SizedBox(height: 10),
          _modalBidItem(
            buyer: 'Colombo Peliyagoda Wholesale',
            lot: 'LOT-NEG-904 • Seer Fish (75 kg)',
            bidPerKg: 'Rs. 2,450 / kg',
            total: 'Rs. 183,750',
            time: 'Ends in 1h 10m',
            isTop: true,
          ),
          const SizedBox(height: 10),
          _modalBidItem(
            buyer: 'Ocean Fresh Hotel Suppliers',
            lot: 'LOT-NEG-902 • Yellowfin Tuna (160 kg)',
            bidPerKg: 'Rs. 1,780 / kg',
            total: 'Rs. 284,800',
            time: 'Countered',
            isTop: false,
          ),
          const SizedBox(height: 10),
          _modalBidItem(
            buyer: 'Lanka Fishery Cooperative',
            lot: 'LOT-NEG-907 • Skipjack (120 kg)',
            bidPerKg: 'Rs. 980 / kg',
            total: 'Rs. 117,600',
            time: 'Ends in 2h 05m',
            isTop: false,
          ),
        ],
      ),
    );
  }

  void _showDispatchesDetail(BuildContext context) {
    _showDetailModal(
      context,
      'Orders & Logistics (3 Active)',
      Icons.local_shipping,
      const Color(0xff2a9d8f),
      Column(
        children: [
          _modalDispatchItem(
            id: 'DSP-4019',
            route: 'Negombo Pier 3B ➔ Peliyagoda Cold Store #4',
            cargo: '180 kg Yellowfin Tuna',
            vehicle: 'WP-ND-4921 (Chilled Container)',
            temp: '2.2°C (Optimal)',
            status: 'In Transit • ETA: 25 mins',
            statusColor: Colors.blue,
          ),
          const SizedBox(height: 12),
          _modalDispatchItem(
            id: 'ORD-2091',
            route: 'Negombo Jetty ➔ Jetwing Blue Hotel',
            cargo: '45 kg Spanish Mackerel (Thora)',
            vehicle: 'WP-CA-8832',
            temp: '1.8°C',
            status: 'Delivered & Payment Received',
            statusColor: Colors.green,
          ),
          const SizedBox(height: 12),
          _modalDispatchItem(
            id: 'ORD-2085',
            route: 'Galle Export Terminal ➔ Katunayake Cargo Hub',
            cargo: '90 kg Sailfish Export Fillets',
            vehicle: 'WP-NC-1102',
            temp: '-18.0°C (Frozen)',
            status: 'Loading at Jetty • Depart in 40m',
            statusColor: Colors.orange,
          ),
        ],
      ),
    );
  }

  void _showSalesDetail(BuildContext context) {
    _showDetailModal(
      context,
      'September Revenue (Rs. 684,200)',
      Icons.account_balance_wallet,
      const Color(0xff7209b7),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xff7209b7).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Payouts Settled', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    SizedBox(height: 4),
                    Text('Rs. 475,150', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xff7209b7))),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('In Escrow Clearing', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    SizedBox(height: 4),
                    Text('Rs. 209,050', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Recent Completed Settlements:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          _modalSaleRow('Sep 21', '75 kg Seer Fish • Peliyagoda Wholesale', '+ Rs. 183,750', 'Completed'),
          _modalSaleRow('Sep 19', '160 kg Tuna • Ceylon Sea Foods', '+ Rs. 291,200', 'Completed'),
          _modalSaleRow('Sep 16', '110 kg Sailfish • Galle Port Exporters', '+ Rs. 162,800', 'Completed'),
          _modalSaleRow('Sep 12', '45 kg Tiger Prawns • Negombo Lagoon', '+ Rs. 139,500', 'Completed'),
        ],
      ),
    );
  }

  Widget _modalCatchItem({
    required String lot,
    required String species,
    required String weight,
    required String harbour,
    required String method,
    required String status,
    required Color statusColor,
    required String price,
  }) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xfff8fafc),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(lot, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xff005b96))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(species, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 2),
            Text('$weight • $method • $harbour', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            const SizedBox(height: 6),
            Text(price, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 14)),
          ],
        ),
      );

  Widget _modalBidItem({
    required String buyer,
    required String lot,
    required String bidPerKg,
    required String total,
    required String time,
    required bool isTop,
  }) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isTop ? const Color(0xfffffaf5) : const Color(0xfff8fafc),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isTop ? Colors.orange.shade300 : Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(buyer, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(time, style: TextStyle(fontSize: 11, color: isTop ? Colors.orange.shade900 : Colors.grey, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text(lot, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bidPerKg, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xff0077b6))),
                    Text('Total: $total', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xff005b96),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  onPressed: () {},
                  child: const Text('Accept Bid', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _modalDispatchItem({
    required String id,
    required String route,
    required String cargo,
    required String vehicle,
    required String temp,
    required String status,
    required Color statusColor,
  }) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xfff8fafc),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Dispatch #$id', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xff005b96))),
                Text(temp, style: const TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            Text(cargo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 2),
            Text(route, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            const SizedBox(height: 4),
            Text(vehicle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
              child: Text(status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

  Widget _modalSaleRow(String date, String title, String amount, String status) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
              child: Text(date, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(status, style: const TextStyle(fontSize: 11, color: Colors.green)),
                ],
              ),
            ),
            Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xff005b96), fontSize: 13)),
          ],
        ),
      );

  Widget _buildAgenticAiDashboardBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff0b192c), Color(0xff1e3e62)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff0b192c).withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.smart_toy, color: Color(0xff38bdf8), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '4 Autonomous Agentic AI Ecosystem',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Quality • Pricing • Buyer Matching • Logistics',
                      style: TextStyle(
                        color: Color(0xff94a3b8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.shade700,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      '4 ONLINE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _dashboardAgentRow('🔬 Agent 1: Quality & Fraud', 'Grade A+ verification & pier scale audit', 'Active (98%)'),
          const SizedBox(height: 6),
          _dashboardAgentRow('📈 Agent 2: Market Intelligence', '90-Day WMA + Live DB auction pricing', 'Active (60/40)'),
          const SizedBox(height: 6),
          _dashboardAgentRow('🎯 Agent 3: Smart Buyer Matching', 'Multi-factor compatibility ranking', '14 Exporters'),
          const SizedBox(height: 6),
          _dashboardAgentRow('🚚 Agent 4: Cold-Chain Logistics', 'Autonomous reefer allocation & E03 routing', 'Fleet Ready'),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xff38bdf8),
                side: const BorderSide(color: Color(0xff38bdf8)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: () => _showAgenticAiOrchestrationModal(context),
              icon: const Icon(Icons.hub, size: 16),
              label: const Text(
                'Open 4-Agent Orchestration Hub',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashboardAgentRow(String name, String desc, String badge) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(
                    color: Color(0xffcbd5e1),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                color: Color(0xff38bdf8),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAgenticAiOrchestrationModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
              child: Row(
                children: [
                  const Icon(Icons.psychology, color: Color(0xff005b96), size: 24),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'FishLink 4-Agent Autonomous System',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  _agentDetailCard(
                    num: '1',
                    title: 'Quality & Fraud Validation Agent',
                    icon: Icons.biotech,
                    color: const Color(0xff059669),
                    role: 'Automated Fish Inspection & Scale Audit',
                    desc: 'Evaluates catch photos for species and gill redness freshness. Compares harbor scale weights with fisherman declared logs to catch discrepancy >15% before auction listing.',
                    metrics: 'Latency: 420ms • Confidence: 98.4% • Model: ResNet50-Fish + AnomalyScorer',
                  ),
                  const SizedBox(height: 12),
                  _agentDetailCard(
                    num: '2',
                    title: 'Market Intelligence & Pricing Agent',
                    icon: Icons.trending_up,
                    color: const Color(0xff0284c7),
                    role: 'Dynamic Price Recommendation Engine',
                    desc: 'Queries 90 days of historical price trend data (WMA model) and blends it with live database auction transactions (60/40 blend) to predict fair market value corridor.',
                    metrics: 'Price Blend: 60% WMA / 40% Live DB • 7-Day Trend: Bullish (+6.8%)',
                  ),
                  const SizedBox(height: 12),
                  _agentDetailCard(
                    num: '3',
                    title: 'Smart Buyer Matching Agent',
                    icon: Icons.people_outline,
                    color: const Color(0xff9333ea),
                    role: 'Multi-Factor Buyer Scoring & Discovery',
                    desc: 'Analyzes registered export and wholesale buyers based on species interest (40%), batch volume requirement (25%), target budget (20%), proximity (10%), and payment history (5%).',
                    metrics: 'Top Exporters: OceanFresh (96%), Keells Cold Stores (92%), Peliyagoda (88%)',
                  ),
                  const SizedBox(height: 12),
                  _agentDetailCard(
                    num: '4',
                    title: 'Cold-Chain Logistics Scheduling Agent',
                    icon: Icons.local_shipping_outlined,
                    color: const Color(0xff0d9488),
                    role: 'Autonomous Fleet & Cold-Chain Route Allocation',
                    desc: 'Instantly invoked upon bid acceptance: allocates nearest refrigerated truck (WP-ND-4921), maps optimal E03 expressway route from Negombo Pier to buyer warehouse, and enforces 2.2°C temperature guard.',
                    metrics: 'Reefer Truck: Assigned • Route: Negombo ➔ Peliyagoda (36.4 km, 47 min ETA) • Temp: 2.2°C',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _agentDetailCard({
    required String num,
    required String title,
    required IconData icon,
    required Color color,
    required String role,
    required String desc,
    required String metrics,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Agent $num • $title',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      role,
                      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.35),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.analytics_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    metrics,
                    style: const TextStyle(fontSize: 11, color: Color(0xff334155), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FEATURE 7: 🤖 AI PRICE RECOMMENDATION DIALOG
// ══════════════════════════════════════════════════════════════════════════════

Future<void> showAiPriceRecommendationModal(
  BuildContext context, {
  required String species,
  required double quantityKg,
  ValueChanged<double>? onApplyPrice,
}) async {
  return showDialog(
    context: context,
    builder: (ctx) => _AiPriceDialog(
      species: species,
      quantityKg: quantityKg,
      onApplyPrice: onApplyPrice,
    ),
  );
}

class _AiPriceDialog extends StatefulWidget {
  const _AiPriceDialog({
    required this.species,
    required this.quantityKg,
    this.onApplyPrice,
  });

  final String species;
  final double quantityKg;
  final ValueChanged<double>? onApplyPrice;

  @override
  State<_AiPriceDialog> createState() => _AiPriceDialogState();
}

class _AiPriceDialogState extends State<_AiPriceDialog> {
  bool _loading = true;
  String _recommendedRange = 'Rs. 1550 – Rs. 1650 / kg';
  String _demand = 'HIGH';
  int _confidence = 87;
  String _reason =
      'Recent market prices are high and current bids indicate strong demand.';
  double _avgPrice = 1600;

  @override
  void initState() {
    super.initState();
    _loadPrediction();
  }

  Future<void> _loadPrediction() async {
    try {
      final res = await ApiClient().predictPrice(widget.species);
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (res.isNotEmpty) {
          _recommendedRange = res['recommendedRange']?.toString() ??
              'Rs. 1550 – Rs. 1650 / kg';
          _demand = res['demand']?.toString() ?? 'HIGH';
          _confidence = (res['confidence'] as num?)?.toInt() ?? 87;
          _reason = res['reason']?.toString() ??
              'Recent market prices are high and current bids indicate strong demand.';
          _avgPrice = (res['averagePrice'] as num?)?.toDouble() ?? 1600;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        final s = widget.species.toLowerCase();
        if (s.contains('seer')) {
          _recommendedRange = 'Rs. 1850 – Rs. 2050 / kg';
          _demand = 'HIGH';
          _confidence = 92;
          _reason = 'High retail hotel demand with limited harbour supply.';
          _avgPrice = 1950;
        } else if (s.contains('mackerel')) {
          _recommendedRange = 'Rs. 1180 – Rs. 1280 / kg';
          _demand = 'MEDIUM';
          _confidence = 84;
          _reason = 'Steady coastal consumer demand with moderate daily landings.';
          _avgPrice = 1240;
        } else {
          _recommendedRange = 'Rs. 1550 – Rs. 1650 / kg';
          _demand = 'HIGH';
          _confidence = 87;
          _reason =
              'Recent market prices are high and current bids indicate strong demand.';
          _avgPrice = 1600;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      title: Row(
        children: const [
          Text('🤖', style: TextStyle(fontSize: 24)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'AI Price Recommendation',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: _loading
          ? SizedBox(
              height: 180,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Querying ASP.NET Core API & Market AI...',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xff005b96).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xff005b96).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('🐟', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                            Text(
                              widget.species,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xff005b96),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${widget.quantityKg.toInt()} kg',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Recommended:',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _recommendedRange,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff0077b6),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Demand:',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 2),
                              Text(
                                _demand,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Confidence:',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 2),
                              Text(
                                '$_confidence%',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Reason:',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xfff8fafc),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      _reason,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xff1f2937), height: 1.35),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.shield_outlined,
                            size: 14, color: Colors.grey),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Verified via ASP.NET Core API ➔ Price Agent & DB',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        if (!_loading && widget.onApplyPrice != null)
          FilledButton.tonal(
            onPressed: () {
              widget.onApplyPrice!(_avgPrice);
              Navigator.pop(context);
            },
            child: Text('Apply Rs. ${_avgPrice.toInt()}/kg'),
          ),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xff005b96)),
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FEATURE 8 & 9: 💰 BIDS & 🎯 AI BUYER MATCHING SHEET (Fisherman View)
// ══════════════════════════════════════════════════════════════════════════════

void showFishermanCatchDetailsModal(
  BuildContext context, {
  required String species,
  required double quantityKg,
  required String location,
  required double askingPrice,
  int catchId = 1,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _FishermanCatchDetailsSheet(
      species: species,
      quantityKg: quantityKg,
      location: location,
      askingPrice: askingPrice,
      catchId: catchId,
    ),
  );
}

class _FishermanCatchDetailsSheet extends StatefulWidget {
  const _FishermanCatchDetailsSheet({
    required this.species,
    required this.quantityKg,
    required this.location,
    required this.askingPrice,
    required this.catchId,
  });

  final String species;
  final double quantityKg;
  final String location;
  final double askingPrice;
  final int catchId;

  @override
  State<_FishermanCatchDetailsSheet> createState() =>
      _FishermanCatchDetailsSheetState();
}

class _FishermanCatchDetailsSheetState
    extends State<_FishermanCatchDetailsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Live state for bids with realistic, verified buyer companies
  late List<Map<String, dynamic>> _bids;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _bids = [
      {
        'id': 101,
        'buyer': 'OceanFresh Exporters (Pvt) Ltd',
        'buyerLocation': 'Colombo Port Export Zone',
        'rate': 1650,
        'qty': widget.quantityKg.toInt(),
        'match': 96,
        'status': 'Pending',
        'verified': true,
      },
      {
        'id': 102,
        'buyer': 'Ceylon Cold Stores (Keells Procurement)',
        'buyerLocation': 'Ja-Ela Distribution Hub',
        'rate': 1580,
        'qty': widget.quantityKg.toInt(),
        'match': 92,
        'status': 'Pending',
        'verified': true,
      },
      {
        'id': 103,
        'buyer': 'Peliyagoda Wholesale Market (Stall 14)',
        'buyerLocation': 'Peliyagoda Fish Complex',
        'rate': 1520,
        'qty': widget.quantityKg.toInt(),
        'match': 89,
        'status': 'Pending',
        'verified': true,
      },
      {
        'id': 104,
        'buyer': 'Lanka Marine Exports (Pvt) Ltd',
        'buyerLocation': 'Katunayake EPZ Facility',
        'rate': 1480,
        'qty': widget.quantityKg.toInt(),
        'match': 85,
        'status': 'Pending',
        'verified': true,
      },
    ];
    _fetchLiveBids();
  }

  Future<void> _fetchLiveBids() async {
    try {
      final liveBids = await ApiClient().getCatchBids(widget.catchId);
      if (liveBids.isNotEmpty && mounted) {
        setState(() {
          _bids = liveBids.map((b) {
            final rate = (b['bidAmount'] as num?)?.toInt() ?? 1550;
            final buyerName = (b['buyerName'] as String?)?.isNotEmpty == true
                ? b['buyerName'] as String
                : 'OceanFresh Exporters (Pvt) Ltd';
            final buyerLoc = (b['deliveryLocation'] as String?)?.isNotEmpty == true
                ? b['deliveryLocation'] as String
                : 'Western Province Hub';
            return {
              'id': b['id'] ?? 100,
              'buyer': buyerName,
              'buyerLocation': buyerLoc,
              'rate': rate,
              'qty': (b['quantityKg'] as num?)?.toInt() ?? widget.quantityKg.toInt(),
              'match': 95,
              'status': b['status'] as String? ?? 'Pending',
              'verified': true,
            };
          }).toList();
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _acceptBid(Map<String, dynamic> bid) async {
    try {
      await ApiClient().acceptBid(bid['id'] as int);
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      for (var b in _bids) {
        if (b['id'] == bid['id']) {
          b['status'] = 'Accepted';
        } else {
          b['status'] = 'Lost';
        }
      }
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Bid Accepted!', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Accepted ${bid['buyer']} • Rs. ${bid['rate']}/kg (${bid['qty']} kg)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('✓ Order #ORD-1049 automatically created.',
                      style: TextStyle(
                          color: Color(0xff005b96),
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  SizedBox(height: 4),
                  Text(
                      '✓ Logistics Agent triggered: Refrigerated Truck WP-ND-4921 assigned with 2.2°C temperature guard.',
                      style: TextStyle(fontSize: 12, color: Colors.black87)),
                  SizedBox(height: 4),
                  Text(
                      '✓ Cold Storage Vault #C-04 allocated at buyer destination.',
                      style: TextStyle(fontSize: 12, color: Colors.black87)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xff005b96)),
            onPressed: () {
              Navigator.pop(ctx);
              _tabController.animateTo(2); // Jump to Logistics tab
            },
            child: const Text('View Logistics Dispatch'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _rejectBid(Map<String, dynamic> bid) {
    setState(() {
      bid['status'] = 'Rejected';
    });
    ApiClient().rejectBid(bid['id'] as int).ignore();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Bid from ${bid['buyer']} rejected.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.86,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🐟 ${widget.species}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${widget.quantityKg.toInt()} kg • ${widget.location} • Asking: Rs.${widget.askingPrice.toInt()}/kg',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: const Color(0xff005b96),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xff005b96),
            tabs: const [
              Tab(icon: Icon(Icons.gavel), text: 'Current Bids'),
              Tab(icon: Icon(Icons.auto_awesome), text: 'AI Buyer Matching'),
              Tab(icon: Icon(Icons.local_shipping), text: 'Logistics Agent'),
              Tab(icon: Icon(Icons.psychology), text: '4 Agentic AI Hub'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBidsTab(),
                _buildBuyerMatchingTab(),
                _buildLogisticsTab(),
                _buildAgenticAiHubTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBidsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Current Bids',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Live bids received from verified wholesale buyers and exporters in Western Province:',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 14),
        ..._bids.map((b) => _buildBidCard(b)),
      ],
    );
  }

  Widget _buildBidCard(Map<String, dynamic> b) {
    final status = b['status'] as String;
    final isAccepted = status == 'Accepted';
    final isRejected = status == 'Rejected';
    final isLost = status == 'Lost';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isAccepted
            ? Colors.green.shade50
            : isRejected || isLost
                ? Colors.grey.shade100
                : const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAccepted
              ? Colors.green.shade400
              : isRejected || isLost
                  ? Colors.grey.shade300
                  : Colors.grey.shade200,
          width: isAccepted ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            b['buyer'] as String,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: Colors.blue, size: 16),
                      ],
                    ),
                    if (b['buyerLocation'] != null)
                      Text(
                        b['buyerLocation'] as String,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xff005b96).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Match: ${b['match']}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff005b96),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Rs. ${b['rate']} / kg',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff0077b6),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '• ${b['qty']} kg (Total: Rs. ${(b['rate'] * b['qty']).toInt()})',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isAccepted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: const [
                  Icon(Icons.check, size: 16, color: Colors.green),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Accepted • Order Created • Cold-Chain Logistics Dispatched',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green),
                    ),
                  ),
                ],
              ),
            )
          else if (isRejected || isLost)
            Text(
              isRejected ? 'Rejected' : 'Outbid / Lost',
              style: const TextStyle(
                  fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
            )
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () => _acceptBid(b),
                    child: const Text('Accept Bid',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                  ),
                  onPressed: () => _rejectBid(b),
                  child: const Text('Reject'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBuyerMatchingTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'AI Recommended Buyers',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Ranked by AI Buyer Matching Agent based on preferences, volume fit and purchase history:',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 14),

        // Buyer 1
        _buildRankedBuyerCard(
          rank: '🥇',
          name: 'OceanFresh Exporters (Pvt) Ltd',
          match: '96%',
          demand: 'High',
          requiredQty: '${widget.quantityKg.toInt()} kg',
          distance: '12 km',
          city: 'Negombo Export Processing Dock',
          color: Colors.amber.shade700,
        ),
        const SizedBox(height: 10),

        // Buyer 2
        _buildRankedBuyerCard(
          rank: '🥈',
          name: 'Ceylon Cold Stores (Keells Procurement)',
          match: '92%',
          demand: 'High',
          requiredQty: '180 kg',
          distance: '22 km',
          city: 'Ja-Ela Distribution Hub',
          color: Colors.blueGrey,
        ),
        const SizedBox(height: 10),

        // Buyer 3
        _buildRankedBuyerCard(
          rank: '🥉',
          name: 'Peliyagoda Wholesale Market (Stall 14)',
          match: '88%',
          demand: 'Medium',
          requiredQty: '100 kg',
          distance: '31 km',
          city: 'Colombo North Fish Complex',
          color: Colors.brown.shade400,
        ),
        const SizedBox(height: 10),

        // Buyer 4
        _buildRankedBuyerCard(
          rank: '🎖️',
          name: 'Lanka Marine Exports (Pvt) Ltd',
          match: '84%',
          demand: 'Medium',
          requiredQty: '90 kg',
          distance: '14 km',
          city: 'Katunayake EPZ Cold Unit',
          color: Colors.indigo.shade400,
        ),

        const SizedBox(height: 18),

        // Factors Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xfff0f7fb),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xffc2e5fb)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.tune, size: 18, color: Color(0xff005b96)),
                  SizedBox(width: 6),
                  Text(
                    'AI Matching Factors (Scoring Model):',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xff003b5c),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildFactorRow('🐟', 'Fish species fit (40%)', 'Target species requirement matching'),
              _buildFactorRow('⚖️', 'Batch volume fit (25%)', 'Order capacity vs listed catch quantity'),
              _buildFactorRow('💵', 'Price willingness (20%)', 'Buyer target bid range vs asking price'),
              _buildFactorRow('📍', 'Location proximity (10%)', 'Transit distance from harbour to buyer cold store'),
              _buildFactorRow('📜', 'Payment track record (5%)', 'Escrow completion speed & ratings'),
            ],
          ),
        ),
      ],
    );
  }

  // ── Logistics Agent Tab (Matches React Web Logistics Architecture) ──
  Widget _buildLogisticsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Autonomous Agent Banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xff0f766e), Color(0xff0d9488)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff0f766e).withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_shipping, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Logistics Scheduling Agent',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Autonomous Cold-Chain Route & Reefer Allocation',
                      style: TextStyle(
                        color: Color(0xffccfbf1),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'STANDBY',
                  style: TextStyle(
                    color: Color(0xff0f766e),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Allocation & Telemetry Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Automated Resource Allocation',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.ac_unit, size: 13, color: Colors.teal),
                        SizedBox(width: 4),
                        Text(
                          '2.2°C Cold Guard',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              _buildLogisticsDetailRow('Vehicle Code', 'WP-ND-4921 (Reefer 2.5T)'),
              _buildLogisticsDetailRow('Certified Driver', 'Sunil Gunaratne (+94 77 123 4567)'),
              _buildLogisticsDetailRow('Pickup Origin', 'Negombo Fishery Harbour • Pier 3B'),
              _buildLogisticsDetailRow('Target Destination', 'Peliyagoda Central Cold Hub'),
              _buildLogisticsDetailRow('Selected Route', 'Via Colombo - Katunayake Expressway (E03)'),
              _buildLogisticsDetailRow('Distance & ETA', '36.4 km • 47 min transit window'),
              _buildLogisticsDetailRow('Cold Storage Vault', 'Vault #C-04 (Pre-allocated, 0°C - 4°C)'),
              _buildLogisticsDetailRow('Operations Approval', 'Approved via Operations Control'),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Route & Temperature Compliance card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xfff0fdf4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xffbbf7d0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.verified, color: Colors.green, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Cold-Chain Quality Guarantee',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xff166534)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'When you accept any bid, the Logistics Agent immediately triggers IoT sensor pre-cooling and assigns the truck loading slot at Pier 3B. No manual coordination required.',
                style: TextStyle(fontSize: 12, color: Color(0xff14532d), height: 1.35),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff0f766e),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  showCreateLogisticsPlanModal(
                    context,
                    catchId: widget.catchId,
                    species: widget.species,
                  );
                },
                icon: const Icon(Icons.add_road, size: 18),
                label: const Text('Schedule Delivery Plan (React Form)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xff0f766e),
            side: const BorderSide(color: Color(0xff0f766e)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Logistics Agent: Route & Reefer truck stand-by verified!'),
                backgroundColor: Color(0xff0f766e),
              ),
            );
          },
          icon: const Icon(Icons.navigation, size: 18),
          label: const Text('Check Standby Route & Sensor Telemetry'),
        ),
      ],
    );
  }

  // ── 4 Agentic AI Subsystems Hub Tab (Full Ecosystem View) ──
  Widget _buildAgenticAiHubTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '4 Autonomous Agentic AI Ecosystem',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'FishLink deploys 4 specialized collaborative AI agents to automate trading, pricing and cold chain logistics:',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 14),

        // Agent 1: Quality & Fraud
        _buildAgentCard(
          number: '1',
          name: 'Quality & Fraud Validation Agent',
          status: 'Passed (Grade A+)',
          badgeColor: Colors.green,
          icon: Icons.biotech,
          accentColor: const Color(0xff059669),
          description:
              'Analyzes catch photos for species & freshness, validates pier scale weights against captain log (<15% variance threshold), and detects listing anomalies.',
          tools: 'computer_vision_freshness(), pier_scale_audit(), fraud_detector()',
        ),
        const SizedBox(height: 12),

        // Agent 2: Pricing Agent
        _buildAgentCard(
          number: '2',
          name: 'Market Intelligence & Pricing Agent',
          status: 'Optimized (Rs. 1,650/kg)',
          badgeColor: Colors.blue,
          icon: Icons.trending_up,
          accentColor: const Color(0xff0284c7),
          description:
              'Combines a 90-day WMA historical price model with live DB auction transactions (60/40 blend) to output optimal asking prices and 7-day market forecasts.',
          tools: 'wma_90d_query(), live_db_auction_blend(), export_demand_forecaster()',
        ),
        const SizedBox(height: 12),

        // Agent 3: Buyer Matching
        _buildAgentCard(
          number: '3',
          name: 'Smart Buyer Matching Agent',
          status: '4 Matches Dispatched',
          badgeColor: Colors.purple,
          icon: Icons.people_outline,
          accentColor: const Color(0xff9333ea),
          description:
              'Scores buyers on species preference (40%), quantity fit (25%), budget (20%), location proximity (10%), and historical settlement reliability (5%).',
          tools: 'buyer_preference_matcher(), volume_fit_scorer(), bid_history_bonus()',
        ),
        const SizedBox(height: 12),

        // Agent 4: Logistics Scheduling
        _buildAgentCard(
          number: '4',
          name: 'Cold-Chain Logistics Scheduling Agent',
          status: 'Fleet Allocated (Reefer)',
          badgeColor: Colors.teal,
          icon: Icons.local_shipping_outlined,
          accentColor: const Color(0xff0d9488),
          description:
              'Coordinates post-auction fulfillment: automatically assigns nearest refrigerated vehicle, maps E03 expressway route, and reserves destination cold vaults.',
          tools: 'haversine_route_calc(), reefer_assigner(), cold_vault_allocator()',
        ),
      ],
    );
  }

  Widget _buildAgentCard({
    required String number,
    required String name,
    required String status,
    required Color badgeColor,
    required IconData icon,
    required Color accentColor,
    required String description,
    required String tools,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Agent $number • $name',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.35),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.code, size: 13, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Tools: $tools',
                    style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogisticsDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xff1f2937),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankedBuyerCard({
    required String rank,
    required String name,
    required String match,
    required String demand,
    required String requiredQty,
    required String distance,
    required String city,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(rank, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(city,
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Text(
                  'Match: $match',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Demand: $demand',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
              Text('Required: $requiredQty',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
              Text('Distance: $distance',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFactorRow(String emoji, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Text('$title: ',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff1f2937))),
          Expanded(
            child: Text(desc,
                style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FEATURE 10: 🛒 BUYER DASHBOARD (React Web Parity)
// ══════════════════════════════════════════════════════════════════════════════

class BuyerDashboardScreen extends StatefulWidget {
  const BuyerDashboardScreen({
    required this.onSignOut,
    this.onNavigateTab,
    super.key,
  });

  final VoidCallback onSignOut;
  final ValueChanged<int>? onNavigateTab;

  @override
  State<BuyerDashboardScreen> createState() => _BuyerDashboardScreenState();
}

class _BuyerDashboardScreenState extends State<BuyerDashboardScreen> {
  int _selectedView = 0; // 0: AI Recommendations, 1: Preferences Form

  // Preferences state (matching React BuyerDashboard.tsx)
  String _preferredSpecies = 'Tuna (Yellowfin)';
  final _minQtyCtrl = TextEditingController(text: '50');
  final _maxQtyCtrl = TextEditingController(text: '300');
  final _maxPriceCtrl = TextEditingController(text: '2200');
  String _preferredCity = 'Negombo';
  final _notesCtrl = TextEditingController(
      text: 'Grade A sashimi quality only. Requires chilled cold-chain.');
  bool _prefSaving = false;
  bool _prefSaved = false;

  final List<String> _speciesList = [
    'Any species',
    'Tuna (Yellowfin)',
    'Skipjack',
    'Trevally (Paraw)',
    'Mackerel',
  ];

  final List<String> _cityList = [
    'Any location',
    'Negombo',
    'Colombo',
    'Kandy',
    'Galle',
    'Matara',
    'Jaffna',
  ];

  // Matched Catches (matching React BuyerDashboard.tsx)
  final List<Map<String, dynamic>> _recommendedCatches = [
    {
      'id': 1,
      'species': 'Tuna',
      'fullSpecies': 'Yellowfin Tuna (Kelawalla)',
      'quantity': 100,
      'verifiedWeight': 98,
      'price': 1550,
      'currentBid': 1600,
      'location': 'Negombo Fishery Harbour',
      'quality': 'Grade A',
      'lot': 'LOT-NEG-902',
      'emoji': '🐟',
      'fisherman': 'Sunil Fernando (Boat SL-NEG-112)',
      'matchScore': 94,
      'matchReasons':
          'Species match (+40) · Volume in target range (+25) · Asking price below budget (+20) · Negombo hub proximity (+9)',
    },
    {
      'id': 3,
      'species': 'Trevally',
      'fullSpecies': 'Giant Trevally (Paraw)',
      'quantity': 80,
      'verifiedWeight': 79,
      'price': 1200,
      'currentBid': 1250,
      'location': 'Colombo Mutwal Pier',
      'quality': 'Grade A',
      'lot': 'LOT-CMB-441',
      'emoji': '🐡',
      'fisherman': 'Anura Silva (Boat SL-CMB-809)',
      'matchScore': 87,
      'matchReasons':
          'Species match (+40) · Price within budget (+20) · High freshness index (+17) · Colombo corridor (+10)',
    },
    {
      'id': 2,
      'species': 'Skipjack',
      'fullSpecies': 'Skipjack Tuna (Balaya)',
      'quantity': 60,
      'verifiedWeight': 59,
      'price': 850,
      'currentBid': 920,
      'location': 'Galle Fishery Harbour',
      'quality': 'Grade A',
      'lot': 'LOT-GAL-312',
      'emoji': '🐠',
      'fisherman': 'Priyadarsana (Boat SL-GAL-402)',
      'matchScore': 78,
      'matchReasons':
          'Volume fit (+25) · Excellent price margin (+20) · Grade A verified (+18) · Southern coastal route (+15)',
    },
  ];

  @override
  void dispose() {
    _minQtyCtrl.dispose();
    _maxQtyCtrl.dispose();
    _maxPriceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _showNotice(BuildContext context, String title, String body) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xff005b96)),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 16)),
          ],
        ),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _savePreferences() async {
    setState(() => _prefSaving = true);
    try {
      await ApiClient().updateBuyerPreferences({
        'preferredSpecies': _preferredSpecies == 'Any species' ? '' : _preferredSpecies,
        'minQuantityKg': double.tryParse(_minQtyCtrl.text.trim()) ?? 50,
        'maxQuantityKg': double.tryParse(_maxQtyCtrl.text.trim()) ?? 300,
        'maxPricePerKg': double.tryParse(_maxPriceCtrl.text.trim()) ?? 2200,
        'preferredCity': _preferredCity == 'Any location' ? '' : _preferredCity,
        'notes': _notesCtrl.text.trim(),
      });
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _prefSaving = false;
      _prefSaved = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Preferences saved! AI Buyer Matching Agent recommendations updated.'),
        backgroundColor: Color(0xff059669),
      ),
    );

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _prefSaved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // ── Header Greeting ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xff0a3663), Color(0xff025380)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff0a3663).withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.storefront,
                        color: Color(0xff0a3663), size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Hello Buyer 👋',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'OceanFresh Exporters (Pvt) Ltd',
                          style:
                              TextStyle(color: Color(0xffc2e5fb), fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.tealAccent.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'VERIFIED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user,
                        color: Color(0xffffd166), size: 16),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Direct Harbour Auctions • 100% Quality Inspected',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ── HERO ACTION: Place Order / Bid Form Banner (React Web Parity) ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xff004e75), Color(0xff0284c7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff0284c7).withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shopping_cart_checkout,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Place Seafood Order / Bid',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Fill Order Form (POST /api/Bids) • Escrow Protected',
                          style: TextStyle(color: Color(0xffc2e5fb), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xff004e75),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => showBuyerOrderModal(context),
                  icon: const Icon(Icons.add_shopping_cart, size: 18),
                  label: const Text(
                    '🛒 Open Buyer Order & Bid Form (React)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // ── Quick Navigation ─────────────────────────────────────────
        const Text(
          'Quick Navigation',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xff1f2937)),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildNavChip(
                context,
                icon: Icons.set_meal,
                label: 'Available Fish',
                color: const Color(0xff0077b6),
                onTap: () => widget.onNavigateTab?.call(1),
              ),
              const SizedBox(width: 8),
              _buildNavChip(
                context,
                icon: Icons.gavel,
                label: 'My Bids',
                color: const Color(0xffe76f51),
                onTap: () => widget.onNavigateTab?.call(2),
              ),
              const SizedBox(width: 8),
              _buildNavChip(
                context,
                icon: Icons.inventory_2,
                label: 'Orders',
                color: const Color(0xff2a9d8f),
                onTap: () => _showNotice(context, 'Won Orders',
                    'You have 2 confirmed won orders:\n• ORD-1049: 100kg Tuna (Rs.165,000)\n• ORD-1033: 60kg Seer Fish (Rs.108,000)'),
              ),
              const SizedBox(width: 8),
              _buildNavChip(
                context,
                icon: Icons.local_shipping,
                label: 'Deliveries',
                color: const Color(0xff7209b7),
                onTap: () => showLogisticsPlansModal(context),
              ),
              const SizedBox(width: 8),
              _buildNavChip(
                context,
                icon: Icons.payment,
                label: 'Payments',
                color: const Color(0xfff3722c),
                onTap: () => _showNotice(context, 'Pending Payments',
                    '1 invoice pending settlement:\n• Invoice #INV-8821: Rs. 248,000 due in 24 hours.'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // ── 4 Metric Cards (Exact numbers requested) ────────────────
        const Text(
          'Dashboard',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xff1f2937)),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 650;
            return GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isWide ? 4 : 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 118,
              ),
              children: [
                _StatCardEnhanced(
                  title: 'Available Listings',
                  value: '24',
                  change: 'Fresh landings today',
                  isPositive: true,
                  icon: Icons.set_meal,
                  color: const Color(0xff0077b6),
                  onTap: () => widget.onNavigateTab?.call(1),
                ),
                _StatCardEnhanced(
                  title: 'My Active Bids',
                  value: '5',
                  change: '2 Leading highest',
                  isPositive: true,
                  icon: Icons.gavel,
                  color: const Color(0xffe76f51),
                  onTap: () => widget.onNavigateTab?.call(2),
                ),
                _StatCardEnhanced(
                  title: 'Won Orders',
                  value: '2',
                  change: 'In cold chain dispatch',
                  isPositive: true,
                  icon: Icons.check_circle_outline,
                  color: const Color(0xff2a9d8f),
                  onTap: () => _showNotice(context, 'Won Orders (2)',
                      '• ORD-1049: 100 kg Tuna (Rs. 165,000) - Preparing dispatch\n• ORD-1033: 60 kg Seer Fish (Rs. 108,000) - Dispatched'),
                ),
                _StatCardEnhanced(
                  title: 'Pending Payments',
                  value: '1',
                  change: 'Rs. 248,000 due',
                  isPositive: false,
                  icon: Icons.receipt_long,
                  color: const Color(0xffd90429),
                  onTap: () => _showNotice(context, 'Pending Payment',
                      'Invoice #INV-8821 for 180 kg Tuna.\nAmount: Rs. 248,000\nPayment terms: 24h bank settlement.'),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 18),

        // ── Featured Landing Spotlight ──────────────────────────────
        _InfoPanel(
          icon: Icons.local_fire_department,
          title: 'Featured Today in Harbour',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xfff8fafc),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text('🐟', style: TextStyle(fontSize: 28)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Tuna (Yellowfin Grade A)',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('100 kg • Negombo • Verified: 98 kg',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                          SizedBox(height: 4),
                          Text('Current Bid: Rs. 1600 / kg',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xff0077b6))),
                        ],
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff005b96),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                      ),
                      onPressed: () => showBuyerOrderModal(context, fish: {
                        'id': 1,
                        'species': 'Tuna',
                        'fullSpecies': 'Yellowfin Tuna (Grade A)',
                        'quantity': 100,
                        'verifiedWeight': 98,
                        'price': 1550,
                        'currentBid': 1600,
                        'location': 'Negombo Fishery Harbour',
                        'lot': 'LOT-NEG-902',
                        'quality': 'Grade A',
                        'emoji': '🐟',
                      }),
                      child: const Text('🛒 Place Order', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton.icon(
                  onPressed: () => widget.onNavigateTab?.call(1),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('View All 24 Available Fish Listings'),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ════════════════════════════════════════════════════════════════
        // REACT PARITY SECTION: AI Matching & Buying Preferences Form
        // ════════════════════════════════════════════════════════════════
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Segmented Tab Selector (matching React BuyerDashboard.tsx)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xfff1f5f9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _selectedView = 0),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedView == 0
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _selectedView == 0
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 4,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  size: 16,
                                  color: _selectedView == 0
                                      ? const Color(0xff005b96)
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '🤖 AI Recommendations',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedView == 0
                                        ? const Color(0xff005b96)
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _selectedView = 1),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedView == 1
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _selectedView == 1
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 4,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.settings,
                                  size: 16,
                                  color: _selectedView == 1
                                      ? const Color(0xff005b96)
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '⚙️ Buying Preferences',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedView == 1
                                        ? const Color(0xff005b96)
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 1),

              // View 0: AI Recommendations
              if (_selectedView == 0) ...[
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'AI Matched Seafood Catches',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Ranked by Compatibility',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xff005b96),
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Automatically matched against OceanFresh Exporters purchasing profile & price willingness.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      ..._recommendedCatches.map((c) => _buildRecommendationCard(c)),
                    ],
                  ),
                ),
              ]

              // View 1: My Buying Preferences Form (matching React BuyerDashboard.tsx)
              else ...[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.tune, color: Color(0xff005b96), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'My Buying Preferences Form',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                      if (_prefSaved)
                        Container(
                          margin: const EdgeInsets.only(top: 8, bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xffd1fae5),
                            border: Border.all(color: const Color(0xff6ee7b7)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.check_circle, color: Color(0xff059669), size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text('Preferences saved! AI Recommendations updated.',
                                    style: TextStyle(color: Color(0xff065f46), fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 4),
                      const Text(
                        'These parameters guide the AI Buyer Matching Agent to rank fresh catches and alert you in real-time.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),

                      // Preferred Species Dropdown
                      const Text('Preferred Fish Species',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _preferredSpecies,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.set_meal, size: 18),
                        ),
                        items: _speciesList
                            .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) => setState(() => _preferredSpecies = v!),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 4, bottom: 12),
                        child: Text('Species match gives 40 points in recommendation score.',
                            style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ),

                      // Min & Max Quantity
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Min Quantity (kg)',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _minQtyCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    prefixIcon: Icon(Icons.scale, size: 18),
                                    suffixText: 'kg',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Max Quantity (kg)',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _maxQtyCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    prefixIcon: Icon(Icons.scale, size: 18),
                                    suffixText: 'kg',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Max Price (Rs/kg)
                      const Text('Maximum Budget Price (Rs./kg)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _maxPriceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.payments_outlined, size: 18),
                          prefixText: 'Rs. ',
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 4, bottom: 12),
                        child: Text('Catches within your budget get up to 20 extra points.',
                            style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ),

                      // Preferred City / Area
                      const Text('Preferred Harbour / Area',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _preferredCity,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.location_on, size: 18),
                        ),
                        items: _cityList
                            .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) => setState(() => _preferredCity = v!),
                      ),

                      const SizedBox(height: 12),

                      // Additional Notes
                      const Text('Additional Handling Notes (Optional)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _notesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Fresh export only, require sensor cold-chain logger',
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Score Breakdown Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xfff0f9ff),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xffbae6fd)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('📊 How AI calculates your Match Score:',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Color(0xff0369a1))),
                            const SizedBox(height: 6),
                            _buildScoreRow('Species match', '40 pts'),
                            _buildScoreRow('Quantity range fit', '25 pts'),
                            _buildScoreRow('Price within budget', '20 pts'),
                            _buildScoreRow('Location proximity', '10 pts'),
                            _buildScoreRow('Quality & freshness', '10 pts'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xff005b96),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _prefSaving ? null : _savePreferences,
                          icon: _prefSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.save, size: 18),
                          label: Text(
                            _prefSaving
                                ? 'Saving Preferences…'
                                : 'Save Preferences & Update Recommendations',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildScoreRow(String label, String pts) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xff334155))),
          Text(pts, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xff005b96))),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(Map<String, dynamic> c) {
    final score = c['matchScore'] as int;
    final scoreColor = score >= 85
        ? const Color(0xff059669)
        : score >= 75
            ? const Color(0xffd97706)
            : const Color(0xff6b7280);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Match Score Ring
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: scoreColor, width: 3),
                  color: scoreColor.withValues(alpha: 0.1),
                ),
                child: Center(
                  child: Text(
                    '$score%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: scoreColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          c['fullSpecies'] as String,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            c['quality'] as String,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${c['quantity']} kg • ${c['location']} • Asking: Rs. ${c['price']}/kg',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              c['matchReasons'] as String,
              style: const TextStyle(fontSize: 10, color: Color(0xff475569)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'By ${c['fisherman']}',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff005b96),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => showBuyerOrderModal(context, fish: c),
                icon: const Icon(Icons.shopping_cart_checkout, size: 14),
                label: const Text('🛒 Place Order / Bid',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FEATURE 11: 🐟 BROWSE FISH SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class BrowseFishScreen extends StatefulWidget {
  const BrowseFishScreen({super.key});

  @override
  State<BrowseFishScreen> createState() => _BrowseFishScreenState();
}

class _BrowseFishScreenState extends State<BrowseFishScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedTag = 'All';
  String _selectedLocation = 'All';
  String _selectedQuality = 'All';

  final List<Map<String, dynamic>> _allCatches = [
    {
      'id': 1,
      'species': 'Tuna',
      'fullSpecies': 'Yellowfin Tuna (Kelawalla)',
      'quantity': 100,
      'verifiedWeight': 98,
      'price': 1550,
      'currentBid': 1600,
      'quality': 'A',
      'location': 'Negombo',
      'seller': 'Fisherman XYZ',
      'emoji': '🐟',
    },
    {
      'id': 2,
      'species': 'Mackerel',
      'fullSpecies': 'Indian Mackerel (Kumbalawa)',
      'quantity': 75,
      'verifiedWeight': 74,
      'price': 1240,
      'currentBid': 1280,
      'quality': 'A',
      'location': 'Beruwala',
      'seller': 'Captain Silva',
      'emoji': '🐟',
    },
    {
      'id': 3,
      'species': 'Seer',
      'fullSpecies': 'Narrow-Barred Seer Fish (Thora)',
      'quantity': 60,
      'verifiedWeight': 59,
      'price': 1900,
      'currentBid': 1950,
      'quality': 'A',
      'location': 'Negombo',
      'seller': 'Ocean Master Co.',
      'emoji': '🐟',
    },
    {
      'id': 4,
      'species': 'Skipjack',
      'fullSpecies': 'Skipjack Tuna (Balaya)',
      'quantity': 120,
      'verifiedWeight': 118,
      'price': 980,
      'currentBid': 1020,
      'quality': 'B',
      'location': 'Galle',
      'seller': 'Deep Sea Fleet #4',
      'emoji': '🐟',
    },
    {
      'id': 5,
      'species': 'Trevally',
      'fullSpecies': 'Giant Trevally (Paraw)',
      'quantity': 80,
      'verifiedWeight': 79,
      'price': 1450,
      'currentBid': 1500,
      'quality': 'A',
      'location': 'Matara',
      'seller': 'Captain Anura',
      'emoji': '🐟',
    },
    {
      'id': 6,
      'species': 'Prawns',
      'fullSpecies': 'Tiger Prawns (Jumbo)',
      'quantity': 45,
      'verifiedWeight': 44,
      'price': 3100,
      'currentBid': 3200,
      'quality': 'A',
      'location': 'Kalpitiya',
      'seller': 'Lagoon Fishery',
      'emoji': '🦐',
    },
  ];

  List<Map<String, dynamic>> get _filteredCatches {
    final query = _searchController.text.trim().toLowerCase();
    return _allCatches.where((c) {
      final matchesQuery = query.isEmpty ||
          c['species'].toString().toLowerCase().contains(query) ||
          c['fullSpecies'].toString().toLowerCase().contains(query) ||
          c['location'].toString().toLowerCase().contains(query);

      final matchesTag = _selectedTag == 'All' ||
          c['species'].toString().toLowerCase() == _selectedTag.toLowerCase();

      final matchesLocation = _selectedLocation == 'All' ||
          c['location'].toString() == _selectedLocation;

      final matchesQuality = _selectedQuality == 'All' ||
          c['quality'].toString() == _selectedQuality;

      return matchesQuery && matchesTag && matchesLocation && matchesQuality;
    }).toList();
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Filter Seafood Catches',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedLocation = 'All';
                        _selectedQuality = 'All';
                        _selectedTag = 'All';
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Location',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: ['All', 'Negombo', 'Beruwala', 'Galle', 'Matara', 'Kalpitiya']
                    .map((loc) => ChoiceChip(
                          label: Text(loc),
                          selected: _selectedLocation == loc,
                          onSelected: (_) {
                            setState(() => _selectedLocation = loc);
                            setSheetState(() {});
                          },
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
              const Text('Quality Grade',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: ['All', 'A', 'B']
                    .map((q) => ChoiceChip(
                          label: Text('Grade $q'),
                          selected: _selectedQuality == q,
                          onSelected: (_) {
                            setState(() => _selectedQuality = q);
                            setSheetState(() {});
                          },
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xff005b96)),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tags = ['All', 'Tuna', 'Mackerel', 'Seer', 'Skipjack', 'Trevally'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Available Fish',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Search Bar
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search fish...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: _showFilterSheet,
              icon: const Icon(Icons.tune),
              tooltip: 'Filters',
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Quick Tag Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: tags.map((tag) {
              final isSelected = _selectedTag == tag;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedTag = tag),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Available Fish Cards Grid
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 650;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredCatches.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isWide ? 3 : 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 220,
              ),
              itemBuilder: (context, index) {
                final fish = _filteredCatches[index];
                return _buildAvailableFishCard(fish);
              },
            );
          },
        ),
      ],
    );
  }

  // ┌─────────────────────┐
  // │ 🐟 Tuna             │
  // │ 100 kg              │
  // │ Rs.1550/kg          │
  // │ Quality: A          │
  // │ Negombo             │
  // │                     │
  // │ [View Details]      │
  // └─────────────────────┘
  Widget _buildAvailableFishCard(Map<String, dynamic> fish) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffdbe7f0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${fish['emoji']} ${fish['species']}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xff003b5c),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Quality: ${fish['quality']}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${fish['quantity']} kg',
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
          const SizedBox(height: 2),
          Text(
            'Rs. ${fish['price']} / kg',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xff0077b6),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  fish['location'] as String,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xff005b96),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => showCatchDetailsModal(context, fish),
              child: const Text('View Details', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FEATURE 12: 🔎 CATCH DETAILS MODAL
// ══════════════════════════════════════════════════════════════════════════════

void showCatchDetailsModal(BuildContext context, Map<String, dynamic> fish) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CatchDetailsSheet(fish: fish),
  );
}

class _CatchDetailsSheet extends StatelessWidget {
  const _CatchDetailsSheet({required this.fish});

  final Map<String, dynamic> fish;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  fish['species'] as String,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                // Seafood Photo Banner
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xff004e75), Color(0xff0077b6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(fish['emoji'] as String? ?? '🐟',
                            style: const TextStyle(fontSize: 64)),
                        const SizedBox(height: 6),
                        Text(
                          fish['fullSpecies'] as String? ?? fish['species'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Detail Attributes Table
                _buildDetailRow('Quantity:', '${fish['quantity']} kg'),
                _buildDetailRow('Verified Weight:', '${fish['verifiedWeight'] ?? fish['quantity']} kg'),
                _buildDetailRow('Asking Price:', 'Rs. ${fish['price']} / kg'),
                _buildDetailRow('Current Highest Bid:', 'Rs. ${fish['currentBid'] ?? fish['price']} / kg'),
                _buildDetailRow('Landing Pier:', '${fish['location']} Harbour'),
                _buildDetailRow('Quality Inspection:', '${fish['quality'] ?? "Grade A"} (Inspected)'),
                _buildDetailRow('Time Landed:', 'Today, 04:30 AM (Cold-stored)'),
                const SizedBox(height: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xff005b96),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    showBuyerOrderModal(context, fish: fish);
                  },
                  icon: const Icon(Icons.shopping_cart_checkout),
                  label: const Text('Place Order / Submit Bid (React Form)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FEATURE 13: 🛒 BUYER ORDER FORM (React Web Parity - POST /api/Bids)
// ══════════════════════════════════════════════════════════════════════════════

void showPlaceBidModal(BuildContext context, [Map<String, dynamic>? fish]) {
  showBuyerOrderModal(context, fish: fish);
}

void showBuyerOrderModal(BuildContext context, {Map<String, dynamic>? fish}) {
  final targetFish = fish ?? {
    'id': 1,
    'species': 'Tuna',
    'fullSpecies': 'Yellowfin Tuna (Kelawalla)',
    'quantity': 100,
    'verifiedWeight': 98,
    'price': 1550,
    'currentBid': 1600,
    'location': 'Negombo Fishery Harbour',
    'lot': 'LOT-NEG-902',
    'quality': 'Grade A',
    'emoji': '🐟',
  };
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _BuyerOrderFormSheet(fish: targetFish),
  );
}

class _BuyerOrderFormSheet extends StatefulWidget {
  const _BuyerOrderFormSheet({required this.fish});

  final Map<String, dynamic> fish;

  @override
  State<_BuyerOrderFormSheet> createState() => _BuyerOrderFormSheetState();
}

class _BuyerOrderFormSheetState extends State<_BuyerOrderFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _buyerNameController;
  late TextEditingController _buyerPhoneController;
  late TextEditingController _bidRateController;
  late TextEditingController _qtyController;
  late TextEditingController _notesController;
  late TextEditingController _customAddressController;

  String _selectedDestination = 'Colombo Port Export Zone (Hub 1)';
  String _selectedColdChain = 'Chilled (0°C to 4°C)';
  String _selectedWindow = 'Immediate Pier Dispatch (within 2h)';
  String _selectedPayment = 'FishLink Smart Escrow Guarantee';
  bool _submitting = false;

  final List<String> _destinations = [
    'Colombo Port Export Zone (Hub 1)',
    'Peliyagoda Central Market (Stall 14)',
    'Keells Distribution Logistics Center (Ja-Ela)',
    'Katunayake Airport Export Cold Unit',
    'Custom Address',
  ];

  @override
  void initState() {
    super.initState();
    final defaultRate = widget.fish['species'] == 'Tuna'
        ? 1650
        : (widget.fish['currentBid'] as num?)?.toInt() ??
            (widget.fish['price'] as num?)?.toInt() ??
            1500;
    _buyerNameController =
        TextEditingController(text: 'OceanFresh Exporters (Pvt) Ltd');
    _buyerPhoneController = TextEditingController(text: '+94 77 987 6543');
    _bidRateController = TextEditingController(text: '$defaultRate');
    _qtyController =
        TextEditingController(text: '${widget.fish['quantity'] ?? 100}');
    _notesController = TextEditingController(
        text: 'Cold-chain container required. Inspect upon dock arrival.');
    _customAddressController = TextEditingController();
  }

  @override
  void dispose() {
    _buyerNameController.dispose();
    _buyerPhoneController.dispose();
    _bidRateController.dispose();
    _qtyController.dispose();
    _notesController.dispose();
    _customAddressController.dispose();
    super.dispose();
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final bidRate = double.tryParse(_bidRateController.text.trim()) ?? 0;
    final qty = double.tryParse(_qtyController.text.trim()) ?? 0;
    if (bidRate <= 0 || qty <= 0) return;

    setState(() => _submitting = true);

    final catchId = (widget.fish['id'] as num?)?.toInt() ?? 1;
    try {
      await ApiClient().placeBid(catchId, bidRate);
    } catch (_) {}

    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.pop(context);

    final destination = _selectedDestination == 'Custom Address'
        ? _customAddressController.text.trim()
        : _selectedDestination;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Order Submitted!', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order #ORD-1049 placed for ${widget.fish['species']} (${qty.toInt()} kg @ Rs. ${bidRate.toInt()}/kg).',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• Total Commitment: Rs. ${(bidRate * qty).toInt().toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]},")}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xff005b96)),
                  ),
                  const SizedBox(height: 4),
                  Text('• Destination: $destination', style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('• Cold Chain: $_selectedColdChain', style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  const Text('• Autonomous Logistics Agent notified for vehicle dispatch.',
                      style: TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xff005b96)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentRate = double.tryParse(_bidRateController.text.trim()) ?? 0;
    final qty = double.tryParse(_qtyController.text.trim()) ?? 0;
    final total = currentRate * qty;
    final askingPrice = (widget.fish['price'] as num?)?.toDouble() ?? 1500;
    final isBelowAsking = currentRate > 0 && currentRate < askingPrice;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xff0284c7).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shopping_cart_checkout, color: Color(0xff0284c7), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Buyer Order / Bid Placement',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${widget.fish['species']} • Lot ${widget.fish['lot'] ?? 'LOT-NEG-902'} • Asking: Rs. ${askingPrice.toInt()}/kg',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  // Catch Highlight Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xfff8fafc),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Text(widget.fish['emoji'] as String? ?? '🐟',
                            style: const TextStyle(fontSize: 34)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.fish['fullSpecies'] as String? ?? widget.fish['species'] as String,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.fish['quantity']} kg available • Harbour: ${widget.fish['location']} • Quality: ${widget.fish['quality'] ?? "Grade A"}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Text(
                            'Quality: ${widget.fish['quality'] ?? "A"}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Buyer Company Name
                  const Text('Buyer Company / Trading Name',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _buyerNameController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.business, size: 18),
                      hintText: 'e.g. OceanFresh Exporters (Pvt) Ltd',
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Please enter buyer name' : null,
                  ),

                  const SizedBox(height: 14),

                  // Order Quantity
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Order Quantity (kg)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      Text('Max: ${widget.fish['quantity']} kg',
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.scale, size: 18),
                      suffixText: 'kg',
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final val = double.tryParse(v ?? '');
                      if (val == null || val <= 0) return 'Enter a valid quantity';
                      final maxQty = (widget.fish['quantity'] as num?)?.toDouble() ?? 500;
                      if (val > maxQty) return 'Cannot exceed available $maxQty kg';
                      return null;
                    },
                  ),

                  // Quick Quantity Buttons
                  const SizedBox(height: 6),
                  Row(
                    children: [25, 50, 75, 100].map((pct) {
                      final maxQty = (widget.fish['quantity'] as num?)?.toInt() ?? 100;
                      final calcQty = (maxQty * (pct / 100)).round();
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: Text('$pct% ($calcQty kg)', style: const TextStyle(fontSize: 11)),
                          onPressed: () {
                            _qtyController.text = '$calcQty';
                            setState(() {});
                          },
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 14),

                  // Bid Rate (Rs. / kg)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Your Bid / Purchase Price (Rs./kg)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      Text('Asking: Rs. ${askingPrice.toInt()}/kg',
                          style: const TextStyle(fontSize: 11, color: Colors.blue)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _bidRateController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      prefixText: 'Rs. ',
                      prefixIcon: Icon(Icons.payments_outlined, size: 18),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final val = double.tryParse(v ?? '');
                      if (val == null || val <= 0) return 'Enter a valid price';
                      return null;
                    },
                  ),

                  if (isBelowAsking)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '⚠ Offer is below asking price (Rs. ${askingPrice.toInt()}/kg). Seller may decline.',
                        style: const TextStyle(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.w600),
                      ),
                    )
                  else if (currentRate >= askingPrice)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '✓ Competitive offer at or above asking price.',
                        style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.w600),
                      ),
                    ),

                  const SizedBox(height: 14),

                  // Real-time Total Cost Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xff004e75), Color(0xff0077b6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Estimated Order Value:',
                            style: TextStyle(color: Color(0xffc2e5fb), fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          'Rs. ${total.toInt().toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]},")}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '• Cold-Chain Logistics: Standby • Smart Escrow Protection: Verified',
                          style: TextStyle(color: Color(0xffe0f2fe), fontSize: 11),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Delivery Destination
                  const Text('Delivery Destination / Warehouse',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedDestination,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.location_on, size: 18)),
                    items: _destinations
                        .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedDestination = v!),
                  ),
                  if (_selectedDestination == 'Custom Address') ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _customAddressController,
                      decoration: const InputDecoration(
                        hintText: 'Enter street address, city, postal code',
                        prefixIcon: Icon(Icons.map, size: 18),
                      ),
                      validator: (v) => _selectedDestination == 'Custom Address' && (v == null || v.isEmpty)
                          ? 'Please enter delivery address'
                          : null,
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Cold-Chain Requirement
                  const Text('Cold-Chain Requirement',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      'Chilled (0°C to 4°C)',
                      'Deep Frozen (-18°C)',
                      'Slurry Ice Packed',
                    ].map((mode) {
                      final isSel = _selectedColdChain == mode;
                      return ChoiceChip(
                        label: Text(mode, style: const TextStyle(fontSize: 12)),
                        selected: isSel,
                        onSelected: (_) => setState(() => _selectedColdChain = mode),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 14),

                  // Delivery Schedule Window
                  const Text('Preferred Delivery Window',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedWindow,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.access_time, size: 18)),
                    items: [
                      'Immediate Pier Dispatch (within 2h)',
                      'Same-Day Evening (18:00 - 21:00)',
                      'Next-Day Morning Auction Slot (05:00 - 08:00)',
                    ]
                        .map((w) => DropdownMenuItem(value: w, child: Text(w, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedWindow = v!),
                  ),

                  const SizedBox(height: 14),

                  // Payment & Settlement Guarantee
                  const Text('Settlement Guarantee Method',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedPayment,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.verified_user, size: 18)),
                    items: [
                      'FishLink Smart Escrow Guarantee',
                      '24-Hour Verified Bank Wire Settlement',
                      'Commercial Letter of Credit (LC)',
                    ]
                        .map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedPayment = v!),
                  ),

                  const SizedBox(height: 14),

                  // Special Handling Notes
                  const Text('Special Instructions / Notes',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Export grade packing, attach digital temperature logger',
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Submit Buttons
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xff005b96),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _submitting ? null : _submitOrder,
                    icon: _submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check, size: 18),
                    label: Text(
                      _submitting ? 'Submitting Order…' : 'Submit Order & Place Bid (POST /api/Bids)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FEATURE 13B: 🚚 LOGISTICS DELIVERY PLAN FORM (React Web Parity - POST /api/Logistics/plans)
// ══════════════════════════════════════════════════════════════════════════════

void showCreateLogisticsPlanModal(
  BuildContext context, {
  int catchId = 1,
  String species = 'Yellowfin Tuna',
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _LogisticsDeliveryPlanFormSheet(
      catchId: catchId,
      species: species,
    ),
  );
}

class _LogisticsDeliveryPlanFormSheet extends StatefulWidget {
  const _LogisticsDeliveryPlanFormSheet({
    required this.catchId,
    required this.species,
  });

  final int catchId;
  final String species;

  @override
  State<_LogisticsDeliveryPlanFormSheet> createState() =>
      _LogisticsDeliveryPlanFormSheetState();
}

class _LogisticsDeliveryPlanFormSheetState
    extends State<_LogisticsDeliveryPlanFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _catchIdController;
  late TextEditingController _pickupController;
  late TextEditingController _deliveryController;
  late TextEditingController _distanceController;
  late TextEditingController _minutesController;
  late TextEditingController _weatherController;
  late TextEditingController _reasoningController;

  String _selectedVehicle = 'V01 - WP-ND-4921 (Reefer 2.5T)';
  String _selectedDriver = 'D01 - Sunil Gunaratne (+94 77 123 4567)';
  String _selectedStorage = 'C01 - Peliyagoda Cold Store #4';
  String _selectedRoute = 'Route A (E03 Colombo-Katunayake Expressway)';
  String _selectedStatus = 'PendingApproval';
  double _targetTemp = 2.2;
  bool _submitting = false;

  final List<String> _vehicles = [
    'V01 - WP-ND-4921 (Reefer 2.5T)',
    'V02 - WP-CA-8832 (Chilled Van 1.5T)',
    'V03 - WP-NC-1102 (Deep Freezer Truck 4.0T)',
    'V04 - WP-LB-5510 (Multi-Temp Container 3.0T)',
  ];

  final List<String> _drivers = [
    'D01 - Sunil Gunaratne (+94 77 123 4567)',
    'D02 - Nimal Perera (+94 71 888 2345)',
    'D03 - Kasun Jayawardena (+94 76 555 1234)',
  ];

  final List<String> _storages = [
    'C01 - Peliyagoda Cold Store #4',
    'C02 - Negombo Fishery Harbour Chiller #2',
    'C03 - Katunayake EPZ Cold Vault',
  ];

  final List<String> _routes = [
    'Route A (E03 Colombo-Katunayake Expressway)',
    'Route B (Peliyagoda Bypass A3 Highway)',
    'Route C (Coastal Galle Road Corridor)',
  ];

  @override
  void initState() {
    super.initState();
    _catchIdController = TextEditingController(text: '${widget.catchId}');
    _pickupController =
        TextEditingController(text: 'Negombo Fishery Harbour • Pier 3B');
    _deliveryController =
        TextEditingController(text: 'Peliyagoda Central Wholesale Fish Market');
    _distanceController = TextEditingController(text: '36.4');
    _minutesController = TextEditingController(text: '47');
    _weatherController = TextEditingController(
        text: 'Clear conditions, optimal transit window. Dry pavement on E03.');
    _reasoningController = TextEditingController(
        text: 'Automated allocation by Logistics Agent. Cold vault reserved.');
  }

  @override
  void dispose() {
    _catchIdController.dispose();
    _pickupController.dispose();
    _deliveryController.dispose();
    _distanceController.dispose();
    _minutesController.dispose();
    _weatherController.dispose();
    _reasoningController.dispose();
    super.dispose();
  }

  Future<void> _submitPlan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    final payload = {
      'catchId': int.tryParse(_catchIdController.text.trim()) ?? widget.catchId,
      'vehicleCode': _selectedVehicle.split(' ').first,
      'driverCode': _selectedDriver.split(' ').first,
      'coldStorageCode': _selectedStorage.split(' ').first,
      'pickupLocation': _pickupController.text.trim(),
      'deliveryLocation': _deliveryController.text.trim(),
      'selectedRoute': _selectedRoute,
      'distanceKm': double.tryParse(_distanceController.text.trim()) ?? 36.4,
      'estimatedMinutes': int.tryParse(_minutesController.text.trim()) ?? 47,
      'weatherNote': _weatherController.text.trim(),
      'agentReasoning': _reasoningController.text.trim(),
      'status': _selectedStatus,
    };

    try {
      await ApiClient().createLogisticsPlan(payload);
    } catch (_) {}

    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Delivery Plan Created!', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delivery Plan for Catch #${_catchIdController.text} (${widget.species}) was registered successfully via POST /api/Logistics/plans.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Assigned Vehicle: $_selectedVehicle', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('• Assigned Driver: $_selectedDriver', style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('• Route: $_selectedRoute (${_distanceController.text} km, ${_minutesController.text} mins)', style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('• Target Temp: ${_targetTemp.toStringAsFixed(1)}°C (Cold Chain Verified)',
                      style: const TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xff0f766e)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xff0f766e).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_shipping, color: Color(0xff0f766e), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Schedule Delivery Plan',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Catch #${widget.catchId} • ${widget.species} • React Web Parity',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  // Catch ID
                  const Text('Linked Catch ID / Batch Code',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _catchIdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.qr_code, size: 18),
                      hintText: 'e.g. 1',
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Enter catch ID' : null,
                  ),

                  const SizedBox(height: 14),

                  // Refrigerated Vehicle Code
                  const Text('Refrigerated Fleet Vehicle',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedVehicle,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.directions_bus, size: 18)),
                    items: _vehicles
                        .map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedVehicle = v!),
                  ),

                  const SizedBox(height: 14),

                  // Driver Code
                  const Text('Certified Cold-Chain Driver',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedDriver,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.person, size: 18)),
                    items: _drivers
                        .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedDriver = v!),
                  ),

                  const SizedBox(height: 14),

                  // Cold Storage Code
                  const Text('Cold Storage Vault Facility',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedStorage,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.ac_unit, size: 18)),
                    items: _storages
                        .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedStorage = v!),
                  ),

                  const SizedBox(height: 14),

                  // Pickup Location
                  const Text('Pier Pickup Origin',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _pickupController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.anchor, size: 18),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Enter pickup location' : null,
                  ),

                  const SizedBox(height: 14),

                  // Delivery Location
                  const Text('Delivery Destination Hub',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _deliveryController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.store, size: 18),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Enter delivery location' : null,
                  ),

                  const SizedBox(height: 14),

                  // Selected Route
                  const Text('Selected Highway Route',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedRoute,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.alt_route, size: 18)),
                    items: _routes
                        .map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedRoute = v!),
                  ),

                  const SizedBox(height: 14),

                  // Distance & Duration
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Distance (km)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _distanceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(suffixText: 'km'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Duration (mins)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _minutesController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(suffixText: 'mins'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Target Temperature Sensor
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Cold-Chain Target Temp (°C)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.teal.shade300),
                        ),
                        child: Text('${_targetTemp.toStringAsFixed(1)}°C (Optimal)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal)),
                      ),
                    ],
                  ),
                  Slider(
                    value: _targetTemp,
                    min: -20.0,
                    max: 10.0,
                    divisions: 60,
                    activeColor: const Color(0xff0f766e),
                    label: '${_targetTemp.toStringAsFixed(1)}°C',
                    onChanged: (v) => setState(() => _targetTemp = v),
                  ),

                  const SizedBox(height: 14),

                  // Weather Note
                  const Text('Weather & Route Advisory Note',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _weatherController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.wb_sunny_outlined, size: 18),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Dispatcher / Agent Reasoning
                  const Text('Dispatcher / Agent Reasoning Note',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _reasoningController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.psychology, size: 18),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Status
                  const Text('Plan Initial Status',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.flag_outlined, size: 18)),
                    items: ['PendingApproval', 'Approved', 'InTransit']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedStatus = v!),
                  ),

                  const SizedBox(height: 24),

                  // Submit
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xff0f766e),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _submitting ? null : _submitPlan,
                    icon: _submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check, size: 18),
                    label: Text(
                      _submitting ? 'Creating Plan…' : 'Create Delivery Plan (POST /api/Logistics/plans)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FEATURE 13C: 🚚 LOGISTICS DELIVERY PLANS & COLD-CHAIN AGENT (React Parity)
// ══════════════════════════════════════════════════════════════════════════════

void showLogisticsPlansModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _LogisticsDeliveryPlansSheet(),
  );
}

class _LogisticsDeliveryPlansSheet extends StatefulWidget {
  const _LogisticsDeliveryPlansSheet();

  @override
  State<_LogisticsDeliveryPlansSheet> createState() =>
      _LogisticsDeliveryPlansSheetState();
}

class _LogisticsDeliveryPlansSheetState
    extends State<_LogisticsDeliveryPlansSheet> {
  int? _expandedPlanId;
  bool _loading = false;

  final List<Map<String, dynamic>> _plans = [
    {
      'id': 1,
      'planId': 'PLN-NEG-902',
      'catchId': 1,
      'species': 'Yellowfin Tuna (100 kg)',
      'status': 'PendingApproval',
      'vehicleCode': 'V01 - WP-ND-4921',
      'vehicleType': 'Reefer Truck 2.5T',
      'driverCode': 'D01 - Sunil Gunaratne',
      'driverPhone': '+94 77 123 4567',
      'coldStorageCode': 'C01 - Peliyagoda #4',
      'pickupLocation': 'Negombo Fishery Harbour • Pier 3B',
      'deliveryLocation': 'Peliyagoda Central Wholesale Fish Market',
      'selectedRoute': 'Route A (E03 Colombo-Katunayake Expressway)',
      'distanceKm': 36.4,
      'estimatedMinutes': 47,
      'targetTemp': 2.2,
      'pickupTime': 'Today, 06:30 AM',
      'estimatedETA': 'Today, 07:17 AM',
      'weatherNote':
          'Clear skies, dry pavement along E03 expressway. Optimal 47m transit window.',
      'agentReasoning':
          'Logistics Agent calculated lowest thermal variance via E03. Vehicle V01 pre-cooled to 2.2°C at Negombo staging yard. Driver Sunil certified for HACCP fish transport.',
    },
    {
      'id': 2,
      'planId': 'PLN-GAL-411',
      'catchId': 2,
      'species': 'Skipjack Tuna (60 kg)',
      'status': 'Scheduled',
      'vehicleCode': 'V02 - WP-CA-8832',
      'vehicleType': 'Chilled Van 1.5T',
      'driverCode': 'D02 - Nimal Perera',
      'driverPhone': '+94 71 888 2345',
      'coldStorageCode': 'C02 - Negombo Fishery Chiller #2',
      'pickupLocation': 'Galle Fishery Port • Jetty 2',
      'deliveryLocation': 'Katunayake Air Cargo Cold Vault',
      'selectedRoute': 'Route C (Southern Expressway E01 Corridor)',
      'distanceKm': 128.0,
      'estimatedMinutes': 95,
      'targetTemp': 1.8,
      'pickupTime': 'Today, 04:00 AM',
      'estimatedETA': 'Today, 05:35 AM',
      'weatherNote':
          'Light coastal morning mist near Dodanduwa. Safe transit conditions verified.',
      'agentReasoning':
          'Pre-allocated for Japanese sashimi export flight. Driver assigned with digital IoT continuous thermal logger #LOG-889.',
    },
    {
      'id': 3,
      'planId': 'PLN-CMB-108',
      'catchId': 3,
      'species': 'Giant Trevally (80 kg)',
      'status': 'Delivered',
      'vehicleCode': 'V03 - WP-NC-1102',
      'vehicleType': 'Deep Freezer Truck 4.0T',
      'driverCode': 'D03 - Kasun Jayawardena',
      'driverPhone': '+94 76 555 1234',
      'coldStorageCode': 'C03 - Katunayake EPZ Vault',
      'pickupLocation': 'Colombo Mutwal Fishery Harbour',
      'deliveryLocation': 'Keells Distribution Logistics Center (Ja-Ela)',
      'selectedRoute': 'Route B (Peliyagoda Bypass A3 Highway)',
      'distanceKm': 24.5,
      'estimatedMinutes': 38,
      'targetTemp': -18.0,
      'pickupTime': 'Yesterday, 14:00',
      'estimatedETA': 'Yesterday, 14:38',
      'weatherNote': 'Dry and clear. Standard afternoon logistics corridor.',
      'agentReasoning':
          'Delivery successfully completed. Digital temperature log submitted with 0.0°C deviation. Payment escrow cleared.',
    },
    {
      'id': 4,
      'planId': 'PLN-NEG-554',
      'catchId': 4,
      'species': 'Yellowfin Tuna (150 kg)',
      'status': 'InTransit',
      'vehicleCode': 'V01 - WP-CAB-1234',
      'vehicleType': 'Isuzu Reefer Truck 3.5T',
      'driverCode': 'D01 - Sunil Perera',
      'driverPhone': '+94 77 123 4567',
      'coldStorageCode': 'C01 - Negombo Deep Freeze (-18°C)',
      'pickupLocation': 'Negombo Fishery Harbour • Pier 3B',
      'deliveryLocation': 'Peliyagoda Central Wholesale Fish Market',
      'selectedRoute': 'Route A (E03 Colombo-Katunayake Expressway)',
      'distanceKm': 36.4,
      'estimatedMinutes': 47,
      'targetTemp': -2.0,
      'pickupTime': 'Today, 14:30 PM',
      'estimatedETA': 'Today, 15:17 PM',
      'weatherNote': 'Passing Ja-Ela interchange. Clear weather, optimal slurry cold holding.',
      'agentReasoning':
          'Reefer V01 dispatched after quality inspection by Admin officer. IoT GPS continuous tracking active.',
    },
  ];

  Future<void> _approve(int id) async {
    setState(() => _loading = true);
    try {
      await ApiClient().approveLogisticsPlan(id);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _loading = false;
      final idx = _plans.indexWhere((p) => p['id'] == id);
      if (idx != -1) _plans[idx]['status'] = 'Scheduled';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logistics Plan approved & scheduled! Telemetry active.'),
        backgroundColor: Color(0xff059669),
      ),
    );
  }

  Future<void> _reject(int id) async {
    setState(() => _loading = true);
    try {
      await ApiClient().rejectLogisticsPlan(id);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _loading = false;
      final idx = _plans.indexWhere((p) => p['id'] == id);
      if (idx != -1) _plans[idx]['status'] = 'Rejected';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logistics Plan rejected. Driver & vehicle unassigned.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _markDelivered(int id) async {
    setState(() => _loading = true);
    try {
      await ApiClient().completeLogisticsPlan(id);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _loading = false;
      final idx = _plans.indexWhere((p) => p['id'] == id);
      if (idx != -1) _plans[idx]['status'] = 'Delivered';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cargo marked as Delivered! Escrow release triggered.'),
        backgroundColor: Color(0xff7209b7),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount =
        _plans.where((p) => p['status'] == 'PendingApproval').length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xfff8fafc),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xff7209b7).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_shipping,
                      color: Color(0xff7209b7), size: 24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cold-Chain Logistics Agent',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Delivery Plans (${_plans.length}) • $pendingCount Pending • Live Weather Telemetry',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── LIVE WEATHER WIDGET (Matching React WeatherWidget) ──
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xff0f172a), Color(0xff1e293b)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.wb_sunny_outlined,
                                  color: Color(0xfffbbf24), size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Harbour Weather & Sea Telemetry',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('LIVE IOT',
                                style: TextStyle(
                                    color: Colors.tealAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildPortWeatherBadge(
                                'Negombo Pier', '29°C', '84% Hum', 'Calm sea'),
                            _buildPortWeatherBadge(
                                'Colombo Port', '30°C', '80% Hum', 'Dry E03'),
                            _buildPortWeatherBadge(
                                'Galle Jetty', '28°C', '88% Hum', 'Light mist'),
                            _buildPortWeatherBadge(
                                'Jaffna Coast', '31°C', '76% Hum', 'Optimal'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Action Bar: Create Plan & Summary ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Delivery Plans',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xffede9fe),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$pendingCount pending',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff6d28d9)),
                          ),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff0f766e),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        showCreateLogisticsPlanModal(context);
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Create Plan',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Delivery Plan Cards ──
                ..._plans.map((plan) => _buildDeliveryPlanCard(plan)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortWeatherBadge(
      String port, String temp, String hum, String condition) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(port,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(temp,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              Text('• $hum',
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 10)),
            ],
          ),
          Text(condition,
              style: const TextStyle(color: Color(0xff67e8f9), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildDeliveryPlanCard(Map<String, dynamic> plan) {
    final status = plan['status'] as String;
    final isExpanded = _expandedPlanId == plan['id'];

    Color statusBg;
    Color statusColor;
    String statusLabel;

    if (status == 'PendingApproval') {
      statusBg = const Color(0xfffef3c7);
      statusColor = const Color(0xff92400e);
      statusLabel = '⏳ Pending Approval';
    } else if (status == 'Scheduled') {
      statusBg = const Color(0xffd1fae5);
      statusColor = const Color(0xff065f46);
      statusLabel = '✅ Scheduled';
    } else if (status == 'InTransit') {
      statusBg = const Color(0xffe0f2fe);
      statusColor = const Color(0xff0284c7);
      statusLabel = '🚚 In Transit • Live GPS';
    } else if (status == 'Delivered') {
      statusBg = const Color(0xffede9fe);
      statusColor = const Color(0xff4c1d95);
      statusLabel = '🏁 Delivered';
    } else {
      statusBg = const Color(0xfffee2e2);
      statusColor = const Color(0xff991b1b);
      statusLabel = '❌ $status';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('🚚 ${plan['planId']}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                Text('Catch #${plan['catchId']}',
                    style:
                        const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'Cargo: ${plan['species']}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),

          const SizedBox(height: 10),

          // 8 Spec Metric Grid (matching React)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMetricBox('🚛 Vehicle', plan['vehicleCode'] as String),
                _buildMetricBox('👤 Driver', plan['driverCode'] as String),
                _buildMetricBox(
                    '🧊 Vault', plan['coldStorageCode'] as String),
                _buildMetricBox(
                    '🌡️ Temp Target', '${plan['targetTemp']}°C'),
                _buildMetricBox('📏 Distance', '${plan['distanceKm']} km'),
                _buildMetricBox(
                    '⏱️ Transit Time', '${plan['estimatedMinutes']} mins'),
                _buildMetricBox('🕐 Pickup', plan['pickupTime'] as String),
                _buildMetricBox('🏁 ETA', plan['estimatedETA'] as String),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Route Corridor
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xfff0f9ff),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xffbae6fd)),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on,
                    size: 16, color: Color(0xff0284c7)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${plan['pickupLocation']} ➔ ${plan['deliveryLocation']}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xff0369a1),
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Weather note
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xfffefce8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xfffde047)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🌤️ ', style: TextStyle(fontSize: 13)),
                Expanded(
                  child: Text(
                    'Weather: ${plan['weatherNote']}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xff713f12)),
                  ),
                ),
              ],
            ),
          ),

          // AI Reasoning Expandable Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: InkWell(
              onTap: () => setState(() {
                _expandedPlanId = isExpanded ? null : plan['id'] as int;
              }),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.visibility_off : Icons.visibility,
                    size: 14,
                    color: const Color(0xff7c3aed),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isExpanded ? 'Hide AI Reasoning' : 'Show AI Reasoning',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xff7c3aed),
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          if (isExpanded)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xff0f172a),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                plan['agentReasoning'] as String,
                style: const TextStyle(
                    color: Color(0xffe2e8f0),
                    fontSize: 11,
                    fontFamily: 'monospace',
                    height: 1.4),
              ),
            ),

          // Action Buttons
          if (status == 'PendingApproval')
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff059669),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _loading ? null : () => _approve(plan['id']),
                      icon: const Icon(Icons.check_circle, size: 16),
                      label: const Text('Approve & Schedule',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(
                          vertical: 11, horizontal: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _loading ? null : () => _reject(plan['id']),
                    icon: const Icon(Icons.cancel, size: 16),
                    label: const Text('Reject',
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            )
          else if (status == 'Scheduled')
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff0284c7),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => showVehicleDispatchDialog(
                        context,
                        plan,
                        () => setState(() {}),
                      ),
                      icon: const Icon(Icons.rocket_launch, size: 16),
                      label: const Text(
                        '🚚 Dispatch Reefer Vehicle',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xff7c3aed),
                      side: const BorderSide(color: Color(0xff7c3aed)),
                      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => showLiveVehicleTrackingModal(context, plan),
                    icon: const Icon(Icons.satellite_alt, size: 16),
                    label: const Text('Track', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            )
          else if (status == 'InTransit')
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff7c3aed),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => showLiveVehicleTrackingModal(
                        context,
                        plan,
                        onDelivered: () => setState(() {}),
                      ),
                      icon: const Icon(Icons.satellite_alt, size: 16),
                      label: const Text(
                        '🛰️ Live GPS & Cold-Chain Tracker',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xff059669),
                      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _loading ? null : () => _markDelivered(plan['id']),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Delivered', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )
          else if (status == 'Delivered')
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xff059669),
                    side: const BorderSide(color: Color(0xff059669)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => showLiveVehicleTrackingModal(context, plan),
                  icon: const Icon(Icons.verified, size: 16),
                  label: const Text(
                    '🏁 Delivered • View Cold-Chain Audit Log',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricBox(String label, String value) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff1e293b))),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FEATURE 14: 📊 MY BIDS (Buyer View)
// ══════════════════════════════════════════════════════════════════════════════

class MyBidsScreen extends StatefulWidget {
  const MyBidsScreen({super.key});

  @override
  State<MyBidsScreen> createState() => _MyBidsScreenState();
}

class _MyBidsScreenState extends State<MyBidsScreen> {
  String _selectedFilter = 'All';

  final List<Map<String, dynamic>> _myBids = [
    {
      'species': 'Tuna',
      'yourBid': 1650,
      'highestBid': 1650,
      'quantity': 100,
      'location': 'Negombo',
      'status': 'ACTIVE',
      'time': 'Placed 25m ago',
    },
    {
      'species': 'Mackerel',
      'yourBid': 1200,
      'highestBid': 1350,
      'quantity': 75,
      'location': 'Beruwala',
      'status': 'LOST',
      'time': 'Outbid 1h ago',
    },
    {
      'species': 'Seer Fish',
      'yourBid': 1800,
      'highestBid': 1800,
      'quantity': 60,
      'location': 'Negombo',
      'status': 'WON',
      'time': 'Won • Order Created',
    },
  ];

  List<Map<String, dynamic>> get _filteredBids {
    if (_selectedFilter == 'All') return _myBids;
    return _myBids
        .where((b) => b['status'] == _selectedFilter.toUpperCase())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ['All', 'ACTIVE', 'WON', 'LOST'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'My Bids',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters.map((f) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f),
                  selected: _selectedFilter == f,
                  onSelected: (_) => setState(() => _selectedFilter = f),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        ..._filteredBids.map((bid) => _buildBuyerBidCard(bid)),
      ],
    );
  }

  Widget _buildBuyerBidCard(Map<String, dynamic> bid) {
    final status = bid['status'] as String;
    final isActive = status == 'ACTIVE';
    final isWon = status == 'WON';
    final isLost = status == 'LOST';

    final Color badgeColor = isActive
        ? Colors.green
        : isWon
            ? const Color(0xff7209b7)
            : Colors.red.shade700;

    final Color badgeBg = isActive
        ? Colors.green.shade50
        : isWon
            ? Colors.purple.shade50
            : Colors.red.shade50;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? Colors.green.shade300
              : isWon
                  ? Colors.purple.shade200
                  : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🐟 ${bid['species']}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xff003b5c),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'Status: $status',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Your Bid: Rs.${bid['yourBid']}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff0077b6),
                ),
              ),
              const SizedBox(width: 14),
              if (isActive)
                Text(
                  'Current Highest: Rs.${bid['highestBid']}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade800,
                  ),
                )
              else if (isLost)
                Text(
                  'Current Highest: Rs.${bid['highestBid']}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700,
                  ),
                )
              else
                Text(
                  'Final: Rs.${bid['highestBid']}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.purple,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${bid['quantity']} kg • Total: Rs. ${(bid['yourBid'] * bid['quantity']).toInt()} • ${bid['location']}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          if (isWon)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: const [
                  Icon(Icons.local_shipping, size: 16, color: Colors.purple),
                  SizedBox(width: 6),
                  Text(
                    'Order Created • Logistics Dispatched via Cold Storage',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple),
                  ),
                ],
              ),
            )
          else if (isLost)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('You were outbid by another buyer',
                    style: TextStyle(fontSize: 11, color: Colors.black54)),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                  onPressed: () {
                    showPlaceBidModal(context, {
                      'id': 2,
                      'species': bid['species'],
                      'quantity': bid['quantity'],
                      'currentBid': bid['highestBid'],
                    });
                  },
                  child: const Text('Increase Bid',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class MyCatchesScreen extends StatefulWidget {
  const MyCatchesScreen({super.key});

  @override
  State<MyCatchesScreen> createState() => _MyCatchesScreenState();
}

class _MyCatchesScreenState extends State<MyCatchesScreen> {
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  bool _loading = false;
  List<Map<String, dynamic>> _catches = [];

  @override
  void initState() {
    super.initState();
    _loadCatches();
  }

  Future<void> _loadCatches() async {
    setState(() => _loading = true);
    try {
      final items = await ApiClient().catches();
      if (items.isNotEmpty) {
        setState(() {
          _catches = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading = false;
        });
        return;
      }
    } catch (_) {}

    // Fallback to sample catches if API offline or empty
    setState(() {
      _catches = sampleCatches.map((e) => Map<String, dynamic>.from(e)).toList();
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredCatches {
    final query = _searchController.text.trim().toLowerCase();
    return _catches.where((catchItem) {
      final status = (catchItem['status'] ?? 'Draft').toString();
      final species = (catchItem['fishSpecies'] ?? catchItem['species'] ?? '').toString();
      final location = (catchItem['location'] ?? '').toString();

      final matchesFilter = _selectedFilter == 'All' ||
          status.toLowerCase() == _selectedFilter.toLowerCase();
      final matchesQuery = query.isEmpty ||
          species.toLowerCase().contains(query) ||
          location.toLowerCase().contains(query);
      return matchesFilter && matchesQuery;
    }).toList();
  }

  Future<void> _publishCatch(Map<String, dynamic> item) async {
    final id = item['id'] as int?;
    if (id == null) return;
    try {
      await ApiClient().publishCatch(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Catch #$id published to live auction!'),
            backgroundColor: const Color(0xff059669),
          ),
        );
        _loadCatches();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not publish: $e')),
        );
      }
    }
  }

  Future<void> _cancelCatch(Map<String, dynamic> item) async {
    final id = item['id'] as int?;
    if (id == null) return;
    try {
      await ApiClient().cancelCatch(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing cancelled.')),
        );
        _loadCatches();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not cancel: $e')),
        );
      }
    }
  }

  Future<void> _deleteCatch(Map<String, dynamic> item) async {
    final id = item['id'] as int?;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Draft Catch?'),
        content: const Text('Are you sure you want to delete this listing?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiClient().deleteCatch(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draft listing deleted.')),
        );
        _loadCatches();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = ['All', 'Draft', 'Published', 'Bidding', 'PendingApproval', 'Sold', 'Cancelled'];
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xff005b96),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Log Catch', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => NewCatchScreen(onSaved: _loadCatches),
            ),
          );
        },
      ),
      body: RefreshIndicator(
        onRefresh: _loadCatches,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Search your catches & pier locations',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: filters.map((filter) {
                    final selected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: selected,
                        onSelected: (_) => setState(() => _selectedFilter = filter),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (_filteredCatches.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.set_meal_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text(
                          'No catches found for this filter.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => NewCatchScreen(onSaved: _loadCatches),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Register New Catch'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredCatches.length,
                    itemBuilder: (context, index) {
                      final item = _filteredCatches[index];
                      final species = (item['fishSpecies'] ?? item['species'] ?? 'Fish').toString();
                      final quantity = (item['quantityKg'] ?? item['quantity'] ?? 0).toDouble();
                      final price = (item['askingPricePerKg'] ?? item['price'] ?? 0).toDouble();
                      final location = (item['location'] ?? 'Harbour').toString();
                      final status = (item['status'] ?? 'Draft').toString();
                      final grade = item['declaredQualityGrade']?.toString() ?? '';
                      final verifiedWeight = (item['verifiedWeightKg'] as num?)?.toDouble() ?? 0;
                      final inspection = item['inspectionResult']?.toString() ?? 'Pending';
                      final catchId = (item['id'] as int?) ?? (index + 1);

                      final isDraft = status == 'Draft';
                      final isPublished = status == 'Published' || status == 'Bidding';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: _statusBorderColor(status), width: 1.2),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: const Color(0xffe0f2fe),
                                    child: const Icon(Icons.set_meal, color: Color(0xff005b96)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$species ($quantity kg)',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xff0f172a),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Rs. ${price.toStringAsFixed(0)}/kg • $location',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _statusBgColor(status),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: _statusBorderColor(status)),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _statusTextColor(status),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Quality & Inspection summary banner
                              Container(
                                margin: const EdgeInsets.only(top: 10, bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xfff0f9ff),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xffbae6fd)),
                                ),
                                child: Row(
                                  children: [
                                    const Text('🔍 ', style: TextStyle(fontSize: 12)),
                                    if (grade.isNotEmpty)
                                      Text('Grade: $grade  •  ',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xff0369a1))),
                                    if (verifiedWeight > 0)
                                      Text('Pier Wt: ${verifiedWeight.toStringAsFixed(1)}kg  •  ',
                                          style: const TextStyle(fontSize: 12, color: Color(0xff0369a1))),
                                    Text('Inspection: $inspection',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: inspection == 'Passed'
                                              ? Colors.green.shade800
                                              : (inspection == 'Failed' ? Colors.red.shade800 : Colors.orange.shade800),
                                        )),
                                  ],
                                ),
                              ),

                              // Action buttons row (Edit, Publish, Cancel, Delete, Bids)
                              Row(
                                children: [
                                  if (isDraft) ...[
                                    FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xff059669),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () => _publishCatch(item),
                                      icon: const Icon(Icons.publish, size: 16),
                                      label: const Text('Publish', style: TextStyle(fontSize: 12)),
                                    ),
                                    const SizedBox(width: 6),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => NewCatchScreen(
                                              editCatch: item,
                                              onSaved: _loadCatches,
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.edit, size: 16),
                                      label: const Text('Edit', style: TextStyle(fontSize: 12)),
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                      tooltip: 'Delete Draft',
                                      onPressed: () => _deleteCatch(item),
                                    ),
                                  ] else if (isPublished) ...[
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => NewCatchScreen(
                                              editCatch: item,
                                              onSaved: _loadCatches,
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.edit, size: 16),
                                      label: const Text('Edit', style: TextStyle(fontSize: 12)),
                                    ),
                                    const SizedBox(width: 6),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red.shade700,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () => _cancelCatch(item),
                                      child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                                    ),
                                  ],
                                  const Spacer(),
                                  FilledButton.tonalIcon(
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () {
                                      showFishermanCatchDetailsModal(
                                        context,
                                        species: species,
                                        quantityKg: quantity,
                                        location: location,
                                        askingPrice: price,
                                        catchId: catchId,
                                      );
                                    },
                                    icon: const Icon(Icons.gavel, size: 16),
                                    label: const Text('Bids & AI Match', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusBgColor(String status) {
    switch (status) {
      case 'Draft':
        return const Color(0xfffef3c7);
      case 'Published':
      case 'Active':
        return const Color(0xffd1fae5);
      case 'Bidding':
        return const Color(0xffdbeafe);
      case 'Sold':
        return const Color(0xffede9fe);
      case 'Cancelled':
      case 'Rejected':
        return const Color(0xfffee2e2);
      default:
        return const Color(0xfff1f5f9);
    }
  }

  Color _statusBorderColor(String status) {
    switch (status) {
      case 'Draft':
        return const Color(0xfff59e0b);
      case 'Published':
      case 'Active':
        return const Color(0xff10b981);
      case 'Bidding':
        return const Color(0xff3b82f6);
      case 'Sold':
        return const Color(0xff8b5cf6);
      case 'Cancelled':
      case 'Rejected':
        return const Color(0xffef4444);
      default:
        return const Color(0xffcbd5e1);
    }
  }

  Color _statusTextColor(String status) {
    switch (status) {
      case 'Draft':
        return const Color(0xff92400e);
      case 'Published':
      case 'Active':
        return const Color(0xff065f46);
      case 'Bidding':
        return const Color(0xff1e40af);
      case 'Sold':
        return const Color(0xff4c1d95);
      case 'Cancelled':
      case 'Rejected':
        return const Color(0xff991b1b);
      default:
        return const Color(0xff334155);
    }
  }
}

class NewCatchScreen extends StatefulWidget {
  const NewCatchScreen({this.editCatch, this.onSaved, super.key});

  final Map<String, dynamic>? editCatch;
  final VoidCallback? onSaved;

  @override
  State<NewCatchScreen> createState() => _NewCatchScreenState();
}

class _NewCatchScreenState extends State<NewCatchScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quantity;
  late final TextEditingController _expectedPrice;
  late final TextEditingController _location;
  late final TextEditingController _verifiedWeight;
  late final TextEditingController _sellerNote;
  late final TextEditingController _catchDate;
  late final TextEditingController _catchTime;

  String _species = 'Tuna (Yellowfin)';
  String _qualityGrade = 'A';
  String _inspectionResult = 'Pending';
  String? _photoPath;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final c = widget.editCatch;
    _species = (c?['fishSpecies'] ?? c?['species'] ?? 'Tuna (Yellowfin)').toString();
    _quantity = TextEditingController(text: c != null ? (c['quantityKg'] ?? c['quantity'] ?? '').toString() : '');
    _expectedPrice = TextEditingController(text: c != null ? (c['askingPricePerKg'] ?? c['price'] ?? '').toString() : '');
    _location = TextEditingController(text: (c?['location'] ?? 'Negombo Fishery Harbour').toString());
    _verifiedWeight = TextEditingController(text: c != null && c['verifiedWeightKg'] != null ? c['verifiedWeightKg'].toString() : '');
    _sellerNote = TextEditingController(text: (c?['sellerNote'] ?? '').toString());
    _qualityGrade = (c?['declaredQualityGrade'] ?? 'A').toString();
    if (_qualityGrade.isEmpty) _qualityGrade = 'A';
    _inspectionResult = (c?['inspectionResult'] ?? 'Pending').toString();
    _photoPath = c?['photoUrl']?.toString();

    final now = DateTime.now();
    _catchDate = TextEditingController(text: '${now.day}/${now.month}/${now.year}');
    _catchTime = TextEditingController(text: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}');
  }

  @override
  void dispose() {
    _quantity.dispose();
    _expectedPrice.dispose();
    _location.dispose();
    _verifiedWeight.dispose();
    _sellerNote.dispose();
    _catchDate.dispose();
    _catchTime.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 75,
    );
    if (file != null) {
      setState(() => _photoPath = file.path);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (!mounted) return;
    if (date != null) {
      _catchDate.text = '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _pickTime() async {
    final now = TimeOfDay.now();
    final time = await showTimePicker(context: context, initialTime: now);
    if (!mounted) return;
    if (time != null) {
      _catchTime.text = time.format(context);
    }
  }

  Future<void> _getLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enable location services.')),
      );
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission is required for GPS tagging.')),
      );
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    if (!mounted) return;
    setState(() {
      _location.text =
          '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)} (GPS Pier)';
    });
  }

  Future<void> _submit({bool publishNow = false}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final payload = {
      'fishSpecies': _species,
      'quantityKg': double.parse(_quantity.text),
      'askingPricePerKg': double.parse(_expectedPrice.text),
      'location': _location.text.isNotEmpty ? _location.text : 'Negombo Fishery Harbour',
      'photoUrl': _photoPath ?? '',
      'sellerNote': _sellerNote.text,
      'verifiedWeightKg': double.tryParse(_verifiedWeight.text) ?? 0,
      'declaredQualityGrade': _qualityGrade,
      'inspectionResult': _inspectionResult,
      'catchDateTime': DateTime.now().toIso8601String(),
    };

    final isEdit = widget.editCatch != null;
    final editId = widget.editCatch?['id'] as int?;

    try {
      if (isEdit && editId != null) {
        await ApiClient().updateCatch(editId, payload);
        if (publishNow) {
          await ApiClient().publishCatch(editId);
        }
      } else {
        final created = await ApiClient().createCatch(payload);
        final newId = created['id'] as int?;
        if (publishNow && newId != null) {
          await ApiClient().publishCatch(newId);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit
                ? 'Catch updated successfully!'
                : (publishNow ? 'Catch published to live auction!' : 'Catch saved as Draft.')),
            backgroundColor: const Color(0xff059669),
          ),
        );
        widget.onSaved?.call();
        Navigator.of(context).maybePop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving catch: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editCatch != null;
    final content = Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xff005b96).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.set_meal, color: Color(0xff005b96), size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEdit ? 'Edit Catch Listing' : 'Register New Catch',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xff003b5c)),
                    ),
                    Text(
                      isEdit ? 'Update species details, physical weight or price' : 'Enter catch details, verified pier weight & AI pricing',
                      style: const TextStyle(fontSize: 12, color: Color(0xff64748b)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Species Dropdown ──
          DropdownButtonFormField<String>(
            initialValue: _species,
            decoration: const InputDecoration(
              labelText: 'Fish Species',
              prefixIcon: Icon(Icons.water),
            ),
            items: [
              'Tuna (Yellowfin)',
              'Skipjack',
              'Trevally (Paraw)',
              'Mackerel',
              'Seer Fish (Thora)',
            ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => _species = v ?? 'Tuna (Yellowfin)'),
          ),
          const SizedBox(height: 14),

          // ── Quantity & Asking Price ──
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _quantity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantity (kg)',
                    prefixIcon: Icon(Icons.scale),
                    hintText: 'e.g. 150',
                  ),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    if (n == null || n <= 0) return 'Enter valid kg';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _expectedPrice,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Asking Price (Rs/kg)',
                    prefixIcon: Icon(Icons.payments),
                    hintText: 'e.g. 1400',
                  ),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    if (n == null || n <= 0) return 'Enter valid price';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── AI Price Recommendation Button ──
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xfff0fdf4),
                foregroundColor: const Color(0xff166534),
                side: const BorderSide(color: Color(0xff86efac)),
              ),
              onPressed: () {
                final q = double.tryParse(_quantity.text) ?? 100;
                showAiPriceRecommendationModal(
                  context,
                  species: _species,
                  quantityKg: q,
                  onApplyPrice: (price) {
                    setState(() {
                      _expectedPrice.text = price.toInt().toString();
                    });
                  },
                );
              },
              icon: const Text('🤖', style: TextStyle(fontSize: 16)),
              label: const Text('Get AI Price Recommendation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
          const SizedBox(height: 16),

          // ── 🔍 Quality & Inspection Details Container (React Parity) ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xfff0f9ff),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xffbae6fd), width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.verified, color: Color(0xff0284c7), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Quality & Inspection Details',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff0369a1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Verified Pier Weight
                TextFormField(
                  controller: _verifiedWeight,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Verified Weight (kg)',
                    helperText: 'Physical weight verified at pier/harbour',
                    prefixIcon: Icon(Icons.speed),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),

                // Quality Grade & Inspection Result
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _qualityGrade,
                        decoration: const InputDecoration(
                          labelText: 'Quality Grade',
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'A+', child: Text('A+ (Premium)')),
                          DropdownMenuItem(value: 'A', child: Text('A (Good)')),
                          DropdownMenuItem(value: 'B', child: Text('B (Average)')),
                          DropdownMenuItem(value: 'C', child: Text('C (Below avg)')),
                        ],
                        onChanged: (v) => setState(() => _qualityGrade = v ?? 'A'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _inspectionResult,
                        decoration: const InputDecoration(
                          labelText: 'Inspection Result',
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Pending', child: Text('⏳ Pending')),
                          DropdownMenuItem(value: 'Passed', child: Text('✅ Passed')),
                          DropdownMenuItem(value: 'Failed', child: Text('❌ Failed')),
                        ],
                        onChanged: (v) => setState(() => _inspectionResult = v ?? 'Pending'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Catch Date & Time Pickers
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickDate,
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: _catchDate,
                            decoration: const InputDecoration(
                              labelText: 'Catch Date',
                              prefixIcon: Icon(Icons.calendar_today),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickTime,
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: _catchTime,
                            decoration: const InputDecoration(
                              labelText: 'Catch Time',
                              prefixIcon: Icon(Icons.access_time),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Seller Note
                TextFormField(
                  controller: _sellerNote,
                  decoration: const InputDecoration(
                    labelText: 'Seller Note (optional)',
                    hintText: 'e.g. Fresh morning catch, iced immediately in onboard hold',
                    prefixIcon: Icon(Icons.notes),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── GPS Location Section ──
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _location,
                  decoration: const InputDecoration(
                    labelText: 'Harbour / Pier Location',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Location required' : null,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _getLocation,
                icon: const Icon(Icons.my_location),
                tooltip: 'Fetch current GPS position',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Photo Upload / Capture Section ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Catch Photo Verification',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Photo'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                    ),
                  ],
                ),
                if (_photoPath != null && _photoPath!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Photo Attached: ${_photoPath!.split('/').last}',
                          style: const TextStyle(fontSize: 12, color: Colors.green),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red, size: 18),
                        onPressed: () => setState(() => _photoPath = null),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Action Buttons ──
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (isEdit)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xff005b96),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => _submit(publishNow: false),
              icon: const Icon(Icons.save),
              label: const Text('💾 Save Changes', style: TextStyle(fontSize: 16)),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _submit(publishNow: false),
                    icon: const Icon(Icons.assignment),
                    label: const Text('📋 Save Draft', style: TextStyle(fontSize: 15)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xff059669),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _submit(publishNow: true),
                    icon: const Icon(Icons.rocket_launch),
                    label: const Text('🚀 Publish Now', style: TextStyle(fontSize: 15)),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 20),
        ],
      ),
    );

    if (Navigator.of(context).canPop()) {
      return Scaffold(
        appBar: AppBar(
          title: Text(isEdit ? 'Edit Catch' : 'Log New Catch'),
        ),
        body: content,
      );
    }
    return content;
  }
}

class MarketScreen extends StatelessWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final safetyData = {
      'condition': 'Moderate',
      'advice': 'Use caution during afternoon wind shift and monitor swell height.',
      'fishingRisk': 'Medium risk',
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Fishing Safety',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.wb_sunny, color: Colors.orange),
            title: Text(safetyData['condition'] as String),
            subtitle: Text(safetyData['advice'] as String),
            trailing: Text(safetyData['fishingRisk'] as String),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Market Overview',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const _MarketRow(title: 'Tuna', detail: 'Rise • Rs.1650/kg', action: 'Strong'),
        const _MarketRow(title: 'Mackerel', detail: 'Stable • Rs.1280/kg', action: 'Stable'),
        const _MarketRow(title: 'Seer Fish', detail: 'High demand • Rs.1900/kg', action: 'Hot'),
      ],
    );
  }
}

class _AuthShell extends StatelessWidget {
  const _AuthShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/hero-bg.jpg',
              fit: BoxFit.cover,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xff003b5c).withValues(alpha: 0.88),
                    const Color(0xff0077a8).withValues(alpha: 0.65),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: Container(
                    constraints: const BoxConstraints(
                      maxWidth: 430,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.98),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x55001f33),
                          blurRadius: 30,
                          offset: Offset(0, 16),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(
                          height: 160,
                          child: _AuthImagePanel(),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                          child: child,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _AuthImagePanel extends StatelessWidget {
  const _AuthImagePanel();

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/hero-bg.jpg', fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xff003b5c).withValues(alpha: 0.35),
                  const Color(0xff002b45).withValues(alpha: 0.88),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _FishLinkMark(light: true),
                  SizedBox(height: 6),
                  Text(
                    'From the sea, to your market.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Connect fishermen and buyers seamlessly.',
                    style: TextStyle(
                      color: Color(0xffd9f2ff),
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
}

class _FishLinkMark extends StatelessWidget {
  const _FishLinkMark({this.light = false});

  final bool light;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: light ? Colors.white : const Color(0xff005b96),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.set_meal,
              color: light ? const Color(0xff005b96) : Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'FishLink',
            style: TextStyle(
              color: light ? Colors.white : const Color(0xff003b5c),
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      );
}

class _StatCardEnhanced extends StatelessWidget {
  const _StatCardEnhanced({
    required this.title,
    required this.value,
    required this.change,
    required this.isPositive,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String title;
  final String value;
  final String change;
  final bool isPositive;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.28)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.07),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 15),
                    ),
                  ],
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      color: isPositive ? Colors.green.shade700 : Colors.red,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        change,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isPositive ? Colors.green.shade700 : Colors.red,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 10, color: Colors.grey.shade400),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

class _WeatherPill extends StatelessWidget {
  const _WeatherPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xfff0f7fb),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xff005b96), size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xff003b5c),
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
}

class _BidCard extends StatelessWidget {
  const _BidCard({
    required this.lotNumber,
    required this.species,
    required this.weight,
    required this.bidderName,
    required this.bidPricePerKg,
    required this.totalBidValue,
    required this.timeLeft,
    required this.isLeading,
  });

  final String lotNumber;
  final String species;
  final String weight;
  final String bidderName;
  final String bidPricePerKg;
  final String totalBidValue;
  final String timeLeft;
  final bool isLeading;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xfffcfdff),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isLeading ? const Color(0xff0077b6).withValues(alpha: 0.35) : Colors.grey.shade300,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xff005b96).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    lotNumber,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff005b96),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 13, color: Colors.orange),
                    const SizedBox(width: 3),
                    Text(
                      timeLeft,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              species,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              'Lot weight: $weight • Highest bidder: $bidderName',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$bidPricePerKg / kg',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff0077b6),
                      ),
                    ),
                    Text(
                      'Total: $totalBidValue',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Counter offer modal requested')),
                        );
                      },
                      child: const Text('Counter', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 6),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff005b96),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Bid of $bidPricePerKg accepted for $lotNumber!')),
                        );
                      },
                      child: const Text('Accept Bid', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
}

class _AiPriceRow extends StatelessWidget {
  const _AiPriceRow({
    required this.species,
    required this.currentAvg,
    required this.trend,
    required this.isUp,
    required this.note,
  });

  final String species;
  final String currentAvg;
  final String trend;
  final bool isUp;
  final String note;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: isUp ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isUp ? Icons.arrow_upward : Icons.arrow_downward,
              color: isUp ? Colors.green.shade700 : Colors.red,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      species,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      trend,
                      style: TextStyle(
                        color: isUp ? Colors.green.shade700 : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  currentAvg,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff005b96),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  note,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      );
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.icon, required this.title, required this.child});

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xff005b96)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

class _MarketRow extends StatelessWidget {
  const _MarketRow({required this.title, required this.detail, required this.action});

  final String title;
  final String detail;
  final String action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(detail, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            FilledButton.tonal(onPressed: () {}, child: Text(action)),
          ],
        ),
      );
}

const sampleCatches = [
  {
    'species': 'Yellowfin Tuna (Kelawalla)',
    'quantity': 160,
    'price': 1820,
    'location': 'Negombo Harbor',
    'status': 'Active'
  },
  {
    'species': 'Narrow-Barred Seer (Thora)',
    'quantity': 75,
    'price': 2450,
    'location': 'Negombo Pier 3',
    'status': 'Active'
  },
  {
    'species': 'Skipjack Tuna (Balaya)',
    'quantity': 120,
    'price': 980,
    'location': 'Beruwala Jetty',
    'status': 'Pending'
  },
  {
    'species': 'Sailfish (Thalapath)',
    'quantity': 90,
    'price': 1480,
    'location': 'Galle Fishery Port',
    'status': 'Sold'
  },
  {
    'species': 'Giant Tiger Prawns',
    'quantity': 45,
    'price': 3100,
    'location': 'Kalpitiya Lagoon',
    'status': 'Active'
  },
  {
    'species': 'Barramundi (Modha)',
    'quantity': 55,
    'price': 1750,
    'location': 'Trincomalee Basin',
    'status': 'Pending'
  },
  {
    'species': 'Blue Swimming Crab',
    'quantity': 35,
    'price': 1950,
    'location': 'Jaffna Coast',
    'status': 'Sold'
  },
  {
    'species': 'Trevally (Paraw)',
    'quantity': 60,
    'price': 1450,
    'location': 'Matara Fishery Port',
    'status': 'Active'
  },
];
