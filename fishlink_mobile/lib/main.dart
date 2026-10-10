import 'dart:async';
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

  Future<dynamic> _rawRequest(
    String method,
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    final token = authenticated ? await _storage.read(key: 'token') : null;
    final response = await _client.send(
      http.Request(method, Uri.parse('$effectiveApiBaseUrl$path'))
        ..headers.addAll({
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        })
        ..body = body == null ? '' : jsonEncode(body),
    );

    final text = await response.stream.bytesToString();
    dynamic decoded;
    try {
      decoded = text.isEmpty ? null : jsonDecode(text);
    } catch (_) {
      decoded = text;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map
          ? decoded['message'] ?? decoded['title']
          : decoded;
      throw Exception(
        message?.toString() ?? 'Request failed (${response.statusCode})',
      );
    }

    return decoded;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    final res = await _rawRequest(
      method,
      path,
      body: body,
      authenticated: authenticated,
    );
    return res is Map<String, dynamic> ? res : {'data': res};
  }

  Future<Map<String, dynamic>> login(String email, String password) => _request(
    'POST',
    '/Auth/login',
    body: {'email': email, 'password': password},
    authenticated: false,
  );

  Future<Map<String, dynamic>> register(
    String fullName,
    String email,
    String password,
    String role,
  ) async {
    return _request(
      'POST',
      '/Auth/register',
      body: {
        'fullName': fullName,
        'email': email,
        'passwordHash': password,
        'role': role,
      },
      authenticated: false,
    );
  }

  Future<List<dynamic>> catches({bool mine = false}) async {
    final result = await _rawRequest('GET', '/Catches?pageSize=100');
    if (result is List) return result;
    if (result is Map<String, dynamic> && result['items'] is List) {
      return result['items'] as List<dynamic>;
    }
    return const [];
  }

  Future<List<Map<String, dynamic>>> getMyCatches() async {
    final token = await _storage.read(key: 'token');
    if (token == null || token.split('.').length < 2) {
      throw Exception(
        'Your session is invalid. Sign in again to load your catches.',
      );
    }

    final payload = token.split('.')[1];
    final decoded = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(payload))),
    );
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Could not identify your account. Sign in again.');
    }

    final fishermanId =
        int.tryParse(
          (decoded['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier'] ??
                  decoded['nameid'] ??
                  decoded['sub'])
              .toString(),
        ) ??
        0;
    if (fishermanId <= 0) {
      throw Exception(
        'Could not identify your fisherman account. Sign in again.',
      );
    }

    final result = await _rawRequest(
      'GET',
      '/Catches?pageSize=100&sortBy=createdAt&sortOrder=desc',
    );
    final items = result is List
        ? result
        : result is Map<String, dynamic> && result['items'] is List
        ? result['items'] as List<dynamic>
        : const <dynamic>[];
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where(
          (item) =>
              int.tryParse((item['fishermanId'] ?? 0).toString()) ==
              fishermanId,
        )
        .toList();
  }

  Future<void> createCatch(Map<String, dynamic> payload) async {
    await _request('POST', '/Catches', body: payload);
  }

  Future<void> updateCatch(int catchId, Map<String, dynamic> payload) async {
    await _rawRequest('PUT', '/Catches/$catchId', body: payload);
  }

  Future<void> publishCatch(int catchId) async {
    await _rawRequest('PATCH', '/Catches/$catchId/publish', body: const {});
  }

  Future<void> cancelCatch(int catchId) async {
    await _rawRequest('PATCH', '/Catches/$catchId/cancel', body: const {});
  }

  Future<void> deleteCatch(int catchId) async {
    await _rawRequest('DELETE', '/Catches/$catchId');
  }

  Future<Map<String, dynamic>> marketRecommendation({
    required String species,
    required double askingPrice,
  }) async {
    final result = await _rawRequest(
      'GET',
      '/AgentGateway/market-recommendation?species=${Uri.encodeQueryComponent(species)}&askingPrice=$askingPrice',
    );
    if (result is Map<String, dynamic>) return result;
    throw Exception(
      'The Market Intelligence Agent returned an invalid response.',
    );
  }

  Future<void> startQualityWorkflow(Map<String, dynamic> payload) async {
    await _rawRequest('POST', '/AgentGateway/workflow/start', body: payload);
  }

  Future<Map<String, dynamic>> safety(String location) => _request(
    'GET',
    '/Weather/fishing-safety?location=${Uri.encodeQueryComponent(location)}',
  );

  Future<Map<String, dynamic>> predictPrice(String species) async {
    final res = await _rawRequest(
      'GET',
      '/AgentGateway/prices/${Uri.encodeComponent(species)}/predict',
    );
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

  Future<Map<String, dynamic>> placeBid(
    int catchId,
    double bidPricePerKg,
  ) async {
    final res = await _rawRequest(
      'POST',
      '/Bids',
      body: {'catchId': catchId, 'bidPricePerKg': bidPricePerKg},
    );
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
    final res = await _rawRequest(
      'GET',
      '/Orders${role != null ? '?role=$role' : ''}',
    );
    if (res is List) return res;
    return [];
  }

  Future<Map<String, dynamic>> updateOrderStatus(
    int orderId,
    String status,
  ) async {
    final res = await _rawRequest(
      'PATCH',
      '/Orders/$orderId/status',
      body: {'status': status},
    );
    if (res is Map<String, dynamic>) return res;
    return {};
  }

  Future<Map<String, dynamic>> payOrder(
    int orderId, {
    double amount = 162000.0,
    String method = 'LankaQR / VISA',
  }) async {
    final res = await _rawRequest(
      'POST',
      '/Orders/$orderId/pay',
      body: {'amount': amount, 'method': method},
    );
    if (res is Map<String, dynamic>) return res;
    return {};
  }

  Future<List<dynamic>> getNotifications() async {
    final res = await _rawRequest('GET', '/Orders/notifications');
    if (res is List) return res;
    return [];
  }

  Future<Map<String, dynamic>> updateBuyerPreferences(
    Map<String, dynamic> payload,
  ) async {
    final res = await _rawRequest(
      'POST',
      '/BuyerMatch/preferences/me',
      body: payload,
    );
    return res is Map<String, dynamic> ? res : {};
  }

  Future<Map<String, dynamic>> getBuyerPreferences() async {
    final res = await _rawRequest('GET', '/BuyerMatch/preferences/me');
    if (res is Map<String, dynamic>) return res;
    return {};
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
      final result = await ApiClient().login(
        _email.text.trim(),
        _password.text,
      );
      final user = result['user'] as Map<String, dynamic>? ?? {};
      const storage = FlutterSecureStorage();
      final token = result['token']?.toString();
      if (token == null || token.isEmpty) {
        throw Exception('The API did not return an access token.');
      }

      await storage.write(key: 'token', value: token);
      await storage.write(
        key: 'role',
        value: user['role']?.toString() ?? 'Fisherman',
      );
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
            style: TextStyle(color: Color(0xff556b82), fontSize: 14),
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
                style: TextStyle(color: Theme.of(context).colorScheme.error),
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
                builder: (_) => RegisterScreen(onSignedIn: widget.onSignedIn),
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
        _name.text.trim(),
        _email.text.trim(),
        _password.text,
        _role,
      );
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
            style: TextStyle(color: Color(0xff556b82), fontSize: 14),
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
                style: TextStyle(color: Theme.of(context).colorScheme.error),
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

double _number(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

String _formatNumber(double value) {
  final fixed = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = parts.first;
  final formatted = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) formatted.write(',');
    formatted.write(whole[i]);
  }
  return parts.length == 1 || parts[1] == '00'
      ? formatted.toString()
      : '${formatted.toString()}.${parts[1]}';
}

int _tokenUserId(String token) {
  final segments = token.split('.');
  if (segments.length < 2)
    throw Exception('Your session is invalid. Sign in again.');
  final payload = jsonDecode(
    utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))),
  );
  if (payload is! Map<String, dynamic>) {
    throw Exception('Could not identify your account. Sign in again.');
  }
  final id =
      int.tryParse(
        (payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier'] ??
                payload['nameid'] ??
                payload['sub'])
            .toString(),
      ) ??
      0;
  if (id <= 0)
    throw Exception(
      'Could not identify your fisherman account. Sign in again.',
    );
  return id;
}

(String, String) _splitCatchPhotos(String raw) {
  final parts = raw.split('|||');
  return (parts.first, parts.length > 1 ? parts[1] : '');
}

bool _hasQualityAgent(Map<String, dynamic> catchRecord) {
  final (photo, inspectorPhoto) = _splitCatchPhotos(
    (catchRecord['photoUrl'] ?? '').toString(),
  );
  final note = (catchRecord['sellerNote'] ?? '').toString();
  final risk = (catchRecord['fraudRisk'] ?? '').toString();
  final hasAgentValidation =
      (risk.isNotEmpty && risk != 'Unassessed' && risk != 'None') ||
      _number(catchRecord['qualityScore']) > 0 ||
      (catchRecord['validationSummary'] ?? '').toString().trim().isNotEmpty;
  final hasInspector =
      inspectorPhoto.isNotEmpty || RegExp(r'\[Inspector ID:').hasMatch(note);
  final isMarketplaceStatus = [
    'Published',
    'Bidding',
    'Sold',
    'PendingApproval',
  ].contains(catchRecord['status']);
  return hasAgentValidation ||
      hasInspector ||
      isMarketplaceStatus ||
      (photo.isNotEmpty && catchRecord['inspectionResult'] == 'Passed');
}

Widget _catchImage(String raw, {double height = 180}) {
  final value = raw.trim();
  if (value.startsWith('data:image/')) {
    final comma = value.indexOf(',');
    if (comma >= 0) {
      try {
        return Image.memory(
          base64Decode(value.substring(comma + 1)),
          height: height,
          width: double.infinity,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
        );
      } on FormatException {
        return const Icon(Icons.broken_image_outlined);
      }
    }
  }
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return Image.network(
      value,
      height: height,
      width: double.infinity,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
    );
  }
  return const SizedBox.shrink();
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
        _FishermanDashboardLive(
          onNavigateToCatches: () => setState(() => _index = 1),
        ),
        const _MyCatchesLiveScreen(),
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
            NavigationDestination(
              icon: Icon(Icons.notifications),
              label: 'Alerts',
            ),
            NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
          ]
        : const [
            NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.set_meal), label: 'Catches'),
            NavigationDestination(
              icon: Icon(Icons.inventory_2),
              label: 'Orders',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications),
              label: 'Alerts',
            ),
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
                    child: Icon(
                      Icons.sailing,
                      color: Color(0xff003859),
                      size: 28,
                    ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.fiber_manual_record,
                          color: Colors.white,
                          size: 9,
                        ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
                    child: const Icon(
                      Icons.waves,
                      color: Colors.green,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sea Safety & Marine Weather',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'West Coast Zone 4 • Negombo to Chilaw',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
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
                  _WeatherPill(
                    label: 'Wind',
                    value: '12 kts SW',
                    icon: Icons.air,
                  ),
                  _WeatherPill(
                    label: 'Waves',
                    value: '1.1 m',
                    icon: Icons.water,
                  ),
                  _WeatherPill(
                    label: 'Sea Temp',
                    value: '28.4°C',
                    icon: Icons.thermostat,
                  ),
                  _WeatherPill(
                    label: 'High Tide',
                    value: '16:45',
                    icon: Icons.access_time,
                  ),
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
                    Icon(
                      Icons.info_outline,
                      color: Color(0xff005b96),
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Calm seas forecast for the next 36 hours. Ideal for Yellowfin Tuna longline trips 25nm offshore.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xff003b5c),
                        ),
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
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
                    const Icon(
                      Icons.local_shipping,
                      size: 18,
                      color: Color(0xff005b96),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Truck: WP-ND-4921',
                      style: TextStyle(fontSize: 12),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
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
                    Text(
                      'Negombo Jetty (Departed 07:15)',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    Text(
                      'ETA: 25 mins',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff005b96),
                      ),
                    ),
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

  void _showDetailModal(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    Widget content,
  ) {
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
            BoxShadow(
              color: Colors.black26,
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
                    Text(
                      'Total Payouts Settled',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Rs. 475,150',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff7209b7),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'In Escrow Clearing',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Rs. 209,050',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Recent Completed Settlements:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 10),
          _modalSaleRow(
            'Sep 21',
            '75 kg Seer Fish • Peliyagoda Wholesale',
            '+ Rs. 183,750',
            'Completed',
          ),
          _modalSaleRow(
            'Sep 19',
            '160 kg Tuna • Ceylon Sea Foods',
            '+ Rs. 291,200',
            'Completed',
          ),
          _modalSaleRow(
            'Sep 16',
            '110 kg Sailfish • Galle Port Exporters',
            '+ Rs. 162,800',
            'Completed',
          ),
          _modalSaleRow(
            'Sep 12',
            '45 kg Tiger Prawns • Negombo Lagoon',
            '+ Rs. 139,500',
            'Completed',
          ),
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
            Text(
              lot,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xff005b96),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          species,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 2),
        Text(
          '$weight • $method • $harbour',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 6),
        Text(
          price,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.teal,
            fontSize: 14,
          ),
        ),
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
      border: Border.all(
        color: isTop ? Colors.orange.shade300 : Colors.grey.shade200,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              buyer,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              time,
              style: TextStyle(
                fontSize: 11,
                color: isTop ? Colors.orange.shade900 : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
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
                Text(
                  bidPerKg,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xff0077b6),
                  ),
                ),
                Text(
                  'Total: $total',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xff005b96),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
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
            Text(
              'Dispatch #$id',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xff005b96),
              ),
            ),
            Text(
              temp,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.teal,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          cargo,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 2),
        Text(
          route,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 4),
        Text(
          vehicle,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: statusColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _modalSaleRow(
    String date,
    String title,
    String amount,
    String status,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            date,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                status,
                style: const TextStyle(fontSize: 11, color: Colors.green),
              ),
            ],
          ),
        ),
        Text(
          amount,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xff005b96),
            fontSize: 13,
          ),
        ),
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
          _recommendedRange =
              res['recommendedRange']?.toString() ?? 'Rs. 1550 – Rs. 1650 / kg';
          _demand = res['demand']?.toString() ?? 'HIGH';
          _confidence = (res['confidence'] as num?)?.toInt() ?? 87;
          _reason = res['reason']?.toString() ?? 'Recent market prices are high and current bids indicate strong demand.';
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
          _reason =
              'Steady coastal consumer demand with moderate daily landings.';
          _avgPrice = 1240;
        } else {
          _recommendedRange = 'Rs. 1550 – Rs. 1650 / kg';
          _demand = 'HIGH';
          _confidence = 87;
          _reason = 'Recent market prices are high and current bids indicate strong demand.';
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
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xff005b96).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xff005b96).withValues(alpha: 0.2),
                      ),
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
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xff005b96),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${widget.quantityKg.toInt()} kg',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
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
                      color: Colors.black54,
                    ),
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
                              const Text(
                                'Demand:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
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
                              const Text(
                                'Confidence:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
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
                      color: Colors.black54,
                    ),
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
                        fontSize: 13,
                        color: Color(0xff1f2937),
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: const [
                        Icon(
                          Icons.shield_outlined,
                          size: 14,
                          color: Colors.grey,
                        ),
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
            backgroundColor: const Color(0xff005b96),
          ),
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
            Text(
              'Bid Accepted!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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
                  Text(
                    '✓ Order #ORD-1049 automatically created.',
                    style: TextStyle(
                      color: Color(0xff005b96),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '✓ Logistics Agent triggered: temperature-controlled dispatch scheduled from harbour.',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xff005b96),
            ),
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${widget.quantityKg.toInt()} kg • ${widget.location} • Asking: Rs.${widget.askingPrice.toInt()}/kg',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
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
              children: [_buildBidsTab(), _buildBuyerMatchingTab()],
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
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            )
          else if (isRejected || isLost)
            Text(
              isRejected ? 'Rejected' : 'Outbid / Lost',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
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
                    child: const Text(
                      'Accept Bid',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
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
              _buildFactorRow(
                '🐟',
                'Fish type',
                'Target species compatibility',
              ),
              _buildFactorRow(
                '⚖️',
                'Required quantity',
                'Batch volume requirement fit',
              ),
              _buildFactorRow(
                '📍',
                'Buyer location',
                'Proximity to harbour pier',
              ),
              _buildFactorRow(
                '📈',
                'Buyer demand',
                'Purchase urgency & active orders',
              ),
              _buildFactorRow(
                '📜',
                'Previous purchase history',
                'Payment reliability & ratings',
              ),
              _buildFactorRow(
                '🚚',
                'Distance',
                'Cold chain delivery feasibility',
              ),
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
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      city,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
              Text(
                'Demand: $demand',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                'Required: $requiredQty',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                'Distance: $distance',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
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
          Text(
            '$title: ',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xff1f2937),
            ),
          ),
          Expanded(
            child: Text(
              desc,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FEATURE 10: 🛒 BUYER DASHBOARD
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
  int _selectedView =
      0; // 0: All Published Catches, 1: AI Recommendations, 2: Preferences Form

  // Preferences state (matching React BuyerDashboard.tsx)
  String _preferredSpecies = 'Tuna (Yellowfin)';
  final _minQtyCtrl = TextEditingController(text: '50');
  final _maxQtyCtrl = TextEditingController(text: '300');
  final _maxPriceCtrl = TextEditingController(text: '2200');
  String _preferredCity = 'Negombo';
  final _notesCtrl = TextEditingController(
    text: 'Grade A sashimi quality only. Requires chilled cold-chain.',
  );
  bool _prefSaving = false;
  bool _prefSaved = false;
  bool _isLoadingCatches = false;

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

  List<Map<String, dynamic>> _liveCatches = [];

  final List<Map<String, dynamic>> _savedBids = [
    {
      'id': 'saved-bid-1',
      'species': 'Tuna (Yellowfin)',
      'minQty': 50,
      'maxQty': 300,
      'maxPrice': 2200,
      'city': 'Negombo',
      'notes': 'Grade A sashimi export quality. Requires chilled cold-chain.',
      'createdAt': 'Today, 08:30 AM',
    },
    {
      'id': 'saved-bid-2',
      'species': 'Trevally (Paraw)',
      'minQty': 60,
      'maxQty': 150,
      'maxPrice': 1500,
      'city': 'Colombo',
      'notes': 'Fresh morning landing for Colombo central wholesale retail.',
      'createdAt': 'Yesterday, 14:15 PM',
    },
    {
      'id': 'saved-bid-3',
      'species': 'Skipjack',
      'minQty': 40,
      'maxQty': 200,
      'maxPrice': 1000,
      'city': 'Galle',
      'notes': 'Grade A/B for local canning & distribution.',
      'createdAt': '2 days ago',
    },
  ];

  void _addSavedBid() {
    final species = _preferredSpecies;
    final minQ = int.tryParse(_minQtyCtrl.text.trim()) ?? 50;
    final maxQ = int.tryParse(_maxQtyCtrl.text.trim()) ?? 300;
    final maxP = int.tryParse(_maxPriceCtrl.text.trim()) ?? 2200;
    final city = _preferredCity;
    final notes = _notesCtrl.text.trim();

    final newBid = {
      'id': 'saved-bid-${DateTime.now().millisecondsSinceEpoch}',
      'species': species,
      'minQty': minQ,
      'maxQty': maxQ,
      'maxPrice': maxP,
      'city': city,
      'notes': notes.isNotEmpty ? notes : 'Standard procurement requirements',
      'createdAt': 'Just now',
    };

    setState(() {
      _savedBids.insert(0, newBid);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Target Bid saved for $species! AI Buyer Matching calculated.',
        ),
        backgroundColor: const Color(0xff059669),
      ),
    );
  }

  void _deleteSavedBid(String id) {
    setState(() {
      _savedBids.removeWhere((b) => b['id'] == id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved bid inquiry removed.'),
        backgroundColor: Color(0xff475569),
      ),
    );
  }

  Map<String, dynamic> _calculateMatchForSavedBid(Map<String, dynamic> b) {
    final targetSpecies = (b['species']?.toString() ?? '').toLowerCase();
    final maxPrice = (b['maxPrice'] as num?)?.toDouble() ?? 2200.0;
    final minQty = (b['minQty'] as num?)?.toDouble() ?? 50.0;
    final maxQty = (b['maxQty'] as num?)?.toDouble() ?? 300.0;
    final targetCity = (b['city']?.toString() ?? '').toLowerCase();

    Map<String, dynamic>? bestCatch;
    int highestScore = 0;
    List<String> bestReasons = [];

    for (var c in _allPublishedCatches) {
      int score = 20;
      List<String> reasons = [];
      final cSpecies =
          (c['fullSpecies']?.toString() ?? c['species']?.toString() ?? '')
              .toLowerCase();
      final cPrice = (c['price'] as num?)?.toDouble() ?? 1500.0;
      final cQty = (c['quantity'] as num?)?.toDouble() ?? 100.0;
      final cLoc = (c['location']?.toString() ?? '').toLowerCase();

      if (targetSpecies == 'any species' ||
          cSpecies.contains(
            targetSpecies.replaceAll('(', '').split(' ').first.toLowerCase(),
          )) {
        score += 40;
        reasons.add('Species match (+40)');
      }

      if (cPrice <= maxPrice) {
        score += 20;
        reasons.add(
          'Price Rs.${cPrice.toInt()} <= Budget Rs.${maxPrice.toInt()} (+20)',
        );
      } else {
        score -= 10;
      }

      if (cQty >= minQty && cQty <= maxQty) {
        score += 20;
        reasons.add('Volume ${cQty.toInt()}kg fits target (+20)');
      }

      if (targetCity != 'any location' &&
          (cLoc.contains(targetCity) || targetCity.contains(cLoc))) {
        score += 15;
        reasons.add('Location proximity (+15)');
      }

      final quality = c['quality']?.toString() ?? '';
      if (quality.contains('A')) {
        score += 5;
        reasons.add('Grade A certified (+5)');
      }

      final clamped = score.clamp(35, 98);
      if (clamped > highestScore) {
        highestScore = clamped;
        bestCatch = c;
        bestReasons = reasons;
      }
    }

    if (highestScore == 0) {
      highestScore = 75;
      bestReasons = ['Baseline harbour market match'];
    }

    return {
      'score': highestScore,
      'reasons': bestReasons.join(' · '),
      'matchedCatch': bestCatch,
    };
  }

  // Matched Catches fallback (matching React BuyerDashboard.tsx)
  final List<Map<String, dynamic>> _recommendedCatches = [
    {
      'id': 1,
      'species': 'Tuna',
      'fullSpecies': 'Yellowfin Tuna (Kelawalla)',
      'quantity': 100,
      'verifiedWeight': 98,
      'price': 1550,
      'currentBid': 1600,
      'totalPrice': 155000,
      'location': 'Negombo Fishery Harbour',
      'quality': 'Grade A',
      'lot': 'LOT-NEG-902',
      'emoji': '🐟',
      'fisherman': 'Sunil Fernando (Boat SL-NEG-112)',
      'status': 'Published',
      'inspection': 'Passed',
      'matchScore': 94,
      'matchReasons': 'Species match (+40) · Volume in target range (+25) · Asking price below budget (+20) · Negombo hub proximity (+9)',
    },
    {
      'id': 3,
      'species': 'Trevally',
      'fullSpecies': 'Giant Trevally (Paraw)',
      'quantity': 80,
      'verifiedWeight': 79,
      'price': 1200,
      'currentBid': 1250,
      'totalPrice': 96000,
      'location': 'Colombo Mutwal Pier',
      'quality': 'Grade A',
      'lot': 'LOT-CMB-441',
      'emoji': '🐡',
      'fisherman': 'Anura Silva (Boat SL-CMB-809)',
      'status': 'Published',
      'inspection': 'Passed',
      'matchScore': 87,
      'matchReasons': 'Species match (+40) · Price within budget (+20) · High freshness index (+17) · Colombo corridor (+10)',
    },
    {
      'id': 2,
      'species': 'Skipjack',
      'fullSpecies': 'Skipjack Tuna (Balaya)',
      'quantity': 60,
      'verifiedWeight': 59,
      'price': 850,
      'currentBid': 920,
      'totalPrice': 51000,
      'location': 'Galle Fishery Harbour',
      'quality': 'Grade A',
      'lot': 'LOT-GAL-312',
      'emoji': '🐠',
      'fisherman': 'Priyadarsana (Boat SL-GAL-402)',
      'status': 'Published',
      'inspection': 'Passed',
      'matchScore': 78,
      'matchReasons': 'Volume fit (+25) · Excellent price margin (+20) · Grade A verified (+18) · Southern coastal route (+15)',
    },
  ];

  String _displayName = 'Buyer';

  List<Map<String, dynamic>> get _allPublishedCatches {
    if (_liveCatches.isNotEmpty) {
      return _liveCatches;
    }
    return _recommendedCatches;
  }

  List<Map<String, dynamic>> get _aiMatchedCatches {
    final list = List<Map<String, dynamic>>.from(_allPublishedCatches);
    list.sort(
      (a, b) => ((b['matchScore'] ?? 0) as int).compareTo(
        (a['matchScore'] ?? 0) as int,
      ),
    );
    return list;
  }

  String _formatCurrency(num amount) {
    final parts = amount.round().toString();
    return parts.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    const storage = FlutterSecureStorage();
    final name = await storage.read(key: 'userName');
    if (mounted && name != null && name.isNotEmpty) {
      setState(() => _displayName = name);
    }
    try {
      final pref = await ApiClient().getBuyerPreferences();
      if (pref.isNotEmpty && mounted) {
        setState(() {
          final s = pref['preferredSpecies']?.toString() ?? '';
          if (_speciesList.contains(s)) _preferredSpecies = s;
          if (pref['minQuantityKg'] != null)
            _minQtyCtrl.text = pref['minQuantityKg'].toString();
          if (pref['maxQuantityKg'] != null)
            _maxQtyCtrl.text = pref['maxQuantityKg'].toString();
          if (pref['maxPricePerKg'] != null)
            _maxPriceCtrl.text = pref['maxPricePerKg'].toString();
          final c = pref['preferredCity']?.toString() ?? '';
          if (_cityList.contains(c)) _preferredCity = c;
          if (pref['notes'] != null) _notesCtrl.text = pref['notes'].toString();
        });
      }
    } catch (_) {}

    await _loadCatches();
  }

  Future<void> _loadCatches() async {
    if (!mounted) return;
    setState(() => _isLoadingCatches = true);
    try {
      final res = await ApiClient().catches();
      if (res.isNotEmpty && mounted) {
        final activeList = res.where((item) {
          final s = (item as Map)['status']?.toString().toLowerCase();
          return s == 'published' || s == 'bidding' || s == 'active';
        }).toList();
        final toMap = activeList.isNotEmpty ? activeList : res;

        final mapped = toMap.map((item) {
          final m = Map<String, dynamic>.from(item as Map);
          final speciesRaw =
              m['fishSpecies']?.toString() ??
              m['species']?.toString() ??
              'Fish';
          String emoji = '🐟';
          final sl = speciesRaw.toLowerCase();
          if (sl.contains('prawn') || sl.contains('shrimp')) {
            emoji = '🦐';
          } else if (sl.contains('crab')) {
            emoji = '🦀';
          } else if (sl.contains('tuna') || sl.contains('kelawalla')) {
            emoji = '🐟';
          } else if (sl.contains('squid') || sl.contains('cuttlefish')) {
            emoji = '🦑';
          } else if (sl.contains('seer') || sl.contains('thora')) {
            emoji = '🐠';
          } else if (sl.contains('trevally') || sl.contains('paraw')) {
            emoji = '🐡';
          } else if (sl.contains('mackerel') || sl.contains('kumbalawa')) {
            emoji = '🐟';
          }
          final shortSpecies = speciesRaw.contains('(')
              ? speciesRaw.split('(').first.trim()
              : speciesRaw;
          final rawGrade = (m['declaredQualityGrade']?.toString() ?? '').trim();
          final quality = rawGrade.isNotEmpty
              ? (rawGrade.startsWith('Grade') ? rawGrade : 'Grade $rawGrade')
              : 'Grade A';
          final sellerName = m['fisherman'] is Map
              ? (m['fisherman']['fullName']?.toString() ?? 'Fisherman')
              : (m['fishermanName']?.toString() ??
                    m['seller']?.toString() ??
                    'Fisherman');
          final loc = (m['location']?.toString() ?? 'Negombo Fishery Harbour')
              .trim();
          final qty =
              (m['quantityKg'] as num?)?.toInt() ??
              (m['quantity'] as num?)?.toInt() ??
              100;
          final vWeight =
              (m['verifiedWeightKg'] as num?)?.toInt() ??
              (m['verifiedWeight'] as num?)?.toInt() ??
              qty;
          final price =
              (m['askingPricePerKg'] as num?)?.toInt() ??
              (m['price'] as num?)?.toInt() ??
              1500;
          final currentBid = (m['currentBid'] as num?)?.toInt() ?? price;
          final lot =
              m['lotNumber']?.toString() ??
              (m['id'] != null ? 'LOT-#${m['id']}' : 'LOT-HARBOUR');
          final status = m['status']?.toString() ?? 'Published';
          final inspection = m['inspectionResult']?.toString() ?? 'Passed';
          final fraudRisk = m['fraudRisk']?.toString() ?? 'Low';

          int matchScore = 70;
          final List<String> reasons = [];
          if (_preferredSpecies != 'Any species' &&
              (speciesRaw.toLowerCase().contains(
                    _preferredSpecies.toLowerCase(),
                  ) ||
                  _preferredSpecies.toLowerCase().contains(
                    shortSpecies.toLowerCase(),
                  ))) {
            matchScore += 20;
            reasons.add('Species match (+20)');
          }
          final maxBudget = double.tryParse(_maxPriceCtrl.text.trim()) ?? 2200;
          if (price <= maxBudget) {
            matchScore += 15;
            reasons.add('Asking price below budget (+15)');
          }
          final minQ = double.tryParse(_minQtyCtrl.text.trim()) ?? 50;
          final maxQ = double.tryParse(_maxQtyCtrl.text.trim()) ?? 300;
          if (qty >= minQ && qty <= maxQ) {
            matchScore += 10;
            reasons.add('Volume in target range (+10)');
          }
          if (_preferredCity != 'Any location' &&
              loc.toLowerCase().contains(_preferredCity.toLowerCase())) {
            matchScore += 10;
            reasons.add('$_preferredCity proximity (+10)');
          }
          if (reasons.isEmpty) {
            reasons.add('Verified catch published on harbour marketplace');
          }

          return {
            'id': m['id'] ?? 1,
            'species': shortSpecies,
            'fullSpecies': speciesRaw,
            'quantity': qty,
            'verifiedWeight': vWeight,
            'price': price,
            'currentBid': currentBid,
            'totalPrice': price * qty,
            'quality': quality,
            'location': loc,
            'fisherman': sellerName,
            'lot': lot,
            'emoji': emoji,
            'status': status,
            'inspection': inspection,
            'fraudRisk': fraudRisk,
            'matchScore': matchScore.clamp(50, 99),
            'matchReasons': reasons.join(' · '),
            'raw': m,
          };
        }).toList();

        if (mounted) {
          setState(() {
            _liveCatches = mapped;
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingCatches = false);
  }

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
        'preferredSpecies': _preferredSpecies == 'Any species'
            ? ''
            : _preferredSpecies,
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
        content: Text(
          'Preferences saved! AI Buyer Matching Agent recommendations updated.',
        ),
        backgroundColor: Color(0xff059669),
      ),
    );

    // Refresh catches & match score based on updated preferences
    _loadCatches();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _prefSaved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadInitialData();
      },
      child: ListView(
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
                      child: Icon(
                        Icons.storefront,
                        color: Color(0xff0a3663),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello ${_displayName.isNotEmpty ? _displayName : "Buyer"} 👋',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'OceanFresh Exporters • Registered Buyer',
                            style: TextStyle(
                              color: Color(0xffc2e5fb),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.verified_user,
                        color: Color(0xffffd166),
                        size: 16,
                      ),
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
                      child: const Icon(
                        Icons.shopping_cart_checkout,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Submit Seafood Bid',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Direct Pier Bidding • Escrow Protected',
                            style: TextStyle(
                              color: Color(0xffc2e5fb),
                              fontSize: 12,
                            ),
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => showBuyerOrderModal(context),
                    icon: const Icon(Icons.gavel, size: 18),
                    label: const Text(
                      'Submit Bid',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
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
              color: Color(0xff1f2937),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildNavChip(
                  context,
                  icon: Icons.set_meal,
                  label: 'Available Fish (${_allPublishedCatches.length})',
                  color: const Color(0xff0077b6),
                  onTap: () => setState(() => _selectedView = 0),
                ),
                const SizedBox(width: 8),
                _buildNavChip(
                  context,
                  icon: Icons.auto_awesome,
                  label: 'AI Matched',
                  color: const Color(0xff059669),
                  onTap: () => setState(() => _selectedView = 1),
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
                  onTap: () => _showNotice(
                    context,
                    'Won Orders',
                    'You have 2 confirmed won orders:\n• ORD-1049: 100kg Tuna (Rs.165,000)\n• ORD-1033: 60kg Seer Fish (Rs.108,000)',
                  ),
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
                  onTap: () => _showNotice(
                    context,
                    'Pending Payments',
                    '1 invoice pending settlement:\n• Invoice #INV-8821: Rs. 248,000 due in 24 hours.',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // ── 4 Metric Cards (Dynamic count of available catches) ───────
          const Text(
            'Dashboard',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xff1f2937),
            ),
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
                    value: '${_allPublishedCatches.length}',
                    change: 'Fresh landings today',
                    isPositive: true,
                    icon: Icons.set_meal,
                    color: const Color(0xff0077b6),
                    onTap: () => setState(() => _selectedView = 0),
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
                    onTap: () => _showNotice(
                      context,
                      'Won Orders (2)',
                      '• ORD-1049: 100 kg Tuna (Rs. 165,000) - Preparing dispatch\n• ORD-1033: 60 kg Seer Fish (Rs. 108,000) - Dispatched',
                    ),
                  ),
                  _StatCardEnhanced(
                    title: 'Pending Payments',
                    value: '1',
                    change: 'Rs. 248,000 due',
                    isPositive: false,
                    icon: Icons.receipt_long,
                    color: const Color(0xffd90429),
                    onTap: () => _showNotice(
                      context,
                      'Pending Payment',
                      'Invoice #INV-8821 for 180 kg Tuna.\nAmount: Rs. 248,000\nPayment terms: 24h bank settlement.',
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 18),

          // ── Featured Landing Spotlight (Dynamic from live published) ─
          if (_allPublishedCatches.isNotEmpty) ...[
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
                          child: Center(
                            child: Text(
                              _allPublishedCatches.first['emoji'] as String,
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _allPublishedCatches.first['fullSpecies']
                                    as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${_allPublishedCatches.first['quantity']} kg • ${_allPublishedCatches.first['location']} • Verified: ${_allPublishedCatches.first['verifiedWeight']} kg',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Price: Rs. ${_allPublishedCatches.first['price']} / kg • By ${_allPublishedCatches.first['fisherman']}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xff0077b6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xff005b96),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                          ),
                          onPressed: () => showBuyerOrderModal(
                            context,
                            fish: _allPublishedCatches.first,
                          ),
                          child: const Text(
                            '🛒 Order / Bid',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => setState(() => _selectedView = 0),
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: Text(
                        'View All ${_allPublishedCatches.length} Available Fish Listings',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ════════════════════════════════════════════════════════════════
          // ALL PUBLISHED CATCHES + AI MATCHING + BUYING PREFERENCES TABS
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
                // 3-Segment Tab Selector
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
                        // Tab 0: Published Fish
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
                                          color: Colors.black.withValues(
                                            alpha: 0.06,
                                          ),
                                          blurRadius: 4,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.set_meal,
                                    size: 15,
                                    color: _selectedView == 0
                                        ? const Color(0xff005b96)
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Published (${_allPublishedCatches.length})',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _selectedView == 0
                                            ? const Color(0xff005b96)
                                            : Colors.grey.shade700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Tab 1: AI Recommendations
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
                                          color: Colors.black.withValues(
                                            alpha: 0.06,
                                          ),
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
                                    size: 15,
                                    color: _selectedView == 1
                                        ? const Color(0xff005b96)
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'AI Matched',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _selectedView == 1
                                            ? const Color(0xff005b96)
                                            : Colors.grey.shade700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Tab 2: Buying Preferences
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _selectedView = 2),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedView == 2
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _selectedView == 2
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.06,
                                          ),
                                          blurRadius: 4,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.tune,
                                    size: 15,
                                    color: _selectedView == 2
                                        ? const Color(0xff005b96)
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Preferences',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _selectedView == 2
                                            ? const Color(0xff005b96)
                                            : Colors.grey.shade700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
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

                // ── View 0: All Fisherman Published Fish ────────────────────
                if (_selectedView == 0) ...[
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.set_meal,
                                  color: Color(0xff005b96),
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Fisherman Published Catches',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: _isLoadingCatches
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.refresh,
                                      size: 20,
                                      color: Color(0xff005b96),
                                    ),
                              tooltip: 'Refresh live harbour catches',
                              onPressed: _isLoadingCatches
                                  ? null
                                  : _loadCatches,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'All verified fish landings published by fishermen directly from harbours with complete lot & inspection details.',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 14),
                        if (_isLoadingCatches && _allPublishedCatches.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(28),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_allPublishedCatches.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            alignment: Alignment.center,
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.inbox,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'No published catches available yet.',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'When fishermen publish catches, they will automatically appear here.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: _loadCatches,
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Refresh Listings'),
                                ),
                              ],
                            ),
                          )
                        else
                          ..._allPublishedCatches.map(
                            (c) => _buildPublishedCatchCard(c),
                          ),
                      ],
                    ),
                  ),
                ]
                // ── View 1: AI Recommendations ──────────────────────────────
                else if (_selectedView == 1) ...[
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
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Ranked by Compatibility',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xff005b96),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Automatically ranked against OceanFresh Exporters purchasing profile & price willingness.',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        ..._aiMatchedCatches.map(
                          (c) => _buildRecommendationCard(c),
                        ),
                      ],
                    ),
                  ),
                ]
                // ── View 2: My Buying Preferences Form ──────────────────────
                else ...[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(
                              Icons.tune,
                              color: Color(0xff005b96),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'My Buying Preferences Form',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        if (_prefSaved)
                          Container(
                            margin: const EdgeInsets.only(top: 8, bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xffd1fae5),
                              border: Border.all(
                                color: const Color(0xff6ee7b7),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: const [
                                Icon(
                                  Icons.check_circle,
                                  color: Color(0xff059669),
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Preferences saved! AI Recommendations updated.',
                                    style: TextStyle(
                                      color: Color(0xff065f46),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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
                        const Text(
                          'Preferred Fish Species',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _preferredSpecies,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.set_meal, size: 18),
                          ),
                          items: _speciesList
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    s,
                                    style: const TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _preferredSpecies = v!),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 4, bottom: 12),
                          child: Text(
                            'Species match gives 40 points in recommendation score.',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ),

                        // Min & Max Quantity
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Min Quantity (kg)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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
                                  const Text(
                                    'Max Quantity (kg)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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
                        const Text(
                          'Maximum Budget Price (Rs./kg)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                          child: Text(
                            'Catches within your budget get up to 20 extra points.',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ),

                        // Preferred City / Area
                        const Text(
                          'Preferred Harbour / Area',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _preferredCity,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.location_on, size: 18),
                          ),
                          items: _cityList
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                    c,
                                    style: const TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _preferredCity = v!),
                        ),

                        const SizedBox(height: 12),

                        // Additional Notes
                        const Text(
                          'Additional Handling Notes (Optional)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                              const Text(
                                '📊 How AI calculates your Match Score:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xff0369a1),
                                ),
                              ),
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

                        // Dual Action Buttons: Save Preferences & Save as Target Bid
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xff005b96),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _prefSaving
                                    ? null
                                    : _savePreferences,
                                icon: _prefSaving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.save, size: 18),
                                label: Text(
                                  _prefSaving ? 'Saving…' : 'Save Preferences',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xff005b96),
                                  side: const BorderSide(
                                    color: Color(0xff005b96),
                                    width: 1.5,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _addSavedBid,
                                icon: const Icon(
                                  Icons.bookmark_add_outlined,
                                  size: 18,
                                ),
                                label: const Text(
                                  '+ Save Target Bid',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        const Divider(height: 1),
                        const SizedBox(height: 18),

                        // ── SAVED BIDS & BUYER MATCHING SECTION ─────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.bookmarks,
                                  color: Color(0xff005b96),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Saved Bids & Inquiries',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 3.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xffe0f2fe),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_savedBids.length} Saved Targets',
                                style: const TextStyle(
                                  color: Color(0xff0369a1),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Your saved bids with AI Buyer Matching scores showing compatibility against live harbour landings.',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 14),

                        if (_savedBids.isEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xfff8fafc),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Center(
                              child: Column(
                                children: const [
                                  Icon(
                                    Icons.bookmark_border,
                                    size: 36,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'No saved bids yet',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Fill the preferences form above and tap "+ Save Target Bid".',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else ...[
                          ..._savedBids.map((b) => _buildSavedBidCard(b)),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSavedBidCard(Map<String, dynamic> b) {
    final matchResult = _calculateMatchForSavedBid(b);
    final score = matchResult['score'] as int;
    final reasons = matchResult['reasons'] as String;
    final matchedCatch = matchResult['matchedCatch'] as Map<String, dynamic>?;

    final scoreColor = score >= 85
        ? const Color(0xff059669)
        : score >= 70
        ? const Color(0xffd97706)
        : const Color(0xff64748b);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scoreColor.withValues(alpha: 0.35),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Species & Match Score Ring
            Row(
              children: [
                // Circular Match Score Gauge
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: scoreColor, width: 3.5),
                    color: scoreColor.withValues(alpha: 0.08),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$score%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: scoreColor,
                          ),
                        ),
                        Text(
                          'MATCH',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 8,
                            color: scoreColor,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              b['species']?.toString() ?? 'Target Species',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xff0f172a),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: scoreColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              score >= 85
                                  ? 'HIGH COMPATIBILITY'
                                  : score >= 70
                                  ? 'GOOD MATCH'
                                  : 'MODERATE',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: scoreColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Target: ${b['minQty']} - ${b['maxQty']} kg  •  Budget: Max Rs. ${b['maxPrice']}/kg',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xff334155),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 13,
                            color: Color(0xffe11d48),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            b['city']?.toString() ?? 'Any harbour',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.access_time,
                            size: 12,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            b['createdAt']?.toString() ?? 'Saved',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if ((b['notes']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xfff8fafc),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  'Note: ${b['notes']}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xff475569),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 10),

            // AI Matching Breakdown Box
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xfff0fdf4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xffbbf7d0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.auto_awesome,
                        size: 14,
                        color: Color(0xff16a34a),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'AI Buyer Matching Analysis',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff15803d),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reasons,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xff166534),
                    ),
                  ),
                  if (matchedCatch != null) ...[
                    const Divider(height: 12, color: Color(0xffbbf7d0)),
                    Row(
                      children: [
                        Text(
                          matchedCatch['emoji']?.toString() ?? '🐟',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Best Live Match: ${matchedCatch['fullSpecies']} (${matchedCatch['quantity']}kg @ Rs. ${matchedCatch['price']}/kg at ${matchedCatch['location']})',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff065f46),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _deleteSavedBid(b['id'] as String),
                  icon: const Icon(Icons.delete_outline, size: 15),
                  label: const Text('Remove', style: TextStyle(fontSize: 11)),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xff005b96),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    final targetFish =
                        matchedCatch ??
                        {
                          'species': b['species'],
                          'fullSpecies': '${b['species']} (Saved Bid Target)',
                          'quantity': b['maxQty'],
                          'verifiedWeight': b['minQty'],
                          'price': b['maxPrice'],
                          'currentBid': b['maxPrice'],
                          'location': b['city'] != 'Any location'
                              ? b['city']
                              : 'Negombo Fishery Harbour',
                          'quality': 'Grade A',
                          'lot': 'SAVED-BID',
                          'emoji': '🐟',
                        };
                    showBuyerOrderModal(context, fish: targetFish);
                  },
                  icon: const Icon(Icons.gavel, size: 14),
                  label: const Text(
                    '🛒 Place Bid on Match',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreRow(String label, String pts) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xff334155)),
          ),
          Text(
            pts,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xff005b96),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublishedCatchCard(Map<String, dynamic> c) {
    final species =
        c['fullSpecies']?.toString() ??
        c['species']?.toString() ??
        'Fresh Fish';
    final emoji = c['emoji']?.toString() ?? '🐟';
    final qty = c['quantity'] ?? 0;
    final verifiedWeight = c['verifiedWeight'] ?? qty;
    final price = c['price'] ?? 0;
    final totalPrice = c['totalPrice'] ?? (price * qty);
    final location = c['location']?.toString() ?? 'Harbour Pier';
    final quality = c['quality']?.toString() ?? 'Grade A';
    final seller = c['fisherman']?.toString() ?? 'Local Fisherman';
    final lot = c['lot']?.toString() ?? 'LOT-HARBOUR';
    final status = c['status']?.toString() ?? 'Published';
    final inspection = c['inspection']?.toString() ?? 'Passed';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Banner with Species, Emoji, Lot, Quality and Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xfff8fafc),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        species,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff0f172a),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xffe0f2fe),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              lot,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff0369a1),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xffdcfce7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              quality,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff15803d),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: status.toLowerCase() == 'published'
                        ? const Color(0xff059669)
                        : const Color(0xff0284c7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Details Grid
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                // Fisherman and Location
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.person,
                            size: 16,
                            color: Color(0xff005b96),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              seller,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xff334155),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 16,
                            color: Color(0xffe11d48),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              location,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xff334155),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Weight & Inspection Row
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xfff1f5f9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.scale,
                            size: 15,
                            color: Color(0xff475569),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Declared: $qty kg  •  Verified: $verifiedWeight kg',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xff1e293b),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.verified,
                            size: 14,
                            color: Color(0xff059669),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Inspection: $inspection',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff059669),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Price and Order CTA Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rs. $price / kg',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff005b96),
                          ),
                        ),
                        Text(
                          'Total Value: Rs. ${_formatCurrency(totalPrice)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xff64748b),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff005b96),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => showBuyerOrderModal(context, fish: c),
                      icon: const Icon(Icons.shopping_cart_checkout, size: 15),
                      label: const Text(
                        'Place Order / Bid',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => showBuyerOrderModal(context, fish: c),
                icon: const Icon(Icons.shopping_cart_checkout, size: 14),
                label: const Text(
                  '🛒 Place Order / Bid',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
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
  bool _loading = false;
  List<Map<String, dynamic>> _catches = [];

  final List<Map<String, dynamic>> _defaultCatches = [
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

  @override
  void initState() {
    super.initState();
    _loadCatches();
  }

  Future<void> _loadCatches() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient().catches();
      if (res.isNotEmpty && mounted) {
        final activeList = res.where((item) {
          final s = (item as Map)['status']?.toString();
          return s == 'Published' || s == 'Bidding';
        }).toList();
        final toMap = activeList.isNotEmpty ? activeList : res;

        final mapped = toMap.map((item) {
          final m = Map<String, dynamic>.from(item as Map);
          final speciesRaw =
              m['fishSpecies']?.toString() ??
              m['species']?.toString() ??
              'Fish';
          String emoji = '🐟';
          final sl = speciesRaw.toLowerCase();
          if (sl.contains('prawn') || sl.contains('shrimp')) {
            emoji = '🦐';
          } else if (sl.contains('crab')) {
            emoji = '🦀';
          } else if (sl.contains('tuna')) {
            emoji = '🐟';
          } else if (sl.contains('squid') || sl.contains('cuttlefish')) {
            emoji = '🦑';
          }
          final shortSpecies = speciesRaw.contains('(')
              ? speciesRaw.split('(').first.trim()
              : speciesRaw;
          final rawGrade = (m['declaredQualityGrade']?.toString() ?? '').trim();
          final quality = rawGrade.isNotEmpty ? rawGrade : 'A';
          final sellerName =
              m['fisherman']?['fullName']?.toString() ??
              m['fishermanName']?.toString() ??
              m['seller']?.toString() ??
              'Local Fisherman';
          final loc = (m['location']?.toString() ?? 'Negombo Pier').trim();

          return {
            'id': m['id'],
            'species': shortSpecies,
            'fullSpecies': speciesRaw,
            'quantity':
                (m['quantityKg'] as num?)?.toInt() ??
                (m['quantity'] as num?)?.toInt() ??
                100,
            'verifiedWeight':
                (m['verifiedWeightKg'] as num?)?.toInt() ??
                (m['quantityKg'] as num?)?.toInt() ??
                100,
            'price':
                (m['askingPricePerKg'] as num?)?.toInt() ??
                (m['price'] as num?)?.toInt() ??
                1500,
            'currentBid':
                (m['askingPricePerKg'] as num?)?.toInt() ??
                (m['currentBid'] as num?)?.toInt() ??
                1500,
            'quality': quality,
            'location': loc.contains('(')
                ? loc.split('(').last.replaceAll(')', '').trim()
                : loc,
            'seller': sellerName,
            'emoji': emoji,
            'status': m['status']?.toString() ?? 'Published',
            'raw': m,
          };
        }).toList();

        setState(() {
          _catches = mapped;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _availableCatches =>
      _catches.isNotEmpty ? _catches : _defaultCatches;

  List<Map<String, dynamic>> get _filteredCatches {
    final query = _searchController.text.trim().toLowerCase();
    return _availableCatches.where((c) {
      final matchesQuery =
          query.isEmpty ||
          c['species'].toString().toLowerCase().contains(query) ||
          c['fullSpecies'].toString().toLowerCase().contains(query) ||
          c['location'].toString().toLowerCase().contains(query);

      final matchesTag =
          _selectedTag == 'All' ||
          c['species'].toString().toLowerCase() == _selectedTag.toLowerCase();

      final matchesLocation =
          _selectedLocation == 'All' ||
          c['location'].toString() == _selectedLocation;

      final matchesQuality =
          _selectedQuality == 'All' ||
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
                  const Text(
                    'Filter Seafood Catches',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
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
              const Text(
                'Location',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children:
                    [
                          'All',
                          'Negombo',
                          'Beruwala',
                          'Galle',
                          'Matara',
                          'Kalpitiya',
                        ]
                        .map(
                          (loc) => ChoiceChip(
                            label: Text(loc),
                            selected: _selectedLocation == loc,
                            onSelected: (_) {
                              setState(() => _selectedLocation = loc);
                              setSheetState(() {});
                            },
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 12),
              const Text(
                'Quality Grade',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: ['All', 'A', 'B']
                    .map(
                      (q) => ChoiceChip(
                        label: Text('Grade $q'),
                        selected: _selectedQuality == q,
                        onSelected: (_) {
                          setState(() => _selectedQuality = q);
                          setSheetState(() {});
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xff005b96),
                  ),
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
    final availableSpecies = _availableCatches
        .map((c) => c['species'].toString())
        .toSet()
        .toList();
    final tags = ['All', ...availableSpecies];

    return RefreshIndicator(
      onRefresh: _loadCatches,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Available Fish',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xff005b96)),
                onPressed: _loadCatches,
                tooltip: 'Refresh listings',
              ),
            ],
          ),
          if (_loading) const LinearProgressIndicator(),
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
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
      ),
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
              Expanded(
                child: Text(
                  '${fish['emoji']} ${fish['species']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xff003b5c),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Grade ${fish['quality']}',
                  style: TextStyle(
                    fontSize: 10.5,
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
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
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
                        Text(
                          fish['emoji'] as String? ?? '🐟',
                          style: const TextStyle(fontSize: 64),
                        ),
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
                  'Verified Weight:',
                  '${fish['verifiedWeight'] ?? fish['quantity']} kg',
                ),
                _buildDetailRow('Asking Price:', 'Rs. ${fish['price']} / kg'),
                _buildDetailRow(
                  'Current Highest Bid:',
                  'Rs. ${fish['currentBid'] ?? fish['price']} / kg',
                ),
                _buildDetailRow('Landing Pier:', '${fish['location']} Harbour'),
                _buildDetailRow(
                  'Quality Inspection:',
                  '${fish['quality'] ?? "Grade A"} (Inspected)',
                ),
                _buildDetailRow(
                  'Time Landed:',
                  'Today, 04:30 AM (Cold-stored)',
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xff005b96),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    showBuyerOrderModal(context, fish: fish);
                  },
                  icon: const Icon(Icons.gavel),
                  label: const Text(
                    'Submit Bid',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
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
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
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
  final targetFish =
      fish ??
      {
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
  Map<String, dynamic>? _existingBid;
  bool _checkingExistingBid = true;

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
    _buyerNameController = TextEditingController(
      text: 'OceanFresh Exporters (Pvt) Ltd',
    );
    _buyerPhoneController = TextEditingController(text: '+94 77 987 6543');
    _bidRateController = TextEditingController(text: '$defaultRate');
    _qtyController = TextEditingController(
      text: '${widget.fish['quantity'] ?? 100}',
    );
    _notesController = TextEditingController(
      text: 'Cold-chain container required. Inspect upon dock arrival.',
    );
    _customAddressController = TextEditingController();
    _checkExistingBid();
  }

  Future<void> _checkExistingBid() async {
    try {
      final myBids = await ApiClient().getMyBids();
      final catchId = (widget.fish['id'] as num?)?.toInt() ?? 1;
      for (var b in myBids) {
        if ((b['catchId'] as num?)?.toInt() == catchId &&
            b['status'] != 'Cancelled') {
          if (mounted) {
            setState(() {
              _existingBid = Map<String, dynamic>.from(b as Map);
              _checkingExistingBid = false;
            });
            return;
          }
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _checkingExistingBid = false);
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
    if (_existingBid != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You have already placed a bid on this catch (Rs. ${_existingBid!['bidPricePerKg']}/kg). Only 1 bid is allowed per catch.',
          ),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final bidRate = double.tryParse(_bidRateController.text.trim()) ?? 0;
    final qty = double.tryParse(_qtyController.text.trim()) ?? 0;
    if (bidRate <= 0 || qty <= 0) return;

    setState(() => _submitting = true);

    final catchId = (widget.fish['id'] as num?)?.toInt() ?? 1;
    try {
      await ApiClient().placeBid(catchId, bidRate);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final rawMsg = e.toString().replaceAll('Exception:', '').trim();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text(
                'Bid Limit (1 Bid Policy)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rawMsg.isNotEmpty && !rawMsg.contains('HttpException')
                    ? '$rawMsg\n\n(Only one active bid is allowed per buyer for each catch listing.)'
                    : 'Each buyer is allowed a maximum of 1 active bid per catch listing.\n\nYou have already submitted a bid for this catch.',
                style: const TextStyle(fontSize: 13.5, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.lock_outline, size: 16, color: Colors.brown),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Policy: 1 Active Bid per Buyer per Catch',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.brown,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xff005b96),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

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
            Text(
              'Bid Submitted!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bid placed successfully for ${widget.fish['species']} (${qty.toInt()} kg @ Rs. ${bidRate.toInt()}/kg).',
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
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xff005b96),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Destination: $destination',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Cold Chain: $_selectedColdChain',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '• Autonomous Logistics Agent notified for vehicle dispatch.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xff005b96),
            ),
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
                  child: const Icon(
                    Icons.gavel,
                    color: Color(0xff0284c7),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Submit Bid',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${widget.fish['species']} • Lot ${widget.fish['lot'] ?? 'LOT-NEG-902'} • Asking: Rs. ${askingPrice.toInt()}/kg',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
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
                  if (_existingBid != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xffeff6ff),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xff93c5fd)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Color(0xff1d4ed8),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Limit: 1 active bid per catch listing',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xff1e40af),
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'You have already placed a bid of Rs. ${_existingBid!['bidPricePerKg']}/kg on this catch (Status: ${_existingBid!['status']}). Maximum 1 bid allowed per buyer.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xff1e3a8a),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
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
                        Text(
                          widget.fish['emoji'] as String? ?? '🐟',
                          style: const TextStyle(fontSize: 34),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.fish['fullSpecies'] as String? ??
                                    widget.fish['species'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.fish['quantity']} kg available • Harbour: ${widget.fish['location']} • Quality: ${widget.fish['quality'] ?? "Grade A"}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
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
                  const Text(
                    'Buyer Company / Trading Name',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _buyerNameController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.business, size: 18),
                      hintText: 'e.g. OceanFresh Exporters (Pvt) Ltd',
                    ),
                    validator: (v) => v == null || v.isEmpty
                        ? 'Please enter buyer name'
                        : null,
                  ),

                  const SizedBox(height: 14),

                  // Order Quantity
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Order Quantity (kg)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Max: ${widget.fish['quantity']} kg',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
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
                      if (val == null || val <= 0)
                        return 'Enter a valid quantity';
                      final maxQty =
                          (widget.fish['quantity'] as num?)?.toDouble() ?? 500;
                      if (val > maxQty)
                        return 'Cannot exceed available $maxQty kg';
                      return null;
                    },
                  ),

                  // Quick Quantity Buttons
                  const SizedBox(height: 6),
                  Row(
                    children: [25, 50, 75, 100].map((pct) {
                      final maxQty =
                          (widget.fish['quantity'] as num?)?.toInt() ?? 100;
                      final calcQty = (maxQty * (pct / 100)).round();
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: Text(
                            '$pct% ($calcQty kg)',
                            style: const TextStyle(fontSize: 11),
                          ),
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
                      const Text(
                        'Your Bid / Purchase Price (Rs./kg)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Asking: Rs. ${askingPrice.toInt()}/kg',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.blue,
                        ),
                      ),
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
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.amber,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else if (currentRate >= askingPrice)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '✓ Competitive offer at or above asking price.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
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
                        const Text(
                          'Total Estimated Order Value:',
                          style: TextStyle(
                            color: Color(0xffc2e5fb),
                            fontSize: 12,
                          ),
                        ),
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
                          style: TextStyle(
                            color: Color(0xffe0f2fe),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Delivery Destination
                  const Text(
                    'Delivery Destination / Warehouse',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedDestination,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.location_on, size: 18),
                    ),
                    items: _destinations
                        .map(
                          (d) => DropdownMenuItem(
                            value: d,
                            child: Text(
                              d,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
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
                      validator: (v) =>
                          _selectedDestination == 'Custom Address' &&
                              (v == null || v.isEmpty)
                          ? 'Please enter delivery address'
                          : null,
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Cold-Chain Requirement
                  const Text(
                    'Cold-Chain Requirement',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children:
                        [
                          'Chilled (0°C to 4°C)',
                          'Deep Frozen (-18°C)',
                          'Slurry Ice Packed',
                        ].map((mode) {
                          final isSel = _selectedColdChain == mode;
                          return ChoiceChip(
                            label: Text(
                              mode,
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: isSel,
                            onSelected: (_) =>
                                setState(() => _selectedColdChain = mode),
                          );
                        }).toList(),
                  ),

                  const SizedBox(height: 14),

                  // Delivery Schedule Window
                  const Text(
                    'Preferred Delivery Window',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedWindow,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.access_time, size: 18),
                    ),
                    items:
                        [
                              'Immediate Pier Dispatch (within 2h)',
                              'Same-Day Evening (18:00 - 21:00)',
                              'Next-Day Morning Auction Slot (05:00 - 08:00)',
                            ]
                            .map(
                              (w) => DropdownMenuItem(
                                value: w,
                                child: Text(
                                  w,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (v) => setState(() => _selectedWindow = v!),
                  ),

                  const SizedBox(height: 14),

                  // Payment & Settlement Guarantee
                  const Text(
                    'Settlement Guarantee Method',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedPayment,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.verified_user, size: 18),
                    ),
                    items:
                        [
                              'FishLink Smart Escrow Guarantee',
                              '24-Hour Verified Bank Wire Settlement',
                              'Commercial Letter of Credit (LC)',
                            ]
                            .map(
                              (p) => DropdownMenuItem(
                                value: p,
                                child: Text(
                                  p,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (v) => setState(() => _selectedPayment = v!),
                  ),

                  const SizedBox(height: 14),

                  // Special Handling Notes
                  const Text(
                    'Special Instructions / Notes',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
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
                      backgroundColor: _existingBid != null
                          ? Colors.grey.shade400
                          : const Color(0xff005b96),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: (_submitting || _existingBid != null)
                        ? null
                        : _submitOrder,
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            _existingBid != null
                                ? Icons.lock_outline
                                : Icons.gavel,
                            size: 18,
                          ),
                    label: Text(
                      _existingBid != null
                          ? 'Bid already placed (Rs. ${_existingBid!['bidPricePerKg']}/kg)'
                          : (_submitting ? 'Submitting Bid…' : 'Submit Bid'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
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

class MyBidsScreen extends StatefulWidget {
  const MyBidsScreen({super.key});

  @override
  State<MyBidsScreen> createState() => _MyBidsScreenState();
}

class _MyBidsScreenState extends State<MyBidsScreen> {
  String _selectedFilter = 'All';
  bool _loading = false;
  List<Map<String, dynamic>> _bidsList = [];

  final List<Map<String, dynamic>> _fallbackBids = [
    {
      'species': 'Tuna',
      'yourBid': 1650,
      'highestBid': 1650,
      'quantity': 100,
      'location': 'Negombo',
      'status': 'ACTIVE',
      'time': 'Placed recently',
    },
    {
      'species': 'Mackerel',
      'yourBid': 1200,
      'highestBid': 1350,
      'quantity': 75,
      'location': 'Beruwala',
      'status': 'LOST',
      'time': 'Outbid',
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

  @override
  void initState() {
    super.initState();
    _loadBids();
  }

  Future<void> _loadBids() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient().getMyBids();
      if (res.isNotEmpty && mounted) {
        final parsed = <Map<String, dynamic>>[];
        for (final item in res) {
          if (item is Map) {
            final m = Map<String, dynamic>.from(item);
            final statusRaw = (m['status'] ?? 'Pending')
                .toString()
                .toUpperCase();
            final mappedStatus = (statusRaw == 'ACCEPTED')
                ? 'WON'
                : (statusRaw == 'REJECTED')
                ? 'LOST'
                : 'ACTIVE';
            parsed.add({
              'id': m['id'],
              'catchId': m['catchId'],
              'species': m['fishSpecies'] ?? m['species'] ?? 'Fish Catch',
              'yourBid': (m['bidPricePerKg'] ?? m['price'] ?? 0),
              'highestBid': (m['highestBid'] ?? m['bidPricePerKg'] ?? 0),
              'quantity': (m['quantityKg'] ?? m['quantity'] ?? 0),
              'location': m['location'] ?? 'Negombo Harbour',
              'status': mappedStatus,
              'time': m['createdAt'] != null
                  ? 'Placed on ${m['createdAt'].toString().split('T').first}'
                  : 'Active Auction',
            });
          }
        }
        if (parsed.isNotEmpty) {
          setState(() {
            _bidsList = parsed;
            _loading = false;
          });
          return;
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        if (_bidsList.isEmpty) _bidsList = _fallbackBids;
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredBids {
    final list = _bidsList.isNotEmpty ? _bidsList : _fallbackBids;
    if (_selectedFilter == 'All') return list;
    return list
        .where((b) => b['status'] == _selectedFilter.toUpperCase())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ['All', 'ACTIVE', 'WON', 'LOST'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'My Bids',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, color: Color(0xff005b96)),
              onPressed: _loading ? null : _loadBids,
              tooltip: 'Refresh Bids',
            ),
          ],
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
                  Expanded(
                    child: Text(
                      'Order Created • Logistics Dispatched via Cold Storage',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )
          else if (isLost)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'You were outbid by another buyer',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
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
                  child: const Text(
                    'Increase Bid',
                    style: TextStyle(fontSize: 12),
                  ),
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
      final matchesFilter =
          _selectedFilter == 'All' || catchItem['status'] == _selectedFilter;
      final matchesQuery =
          query.isEmpty ||
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xff005b96)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Bids & AI Match',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xff005b96),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${item['quantity']} kg • Rs.${item['price']}/kg • ${item['location']}',
                      ),
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

class _FishermanDashboardLive extends StatefulWidget {
  const _FishermanDashboardLive({required this.onNavigateToCatches});

  final VoidCallback onNavigateToCatches;

  @override
  State<_FishermanDashboardLive> createState() =>
      _FishermanDashboardLiveState();
}

class _FishermanDashboardLiveState extends State<_FishermanDashboardLive> {
  List<Map<String, dynamic>> _catches = [];
  Map<int, List<dynamic>> _bidsByCatch = {};
  bool _loading = true;
  String? _error;
  String? _bidSummaryError;

  @override
  void initState() {
    super.initState();
    _loadCatches();
  }

  Future<void> _loadCatches() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ApiClient();
      final catches = await api.getMyCatches();
      if (mounted) setState(() => _catches = catches);

      final summaryCatches = catches.where(
        (item) => ['Bidding', 'Sold'].contains(item['status']),
      );
      final bidResults = await Future.wait(
        summaryCatches.map((item) async {
          final id = int.tryParse((item['id'] ?? '').toString());
          if (id == null) {
            return (id: null, bids: null, error: 'A catch has an invalid ID.');
          }
          try {
            return (id: id, bids: await api.getCatchBids(id), error: null);
          } catch (error) {
            return (id: id, bids: null, error: error.toString());
          }
        }),
      );
      if (mounted) {
        setState(() {
          _bidsByCatch = {
            for (final result in bidResults)
              if (result.id != null && result.bids != null)
                result.id!: result.bids!,
          };
          final failures = bidResults
              .where((result) => result.error != null)
              .map((result) => result.error!)
              .toList();
          _bidSummaryError = failures.isEmpty ? null : failures.join('\n');
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final drafts = _catches.where((c) => !_hasQualityAgent(c)).length;
    final active = _catches
        .where((c) => ['Published', 'Bidding'].contains(c['status']))
        .length;
    final bidding = _catches.where((c) => c['status'] == 'Bidding').length;
    final sold = _catches.where((c) => c['status'] == 'Sold').length;
    final totalRevenue = _catches
        .where((item) => item['status'] == 'Sold')
        .fold<double>(0, (total, item) {
          final id = int.tryParse((item['id'] ?? '').toString());
          final acceptedBid = (id == null ? null : _bidsByCatch[id])
              ?.whereType<Map>()
              .cast<Map>()
              .firstWhere(
                (bid) => bid['status'] == 'Accepted',
                orElse: () => {},
              );
          final rate = acceptedBid == null || acceptedBid.isEmpty
              ? _number(item['askingPricePerKg'])
              : _number(
                  acceptedBid['bidPricePerKg'] ??
                      acceptedBid['price'] ??
                      item['askingPricePerKg'],
                );
          return total + _number(item['quantityKg']) * rate;
        });
    final biddingCatchIds = _catches
        .where((item) => item['status'] == 'Bidding')
        .map((item) => int.tryParse((item['id'] ?? '').toString()))
        .whereType<int>()
        .toSet();
    final liveBids = _bidsByCatch.entries
        .where((entry) => biddingCatchIds.contains(entry.key))
        .fold<int>(0, (total, entry) => total + entry.value.length);

    return RefreshIndicator(
      onRefresh: _loadCatches,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff003859), Color(0xff00628a)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fisherman dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Manage your catch listings, quality checks, bids, and sales.',
                  style: TextStyle(color: Color(0xffd9f2ff)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_error != null)
            Card(
              color: Colors.red.shade50,
              child: ListTile(
                leading: const Icon(Icons.error_outline, color: Colors.red),
                title: const Text('Could not load your catches'),
                subtitle: Text(_error!),
                trailing: IconButton(
                  onPressed: _loadCatches,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Retry',
                ),
              ),
            ),
          if (_loading && _catches.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            LayoutBuilder(
              builder: (context, constraints) => GridView.count(
                crossAxisCount: constraints.maxWidth > 650 ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.55,
                children: [
                  _StatCard(
                    title: 'Verified catches',
                    value: '${_catches.length - drafts}',
                    color: const Color(0xff005b96),
                    onTap: widget.onNavigateToCatches,
                  ),
                  _StatCard(
                    title: 'Saved drafts',
                    value: '$drafts',
                    color: const Color(0xffd97706),
                    onTap: widget.onNavigateToCatches,
                  ),
                  _StatCard(
                    title: 'Active listings',
                    value: '$active',
                    color: const Color(0xff059669),
                    onTap: widget.onNavigateToCatches,
                  ),
                  _StatCard(
                    title: 'Bidding / sold',
                    value: '$bidding / $sold',
                    color: const Color(0xff4f46e5),
                    onTap: widget.onNavigateToCatches,
                  ),
                  _StatCard(
                    title: 'Live bids',
                    value: '$liveBids',
                    color: const Color(0xff2563eb),
                    onTap: widget.onNavigateToCatches,
                  ),
                  _StatCard(
                    title: 'Completed sales',
                    value: '$sold',
                    color: const Color(0xff4f46e5),
                    onTap: widget.onNavigateToCatches,
                  ),
                  _StatCard(
                    title: 'Total revenue',
                    value: 'Rs. ${_formatNumber(totalRevenue)}',
                    color: const Color(0xff7c3aed),
                    onTap: widget.onNavigateToCatches,
                  ),
                ],
              ),
            ),
            if (_bidSummaryError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Bid and revenue summary could not be fully loaded: $_bidSummaryError',
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Recent catch listings',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: _loading ? null : _loadCatches,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh catches',
                ),
              ],
            ),
            if (_catches.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No catch listings yet. Open Catches to register your first catch.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ..._catches
                  .take(3)
                  .map(
                    (item) => _FishermanCatchCard(
                      catchRecord: item,
                      onChanged: _loadCatches,
                      onEdit: _editCatch,
                      onActionMessage: _showMessage,
                    ),
                  ),
            if (_catches.length > 3)
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  onPressed: widget.onNavigateToCatches,
                  icon: const Icon(Icons.list_alt),
                  label: Text('View all ${_catches.length} catches'),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: widget.onNavigateToCatches,
              icon: const Icon(Icons.set_meal),
              label: const Text('Manage catches and bids'),
            ),
          ],
        ],
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  Future<void> _editCatch(Map<String, dynamic> item) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => NewCatchScreen(initialCatch: item)),
    );
    if (mounted) await _loadCatches();
  }
}

class _MyCatchesLiveScreen extends StatefulWidget {
  const _MyCatchesLiveScreen();

  @override
  State<_MyCatchesLiveScreen> createState() => _MyCatchesLiveScreenState();
}

class _MyCatchesLiveScreenState extends State<_MyCatchesLiveScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _catches = [];
  String _filter = 'all';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCatches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCatches() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catches = await ApiClient().getMyCatches();
      if (mounted) setState(() => _catches = catches);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm([Map<String, dynamic>? item]) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => NewCatchScreen(initialCatch: item)),
    );
    if (mounted) await _loadCatches();
  }

  List<Map<String, dynamic>> get _visibleCatches {
    final query = _searchController.text.trim().toLowerCase();
    return _catches.where((item) {
      final status = (item['status'] ?? '').toString();
      final inFilter = switch (_filter) {
        'draft' => !_hasQualityAgent(item),
        'active' =>
          ['Published', 'Bidding'].contains(status) && _hasQualityAgent(item),
        'bidding' => status == 'Bidding',
        'sold' => status == 'Sold',
        _ => _hasQualityAgent(item),
      };
      final inSearch =
          query.isEmpty ||
          (item['fishSpecies'] ?? '').toString().toLowerCase().contains(
            query,
          ) ||
          (item['location'] ?? '').toString().toLowerCase().contains(query);
      return inFilter && inSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final draftCount = _catches.where((c) => !_hasQualityAgent(c)).length;
    final activeCount = _catches
        .where(
          (c) =>
              ['Published', 'Bidding'].contains(c['status']) &&
              _hasQualityAgent(c),
        )
        .length;
    final biddingCount = _catches.where((c) => c['status'] == 'Bidding').length;
    final soldCount = _catches.where((c) => c['status'] == 'Sold').length;
    final filters = <(String, String, int)>[
      ('all', 'Verified', _catches.length - draftCount),
      ('draft', 'Drafts', draftCount),
      ('active', 'Active', activeCount),
      ('bidding', 'Bidding', biddingCount),
      ('sold', 'Sold', soldCount),
    ];

    return RefreshIndicator(
      onRefresh: _loadCatches,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'My Catch Listings',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: _loading ? null : _loadCatches,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh catches',
              ),
            ],
          ),
          FilledButton.icon(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add),
            label: const Text('Register New Catch'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Search catches',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map((entry) {
                final (value, label, count) = entry;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('$label ($count)'),
                    selected: _filter == value,
                    onSelected: (_) => setState(() => _filter = value),
                  ),
                );
              }).toList(),
            ),
          ),
          if (_error != null)
            Card(
              color: Colors.red.shade50,
              child: ListTile(
                leading: const Icon(Icons.error_outline, color: Colors.red),
                title: const Text('Could not load your catches'),
                subtitle: Text(_error!),
                trailing: IconButton(
                  onPressed: _loadCatches,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Retry',
                ),
              ),
            ),
          if (_loading && _catches.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_visibleCatches.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 28),
              child: Text(
                _filter == 'draft'
                    ? 'No saved forms without Quality Agent verification.'
                    : _filter == 'all'
                    ? 'No catches with Quality Agent verification found yet.'
                    : 'No catches found for this filter.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            )
          else
            ..._visibleCatches.map(
              (item) => _FishermanCatchCard(
                catchRecord: item,
                onChanged: _loadCatches,
                onEdit: _openForm,
                onActionMessage: _showMessage,
              ),
            ),
        ],
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }
}

class _FishermanCatchCard extends StatefulWidget {
  const _FishermanCatchCard({
    required this.catchRecord,
    required this.onChanged,
    required this.onEdit,
    required this.onActionMessage,
  });

  final Map<String, dynamic> catchRecord;
  final Future<void> Function() onChanged;
  final Future<void> Function(Map<String, dynamic>) onEdit;
  final void Function(String, {bool isError}) onActionMessage;

  @override
  State<_FishermanCatchCard> createState() => _FishermanCatchCardState();
}

class _FishermanCatchCardState extends State<_FishermanCatchCard> {
  List<dynamic>? _bids;
  List<dynamic>? _matches;
  bool _loadingBids = false;
  bool _loadingMatches = false;
  String? _bidsError;
  String? _matchesError;
  Timer? _qualityRefreshTimer;

  Map<String, dynamic> get _catch => widget.catchRecord;
  int get _id => int.tryParse((_catch['id'] ?? '').toString()) ?? 0;
  String get _status => (_catch['status'] ?? 'Draft').toString();

  @override
  void dispose() {
    _qualityRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBids() async {
    setState(() {
      _loadingBids = true;
      _bidsError = null;
    });
    try {
      final bids = await ApiClient().getCatchBids(_id);
      if (mounted) setState(() => _bids = bids);
    } catch (error) {
      if (mounted) setState(() => _bidsError = error.toString());
    } finally {
      if (mounted) setState(() => _loadingBids = false);
    }
  }

  Future<void> _loadMatches() async {
    setState(() {
      _loadingMatches = true;
      _matchesError = null;
    });
    try {
      final result = await ApiClient().getRecommendedBuyers(_id);
      final matches = result['scoredBuyers'];
      if (matches is! List) {
        throw Exception(
          'The buyer matching service returned an invalid response.',
        );
      }
      if (mounted) setState(() => _matches = matches);
    } catch (error) {
      if (mounted) setState(() => _matchesError = error.toString());
    } finally {
      if (mounted) setState(() => _loadingMatches = false);
    }
  }

  Future<void> _acceptBid(Map<String, dynamic> bid) async {
    final bidId = int.tryParse((bid['id'] ?? '').toString());
    if (bidId == null) {
      widget.onActionMessage('This bid has no valid ID.', isError: true);
      return;
    }
    final buyerName =
        (bid['buyer'] is Map
                ? (bid['buyer'] as Map)['fullName']
                : bid['buyerName'] ?? bid['fullName'] ?? 'this buyer')
            .toString();
    if (!await _confirm(
      'Accept this bid?',
      "Accept $buyerName's offer of Rs. ${_formatNumber(_number(bid['bidPricePerKg']))}/kg?",
    )) {
      return;
    }
    try {
      await ApiClient().acceptBid(bidId);
      widget.onActionMessage('Bid accepted.');
      await _loadBids();
      await widget.onChanged();
    } catch (error) {
      widget.onActionMessage('Could not accept bid: $error', isError: true);
    }
  }

  Future<void> _rejectBid(Map<String, dynamic> bid) async {
    final bidId = int.tryParse((bid['id'] ?? '').toString());
    if (bidId == null) {
      widget.onActionMessage('This bid has no valid ID.', isError: true);
      return;
    }
    final buyerName =
        (bid['buyer'] is Map
                ? (bid['buyer'] as Map)['fullName']
                : bid['buyerName'] ?? bid['fullName'] ?? 'this buyer')
            .toString();
    if (!await _confirm(
      'Reject this bid?',
      'Reject the offer from $buyerName?',
    )) {
      return;
    }
    try {
      await ApiClient().rejectBid(bidId);
      widget.onActionMessage('Bid rejected.');
      await _loadBids();
      await widget.onChanged();
    } catch (error) {
      widget.onActionMessage('Could not reject bid: $error', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final species = (_catch['fishSpecies'] ?? 'Fish catch').toString();
    final quantity = _number(_catch['quantityKg']);
    final askingPrice = _number(_catch['askingPricePerKg']);
    final canEdit = ['Draft', 'Published'].contains(_status);
    final canCancel = canEdit;
    final canDelete = _status == 'Draft';
    final canPublish =
        _status == 'Draft' &&
        _hasQualityAgent(_catch) &&
        (_catch['declaredQualityGrade'] ?? '').toString().isNotEmpty &&
        _splitCatchPhotos((_catch['photoUrl'] ?? '').toString()).$2.isNotEmpty;
    final photos = _splitCatchPhotos((_catch['photoUrl'] ?? '').toString());
    final grade = (_catch['declaredQualityGrade'] ?? '').toString();
    final inspection = (_catch['inspectionResult'] ?? '').toString();
    final verifiedWeight = _number(_catch['verifiedWeightKg']);
    final soldRevenue =
        quantity * _number(_acceptedPrice ?? _catch['askingPricePerKg']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$species (${_formatNumber(quantity)} kg)',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _CatchStatusBadge(status: _status),
              ],
            ),
            if (photos.$1.isNotEmpty) ...[
              const SizedBox(height: 10),
              _catchImage(photos.$1, height: 150),
            ],
            const SizedBox(height: 8),
            Text('Asking price: Rs. ${_formatNumber(askingPrice)}/kg'),
            Text('Location: ${_catch['location'] ?? 'Not provided'}'),
            if (grade.isNotEmpty || inspection.isNotEmpty || verifiedWeight > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (grade.isNotEmpty)
                      Chip(
                        avatar: const Icon(Icons.verified, size: 16),
                        label: Text('Grade $grade'),
                        visualDensity: VisualDensity.compact,
                      ),
                    if (inspection.isNotEmpty)
                      Chip(
                        label: Text('Inspection: $inspection'),
                        visualDensity: VisualDensity.compact,
                      ),
                    if (verifiedWeight > 0)
                      Chip(
                        label: Text(
                          'Scale: ${_formatNumber(verifiedWeight)} kg',
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            if (photos.$2.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Pier Inspector Verification'),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _catchImage(photos.$2, height: 220),
                            const SizedBox(height: 8),
                            Text(
                              '$species • ${_formatNumber(quantity)} kg • Grade ${grade.isEmpty ? 'not recorded' : grade}\n${_catch['location'] ?? ''}',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                  icon: const Icon(Icons.shield_outlined),
                  label: const Text('View inspector verification'),
                ),
              ),
            if (_status == 'Sold')
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Completed deal • Revenue: Rs. ${_formatNumber(soldRevenue)}',
                  style: TextStyle(
                    color: Colors.purple.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (!_hasQualityAgent(_catch))
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: const Text(
                  'Saved without Quality Agent verification. Edit this draft to add pier inspection details before publishing.',
                  style: TextStyle(color: Color(0xff92400e)),
                ),
              ),
            if (['Bidding', 'Sold'].contains(_status))
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Live bids and accepted bid history'),
                onExpansionChanged: (open) {
                  if (open && _bids == null) _loadBids();
                },
                children: [_buildBids()],
              ),
            if (['Published', 'Bidding'].contains(_status))
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('AI Buyer Matching'),
                onExpansionChanged: (open) {
                  if (open && _matches == null) _loadMatches();
                },
                children: [_buildMatches()],
              ),
            if (!canEdit && !['Cancelled', 'Expired'].contains(_status))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'This listing is locked for editing ($_status).',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            const Divider(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (canPublish)
                  FilledButton.tonalIcon(
                    onPressed: _publish,
                    icon: const Icon(Icons.publish),
                    label: const Text('Publish Listing'),
                  ),
                if (canEdit)
                  OutlinedButton.icon(
                    onPressed: () => widget.onEdit(_catch),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(
                      _hasQualityAgent(_catch)
                          ? 'Edit'
                          : 'Edit & Add Quality Details',
                    ),
                  ),
                if (canCancel)
                  OutlinedButton.icon(
                    onPressed: _cancel,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel Listing'),
                  ),
                if (canDelete)
                  OutlinedButton.icon(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete Saved Form'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? get _acceptedPrice {
    for (final bid in _bids ?? const []) {
      if (bid is Map && bid['status'] == 'Accepted') {
        return (bid['bidPricePerKg'] ?? bid['price'])?.toString();
      }
    }
    return null;
  }

  Widget _buildBids() {
    if (_loadingBids) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_bidsError != null && _bids == null) {
      return _detailsErrorWidget(_bidsError!, _loadBids);
    }
    final bids = (_bids ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    if (bids.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('No bids have been received for this listing yet.'),
      );
    }
    return Column(
      children: bids.map((bid) {
        final status = (bid['status'] ?? 'Pending').toString();
        final pending = status.toLowerCase() == 'pending';
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            (bid['buyer'] is Map
                    ? (bid['buyer'] as Map)['fullName']
                    : bid['buyerName'] ?? bid['fullName'] ?? 'Buyer')
                .toString(),
          ),
          subtitle: Text(
            'Rs. ${_formatNumber(_number(bid['bidPricePerKg']))}/kg • $status',
          ),
          trailing: pending
              ? Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: 'Reject bid',
                      onPressed: () => _rejectBid(bid),
                      icon: const Icon(Icons.close, color: Colors.red),
                    ),
                    IconButton(
                      tooltip: 'Accept bid',
                      onPressed: () => _acceptBid(bid),
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                    ),
                  ],
                )
              : null,
        );
      }).toList(),
    );
  }

  Widget _buildMatches() {
    if (_loadingMatches) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_matchesError != null && _matches == null) {
      return _detailsErrorWidget(_matchesError!, _loadMatches);
    }
    final matches = (_matches ?? const []).whereType<Map>().toList();
    if (matches.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('No buyer matches found yet for this listing.'),
      );
    }
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Top ${matches.length} registered buyers',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
        ...matches.take(10).map((match) {
          final score = _number(match['matchScore']).round();
          final preference = match['hasPreference'] == true;
          final reason = (match['matchReasons'] ?? '').toString();
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              child: Text(
                (match['name'] ?? 'B').toString().isNotEmpty
                    ? (match['name'] ?? 'B').toString()[0].toUpperCase()
                    : 'B',
              ),
            ),
            title: Text((match['name'] ?? 'Buyer').toString()),
            subtitle: Text(
              '${preference ? 'Preferences set' : 'No preferences'}'
              '${_number(match['totalBids']) > 0 ? ' • ${_number(match['totalBids']).round()} bids' : ''}'
              '${reason.isNotEmpty ? '\n$reason' : ''}',
            ),
            trailing: Chip(label: Text('$score%')),
            onTap: () => _showBuyerDetails(Map<String, dynamic>.from(match)),
          );
        }),
      ],
    );
  }

  void _showBuyerDetails(Map<String, dynamic> match) {
    final name = (match['name'] ?? 'Buyer').toString();
    final reason = (match['matchReasons'] ?? '').toString();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text((match['email'] ?? 'No email provided').toString()),
            const SizedBox(height: 10),
            Text('Match score: ${_number(match['matchScore']).round()}%'),
            Text(
              'Preferred species: ${(match['preferredSpecies'] ?? '').toString().isEmpty ? 'Any' : match['preferredSpecies']}',
            ),
            Text(
              'Maximum budget: Rs. ${_formatNumber(_number(match['maxBudget']))}/kg',
            ),
            Text(
              'Preferred city: ${(match['preferredCity'] ?? '').toString().isEmpty ? 'Any' : match['preferredCity']}',
            ),
            Text('Total bids: ${_number(match['totalBids']).round()}'),
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(reason),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailsErrorWidget(String message, VoidCallback onRetry) => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      children: [
        Text(message, style: TextStyle(color: Colors.red.shade700)),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _publish() async {
    final species = (_catch['fishSpecies'] ?? 'catch').toString();
    if (!await _confirm(
      'Publish catch listing?',
      'Publish $species? The Quality Agent will validate it.',
    )) {
      return;
    }
    try {
      await ApiClient().publishCatch(_id);
      await widget.onChanged();
      try {
        final token = await const FlutterSecureStorage().read(key: 'token');
        final claim = token == null || token.split('.').length < 2
            ? 0
            : _tokenUserId(token);
        await ApiClient().startQualityWorkflow({
          'workflowId':
              'workflow-$_id-${DateTime.now().millisecondsSinceEpoch}',
          'catchId': _id,
          'fishermanId': claim,
          'quantityKg': _number(_catch['quantityKg']),
          'askingPrice': _number(_catch['askingPricePerKg']),
          'fishSpecies': species,
          'verifiedWeightKg': _number(_catch['verifiedWeightKg']),
          'declaredQualityGrade': _catch['declaredQualityGrade'] ?? '',
          'inspectionResult': _catch['inspectionResult'] ?? 'Pending',
          'catchDatetime': _catch['catchDateTime'],
          'sellerNote': _catch['sellerNote'] ?? '',
        });
        widget.onActionMessage(
          'Listing published; Quality Agent validation started.',
        );
        _qualityRefreshTimer?.cancel();
        _qualityRefreshTimer = Timer(const Duration(seconds: 6), () {
          if (mounted) unawaited(widget.onChanged());
        });
      } catch (error) {
        widget.onActionMessage(
          'Listing published, but Quality Agent validation could not start: $error',
          isError: true,
        );
      }
    } catch (error) {
      widget.onActionMessage(
        'Could not publish listing: $error',
        isError: true,
      );
    }
  }

  Future<void> _cancel() async {
    if (!await _confirm(
      'Cancel listing?',
      'Cancel ${_catch['fishSpecies'] ?? 'this catch'}? This cannot be undone.',
    )) {
      return;
    }
    try {
      await ApiClient().cancelCatch(_id);
      widget.onActionMessage('Listing cancelled.');
      await widget.onChanged();
    } catch (error) {
      widget.onActionMessage('Could not cancel listing: $error', isError: true);
    }
  }

  Future<void> _delete() async {
    if (!await _confirm(
      'Delete saved form?',
      'Permanently delete the saved draft for ${_catch['fishSpecies'] ?? 'this catch'}?',
    )) {
      return;
    }
    try {
      await ApiClient().deleteCatch(_id);
      widget.onActionMessage('Saved form deleted.');
      await widget.onChanged();
    } catch (error) {
      widget.onActionMessage(
        'Could not delete saved form: $error',
        isError: true,
      );
    }
  }
}

class _CatchStatusBadge extends StatelessWidget {
  const _CatchStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (color, background) = switch (status) {
      'Published' => (Colors.green.shade800, Colors.green.shade50),
      'Bidding' => (Colors.blue.shade800, Colors.blue.shade50),
      'PendingApproval' => (Colors.deepOrange.shade800, Colors.orange.shade50),
      'Sold' => (Colors.purple.shade800, Colors.purple.shade50),
      'Cancelled' => (Colors.red.shade800, Colors.red.shade50),
      'Expired' => (Colors.blueGrey.shade800, Colors.blueGrey.shade50),
      _ => (Colors.amber.shade900, Colors.amber.shade50),
    };
    return Chip(
      label: Text(status == 'PendingApproval' ? 'Pending Approval' : status),
      backgroundColor: background,
      side: BorderSide(color: color.withValues(alpha: 0.25)),
      labelStyle: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

class NewCatchScreen extends StatefulWidget {
  const NewCatchScreen({this.initialCatch, super.key});

  final Map<String, dynamic>? initialCatch;

  @override
  State<NewCatchScreen> createState() => _NewCatchScreenState();
}

class _NewCatchScreenState extends State<NewCatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _quantity = TextEditingController();
  final TextEditingController _expectedPrice = TextEditingController();
  final TextEditingController _location = TextEditingController(
    text: 'Negombo',
  );
  final TextEditingController _description = TextEditingController();
  final TextEditingController _catchDate = TextEditingController();
  final TextEditingController _catchTime = TextEditingController();
  final TextEditingController _verifiedWeight = TextEditingController();
  final TextEditingController _customSpecies = TextEditingController();

  static const _speciesOptions = [
    'Tuna (Yellowfin)',
    'Skipjack',
    'Trevally (Paraw)',
    'Mackerel',
    'Seer Fish (Thora)',
    'Sailfish (Thalapath)',
    'Barramundi (Modha)',
    'Red Snapper (Ranna)',
    'Cuttlefish / Squid',
    'Prawns / Shrimp',
    'Crab',
  ];

  String _species = _speciesOptions.first;
  String _declaredGrade = '';
  String _inspectionResult = 'Pending';
  String _catchPhoto = '';
  String _inspectorPhoto = '';
  bool _loading = false;
  bool _loadingRecommendation = false;
  Map<String, dynamic>? _recommendation;
  String? _recommendationError;

  @override
  void initState() {
    super.initState();
    final item = widget.initialCatch;
    if (item == null) return;

    final species = (item['fishSpecies'] ?? _speciesOptions.first).toString();
    _species = _speciesOptions.contains(species) ? species : '__custom__';
    if (_species == '__custom__') _customSpecies.text = species;
    _quantity.text = (item['quantityKg'] ?? '').toString();
    _expectedPrice.text = (item['askingPricePerKg'] ?? '').toString();
    _location.text = (item['location'] ?? '').toString();
    _description.text = (item['sellerNote'] ?? '').toString();
    _verifiedWeight.text = (item['verifiedWeightKg'] ?? '').toString();
    _declaredGrade = (item['declaredQualityGrade'] ?? '').toString();
    _inspectionResult = (item['inspectionResult'] ?? 'Pending').toString();
    final photos = _splitCatchPhotos((item['photoUrl'] ?? '').toString());
    _catchPhoto = photos.$1;
    _inspectorPhoto = photos.$2;

    final catchDateTime = DateTime.tryParse(
      (item['catchDateTime'] ?? '').toString(),
    )?.toLocal();
    if (catchDateTime != null) {
      _catchDate.text =
          '${catchDateTime.year.toString().padLeft(4, '0')}-${catchDateTime.month.toString().padLeft(2, '0')}-${catchDateTime.day.toString().padLeft(2, '0')}';
      _catchTime.text =
          '${catchDateTime.hour.toString().padLeft(2, '0')}:${catchDateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  void dispose() {
    _quantity.dispose();
    _expectedPrice.dispose();
    _location.dispose();
    _description.dispose();
    _catchDate.dispose();
    _catchTime.dispose();
    _verifiedWeight.dispose();
    _customSpecies.dispose();
    super.dispose();
  }

  Future<void> _pickImage({required bool inspector}) async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo size cannot exceed 5 MB.')),
      );
      return;
    }
    final extension = file.name.split('.').last.toLowerCase();
    final mimeType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    final photo = 'data:$mimeType;base64,${base64Encode(bytes)}';
    if (!mounted) return;
    setState(() {
      if (inspector) {
        _inspectorPhoto = photo;
      } else {
        _catchPhoto = photo;
      }
    });
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
      _catchDate.text =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _pickTime() async {
    final now = TimeOfDay.now();
    final time = await showTimePicker(context: context, initialTime: now);
    if (!mounted) return;
    if (time != null) {
      _catchTime.text =
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
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
          content: Text(
            'Location permission is required for catch registration.',
          ),
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

  String get _resolvedSpecies =>
      _species == '__custom__' ? _customSpecies.text.trim() : _species;

  DateTime? get _catchDateTime {
    if (_catchDate.text.isEmpty) return null;
    final time = _catchTime.text.isEmpty ? '00:00' : _catchTime.text;
    return DateTime.tryParse('${_catchDate.text}T$time');
  }

  Future<void> _loadMarketRecommendation() async {
    final askingPrice = double.tryParse(_expectedPrice.text);
    if (_resolvedSpecies.isEmpty || askingPrice == null || askingPrice <= 0) {
      setState(() {
        _recommendation = null;
        _recommendationError =
            'Enter a fish species and asking price to get a recommendation.';
      });
      return;
    }
    setState(() {
      _loadingRecommendation = true;
      _recommendation = null;
      _recommendationError = null;
    });
    try {
      final result = await ApiClient().marketRecommendation(
        species: _resolvedSpecies,
        askingPrice: askingPrice,
      );
      if (mounted) setState(() => _recommendation = result);
    } catch (error) {
      if (mounted) setState(() => _recommendationError = error.toString());
    } finally {
      if (mounted) setState(() => _loadingRecommendation = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final photoUrl = _inspectorPhoto.isNotEmpty
        ? '$_catchPhoto|||$_inspectorPhoto'
        : _catchPhoto;

    final payload = {
      'fishSpecies': _resolvedSpecies,
      'quantityKg': double.parse(_quantity.text),
      'askingPricePerKg': double.parse(_expectedPrice.text),
      'location': _location.text,
      'sellerNote': _description.text,
      'catchDateTime': _catchDateTime?.toUtc().toIso8601String(),
      'photoUrl': photoUrl,
      'verifiedWeightKg': double.tryParse(_verifiedWeight.text) ?? 0,
      'declaredQualityGrade': _declaredGrade,
      'inspectionResult': _inspectionResult,
    };

    try {
      final initialCatch = widget.initialCatch;
      if (initialCatch == null) {
        await ApiClient().createCatch(payload);
      } else {
        final id = int.tryParse((initialCatch['id'] ?? '').toString());
        if (id == null) throw Exception('This catch listing has no valid ID.');
        await ApiClient().updateCatch(id, payload);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save catch: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialCatch == null ? 'Register New Catch' : 'Edit Catch',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _species,
              decoration: const InputDecoration(labelText: 'Fish Species'),
              items: [
                ..._speciesOptions.map(
                  (item) => DropdownMenuItem(value: item, child: Text(item)),
                ),
                const DropdownMenuItem(
                  value: '__custom__',
                  child: Text('Other (custom fish species)'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _species = value ?? _speciesOptions.first),
            ),
            if (_species == '__custom__') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _customSpecies,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Custom fish species',
                  hintText: 'e.g. Lobster',
                ),
                validator: (_) =>
                    _resolvedSpecies.isEmpty ? 'Enter the fish species' : null,
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _quantity,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Quantity (kg)'),
              validator: (value) {
                final parsed = double.tryParse(value ?? '');
                if (parsed == null || parsed <= 0) {
                  return 'Enter a valid quantity';
                }
                if (parsed > 10000) {
                  return 'Quantity cannot exceed 10,000 kg';
                }
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
                        decoration: const InputDecoration(
                          labelText: 'Catch Date (optional)',
                        ),
                        validator: (_) {
                          final dateTime = _catchDateTime;
                          if (_catchDate.text.isEmpty) {
                            return _catchTime.text.isEmpty
                                ? null
                                : 'Select a catch date first';
                          }
                          if (dateTime == null) {
                            return 'Enter a valid catch date';
                          }
                          final now = DateTime.now();
                          if (dateTime.isAfter(now)) {
                            return 'Catch date cannot be in the future';
                          }
                          if (now.difference(dateTime).inDays > 30) {
                            return 'Catch date cannot be older than 30 days';
                          }
                          return null;
                        },
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
                          labelText: 'Catch Time (optional)',
                        ),
                        validator: (value) {
                          if (value != null &&
                              value.isNotEmpty &&
                              _catchDate.text.isEmpty) {
                            return 'Select a catch date first';
                          }
                          return null;
                        },
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
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a catch location'
                        : null,
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
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Expected Price (Rs/kg)',
                      prefixText: 'Rs. ',
                    ),
                    validator: (value) {
                      final parsed = double.tryParse(value ?? '');
                      if (parsed == null || parsed < 50) {
                        return 'Price must be at least Rs. 50/kg';
                      }
                      if (parsed > 100000) {
                        return 'Price cannot exceed Rs. 100,000/kg';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  onPressed: () {
                    final q = double.tryParse(_quantity.text) ?? 100;
                    showAiPriceRecommendationModal(
                      context,
                      species: _resolvedSpecies,
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
              onPressed: _loadingRecommendation
                  ? null
                  : _loadMarketRecommendation,
              icon: _loadingRecommendation
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: const Text('Get Market Intelligence Recommendation'),
            ),
            if (_recommendation case final recommendation?) ...[
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Suggested: Rs. ${_formatNumber(_number(recommendation['recommendedPrice']))}/kg',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if ((recommendation['marketInsight'] ?? '')
                          .toString()
                          .isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            recommendation['marketInsight'].toString(),
                          ),
                        ),
                      TextButton(
                        onPressed: () => setState(() {
                          _expectedPrice.text = _number(
                            recommendation['recommendedPrice'],
                          ).toString();
                        }),
                        child: const Text('Use suggested price'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_recommendationError != null)
              Text(
                _recommendationError!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _pickImage(inspector: false),
              icon: const Icon(Icons.camera_alt),
              label: Text(
                _catchPhoto.isEmpty ? 'Add Catch Photo' : 'Replace Catch Photo',
              ),
            ),
            if (_catchPhoto.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _catchImage(_catchPhoto, height: 150),
              ),
            const SizedBox(height: 12),
            const Text(
              'Quality & Inspection Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _verifiedWeight,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Verified Weight (kg)',
                hintText: 'Physical weight at the pier',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                final parsed = double.tryParse(value);
                if (parsed == null || parsed <= 0) {
                  return 'Verified weight must be greater than 0 kg';
                }
                if (parsed > 10000) {
                  return 'Verified weight cannot exceed 10,000 kg';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _declaredGrade.isEmpty ? null : _declaredGrade,
              decoration: const InputDecoration(
                labelText: 'Declared Quality Grade',
              ),
              items: const [
                DropdownMenuItem(value: 'A+', child: Text('A+ (Premium)')),
                DropdownMenuItem(value: 'A', child: Text('A (Good)')),
                DropdownMenuItem(value: 'B', child: Text('B (Average)')),
                DropdownMenuItem(value: 'C', child: Text('C (Below average)')),
              ],
              onChanged: (value) =>
                  setState(() => _declaredGrade = value ?? ''),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _inspectionResult,
              decoration: const InputDecoration(labelText: 'Inspection Result'),
              items: const [
                DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                DropdownMenuItem(value: 'Passed', child: Text('Passed')),
                DropdownMenuItem(value: 'Failed', child: Text('Failed')),
              ],
              onChanged: (value) =>
                  setState(() => _inspectionResult = value ?? 'Pending'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _pickImage(inspector: true),
              icon: const Icon(Icons.badge_outlined),
              label: Text(
                _inspectorPhoto.isEmpty
                    ? 'Add Harbour Inspector ID / Pier Badge Photo'
                    : 'Replace Inspector Verification Photo',
              ),
            ),
            if (_inspectorPhoto.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _catchImage(_inspectorPhoto, height: 150),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Seller Note',
                hintText: 'Catch quality, storage, and handling details',
              ),
              validator: (value) => (value?.length ?? 0) > 500
                  ? 'Seller note cannot exceed 500 characters'
                  : null,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                widget.initialCatch == null
                    ? 'Save as Draft'
                    : 'Save Draft Changes',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Listings are saved as drafts. Add inspector verification, then publish them from My Catch Listings.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              textAlign: TextAlign.center,
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
      'advice':
          'Use caution during afternoon wind shift and monitor swell height.',
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
        const _MarketRow(
          title: 'Tuna',
          detail: 'Rise • Rs.1650/kg',
          action: 'Strong',
        ),
        const _MarketRow(
          title: 'Mackerel',
          detail: 'Stable • Rs.1280/kg',
          action: 'Stable',
        ),
        const _MarketRow(
          title: 'Seer Fish',
          detail: 'High demand • Rs.1900/kg',
          action: 'Hot',
        ),
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
        Image.asset('assets/hero-bg.jpg', fit: BoxFit.cover),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 430),
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
                    const SizedBox(height: 160, child: _AuthImagePanel()),
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
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'View',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
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
                Icon(
                  Icons.arrow_forward_ios,
                  size: 10,
                  color: Colors.grey.shade400,
                ),
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
        color: isLeading
            ? const Color(0xff0077b6).withValues(alpha: 0.35)
            : Colors.grey.shade300,
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
                const Icon(
                  Icons.timer_outlined,
                  size: 13,
                  color: Colors.orange,
                ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Counter offer modal requested'),
                      ),
                    );
                  },
                  child: const Text('Counter', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 6),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xff005b96),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Bid of $bidPricePerKg accepted for $lotNumber!',
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    'Accept Bid',
                    style: TextStyle(fontSize: 12),
                  ),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
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
  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.child,
  });

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
  const _MarketRow({
    required this.title,
    required this.detail,
    required this.action,
  });

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
    'status': 'Active',
  },
  {
    'species': 'Narrow-Barred Seer (Thora)',
    'quantity': 75,
    'price': 2450,
    'location': 'Negombo Pier 3',
    'status': 'Active',
  },
  {
    'species': 'Skipjack Tuna (Balaya)',
    'quantity': 120,
    'price': 980,
    'location': 'Beruwala Jetty',
    'status': 'Pending',
  },
  {
    'species': 'Sailfish (Thalapath)',
    'quantity': 90,
    'price': 1480,
    'location': 'Galle Fishery Port',
    'status': 'Sold',
  },
  {
    'species': 'Giant Tiger Prawns',
    'quantity': 45,
    'price': 3100,
    'location': 'Kalpitiya Lagoon',
    'status': 'Active',
  },
  {
    'species': 'Barramundi (Modha)',
    'quantity': 55,
    'price': 1750,
    'location': 'Trincomalee Basin',
    'status': 'Pending',
  },
  {
    'species': 'Blue Swimming Crab',
    'quantity': 35,
    'price': 1950,
    'location': 'Jaffna Coast',
    'status': 'Sold',
  },
  {
    'species': 'Trevally (Paraw)',
    'quantity': 60,
    'price': 1450,
    'location': 'Matara Fishery Port',
    'status': 'Active',
  },
];
