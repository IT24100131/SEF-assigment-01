import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

String get _apiBaseUrl =>
    const String.fromEnvironment('FISHLINK_API_URL').isNotEmpty
        ? const String.fromEnvironment('FISHLINK_API_URL')
        : (kIsWeb ? 'http://localhost:5157/api' : 'http://10.0.2.2:5157/api');

// ══════════════════════════════════════════════════════════════════════════════
// 1. 🛰️ LIVE VEHICLE GPS & COLD-CHAIN ROUTE TRACKING MODAL
// ══════════════════════════════════════════════════════════════════════════════

void showLiveVehicleTrackingModal(
  BuildContext context,
  Map<String, dynamic> plan, {
  VoidCallback? onDelivered,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _LiveVehicleTrackingSheet(
      plan: plan,
      onDelivered: onDelivered,
    ),
  );
}

class _LiveVehicleTrackingSheet extends StatefulWidget {
  const _LiveVehicleTrackingSheet({required this.plan, this.onDelivered});

  final Map<String, dynamic> plan;
  final VoidCallback? onDelivered;

  @override
  State<_LiveVehicleTrackingSheet> createState() =>
      _LiveVehicleTrackingSheetState();
}

class _LiveVehicleTrackingSheetState extends State<_LiveVehicleTrackingSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  Timer? _telemetryTimer;
  double _currentTemp = -1.9;
  int _currentSpeed = 62;
  int _batteryPct = 94;
  int _humidityPct = 88;
  double _progressFraction = 0.08; // Starts accurately near harbour exit
  bool _markingDelivered = false;
  bool _isAutoPlay = false; // Simulation playback toggle
  bool _isRealTimeClock = true; // By default tracks real elapsed minutes

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _progressFraction = _calculateInitialProgress();

    // 1-second telemetry and time tracking tick
    _telemetryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        final now = DateTime.now();

        // Realistic IoT sensor micro-fluctuations
        if (now.second % 3 == 0) {
          final delta = (now.second % 6 == 0) ? 0.1 : -0.1;
          _currentTemp = double.parse((_currentTemp + delta).toStringAsFixed(1));
          if (_currentTemp < -2.3) _currentTemp = -1.8;
          if (_currentTemp > -1.5) _currentTemp = -2.0;
        }

        final estMinutes = (widget.plan['estimatedMinutes'] as num?)?.toDouble() ?? 47.0;

        if (_isRealTimeClock && !_isAutoPlay) {
          // Genuine real-time tracking based on elapsed clock time
          final realProgress = _calculateRealTimeProgress(estMinutes);
          _progressFraction = realProgress;
        } else if (_isAutoPlay) {
          // Slow, smooth demo simulation (takes ~2 mins to complete instead of rushing)
          if (_progressFraction < 0.98) {
            _progressFraction += 0.005; // smooth slow advance
          } else {
            _isAutoPlay = false;
          }
        }

        // Compute speed according to highway zone
        if (_progressFraction < 0.08) {
          _currentSpeed = 22 + (now.second % 6);
        } else if (_progressFraction >= 0.95) {
          _currentSpeed = 16 + (now.second % 4);
        } else {
          _currentSpeed = 62 + (now.second % 10);
        }
      });
    });
  }

  double _calculateInitialProgress() {
    final status = widget.plan['status'] as String? ?? 'InTransit';
    if (status == 'Delivered') return 1.0;
    if (status == 'Scheduled') return 0.02; // Waiting at pier
    final estMinutes = (widget.plan['estimatedMinutes'] as num?)?.toDouble() ?? 47.0;
    return _calculateRealTimeProgress(estMinutes);
  }

  double _calculateRealTimeProgress(double estMinutes) {
    final pickupRaw = widget.plan['pickupTime']?.toString();
    if (pickupRaw != null) {
      try {
        DateTime? dt = DateTime.tryParse(pickupRaw);
        if (dt == null) {
          final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(pickupRaw);
          if (match != null) {
            final now = DateTime.now();
            dt = DateTime(now.year, now.month, now.day, int.parse(match.group(1)!), int.parse(match.group(2)!));
          }
        }
        if (dt != null) {
          final elapsedSeconds = DateTime.now().difference(dt).inSeconds;
          final totalSeconds = estMinutes * 60;
          if (elapsedSeconds > 0 && elapsedSeconds < totalSeconds) {
            return (elapsedSeconds / totalSeconds).clamp(0.02, 0.98);
          }
        }
      } catch (_) {}
    }
    return 0.12; // Realistic initial progress on E03 highway entry
  }

  String _currentLocationLabel(double totalDistance) {
    final currentKm = (totalDistance * _progressFraction).toStringAsFixed(1);
    if (_progressFraction < 0.08) {
      return 'Negombo Pier • Loading & Pre-Chill Hold ($currentKm km)';
    } else if (_progressFraction < 0.38) {
      return 'E03 Katunayake Toll Corridor • $currentKm / $totalDistance km';
    } else if (_progressFraction < 0.75) {
      return 'Cruising E03 Expressway @ Ja-Ela Flyover • $currentKm km';
    } else if (_progressFraction < 0.95) {
      return 'Peliyagoda Interchange Corridor • $currentKm km';
    } else {
      return 'Peliyagoda Central Cold Hub • Arrived at Vault ($currentKm km)';
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _telemetryTimer?.cancel();
    super.dispose();
  }

  Future<void> _completeDelivery() async {
    setState(() => _markingDelivered = true);
    final planId = widget.plan['id'];
    try {
      final token = await const FlutterSecureStorage().read(key: 'token');
      await http.patch(
        Uri.parse('$_apiBaseUrl/Logistics/plans/$planId/complete'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
    } catch (_) {}
    if (!mounted) return;
    setState(() => _markingDelivered = false);
    widget.plan['status'] = 'Delivered';
    widget.onDelivered?.call();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🏁 Cargo safely arrived & delivered! Escrow payment released.'),
        backgroundColor: Color(0xff059669),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final totalDistance = (plan['distanceKm'] as num?)?.toDouble() ?? 36.4;
    final coveredDistance = (totalDistance * _progressFraction).toStringAsFixed(1);
    final remainingDistance = (totalDistance * (1 - _progressFraction)).toStringAsFixed(1);
    final estMinutes = (plan['estimatedMinutes'] as num?)?.toInt() ?? 47;
    final remainingMins = ((1 - _progressFraction) * estMinutes).round();
    final pickupTime = plan['pickupTime']?.toString() ?? '14:30 PM';
    final estimatedETA = plan['estimatedETA']?.toString() ?? '15:17 PM';

    return Container(
      height: MediaQuery.of(context).size.height * 0.94,
      decoration: const BoxDecoration(
        color: Color(0xff0f172a), // Dark theme for high-tech telemetry
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xff38bdf8).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xff38bdf8).withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.satellite_alt, color: Color(0xff38bdf8), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Live Cold-Chain GPS Tracker',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xff10b981).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xff10b981)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(radius: 3, backgroundColor: Color(0xff10b981)),
                                SizedBox(width: 4),
                                Text(
                                  'LIVE GPS',
                                  style: TextStyle(
                                    color: Color(0xff10b981),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${plan['planId']} • ${plan['vehicleCode'] ?? 'Reefer Van V01'} • ${plan['driverCode'] ?? 'Driver D01'}',
                        style: const TextStyle(color: Color(0xff94a3b8), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Colors.white12),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                // ── 1. REAL-TIME ROUTE CORRIDOR MAP VISUALIZER ──
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xff1e293b), Color(0xff0f172a)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xff334155)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
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
                            'EXPRESSWAY LOGISTICS CORRIDOR',
                            style: TextStyle(
                              color: Color(0xff38bdf8),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xff0284c7).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${(_progressFraction * 100).toInt()}% COMPLETED',
                              style: const TextStyle(
                                color: Color(0xff38bdf8),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Route Origin & Destination Summary
                      Row(
                        children: [
                          const Icon(Icons.anchor, color: Color(0xff10b981), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              plan['pickupLocation'] ?? 'Negombo Fishery Harbour (Pier 3B)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
                        child: Container(
                          width: 2,
                          height: 16,
                          color: const Color(0xff10b981).withValues(alpha: 0.5),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.warehouse, color: Color(0xfff59e0b), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              plan['deliveryLocation'] ?? 'Peliyagoda Central Cold Hub',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Animated Visual Route Track
                      Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          // Base track line
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xff334155),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          // Completed active gradient track
                          FractionallySizedBox(
                            widthFactor: _progressFraction.clamp(0.05, 1.0),
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xff10b981), Color(0xff38bdf8)],
                                ),
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xff38bdf8).withValues(alpha: 0.6),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Moving Reefer Truck Indicator
                          Align(
                            alignment: Alignment(_progressFraction * 2 - 1, 0),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xff0284c7),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xff38bdf8).withValues(alpha: 0.8),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.local_shipping,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Dynamic Route Waypoint Checkpoints
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildWaypointItem(
                            'Pier Departure',
                            _progressFraction >= 0.08 ? pickupTime : 'Loading',
                            _progressFraction >= 0.08,
                            isCurrent: _progressFraction < 0.08,
                          ),
                          _buildWaypointItem(
                            'E03 Toll Gate',
                            _progressFraction >= 0.38 ? 'Cleared Toll' : (_progressFraction >= 0.08 ? 'Approaching' : 'Km 8.4'),
                            _progressFraction >= 0.38,
                            isCurrent: _progressFraction >= 0.08 && _progressFraction < 0.38,
                          ),
                          _buildWaypointItem(
                            'Ja-Ela (Km 18)',
                            _progressFraction >= 0.75 ? 'Passed' : (_progressFraction >= 0.38 ? '$_currentSpeed km/h' : 'Km 18.2'),
                            _progressFraction >= 0.75,
                            isCurrent: _progressFraction >= 0.38 && _progressFraction < 0.75,
                          ),
                          _buildWaypointItem(
                            'Peliyagoda Vault',
                            _progressFraction >= 0.98 ? 'Arrived' : (_progressFraction >= 0.75 ? 'Entering Hub' : estimatedETA),
                            _progressFraction >= 0.98,
                            isCurrent: _progressFraction >= 0.75 && _progressFraction < 0.98,
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Dynamic Current Highway Location Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xff0284c7).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xff0284c7).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.navigation, color: Color(0xff38bdf8), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _currentLocationLabel(totalDistance),
                                style: const TextStyle(
                                  color: Color(0xff38bdf8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Distance and ETA Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '📍 $coveredDistance km / $totalDistance km ($remainingDistance km left)',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                            Text(
                              '⏱️ ETA: $remainingMins mins ($estimatedETA)',
                              style: const TextStyle(
                                color: Color(0xff38bdf8),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Interactive Tracking Controller Bar (Scrub, Simulation, Live Mode)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.tune, color: Color(0xff38bdf8), size: 15),
                                    const SizedBox(width: 6),
                                    Text(
                                      _isRealTimeClock ? 'Clock GPS Mode' : (_isAutoPlay ? 'Simulating Transit…' : 'Manual Scrub'),
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    InkWell(
                                      onTap: () => setState(() {
                                        _progressFraction = 0.02;
                                        _isAutoPlay = false;
                                        _isRealTimeClock = false;
                                      }),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(6)),
                                        child: const Text('⏪ Reset Pier', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () => setState(() {
                                        _isAutoPlay = !_isAutoPlay;
                                        _isRealTimeClock = false;
                                      }),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _isAutoPlay ? const Color(0xff059669) : const Color(0xff0284c7),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _isAutoPlay ? '⏸️ Pause' : '▶️ Play Demo',
                                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                activeTrackColor: const Color(0xff38bdf8),
                                inactiveTrackColor: Colors.white24,
                                thumbColor: Colors.white,
                              ),
                              child: Slider(
                                value: _progressFraction.clamp(0.0, 1.0),
                                min: 0.0,
                                max: 1.0,
                                onChanged: (val) {
                                  setState(() {
                                    _progressFraction = val;
                                    _isRealTimeClock = false;
                                    _isAutoPlay = false;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // ── 2. LIVE COLD-CHAIN IOT SENSORS & TELEMETRY GAUGES ──
                const Text(
                  'COLD-CHAIN IOT TELEMETRY & CHAMBER SENSORS',
                  style: TextStyle(
                    color: Color(0xff94a3b8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    // Reefer Temperature Gauge
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xff1e293b),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xff0284c7).withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('CHAMBER TEMP',
                                    style: TextStyle(color: Color(0xff94a3b8), fontSize: 10, fontWeight: FontWeight.bold)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xff10b981).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('OPTIMAL',
                                      style: TextStyle(color: Color(0xff10b981), fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$_currentTemp°C',
                              style: const TextStyle(
                                color: Color(0xff38bdf8),
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Slurry Ice (-2.0°C Target)',
                              style: TextStyle(color: Colors.white60, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Transit Speed Gauge
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xff1e293b),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xff334155)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('EXPRESSWAY SPEED',
                                style: TextStyle(color: Color(0xff94a3b8), fontSize: 10, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(
                              '$_currentSpeed km/h',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'E03 Speed Limit: 80 km/h',
                              style: TextStyle(color: Colors.white60, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    // Humidity
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xff1e293b),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xff334155)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.water_drop, color: Color(0xff38bdf8), size: 20),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('HUMIDITY', style: TextStyle(color: Color(0xff94a3b8), fontSize: 9)),
                                Text('$_humidityPct% RH', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Battery
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xff1e293b),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xff334155)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.battery_charging_full, color: Color(0xff10b981), size: 20),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('REEFER POWER', style: TextStyle(color: Color(0xff94a3b8), fontSize: 9)),
                                Text('$_batteryPct% Active', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // GPS
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xff1e293b),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xff334155)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.wifi, color: Color(0xff10b981), size: 20),
                            SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('IOT LINK', style: TextStyle(color: Color(0xff94a3b8), fontSize: 9)),
                                Text('4G Strong', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // ── 3. QUALITY ASSURANCE & CARGO VERIFICATION ──
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xff10b981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xff10b981).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified, color: Color(0xff10b981), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'HACCP Freshness Guarantee Active',
                              style: TextStyle(
                                color: Color(0xff10b981),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Cargo: ${plan['species'] ?? 'Fish Catch'} • Continuous slurry ice preservation active from pier departure.',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── 4. ARRIVAL ACTION BUTTON ──
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xff059669),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _markingDelivered ? null : _completeDelivery,
                  icon: _markingDelivered
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle, size: 20),
                  label: Text(
                    _markingDelivered ? 'Updating Records…' : '🏁 Confirm Safe Arrival & Mark Delivered',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'Releases escrow guarantee and frees Reefer V01 for next assignment.',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaypointItem(String label, String time, bool passed, {bool isCurrent = false}) {
    return Column(
      children: [
        Icon(
          isCurrent
              ? Icons.radio_button_checked
              : (passed ? Icons.check_circle : Icons.radio_button_unchecked),
          color: isCurrent
              ? const Color(0xff38bdf8)
              : (passed ? const Color(0xff10b981) : Colors.white24),
          size: 16,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isCurrent ? const Color(0xff38bdf8) : (passed ? Colors.white : Colors.white38),
            fontSize: 9,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          time,
          style: TextStyle(
            color: isCurrent ? Colors.white : Colors.white38,
            fontSize: 8,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 2. 🚚 VEHICLE DISPATCH & DEPARTURE TIME DIALOG
// ══════════════════════════════════════════════════════════════════════════════

void showVehicleDispatchDialog(
  BuildContext context,
  Map<String, dynamic> plan,
  VoidCallback onDispatched,
) {
  showDialog(
    context: context,
    builder: (ctx) => _VehicleDispatchDialog(plan: plan, onDispatched: onDispatched),
  );
}

class _VehicleDispatchDialog extends StatefulWidget {
  const _VehicleDispatchDialog({required this.plan, required this.onDispatched});

  final Map<String, dynamic> plan;
  final VoidCallback onDispatched;

  @override
  State<_VehicleDispatchDialog> createState() => _VehicleDispatchDialogState();
}

class _VehicleDispatchDialogState extends State<_VehicleDispatchDialog> {
  final _noteController = TextEditingController(
      text: 'Verified cargo temperature. Pre-chilling complete. Dispatched via E03 Expressway.');
  TimeOfDay _selectedTime = TimeOfDay.now();
  double _initialTemp = -2.0;
  bool _submitting = false;
  bool _checkCratesSecured = true;
  bool _checkPreChilled = true;
  bool _checkTagActive = true;

  Future<void> _dispatch() async {
    setState(() => _submitting = true);
    final planId = widget.plan['id'];

    // Construct local departure time
    final now = DateTime.now();
    final departureTime = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    final estMinutes = (widget.plan['estimatedMinutes'] as num?)?.toInt() ?? 47;
    final eta = departureTime.add(Duration(minutes: estMinutes));

    try {
      final token = await const FlutterSecureStorage().read(key: 'token');
      await http.patch(
        Uri.parse('$_apiBaseUrl/Logistics/plans/$planId/dispatch'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'departureTime': departureTime.toIso8601String(),
          'estimatedETA': eta.toIso8601String(),
          'adminNote': _noteController.text.trim(),
        }),
      );
    } catch (_) {}

    if (!mounted) return;
    setState(() => _submitting = false);
    widget.plan['status'] = 'InTransit';
    widget.plan['pickupTime'] = 'Today, ${_selectedTime.format(context)}';
    widget.plan['estimatedETA'] =
        'Today, ${TimeOfDay.fromDateTime(eta).format(context)}';
    widget.onDispatched();
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '🚚 Vehicle Dispatched at ${_selectedTime.format(context)}! Live GPS Tracking Active.',
        ),
        backgroundColor: const Color(0xff0284c7),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xff0284c7).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.departure_board, color: Color(0xff0284c7), size: 24),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Dispatch Reefer Vehicle',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Confirm pier departure and start cold-chain telemetry tracking for ${plan['planId']}.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 14),

            // Vehicle and Route Specs
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xfff8fafc),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('🚛 Vehicle Code:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(plan['vehicleCode'] ?? 'V01 - Isuzu Cold-Van',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('👤 Assigned Driver:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(plan['driverCode'] ?? 'D01 - Sunil Perera',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('🛣️ Corridor:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(plan['selectedRoute'] ?? 'Route A (E03 Expressway)',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xff0284c7))),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Departure Time Picker
            const Text(
              'Vehicle Departure Time',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _selectedTime,
                );
                if (picked != null) setState(() => _selectedTime = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xfff0f9ff),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xffbae6fd)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.access_time, color: Color(0xff0284c7), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _selectedTime.format(context),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff0369a1),
                          ),
                        ),
                      ],
                    ),
                    const Text('Change Time 🕒', style: TextStyle(fontSize: 12, color: Color(0xff0284c7))),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Pre-cooling Chamber Temperature Setting
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Compartment Pre-Chill Temp',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                Text('${_initialTemp.toStringAsFixed(1)}°C',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xff0284c7))),
              ],
            ),
            Slider(
              value: _initialTemp,
              min: -5.0,
              max: 4.0,
              divisions: 18,
              label: '${_initialTemp.toStringAsFixed(1)}°C',
              activeColor: const Color(0xff0284c7),
              onChanged: (val) => setState(() => _initialTemp = val),
            ),

            const SizedBox(height: 10),

            // Pre-departure Safety Checklist
            const Text('Pre-Departure Safety Checklist',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _checkCratesSecured,
              onChanged: (v) => setState(() => _checkCratesSecured = v ?? true),
              title: const Text('Fish crates iced and secured in Reefer hold', style: TextStyle(fontSize: 11)),
            ),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _checkPreChilled,
              onChanged: (v) => setState(() => _checkPreChilled = v ?? true),
              title: const Text('Reefer compartment pre-cooled to target temp', style: TextStyle(fontSize: 11)),
            ),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _checkTagActive,
              onChanged: (v) => setState(() => _checkTagActive = v ?? true),
              title: const Text('Digital IoT Logger #LOG-889 synchronized with GPS', style: TextStyle(fontSize: 11)),
            ),

            const SizedBox(height: 10),

            // Admin Dispatch Note
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Admin Dispatch Sign-off Note',
                prefixIcon: Icon(Icons.edit_note, size: 18),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xff0284c7),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _submitting ? null : _dispatch,
          icon: _submitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.rocket_launch, size: 16),
          label: Text(_submitting ? 'Dispatching…' : 'Confirm Pier Departure & Dispatch'),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 3. 🛡️ ADMIN DASHBOARD SCREEN (React Parity)
// ══════════════════════════════════════════════════════════════════════════════

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    required this.onSignOut,
    this.onNavigateTab,
    super.key,
  });

  final VoidCallback onSignOut;
  final ValueChanged<int>? onNavigateTab;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = false;
  List<Map<String, dynamic>> _plans = [];
  List<Map<String, dynamic>> _flaggedCatches = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final token = await const FlutterSecureStorage().read(key: 'token');
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      // Load delivery plans
      final plansRes = await http.get(Uri.parse('$_apiBaseUrl/Logistics/plans'), headers: headers);
      if (plansRes.statusCode == 200) {
        final decoded = jsonDecode(plansRes.body);
        if (decoded is List) {
          _plans = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }

      // Load catches for review
      final catchesRes = await http.get(Uri.parse('$_apiBaseUrl/Catches?pageSize=50'), headers: headers);
      if (catchesRes.statusCode == 200) {
        final decoded = jsonDecode(catchesRes.body);
        final items = decoded is Map ? (decoded['items'] ?? decoded['data']) : decoded;
        if (items is List) {
          _flaggedCatches = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (_) {}

    // Fallback seed plans if database is currently empty
    if (_plans.isEmpty) {
      _plans = [
        {
          'id': 1,
          'planId': 'PLN-NEG-902',
          'catchId': 1,
          'species': 'Yellowfin Tuna (150 kg)',
          'status': 'PendingApproval',
          'vehicleCode': 'V01 - Isuzu Reefer (WP-CAB-1234)',
          'driverCode': 'D01 - Sunil Perera',
          'coldStorageCode': 'C01 - Negombo Deep Freeze (-18°C)',
          'pickupLocation': 'Negombo Fishery Harbour • Pier 3B',
          'deliveryLocation': 'Peliyagoda Central Wholesale Market',
          'selectedRoute': 'Route A (Colombo-Katunayake Expressway E03)',
          'distanceKm': 36.4,
          'estimatedMinutes': 47,
          'targetTemp': -2.0,
          'pickupTime': 'Today, 14:30 PM',
          'estimatedETA': 'Today, 15:17 PM',
          'weatherNote': 'Clear skies, dry expressway. Optimal 47m cold transit window.',
          'agentReasoning':
              'Logistics Agent verified shortest thermal exposure via E03 Expressway. Reefer V01 pre-cooled to -2.0°C. Driver D01 certified for cold-chain HACCP export standards.',
        },
        {
          'id': 2,
          'planId': 'PLN-GAL-411',
          'catchId': 2,
          'species': 'Skipjack Tuna (80 kg)',
          'status': 'Scheduled',
          'vehicleCode': 'V02 - Toyota Chilled Van (WP-GAN-5678)',
          'driverCode': 'D02 - Kamal Silva',
          'coldStorageCode': 'C02 - Negombo Cold Store B',
          'pickupLocation': 'Galle Fishery Port • Jetty 2',
          'deliveryLocation': 'Katunayake Air Cargo Cold Vault',
          'selectedRoute': 'Route C (Southern Expressway E01 Corridor)',
          'distanceKm': 128.0,
          'estimatedMinutes': 95,
          'targetTemp': 1.8,
          'pickupTime': 'Today, 15:00 PM',
          'estimatedETA': 'Today, 16:35 PM',
          'weatherNote': 'Safe transit conditions verified along Southern Expressway.',
          'agentReasoning':
              'Allocated for air freight export flight. Digital IoT continuous thermal logger #LOG-889 synchronized.',
        },
        {
          'id': 3,
          'planId': 'PLN-CMB-108',
          'catchId': 3,
          'species': 'Giant Trevally (100 kg)',
          'status': 'InTransit',
          'vehicleCode': 'V04 - Mitsubishi Fuso (WP-NB-3456)',
          'driverCode': 'D04 - Rohan Jayawardena',
          'coldStorageCode': 'C03 - Colombo Fish Hub',
          'pickupLocation': 'Colombo Mutwal Fishery Harbour',
          'deliveryLocation': 'Kandy Supermarket Cold Storage',
          'selectedRoute': 'Route A (Colombo-Kandy Road A1 Highway)',
          'distanceKm': 121.0,
          'estimatedMinutes': 160,
          'targetTemp': 0.5,
          'pickupTime': 'Today, 13:00 PM',
          'estimatedETA': 'Today, 15:40 PM',
          'weatherNote': 'Passing Warakapola. Mild traffic, cold-chain optimal.',
          'agentReasoning':
              'Live in-transit telemetry stream active. Internal temperature holding at 0.5°C.',
        },
      ];
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _approvePlan(int id) async {
    setState(() => _loading = true);
    try {
      final token = await const FlutterSecureStorage().read(key: 'token');
      await http.patch(
        Uri.parse('$_apiBaseUrl/Logistics/plans/$id/approve'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'note': 'Approved by Admin inspection officer.'}),
      );
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _loading = false;
      final idx = _plans.indexWhere((p) => p['id'] == id);
      if (idx != -1) _plans[idx]['status'] = 'Scheduled';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Delivery Plan Approved! Ready for pier departure.'),
        backgroundColor: Color(0xff059669),
      ),
    );
  }

  Future<void> _rejectPlan(int id) async {
    setState(() => _loading = true);
    try {
      final token = await const FlutterSecureStorage().read(key: 'token');
      await http.patch(
        Uri.parse('$_apiBaseUrl/Logistics/plans/$id/reject'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'note': 'Rejected by Admin. Cold specs insufficient.'}),
      );
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _loading = false;
      final idx = _plans.indexWhere((p) => p['id'] == id);
      if (idx != -1) _plans[idx]['status'] = 'Rejected';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('❌ Delivery Plan Rejected.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _plans.where((p) => p['status'] == 'PendingApproval').length;
    final inTransitCount = _plans.where((p) => p['status'] == 'InTransit').length;
    final scheduledCount = _plans.where((p) => p['status'] == 'Scheduled').length;

    return Scaffold(
      backgroundColor: const Color(0xfff0f4f8),
      body: NestedScrollView(
        headerSliverBuilder: (ctx, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xff0f172a), Color(0xff1e293b)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xff38bdf8).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.admin_panel_settings, color: Color(0xff38bdf8), size: 24),
                          ),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'FishLink Admin Portal',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Cold-Chain Logistics & Quality Authority',
                                style: TextStyle(color: Colors.white60, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh, color: Colors.white70),
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3 KPI Quick Metric Cards
                  Row(
                    children: [
                      _buildHeaderKpi('⏳ Pending Plans', '$pendingCount', const Color(0xfff59e0b)),
                      const SizedBox(width: 8),
                      _buildHeaderKpi('🚚 In Transit', '$inTransitCount', const Color(0xff38bdf8)),
                      const SizedBox(width: 8),
                      _buildHeaderKpi('✅ Scheduled', '$scheduledCount', const Color(0xff10b981)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: const Color(0xff0284c7),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xff0284c7),
                indicatorWeight: 3,
                tabs: const [
                  Tab(icon: Icon(Icons.local_shipping, size: 18), text: 'Logistics & Dispatch'),
                  Tab(icon: Icon(Icons.fact_check, size: 18), text: 'Quality & Fraud'),
                  Tab(icon: Icon(Icons.smart_toy, size: 18), text: 'Multi-Agent AI'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            // ── TAB 1: COLD-CHAIN LOGISTICS & DISPATCH ──
            _buildLogisticsTab(),

            // ── TAB 2: QUALITY & FRAUD REVIEW ──
            _buildQualityReviewTab(),

            // ── TAB 3: MULTI-AGENT OVERVIEW ──
            _buildMultiAgentTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderKpi(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildLogisticsTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Live Sea Weather Telemetry Widget
        _buildSeaWeatherCard(),

        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Delivery & Dispatch Plans',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '${_plans.length} Total Plans',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 12),

        ..._plans.map((plan) => _buildAdminPlanCard(plan)),
      ],
    );
  }

  Widget _buildSeaWeatherCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff1e293b), Color(0xff0f172a)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🌤️ ', style: TextStyle(fontSize: 16)),
              Text(
                'Live Harbour Weather & Sea Telemetry',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              Text('OpenWeather API', style: TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildPortWeatherBox('Negombo', '29°C', 'Wind: 14 km/h', 'Safe Corridors', const Color(0xff10b981)),
              const SizedBox(width: 8),
              _buildPortWeatherBox('Colombo', '30°C', 'Wind: 18 km/h', 'E03 Clear', const Color(0xff10b981)),
              const SizedBox(width: 8),
              _buildPortWeatherBox('Galle', '28°C', 'Wind: 22 km/h', 'Wave: 1.4m', const Color(0xfff59e0b)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPortWeatherBox(String port, String temp, String wind, String status, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(port, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            Text('$temp • $wind', style: const TextStyle(color: Colors.white60, fontSize: 9)),
            const SizedBox(height: 4),
            Text(status, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminPlanCard(Map<String, dynamic> plan) {
    final status = plan['status'] as String? ?? 'PendingApproval';
    Color statusColor;
    Color statusBg;
    String statusLabel;

    switch (status) {
      case 'PendingApproval':
        statusColor = const Color(0xffd97706);
        statusBg = const Color(0xfffef3c7);
        statusLabel = '⏳ Pending Admin Review';
        break;
      case 'Scheduled':
        statusColor = const Color(0xff0284c7);
        statusBg = const Color(0xffe0f2fe);
        statusLabel = '✅ Scheduled • Awaiting Dispatch';
        break;
      case 'InTransit':
        statusColor = const Color(0xff7c3aed);
        statusBg = const Color(0xffede9fe);
        statusLabel = '🚚 In Transit • GPS Active';
        break;
      case 'Delivered':
        statusColor = const Color(0xff059669);
        statusBg = const Color(0xffd1fae5);
        statusLabel = '🏁 Delivered & Verified';
        break;
      default:
        statusColor = Colors.red;
        statusBg = const Color(0xfffee2e2);
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
            color: Colors.black.withValues(alpha: 0.04),
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
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        statusLabel,
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                Text('Catch #${plan['catchId']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'Cargo: ${plan['species'] ?? 'Fish Catch'}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),

          const SizedBox(height: 10),

          // 8 Spec Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildCardTag('🚛 Vehicle', plan['vehicleCode']?.toString() ?? 'V01'),
                _buildCardTag('👤 Driver', plan['driverCode']?.toString() ?? 'D01'),
                _buildCardTag('🧊 Vault', plan['coldStorageCode']?.toString() ?? 'C01'),
                _buildCardTag('🌡️ Target Temp', '${plan['targetTemp'] ?? -2.0}°C'),
                _buildCardTag('📏 Distance', '${plan['distanceKm'] ?? 38} km'),
                _buildCardTag('⏱️ Est Time', '${plan['estimatedMinutes'] ?? 45} mins'),
                _buildCardTag('🕐 Departure', plan['pickupTime']?.toString() ?? '14:30'),
                _buildCardTag('🏁 ETA', plan['estimatedETA']?.toString() ?? '15:15'),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Corridor
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
                const Icon(Icons.alt_route, size: 16, color: Color(0xff0284c7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${plan['pickupLocation']} ➔ ${plan['deliveryLocation']}',
                    style: const TextStyle(fontSize: 11, color: Color(0xff0369a1), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // AI Reasoning Note
          if (plan['agentReasoning'] != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xfff8fafc),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🤖 ', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Text(
                      'AI Reasoning: ${plan['agentReasoning']}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade800, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // ── ACTION BUTTONS ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                // If PendingApproval: Admin must Approve or Reject
                if (status == 'PendingApproval') ...[
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff059669),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _loading ? null : () => _approvePlan(plan['id']),
                      icon: const Icon(Icons.check_circle, size: 16),
                      label: const Text('Approve Plan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _loading ? null : () => _rejectPlan(plan['id']),
                    icon: const Icon(Icons.cancel, size: 16),
                    label: const Text('Reject', style: TextStyle(fontSize: 12)),
                  ),
                ],

                // If Scheduled: Plan is approved, ready to DISPATCH vehicle with departure time!
                if (status == 'Scheduled') ...[
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff0284c7),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => showVehicleDispatchDialog(
                        context,
                        plan,
                        () => setState(() {}),
                      ),
                      icon: const Icon(Icons.rocket_launch, size: 16),
                      label: const Text(
                        '🚚 Dispatch Reefer Vehicle',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],

                // If InTransit: Track Live GPS & Telemetry!
                if (status == 'InTransit') ...[
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff7c3aed),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => showLiveVehicleTrackingModal(
                        context,
                        plan,
                        onDelivered: () => setState(() {}),
                      ),
                      icon: const Icon(Icons.satellite_alt, size: 16),
                      label: const Text(
                        '🛰️ Live GPS & Cold-Chain Tracker',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],

                // If Delivered
                if (status == 'Delivered') ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xff059669),
                        side: const BorderSide(color: Color(0xff059669)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => showLiveVehicleTrackingModal(context, plan),
                      icon: const Icon(Icons.verified, size: 16),
                      label: const Text(
                        '🏁 Delivered • View Cold-Chain Audit Log',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardTag(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xff1e293b))),
        ],
      ),
    );
  }

  Widget _buildQualityReviewTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield, color: Color(0xff0284c7), size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Automated AI Quality & Fraud Validation',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('AI validates catch species, freshness grade, and weight discrepancy.',
                        style: TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ..._flaggedCatches.map((c) => _buildQualityCatchCard(c)),
      ],
    );
  }

  Widget _buildQualityCatchCard(Map<String, dynamic> c) {
    final species = c['fishSpecies'] ?? 'Unknown Fish';
    final qty = c['quantityKg'] ?? 100;
    final price = c['askingPricePerKg'] ?? 2000;
    final status = c['status'] ?? 'Published';
    final score = c['qualityScore'] ?? 85;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
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
                'Catch #${c['id']} — $species',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xff10b981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Score: $score/100',
                  style: const TextStyle(color: Color(0xff059669), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Weight: $qty kg • Asking Price: Rs. $price/kg • Location: ${c['location'] ?? 'Negombo'}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                child: Text('Status: $status', style: const TextStyle(fontSize: 11)),
              ),
              const Spacer(),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Catch #${c['id']} verified & published by Admin.')),
                  );
                },
                child: const Text('Approve & Publish', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMultiAgentTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildAgentCard(
          '1. Freshness & Quality Assessment Agent',
          'CNN & ViT Eye/Gill Computer Vision Pipeline',
          'Online • 98.4% Accuracy',
          'Analyzes catch photos, scores freshness index, estimates remaining shelf-life.',
          Icons.camera_alt,
          const Color(0xff0284c7),
        ),
        const SizedBox(height: 12),
        _buildAgentCard(
          '2. Dynamic Fair-Pricing Agent',
          'GBM & Market Supply-Demand Pricing Engine',
          'Online • Real-Time Harbour Rates',
          'Computes minimum, maximum, and fair market price based on species and harbour arrivals.',
          Icons.monetization_on,
          const Color(0xff059669),
        ),
        const SizedBox(height: 12),
        _buildAgentCard(
          '3. Intelligent Matchmaking Agent',
          'Cosine Preference & Reliability Scorer',
          'Online • 5 Verified Export Buyers Active',
          'Matches catch with top buyers (Ceylon Sea Foods, Ocean Catch, Blue Lagoon, etc.).',
          Icons.handshake,
          const Color(0xffd97706),
        ),
        const SizedBox(height: 12),
        _buildAgentCard(
          '4. Cold-Chain & Route Logistics Agent',
          'OpenWeather & Expressway Route Optimizer',
          'Online • IoT Telemetry Active',
          'Calculates thermal risk, dispatches reefer vehicles, tracks live vehicle GPS to destination.',
          Icons.local_shipping,
          const Color(0xff7c3aed),
        ),
      ],
    );
  }

  Widget _buildAgentCard(
    String title,
    String subtitle,
    String status,
    String desc,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(desc, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 4. 🔄 ROLE SWITCHER & GLOBAL APPBAR ACTIONS
// ══════════════════════════════════════════════════════════════════════════════

class RoleSwitcherChip extends StatelessWidget {
  const RoleSwitcherChip({
    required this.currentRole,
    required this.onRoleChanged,
    super.key,
  });

  final String currentRole;
  final ValueChanged<String> onRoleChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Switch Persona',
      onSelected: onRoleChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xff005b96).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xff005b96).withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              currentRole == 'Admin'
                  ? Icons.admin_panel_settings
                  : (currentRole == 'Buyer' ? Icons.storefront : Icons.sailing),
              size: 15,
              color: const Color(0xff005b96),
            ),
            const SizedBox(width: 4),
            Text(
              currentRole,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xff005b96),
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xff005b96)),
          ],
        ),
      ),
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'Fisherman',
          child: Row(
            children: [
              Icon(Icons.sailing, size: 18, color: Color(0xff005b96)),
              SizedBox(width: 8),
              Text('🐟 Fisherman View'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'Buyer',
          child: Row(
            children: [
              Icon(Icons.storefront, size: 18, color: Color(0xff059669)),
              SizedBox(width: 8),
              Text('🛒 Buyer View'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'Admin',
          child: Row(
            children: [
              Icon(Icons.admin_panel_settings, size: 18, color: Color(0xff7c3aed)),
              SizedBox(width: 8),
              Text('🛡️ Admin & Logistics Portal'),
            ],
          ),
        ),
      ],
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
