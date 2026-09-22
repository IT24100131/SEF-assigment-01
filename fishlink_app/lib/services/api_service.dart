import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../models/catch.dart';
import '../models/market_trend.dart';
import '../models/auth_response.dart';

class ApiService {
  // Update this to your deployed API URL or local IP for testing
  static const String baseUrl = 'https://localhost:7012/api';  // Update with your deployed URL
  
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<String?> _getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  static Future<void> _saveToken(String token) async {
    await _storage.write(key: 'jwt_token', value: token);
  }

  static Future<void> _clearToken() async {
    await _storage.delete(key: 'jwt_token');
  }

  static Map<String, String> _getHeaders([bool includeAuth = true]) {
    Map<String, String> headers = {
      'Content-Type': 'application/json',
    };
    
    return headers;
  }

  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Authentication
  static Future<AuthResponse> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _getHeaders(false),
      body: json.encode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final authResponse = AuthResponse.fromJson(json.decode(response.body));
      await _saveToken(authResponse.token);
      return authResponse;
    } else {
      throw Exception('Failed to login: ${response.body}');
    }
  }

  static Future<AuthResponse> register(RegisterRequest request) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: _getHeaders(false),
      body: json.encode(request.toJson()),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final authResponse = AuthResponse.fromJson(json.decode(response.body));
      await _saveToken(authResponse.token);
      return authResponse;
    } else {
      throw Exception('Failed to register: ${response.body}');
    }
  }

  static Future<void> logout() async {
    await _clearToken();
  }

  // Catches
  static Future<List<Catch>> getCatches() async {
    final headers = await _getAuthHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/catches'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => Catch.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load catches: ${response.body}');
    }
  }

  static Future<Catch> createCatch(Catch catchData) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/catches'),
      headers: headers,
      body: json.encode(catchData.toJson()),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Catch.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create catch: ${response.body}');
    }
  }

  static Future<Catch> updateCatch(int id, Catch catchData) async {
    final headers = await _getAuthHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/catches/$id'),
      headers: headers,
      body: json.encode(catchData.toJson()),
    );

    if (response.statusCode == 200) {
      return Catch.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update catch: ${response.body}');
    }
  }

  static Future<void> deleteCatch(int id) async {
    final headers = await _getAuthHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/catches/$id'),
      headers: headers,
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete catch: ${response.body}');
    }
  }

  // Market Trends
  static Future<List<MarketTrend>> getMarketTrends() async {
    final headers = await _getAuthHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/catches/market-trends'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => MarketTrend.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load market trends: ${response.body}');
    }
  }

  // Weather info (bonus feature)
  static Future<Map<String, dynamic>> getWeatherInfo(String location) async {
    final headers = await _getAuthHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/catches/weather?location=$location'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load weather info: ${response.body}');
    }
  }
}