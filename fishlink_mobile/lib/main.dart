import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

const apiBaseUrl = String.fromEnvironment(
  'FISHLINK_API_URL',
  defaultValue: 'https://10.0.2.2:7042/api',
);

void main() => runApp(const FishLinkApp());

class ApiClient {
  ApiClient({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();
  final http.Client _client;
  final FlutterSecureStorage _storage;

  Future<Map<String, dynamic>> _request(String method, String path,
      {Object? body, bool authenticated = true}) async {
    final token = authenticated ? await _storage.read(key: 'token') : null;
    final response = await _client
        .send(http.Request(method, Uri.parse('$apiBaseUrl$path'))
          ..headers.addAll({
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          })
          ..body = body == null ? '' : jsonEncode(body));
    final text = await response.stream.bytesToString();
    dynamic decoded;
    try {
      decoded = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
    } catch (_) {
      decoded = text;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map ? decoded['message'] ?? decoded['title'] : decoded;
      throw Exception(message?.toString() ?? 'Request failed (${response.statusCode})');
    }
    return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
  }

  Future<Map<String, dynamic>> login(String email, String password) =>
      _request('POST', '/Auth/login',
          body: {'email': email, 'password': password}, authenticated: false);

  Future<List<dynamic>> catches({bool mine = false}) async {
    final result = await _request('GET', '/Catches');
    return (result['items'] as List<dynamic>? ?? const []);
  }

  Future<void> createCatch(Map<String, dynamic> payload) async {
    await _request('POST', '/Catches', body: payload);
  }

  Future<Map<String, dynamic>> safety(String location) =>
      _request('GET', '/Weather/fishing-safety?location=${Uri.encodeQueryComponent(location)}');
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
      if (mounted) setState(() => _signedIn = token != null);
    });
  }

  void _onSignedIn(String role) => setState(() {
        _role = role;
        _signedIn = true;
      });

  Future<void> _signOut() async {
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'role');
    if (mounted) setState(() => _signedIn = false);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'FishLink AI',
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff006b78)),
            useMaterial3: true, inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder())),
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
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ApiClient().login(_email.text.trim(), _password.text);
      final user = result['user'] as Map<String, dynamic>? ?? {};
      const storage = FlutterSecureStorage();
      final token = result['token']?.toString();
      if (token == null || token.isEmpty) throw Exception('The API did not return an access token.');
      await storage.write(key: 'token', value: token);
      await storage.write(key: 'role', value: user['role']?.toString() ?? 'Fisherman');
      widget.onSignedIn(user['role']?.toString() ?? 'Fisherman');
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: Center(child: SingleChildScrollView(
          padding: const EdgeInsets.all(24), child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480), child: Form(
              key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Icon(Icons.waves, size: 64, color: Color(0xff006b78)),
                const Text('FishLink AI', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                const Text('Trusted digital fish marketplace', textAlign: TextAlign.center),
                const SizedBox(height: 32),
                TextFormField(controller: _email, keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
                    validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null),
                const SizedBox(height: 16),
                TextFormField(controller: _password, obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock)),
                    validator: (v) => v == null || v.length < 6 ? 'Minimum 6 characters' : null),
                if (_error != null) Padding(padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                const SizedBox(height: 24),
                FilledButton(onPressed: _loading ? null : _login,
                    child: _loading ? const CircularProgressIndicator() : const Text('Sign in')),
              ])))))),
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
    final screens = [
      CatchListScreen(role: widget.role),
      const NewCatchScreen(),
      const MarketScreen(),
    ];
    return Scaffold(
      appBar: AppBar(title: Text('FishLink • ${widget.role}'), actions: [
        IconButton(onPressed: widget.onSignOut, icon: const Icon(Icons.logout), tooltip: 'Sign out')
      ]),
      body: screens[_index],
      bottomNavigationBar: NavigationBar(selectedIndex: _index,
          onDestinationSelected: (value) => setState(() => _index = value),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.set_meal), label: 'My catches'),
            NavigationDestination(icon: Icon(Icons.add_circle), label: 'Register'),
            NavigationDestination(icon: Icon(Icons.show_chart), label: 'Market'),
          ]),
    );
  }
}

class CatchListScreen extends StatefulWidget {
  const CatchListScreen({required this.role, super.key});
  final String role;
  @override
  State<CatchListScreen> createState() => _CatchListScreenState();
}

class _CatchListScreenState extends State<CatchListScreen> {
  late Future<List<dynamic>> _catches;
  @override
  void initState() { super.initState(); _reload(); }
  void _reload() => _catches = ApiClient().catches();
  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async => setState(_reload),
    child: FutureBuilder<List<dynamic>>(future: _catches, builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return Center(child: Text('Unable to load catches\n${snapshot.error}', textAlign: TextAlign.center));
      final items = snapshot.data ?? [];
      if (items.isEmpty) return const Center(child: Text('No catches found. Register your first catch.'));
      return ListView.builder(itemCount: items.length, itemBuilder: (context, index) {
        final item = items[index] as Map<String, dynamic>;
        return Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.set_meal)),
          title: Text(item['fishSpecies']?.toString() ?? 'Unknown species'),
          subtitle: Text('${item['quantityKg']} kg • Rs ${item['askingPricePerKg']}/kg'),
          trailing: Chip(label: Text(item['status']?.toString() ?? 'Draft'))));
      });
    }),
  );
}

class NewCatchScreen extends StatefulWidget {
  const NewCatchScreen({super.key});
  @override
  State<NewCatchScreen> createState() => _NewCatchScreenState();
}

class _NewCatchScreenState extends State<NewCatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _price = TextEditingController();
  final _locationController = TextEditingController(text: 'Negombo');
  final _note = TextEditingController();
  String _species = 'Tuna';
  String? _photoPath;
  bool _loading = false;

  Future<void> _photo() async {
    final file = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 75);
    if (file != null) setState(() => _photoPath = file.path);
  }
  Future<void> _getLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
    final position = await Geolocator.getCurrentPosition();
    setState(() => _locationController.text = '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}');
  }
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ApiClient().createCatch({'fishSpecies': _species, 'quantityKg': double.parse(_quantity.text),
        'askingPricePerKg': double.parse(_price.text), 'location': _locationController.text, 'sellerNote': _note.text,
        'photoUrl': _photoPath ?? ''});
      if (mounted) { _formKey.currentState!.reset(); ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Catch saved as draft. AI validation will process it.'))); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save catch: $e')));
    } finally { if (mounted) setState(() => _loading = false); }
  }
  @override
  Widget build(BuildContext context) => Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(16), children: [
    Text('Register a new catch', style: Theme.of(context).textTheme.headlineSmall),
    const SizedBox(height: 16),
    DropdownButtonFormField<String>(initialValue: _species, decoration: const InputDecoration(labelText: 'Species'),
      items: ['Tuna', 'Skipjack', 'Trevally', 'Mackerel'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
      onChanged: (v) => setState(() => _species = v!)),
    const SizedBox(height: 12),
    TextFormField(controller: _quantity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity (kg)'),
      validator: (v) => double.tryParse(v ?? '') == null || double.parse(v!) <= 0 ? 'Enter a positive quantity' : null),
    const SizedBox(height: 12),
    TextFormField(controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Asking price (Rs/kg)'),
      validator: (v) => double.tryParse(v ?? '') == null || double.parse(v!) <= 0 ? 'Enter a positive price' : null),
    const SizedBox(height: 12),
    TextFormField(controller: _locationController, decoration: const InputDecoration(labelText: 'Location')),
    const SizedBox(height: 12),
    TextFormField(controller: _note, maxLines: 3, decoration: const InputDecoration(labelText: 'Seller note (optional)')),
    const SizedBox(height: 12),
    Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _photo, icon: const Icon(Icons.camera_alt), label: Text(_photoPath == null ? 'Photo' : 'Photo added'))),
      const SizedBox(width: 8), Expanded(child: OutlinedButton.icon(onPressed: _getLocation, icon: const Icon(Icons.my_location), label: const Text('GPS')))]),
    const SizedBox(height: 24),
    FilledButton.icon(onPressed: _loading ? null : _submit, icon: const Icon(Icons.publish), label: const Text('Save catch')),
  ]));
}

class MarketScreen extends StatelessWidget {
  const MarketScreen({super.key});
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: ApiClient().safety('Negombo'), builder: (context, snapshot) => ListView(padding: const EdgeInsets.all(16), children: [
      Text('Fishing safety', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      if (snapshot.connectionState == ConnectionState.waiting) const LinearProgressIndicator(),
      if (snapshot.hasError) Text('Weather unavailable: ${snapshot.error}'),
      if (snapshot.hasData) Card(child: ListTile(leading: const Icon(Icons.wb_sunny), title: Text(snapshot.data!['condition']?.toString() ?? 'Unknown'),
        subtitle: Text(snapshot.data!['advice']?.toString() ?? ''), trailing: Text(snapshot.data!['fishingRisk']?.toString() ?? ''))),
      const SizedBox(height: 16), const Text('Market prices are shared with the React dashboard through the same API.'),
    ]));
}
