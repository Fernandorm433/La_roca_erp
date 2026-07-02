import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';  // ← sigue para auth + rol
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../checklists/checklist_page.dart';
import 'gps_settings_page.dart';

class MapaPage extends StatefulWidget {
  const MapaPage({super.key});
  @override
  State<MapaPage> createState() => _MapaPageState();
}

class _MapaPageState extends State<MapaPage> {
  final MapController _mapController = MapController();

  // ── Firestore listener (reemplaza Timer.periodic) ──────────────────────
  StreamSubscription<List<Map<String, dynamic>>>? _fleetSubscription;
  StreamSubscription<QuerySnapshot>? _historySubscription;
  StreamSubscription<QuerySnapshot>? _configSubscription;
  Map<String, Map<String, dynamic>> _gpsConfig = {};

  // --- ROL ---
  bool _cargandoRol = true;

  // --- ESTADO GENERAL ---
  // ¡Importante! ahora String porque Firestore usa doc.id (String)
  String? _selectedConductorId;
  String? _selectedVehicleId;
  bool _isLeftPanelOpen  = true;
  String _currentLayer   = 'Tráfico Google';
  bool _showingHistoryMap  = false;
  bool _cargandoHistorial  = false;

  // --- DATOS EN VIVO ---
  List<Map<String, dynamic>> _fleetVehicles = [];
  Map<String, List<LatLng>> _liveTrails = {};
  String  _direccionActual = "Selecciona un vehículo...";
  LatLng? _lastGeocodedPos;

  // --- HISTORIAL (leído desde subcolección Firestore) ---
  DateTime _histDesde = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 0, 0);
  DateTime _histHasta = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59);
  List<LatLng>              _historyRoute  = [];
  List<Map<String, dynamic>> _historyStops  = [];
  List<Map<String, dynamic>> _historyEvents = [];

  final Map<String, String> _mapLayers = {
    'Calles'         : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    'Oscuro'         : 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
    'Tráfico Google' : 'https://mt1.google.com/vt/lyrs=m,traffic&x={x}&y={y}&z={z}',
  };

  @override
  void initState() {
    super.initState();
    _verificarRolYArrancar();
  }

  @override
  void dispose() {
    _configSubscription?.cancel();
    _fleetSubscription?.cancel();
    _historySubscription?.cancel();
    super.dispose();
  }

  // ─── 0. VERIFICAR ROL (sigue usando Supabase auth) ───────────────────
  Future<void> _verificarRolYArrancar() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _cargandoRol = false);
        _startFleetListener();
        return;
      }

      final userData = await Supabase.instance.client
          .from('usuarios')
          .select('rol')
          .eq('id', user.id)
          .single();

      final rol = userData['rol'] as String? ?? '';

      if (rol == 'operador') {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ChecklistPage()),
          );
        }
      } else {
        if (mounted) setState(() => _cargandoRol = false);
        _startFleetListener();
      }
    } catch (e) {
      debugPrint('Error verificando rol: $e');
      if (mounted) setState(() => _cargandoRol = false);
      _startFleetListener();
    }
  }

  // ─── 1. FLOTA EN VIVO: Stream de Supabase ───────────────────
  void _startFleetListener() {
    final _supabase = Supabase.instance.client;
    
    _fleetSubscription = _supabase
        .from('unidades_gps')
        .stream(primaryKey: ['imei'])
        .listen((List<Map<String, dynamic>> snapshot) {
      if (!mounted) return;

      final List<Map<String, dynamic>> vehicles = [];

      for (final data in snapshot) {
        final double? lat = (data['lat'] as num?)?.toDouble();
        final double? lng = (data['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        // Check if inactive
        if (data['activo'] == false) continue;

        final String tsString = data['ultima_actualizacion'] ?? '';
        String lastUpdate = '--:--:--';
        bool isConnected = false;
        if (tsString.isNotEmpty) {
          try {
            final DateTime dt = DateTime.parse(tsString).toLocal();
            lastUpdate = DateFormat('dd/MM/yyyy HH:mm:ss').format(dt);
            isConnected = DateTime.now().difference(dt).inMinutes < 5;
          } catch (_) {}
        }

        final int speedKmh = (data['velocidad'] as num?)?.toInt() ?? 0;
        final String docId = data['imei'];

        vehicles.add({
          'conductor_id': docId,                               
          'id'          : data['nombre'] ?? docId,
          'nombre'      : data['nombre'] ?? 'Sin Nombre',
          'icono'       : data['icono'] ?? 'mixer',
          'telefono'    : data['telefono'] ?? '',
          'last_update' : lastUpdate,
          'is_connected': isConnected,
          'speed'       : speedKmh,
          'lat'         : lat,
          'lng'         : lng,
        });

        // Almacenar el rastro en vivo
        final LatLng currentPos = LatLng(lat, lng);
        if (!_liveTrails.containsKey(docId)) {
          _liveTrails[docId] = [];
        }
        if (_liveTrails[docId]!.isEmpty || _liveTrails[docId]!.last != currentPos) {
          _liveTrails[docId]!.add(currentPos);
          if (_liveTrails[docId]!.length > 50) {
            _liveTrails[docId]!.removeAt(0);
          }
        }
      }

      // ✅ 1. Síncrono: Actualiza los camiones en el mapa
      setState(() {
        _fleetVehicles = vehicles;
      });

      // ✅ 2. Asíncrono: Geocodificación (fuera del setState)
      if (_selectedConductorId != null && !_showingHistoryMap) {
        final Map<String, dynamic>? selectedV =
            _fleetVehicles.cast<Map<String, dynamic>?>().firstWhere(
                  (v) => v!['conductor_id'] == _selectedConductorId,
                  orElse: () => null,
                );
        if (selectedV != null) {
          final LatLng pos = LatLng(selectedV['lat'] as double, selectedV['lng'] as double);
          if (_lastGeocodedPos == null ||
              const Distance().distance(_lastGeocodedPos!, pos) > 50) {
            _lastGeocodedPos = pos;
            _obtenerDireccionReal(pos.latitude, pos.longitude);
          }
        }
      }
    }, onError: (e) => debugPrint("Error stream Supabase flota: $e"));
  }

  // ─── 2. HISTORIAL: Descarga desde Supabase ──
  Future<void> _cargarHistorial() async {
    if (_selectedConductorId == null) return;

    setState(() {
      _cargandoHistorial = true;
      _historyRoute.clear();
      _historyStops.clear();
      _historyEvents.clear();
    });

    try {
      final _supabase = Supabase.instance.client;
      final response = await _supabase
          .from('historial_gps')
          .select()
          .eq('imei', _selectedConductorId!)
          .gte('fecha', _histDesde.toUtc().toIso8601String())
          .lte('fecha', _histHasta.toUtc().toIso8601String())
          .order('fecha', ascending: true);

      if (!mounted) return;

      final List<dynamic> docs = response;

      if (docs.isEmpty) {
        setState(() {
          _cargandoHistorial = false;
        });
        return;
      }

      final List<LatLng> route = [];
      final List<Map<String, dynamic>> stops = [];
      final List<Map<String, dynamic>> events = [];

      final DateTime primerInicio = DateTime.parse(docs.first['fecha']).toLocal();
      events.add({
        'icon'  : Icons.play_circle_filled_rounded,
        'color' : const Color(0xFF10B981),
        'time'  : DateFormat('HH:mm').format(primerInicio),
        'desc'  : 'Inicio de ruta',
        'type'  : 'start',
        'lat'   : null,
        'lng'   : null,
      });

      DateTime? lastStopStart;
      LatLng? lastStopPos;

      for (var i = 0; i < docs.length; i++) {
        final data = docs[i];
        final double? lat = (data['lat'] as num?)?.toDouble();
        final double? lng = (data['lng'] as num?)?.toDouble();
        final double vel = (data['velocidad'] as num?)?.toDouble() ?? 0;
        final DateTime time = DateTime.parse(data['fecha']).toLocal();

        if (lat != null && lng != null) {
          route.add(LatLng(lat, lng));

          // Detección de paradas
          if (vel < 3) {
            if (lastStopStart == null) {
              lastStopStart = time;
              lastStopPos = LatLng(lat, lng);
            }
          } else {
            if (lastStopStart != null && lastStopPos != null) {
              final duracion = time.difference(lastStopStart).inMinutes;
              if (duracion >= 5) { // Paradas de más de 5 minutos
                stops.add({
                  'lat': lastStopPos.latitude,
                  'lng': lastStopPos.longitude,
                  'dur': '$duracion min'
                });
                events.add({
                  'icon'  : Icons.pause_circle_filled_rounded,
                  'color' : Colors.orange,
                  'time'  : DateFormat('HH:mm').format(lastStopStart),
                  'desc'  : 'Parada (${duracion}m)',
                  'type'  : 'stop',
                  'lat'   : lastStopPos.latitude,
                  'lng'   : lastStopPos.longitude,
                });
              }
              lastStopStart = null;
            }
          }
        }
      }

      final DateTime ultimoFin = DateTime.parse(docs.last['fecha']).toLocal();
      events.add({
        'icon'  : Icons.stop_circle_rounded,
        'color' : const Color(0xFFEF4444),
        'time'  : DateFormat('HH:mm').format(ultimoFin),
        'desc'  : 'Fin de ruta',
        'type'  : 'end',
        'lat'   : null,
        'lng'   : null,
      });

      setState(() {
        _historyRoute = route;
        _historyStops = stops;
        _historyEvents = events;
        _cargandoHistorial = false;
      });

      if (route.isNotEmpty && _showingHistoryMap) {
        _mapController.move(route.first, 14.0);
      }
    } catch (e) {
      debugPrint("Error historial Supabase: $e");
      if (mounted) setState(() => _cargandoHistorial = false);
    }
  }

  // ─── 3. UTILIDADES ────────────────────────────────────────────────────
  Future<void> _obtenerDireccionReal(double lat, double lng) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
        ),
        headers: {
          // ✅ Obligatorio por Nominatim para no banear tu IP
          'User-Agent': 'com.rmmetaltec.erp', 
        },
      ).timeout(const Duration(seconds: 6)); // ✅ Timeout de 6 segundos para evitar bloqueos

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] as Map<String, dynamic>? ?? {};

        // ✅ Construir una dirección más corta y legible
        final String road = address['road'] ?? address['pedestrian'] ?? '';
        final String suburb = address['suburb'] ?? address['neighbourhood'] ?? '';
        final String city = address['city'] ?? address['town'] ?? address['village'] ?? '';

        String shortAddress = [road, suburb, city]
            .where((e) => e.toString().isNotEmpty)
            .join(', ');

        if (shortAddress.isEmpty) {
          shortAddress = data['display_name'] ?? 'Dirección desconocida';
        }

        // ✅ Verificamos que la vista siga existiendo antes de actualizarla
        if (mounted) {
          setState(() => _direccionActual = shortAddress);
        }
      }
    } catch (e) {
      debugPrint("Error Geocoding: $e");
      if (mounted) {
        setState(() => _direccionActual = 'Error de conexión / Timeout');
      }
    }
  }

  void _seleccionarUnidad(Map<String, dynamic> vehiculo) {
  setState(() {
    _selectedConductorId = vehiculo['conductor_id'] as String;
    _selectedVehicleId   = vehiculo['id'] as String;
    _showingHistoryMap   = false;
    _direccionActual     = "Calculando dirección...";
  });
  
  _mapController.move(LatLng(vehiculo['lat'], vehiculo['lng']), 16.0);
  _obtenerDireccionReal(vehiculo['lat'], vehiculo['lng']);

  if (MediaQuery.of(context).size.width < 800) {
    setState(() => _isLeftPanelOpen = false);
  }

  // Cargar historial de la unidad dinámicamente
  _cargarHistorial();
}

  Future<void> _openGoogleMaps(double lat, double lng) async {
    final Uri url = Uri.parse('http://maps.google.com/maps?q=loc:$lat,$lng');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _selectDateTime(BuildContext context, bool isDesde) async {
    final initialDate = isDesde ? _histDesde : _histHasta;
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        if (!context.mounted) return;
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
      );
      if (pickedTime != null) {
        setState(() {
          final newDateTime = DateTime(
            pickedDate.year, pickedDate.month, pickedDate.day,
            pickedTime.hour, pickedTime.minute,
          );
          if (isDesde) _histDesde = newDateTime;
          else         _histHasta = newDateTime;
        });
        
        // Reiniciar listener de historial si hay un conductor seleccionado
        if (_selectedConductorId != null) {
          _cargarHistorial();
        }
      }
    }
  }

  // ─── 4. BUILD ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_cargandoRol) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final bool isMobile   = MediaQuery.of(context).size.width < 800;
    final double panelWidth =
        isMobile ? MediaQuery.of(context).size.width * 0.85 : 340.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // ── MAPA ───────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(-16.377, -71.515),
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: _mapLayers[_currentLayer]!,
                userAgentPackageName: 'com.rmmetaltec.erp',
              ),

              // Ruta historial
              if (_showingHistoryMap && _historyRoute.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _historyRoute,
                      strokeWidth: 3.0,
                      color: Colors.red.withOpacity(0.9),
                      borderColor: Colors.red.shade900,
                      borderStrokeWidth: 1.0,
                    ),
                  ],
                ),

              // Marcadores de paradas historial
              if (_showingHistoryMap)
                MarkerLayer(
                  markers: _historyStops
                      .map(
                        (stop) => Marker(
                          point: LatLng(stop['lat'], stop['lng']),
                          width: 40,
                          height: 40,
                          child: _buildStopMarker(stop['dur']),
                        ),
                      )
                      .toList(),
                ),

              // Camiones en vivo
              if (!_showingHistoryMap)
                PolylineLayer(
                  polylines: _liveTrails.entries.map((entry) => Polyline(
                    points: entry.value,
                    strokeWidth: 3.0,
                    color: Colors.blueAccent.withOpacity(0.7),
                  )).toList(),
                ),
              if (!_showingHistoryMap)
                MarkerLayer(
                  markers: _fleetVehicles
                      .map(
                        (v) => Marker(
                          point: LatLng(v['lat'], v['lng']),
                          width: 140,
                          height: 80,
                          alignment: Alignment.bottomCenter,
                          child: _buildVehicleMarker(v),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),

          // Overlay oscuro en mobile cuando panel está abierto
          if (isMobile && (_isLeftPanelOpen || _selectedConductorId != null))
            GestureDetector(
              onTap: () => setState(() {
                _isLeftPanelOpen      = false;
                _selectedConductorId  = null;
              }),
              child: Container(color: Colors.black.withOpacity(0.2)),
            ),

          // Panel izquierdo
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            top: 15, bottom: 15,
            left: _isLeftPanelOpen ? 15 : -panelWidth - 20,
            width: panelWidth,
            child: _buildLeftSidebar(),
          ),

          // FAB menú
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            top: 20,
            left: _isLeftPanelOpen ? -60 : 15,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              child: const Icon(Icons.menu, color: Color(0xFF0F172A)),
              onPressed: () => setState(() => _isLeftPanelOpen = true),
            ),
          ),

          // Panel derecho (detalle unidad)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            top: 15, bottom: 15,
            right: _selectedConductorId != null && !_showingHistoryMap
                ? 15
                : -350,
            width: 320,
            child: _buildRightSidebar(),
          ),

          // Selector de capa y Ajustes
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            top: 15,
            right: _selectedConductorId != null && !_showingHistoryMap
                ? 320 + 30
                : 15,
            child: Row(
              children: [
                _LightGlassContainer(
                  padding: const EdgeInsets.all(8),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const GpsSettingsPage()));
                    },
                    child: const Icon(Icons.settings, color: Color(0xFF0F172A), size: 22),
                  ),
                ),
                const SizedBox(width: 10),
                _LightGlassContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _currentLayer,
                      icon: const Icon(Icons.layers, size: 18),
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      dropdownColor: Colors.white,
                      items: _mapLayers.keys
                          .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _currentLayer = v);
                      },
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

  // ─── COMPONENTES GRÁFICOS ─────────────────────────────────────────────
  IconData _getVehicleIcon(String? iconType) {
    switch (iconType) {
      case 'camioneta': return Icons.directions_car_filled_outlined;
      case 'auto': return Icons.directions_car_outlined;
      case 'cargador': return Icons.agriculture_outlined;
      case 'volquete': return Icons.local_shipping_outlined;
      case 'mixer':
      default:
        return Icons.local_shipping_rounded;
    }
  }

  Widget _buildVehicleMarker(Map<String, dynamic> v) {
    final bool isSelected = v['conductor_id'] == _selectedConductorId;
    return GestureDetector(
      onTap: () => _seleccionarUnidad(v),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blue.shade900
                  : Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.grey.shade300,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              '${v['id']} (${v['speed']} kph)',
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF0F172A),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: (v['speed'] as int) > 0
                    ? const Color(0xFF10B981)
                    : Colors.red,
                width: 2,
              ),
            ),
            child: Icon(
              _getVehicleIcon(v['icono'] as String?),
              color: const Color(0xFF0F172A),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopMarker(String duration) {
    return Tooltip(
      message: 'Parada: $duration',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.red.shade700,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
        ),
        child: const Center(
          child: Text(
            'P',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeftSidebar() {
    return _LightGlassContainer(
      padding: EdgeInsets.zero,
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Rastreo Flota',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Badge en vivo
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF10B981),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_fleetVehicles.length}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                    onPressed: () => setState(() => _isLeftPanelOpen = false),
                  ),
                ],
              ),
            ),
            TabBar(
              tabs: const [Tab(text: 'En Vivo'), Tab(text: 'Historial')],
              labelColor: const Color(0xFF0F172A),
              indicatorColor: const Color(0xFF10B981),
              onTap: (index) {
                if (index == 1) {
                  setState(() => _showingHistoryMap = true);
                  if (_historyRoute.isNotEmpty) {
                    _mapController.move(_historyRoute.first, 14.0);
                  }
                } else {
                  setState(() => _showingHistoryMap = false);
                }
              },
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // ── TAB: EN VIVO ─────────────────────────────────────
                  _fleetVehicles.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.local_shipping_outlined,
                                size: 40,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Esperando conexión\nde operadores...',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _fleetVehicles.length,
                          separatorBuilder: (ctx, i) =>
                              const Divider(height: 16),
                          itemBuilder: (ctx, index) {
                            final v = _fleetVehicles[index];
                            final int speed = v['speed'] as int;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: speed > 0
                                    ? Colors.green.shade100
                                    : Colors.red.shade50,
                                child: Icon(
                                  _getVehicleIcon(v['icono'] as String?),
                                  color: speed > 0
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      v['id'] as String,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    (v['is_connected'] as bool? ?? false) ? Icons.wifi : Icons.wifi_off,
                                    size: 16,
                                    color: (v['is_connected'] as bool? ?? false) ? Colors.green : Colors.grey.shade400,
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                'Actualizado: ${v['last_update']}',
                                style: const TextStyle(fontSize: 10),
                              ),
                              trailing: Text(
                                '$speed kph',
                                style: TextStyle(
                                  color: speed > 0
                                      ? Colors.green
                                      : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onTap: () {
                                _seleccionarUnidad(v);
                                setState(() => _showingHistoryMap = false);
                              },
                            );
                          },
                        ),

                  // ── TAB: HISTORIAL ───────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Unidad seleccionada
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Vehículo a consultar',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.local_shipping_outlined, color: Colors.grey),
                          ),
                          value: _fleetVehicles.any((v) => v['conductor_id'] == _selectedConductorId) ? _selectedConductorId : null,
                          hint: const Text('Selecciona una unidad'),
                          items: _fleetVehicles.map((v) {
                            return DropdownMenuItem<String>(
                              value: v['conductor_id'] as String,
                              child: Text(
                                v['id'] as String,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              final v = _fleetVehicles.firstWhere((element) => element['conductor_id'] == val);
                              setState(() {
                                _selectedConductorId = v['conductor_id'] as String;
                                _selectedVehicleId   = v['id'] as String;
                              });
                              _cargarHistorial();
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        // Selector de rango de fechas
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.tonal(
                                onPressed: () =>
                                    _selectDateTime(context, true),
                                child: Text(
                                  DateFormat('dd/MM HH:mm').format(_histDesde),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(
                                Icons.arrow_forward,
                                size: 14,
                                color: Colors.grey,
                              ),
                            ),
                            Expanded(
                              child: FilledButton.tonal(
                                onPressed: () =>
                                    _selectDateTime(context, false),
                                child: Text(
                                  DateFormat('dd/MM HH:mm').format(_histHasta),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),

                        // ── TIMELINE DE EVENTOS ──────────────────────
                        Expanded(
                          child: _historyEvents.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.timeline_outlined,
                                        size: 36,
                                        color: Colors.grey.shade300,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Selecciona una unidad\ny carga su historial',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _historyEvents.length,
                                  itemBuilder: (context, index) {
                                    return _buildTimelineItem(
                                      _historyEvents[index],
                                      isLast: index ==
                                          _historyEvents.length - 1,
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── TIMELINE ITEM (diseño moderno) ─────────────────────────────────────
  Widget _buildTimelineItem(Map<String, dynamic> ev, {required bool isLast}) {
    final Color  color = ev['color'] as Color;
    final IconData icon = ev['icon']  as IconData;
    final String type  = ev['type']  as String;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Línea vertical + nodo
          SizedBox(
            width: 36,
            child: Column(
              children: [
                // Nodo circular
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(icon, color: color, size: 14),
                ),
                // Línea de conexión (excepto último)
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            color.withOpacity(0.4),
                            Colors.grey.shade200,
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Contenido del evento
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título + hora
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ev['desc'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: type == 'stop'
                                ? color
                                : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Text(
                        ev['time'] as String,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  // Hora fin (solo para paradas)
                  if (type == 'stop' && ev['time_fin'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Salida: ${ev['time_fin']}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ),

                  // Badge de duración + botón ver en mapa
                  if (type == 'stop') ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Badge duración
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: color.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            ev['desc'] as String,
                            style: TextStyle(
                              fontSize: 10,
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Botón ver en mapa
                        if (ev['lat'] != null && ev['lng'] != null)
                          GestureDetector(
                            onTap: () => _mapController.move(
                              LatLng(
                                ev['lat'] as double,
                                ev['lng'] as double,
                              ),
                              16.0,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.my_location,
                                    size: 10,
                                    color: Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Ver',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightSidebar() {
    final Map<String, dynamic>? v = _fleetVehicles
        .cast<Map<String, dynamic>?>()
        .firstWhere(
          (e) => e!['conductor_id'] == _selectedConductorId,
          orElse: () => null,
        );

    if (v == null) return const SizedBox();

    return _LightGlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                v['id'] as String,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => setState(() => _selectedConductorId = null),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const Divider(),
          _buildDetailRow(
            'Velocidad:',
            '${v['speed']} kph',
            highlight: true,
          ),
          _buildDetailRow('Hora GPS:', v['last_update'] as String),
          _buildDetailRow('Dirección:', _direccionActual),
          _buildDetailRow(
            'Posición:',
            '${(v['lat'] as double).toStringAsFixed(5)}, ${(v['lng'] as double).toStringAsFixed(5)}',
            isLink: true,
            onTap: () => _openGoogleMaps(
              v['lat'] as double,
              v['lng'] as double,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isLink = false,
    bool highlight = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Text(
                value,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      highlight ? FontWeight.bold : FontWeight.normal,
                  color: isLink ? Colors.blue : Colors.black87,
                  decoration:
                      isLink ? TextDecoration.underline : TextDecoration.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Glassmorphism container (igual que antes) ─────────────────────────────
class _LightGlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _LightGlassContainer({
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            border: Border.all(
              color: Colors.white.withOpacity(0.8),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}