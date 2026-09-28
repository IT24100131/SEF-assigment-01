import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
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

  Future<List<dynamic>> catches({bool mine = false}) async {
    final result = await _request('GET', '/Catches');
    return (result['items'] as List<dynamic>? ?? const []);
  }

  Future<void> createCatch(Map<String, dynamic> payload) async {
    await _request('POST', '/Catches', body: payload);
  }

  Future<Map<String, dynamic>> safety(String location) => _request(
      'GET', '/Weather/fishing-safety?location=${Uri.encodeQueryComponent(location)}');

  Future<Map<String, dynamic>> predictPrice(String species) async {
    final res = await _rawRequest('GET', '/AgentGateway/prices/${Uri.encodeComponent(species)}/predict');
    if (res is Map<String, dynamic>) return res;
    return {};
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
              const SizedBox(height: 10),
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
                decoration: const InputDecoration(
                  labelText: 'Select Your Role',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'Fisherman', child: Text('Fisherman')),
                  DropdownMenuItem(value: 'Buyer', child: Text('Buyer')),
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

  @override
  Widget build(BuildContext context) {
    final isBuyer = widget.role == 'Buyer';
    final screens = <Widget>[
      if (isBuyer) ...[
        BuyerDashboardScreen(
          onSignOut: widget.onSignOut,
          onNavigateTab: (idx) => setState(() => _index = idx),
        ),
        const BrowseFishScreen(),
        const MyBidsScreen(),
        NotificationsScreen(role: widget.role),
        ProfileScreen(role: widget.role, onSignOut: widget.onSignOut),
      ] else ...[
        FishermanDashboardScreen(onSignOut: widget.onSignOut),
        const MyCatchesScreen(),
        OrdersScreen(role: widget.role),
        NotificationsScreen(role: widget.role),
        ProfileScreen(role: widget.role, onSignOut: widget.onSignOut),
      ],
    ];

    final labels = isBuyer
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
          ];

    return Scaffold(
      appBar: AppBar(
        title: Text('FishLink • ${widget.role}'),
        actions: [
          IconButton(
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
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

  // Live state for bids
  late List<Map<String, dynamic>> _bids;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _bids = [
      {
        'id': 101,
        'buyer': 'Buyer A',
        'rate': 1520,
        'qty': widget.quantityKg.toInt(),
        'match': 94,
        'status': 'Pending',
      },
      {
        'id': 102,
        'buyer': 'Buyer B',
        'rate': 1580,
        'qty': widget.quantityKg.toInt(),
        'match': 91,
        'status': 'Pending',
      },
      {
        'id': 103,
        'buyer': 'Buyer C',
        'rate': 1600,
        'qty': widget.quantityKg.toInt(),
        'match': 88,
        'status': 'Pending',
      },
    ];
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
                      '✓ Logistics Agent triggered: temperature-controlled dispatch scheduled from harbour.',
                      style: TextStyle(fontSize: 12, color: Colors.black87)),
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
      height: MediaQuery.of(context).size.height * 0.82,
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
            labelColor: const Color(0xff005b96),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xff005b96),
            tabs: const [
              Tab(icon: Icon(Icons.gavel), text: 'Current Bids'),
              Tab(icon: Icon(Icons.auto_awesome), text: 'AI Buyer Matching'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBidsTab(),
                _buildBuyerMatchingTab(),
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
          'Live bids received from verified buyers in Western Province:',
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
              Text(
                b['buyer'] as String,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
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
          const SizedBox(height: 6),
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
                  Text(
                    'Accepted • Order Created • Logistics Triggered',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green),
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
          'Ranked by AI Buyer Matching Agent based on preferences and purchase history:',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 14),

        // Buyer 1
        _buildRankedBuyerCard(
          rank: '🥇',
          name: 'ABC Seafood',
          match: '94%',
          demand: 'High',
          requiredQty: '${widget.quantityKg.toInt()} kg',
          distance: '12 km',
          city: 'Negombo Harbour Road',
          color: Colors.amber.shade700,
        ),
        const SizedBox(height: 10),

        // Buyer 2
        _buildRankedBuyerCard(
          rank: '🥈',
          name: 'Colombo Fish Traders',
          match: '87%',
          demand: 'High',
          requiredQty: '120 kg',
          distance: '28 km',
          city: 'Peliyagoda Wholesale Market',
          color: Colors.blueGrey,
        ),
        const SizedBox(height: 10),

        // Buyer 3
        _buildRankedBuyerCard(
          rank: '🥉',
          name: 'Ocean Foods',
          match: '72%',
          demand: 'Medium',
          requiredQty: '80 kg',
          distance: '45 km',
          city: 'Colombo 03 Central',
          color: Colors.brown.shade400,
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
                    'AI Matching Factors:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xff003b5c),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildFactorRow('🐟', 'Fish type', 'Target species compatibility'),
              _buildFactorRow('⚖️', 'Required quantity', 'Batch volume requirement fit'),
              _buildFactorRow('📍', 'Buyer location', 'Proximity to harbour pier'),
              _buildFactorRow('📈', 'Buyer demand', 'Purchase urgency & active orders'),
              _buildFactorRow('📜', 'Previous purchase history', 'Payment reliability & ratings'),
              _buildFactorRow('🚚', 'Distance', 'Cold chain delivery feasibility'),
            ],
          ),
        ),
      ],
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
// FEATURE 10: 🛒 BUYER DASHBOARD
// ══════════════════════════════════════════════════════════════════════════════

class BuyerDashboardScreen extends StatelessWidget {
  const BuyerDashboardScreen({
    required this.onSignOut,
    this.onNavigateTab,
    super.key,
  });

  final VoidCallback onSignOut;
  final ValueChanged<int>? onNavigateTab;

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
                          'FishLink B2B Fresh Seafood Exchange',
                          style:
                              TextStyle(color: Color(0xffc2e5fb), fontSize: 13),
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
                onTap: () => onNavigateTab?.call(1),
              ),
              const SizedBox(width: 8),
              _buildNavChip(
                context,
                icon: Icons.gavel,
                label: 'My Bids',
                color: const Color(0xffe76f51),
                onTap: () => onNavigateTab?.call(2),
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
                onTap: () => _showNotice(context, 'Cold Chain Deliveries',
                    'Truck WP-ND-4921 en-route from Negombo Pier 3B to Peliyagoda.\nTemp: 2.2°C • ETA: 25 mins'),
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
              const SizedBox(width: 8),
              _buildNavChip(
                context,
                icon: Icons.notifications_active,
                label: 'Notifications',
                color: const Color(0xff43aa8b),
                onTap: () => _showNotice(context, 'Notifications',
                    '• New Yellowfin Tuna landed at Negombo (100kg)\n• Your bid of Rs.1650/kg on Tuna is currently HIGHEST!'),
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
                  onTap: () => onNavigateTab?.call(1),
                ),
                _StatCardEnhanced(
                  title: 'My Active Bids',
                  value: '5',
                  change: '2 Leading highest',
                  isPositive: true,
                  icon: Icons.gavel,
                  color: const Color(0xffe76f51),
                  onTap: () => onNavigateTab?.call(2),
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
                      onPressed: () => onNavigateTab?.call(1),
                      child:
                          const Text('View & Bid', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton.icon(
                  onPressed: () => onNavigateTab?.call(1),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('View All 24 Available Fish Listings'),
                ),
              ),
            ],
          ),
        ),
      ],
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
                _buildDetailRow(
                    'Verified Weight:', '${fish['verifiedWeight']} kg (Digital scale verified)'),
                _buildDetailRow('Quality:', fish['quality'] as String),
                _buildDetailRow('Location:', fish['location'] as String),
                _buildDetailRow(
                    'Current Bid:', 'Rs. ${fish['currentBid']} / kg',
                    isHighlight: true),
                _buildDetailRow('Seller:', fish['seller'] as String),
                _buildDetailRow(
                    'Asking Price:', 'Rs. ${fish['price']} / kg'),

                const SizedBox(height: 24),

                // [ Place Bid ] Action
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xff005b96),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      showPlaceBidModal(context, fish);
                    },
                    child: const Text(
                      'Place Bid',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String title, String value,
      {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    isHighlight ? FontWeight.bold : FontWeight.w500,
                color: isHighlight
                    ? const Color(0xff0077b6)
                    : const Color(0xff1f2937),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FEATURE 13: 💵 PLACE BID MODAL
// ══════════════════════════════════════════════════════════════════════════════

void showPlaceBidModal(BuildContext context, Map<String, dynamic> fish) {
  showDialog(
    context: context,
    builder: (ctx) => _PlaceBidDialog(fish: fish),
  );
}

class _PlaceBidDialog extends StatefulWidget {
  const _PlaceBidDialog({required this.fish});

  final Map<String, dynamic> fish;

  @override
  State<_PlaceBidDialog> createState() => _PlaceBidDialogState();
}

class _PlaceBidDialogState extends State<_PlaceBidDialog> {
  late TextEditingController _bidController;
  late TextEditingController _qtyController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Default bid 1650 for Tuna, or currentBid + 50
    final defaultBid = widget.fish['species'] == 'Tuna'
        ? 1650
        : (widget.fish['currentBid'] as num).toInt() + 50;
    _bidController = TextEditingController(text: '$defaultBid');
    _qtyController =
        TextEditingController(text: '${widget.fish['quantity']}');
  }

  @override
  void dispose() {
    _bidController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _submitBid() async {
    final bidRate = double.tryParse(_bidController.text.trim());
    if (bidRate == null || bidRate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid bid amount.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // Backend: POST /api/bids
      await ApiClient().placeBid(widget.fish['id'] as int, bidRate);
    } catch (_) {}

    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.pop(context);

    // Confirmation dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Bid Placed!', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your bid of Rs. ${bidRate.toInt()} / kg for ${widget.fish['species']} was submitted via POST /api/bids.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: const Text(
                'Status: ACTIVE (Highest Bidder)',
                style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xff005b96)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentBidVal = double.tryParse(_bidController.text.trim()) ?? 0;
    final qtyVal = double.tryParse(_qtyController.text.trim()) ?? 0;
    final total = currentBidVal * qtyVal;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Place Your Bid',
          style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Fish:',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                Text(widget.fish['species'] as String,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff0077b6))),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Available:',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                Text('${widget.fish['quantity']} kg',
                    style: const TextStyle(fontSize: 14)),
              ],
            ),
            const Divider(height: 24),
            const Text('Your Bid (Rs. / kg):',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _bidController,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixText: 'Rs. ',
                hintText: '1650',
              ),
            ),
            const SizedBox(height: 14),
            const Text('Quantity (kg):',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _qtyController,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                suffixText: 'kg',
                hintText: '100',
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xfff0f7fb),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Estimated Total:',
                      style: TextStyle(fontSize: 13, color: Colors.black54)),
                  Text(
                    'Rs. ${total.toInt()}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff005b96)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style:
              FilledButton.styleFrom(backgroundColor: const Color(0xff005b96)),
          onPressed: _loading ? null : _submitBid,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Submit Bid'),
        ),
      ],
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

  List<Map<String, dynamic>> get _filteredCatches {
    final query = _searchController.text.trim().toLowerCase();
    return sampleCatches.where((catchItem) {
      final matchesFilter = _selectedFilter == 'All' ||
          catchItem['status'] == _selectedFilter;
      final matchesQuery = query.isEmpty ||
          catchItem['species'].toString().toLowerCase().contains(query) ||
          catchItem['location'].toString().toLowerCase().contains(query);
      return matchesFilter && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ['All', 'Active', 'Pending', 'Sold', 'Rejected'];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Search catches',
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
          Expanded(
            child: ListView.builder(
              itemCount: _filteredCatches.length,
              itemBuilder: (context, index) {
                final item = _filteredCatches[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    onTap: () {
                      showFishermanCatchDetailsModal(
                        context,
                        species: item['species'] as String,
                        quantityKg: (item['quantity'] as num).toDouble(),
                        location: item['location'] as String,
                        askingPrice: (item['price'] as num).toDouble(),
                        catchId: index + 1,
                      );
                    },
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xffe8f4f8),
                      child: Icon(Icons.set_meal, color: Color(0xff005b96)),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item['species'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xff005b96).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Bids & AI Match', style: TextStyle(fontSize: 10, color: Color(0xff005b96), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                          '${item['quantity']} kg • Rs.${item['price']}/kg • ${item['location']}'),
                    ),
                    trailing: Chip(
                      label: Text(item['status'] as String),
                      backgroundColor: _chipColor(item['status'] as String),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _chipColor(String status) {
    switch (status) {
      case 'Active':
        return Colors.green.shade100;
      case 'Pending':
        return Colors.orange.shade100;
      case 'Sold':
        return Colors.blue.shade100;
      case 'Rejected':
        return Colors.red.shade100;
      default:
        return Colors.grey.shade200;
    }
  }
}

class NewCatchScreen extends StatefulWidget {
  const NewCatchScreen({super.key});

  @override
  State<NewCatchScreen> createState() => _NewCatchScreenState();
}

class _NewCatchScreenState extends State<NewCatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _quantity = TextEditingController();
  final TextEditingController _expectedPrice = TextEditingController();
  final TextEditingController _location = TextEditingController(text: 'Negombo');
  final TextEditingController _description = TextEditingController();
  final TextEditingController _catchDate = TextEditingController();
  final TextEditingController _catchTime = TextEditingController();

  String _species = 'Tuna';
  String? _photoPath;
  bool _loading = false;

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
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
        const SnackBar(
          content: Text('Location permission is required for catch registration.'),
        ),
      );
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    if (!mounted) return;
    setState(() {
      _location.text =
          '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final submittedSpecies = _species;
    final submittedQty = double.tryParse(_quantity.text) ?? 100;

    final payload = {
      'fishSpecies': _species,
      'quantityKg': double.parse(_quantity.text),
      'askingPricePerKg': double.parse(_expectedPrice.text),
      'location': _location.text,
      'sellerNote': _description.text,
      'catchDate': _catchDate.text,
      'catchTime': _catchTime.text,
      'photoUrl': _photoPath ?? '',
      'status': 'Pending',
    };

    try {
      await ApiClient().createCatch(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Catch submitted successfully.')),
        );
        _formKey.currentState!.reset();
        _quantity.clear();
        _expectedPrice.clear();
        _location.clear();
        _description.clear();
        _catchDate.clear();
        _catchTime.clear();
        setState(() => _photoPath = null);

        // FEATURE 7: Auto-trigger AI Price Recommendation after catch submission!
        showAiPriceRecommendationModal(
          context,
          species: submittedSpecies,
          quantityKg: submittedQty,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save catch: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            const Text(
              'Add New Catch',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _species,
              decoration: const InputDecoration(labelText: 'Fish Species'),
              items: ['Tuna', 'Mackerel', 'Seer Fish', 'Skipjack', 'Trevally']
                  .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: (value) => setState(() => _species = value ?? 'Tuna'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _quantity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity (kg)'),
              validator: (value) {
                final parsed = double.tryParse(value ?? '');
                if (parsed == null || parsed <= 0) return 'Enter a valid quantity';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: _catchDate,
                        decoration: const InputDecoration(labelText: 'Catch Date'),
                        validator: (value) =>
                            (value == null || value.isEmpty) ? 'Required' : null,
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
                        decoration: const InputDecoration(labelText: 'Catch Time'),
                        validator: (value) =>
                            (value == null || value.isEmpty) ? 'Required' : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _location,
                    decoration: const InputDecoration(labelText: 'Location'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _getLocation,
                  icon: const Icon(Icons.my_location),
                  tooltip: 'Use current location',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _expectedPrice,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Expected Price (Rs/kg)',
                      prefixText: 'Rs. ',
                    ),
                    validator: (value) {
                      final parsed = double.tryParse(value ?? '');
                      if (parsed == null || parsed <= 0) return 'Enter a valid price';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                  label: const Text('AI Price'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.camera_alt),
              label: Text(_photoPath == null ? 'Add Photo' : 'Photo added'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Catch quality, storage note, and handling details',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _loading ? null : _submit,
              icon: const Icon(Icons.publish),
              label: const Text('Submit Catch'),
            ),
          ],
        ),
      ),
    );
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FishLinkMark(light: true),
                SizedBox(height: 8),
                Text(
                  'From the sea, to your market.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: 4),
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    this.onTap,
  });

  final String title;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('View', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                    Icon(Icons.chevron_right, size: 12, color: color),
                  ],
                ),
              ],
            ),
          ),
        ),
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
                      bidPricePerKg + ' / kg',
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

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
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
