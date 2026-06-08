// gps_service.dart
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'notificacion_service.dart';

class GpsService {
  static final GpsService _instance = GpsService._internal();
  factory GpsService() => _instance;
  GpsService._internal();

  StreamSubscription<Position>? _trackingStream;
  Timer? _stopTimer;
  String? _conductorDocId;
  String? _conductorNombre;

  // -- ESTADO HISTORIAL --
  bool _isStopped = false;
  bool _notifiedStop = false; // Evita notificaciones duplicadas
  DateTime? _stopStartTime;
  String? _currentStopDocId;

  Future<void> inicializarRastreoSiEsOperador() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    // Verificar rol
    final userData = await client.from('usuarios').select('rol').eq('id', user.id).single();
    if (userData['rol'] != 'operador') return;

    // Obtener datos del conductor
    final conductorData = await client.from('conductores').select('id, nombre, marca').eq('usuario_id', user.id).maybeSingle();
    if (conductorData == null) return;

    _conductorDocId = conductorData['id'].toString();
    _conductorNombre = conductorData['nombre'].toString();
    _iniciarStreamGps(conductorData['nombre'], conductorData['marca']);
  }

  void _iniciarTimerParada() {
    _stopTimer?.cancel();
    _stopTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (_isStopped && _currentStopDocId != null && _stopStartTime != null && _conductorDocId != null) {
        final duracionMin = DateTime.now().difference(_stopStartTime!).inMinutes;
        
        // 🔔 Notificar a jefes si la parada ya duró 5 minutos (evita semáforos)
        if (duracionMin >= 5 && !_notifiedStop) {
          _notifiedStop = true;
          NotificationService().notificarJefes(
            titulo: '🚧 Mixero en Obra',
            cuerpo: 'El mixero $_conductorNombre lleva 5 minutos detenido (Posible llegada a obra).',
            datos: {'tipo': 'llegada_obra', 'conductor_id': _conductorDocId!},
          );
        }

        try {
          await FirebaseFirestore.instance
              .collection('operadores_gps')
              .doc(_conductorDocId)
              .collection('historial')
              .doc(_currentStopDocId)
              .set({
            'fin': FieldValue.serverTimestamp(),
            'duracion_min': duracionMin,
          }, SetOptions(merge: true));
        } catch (e) {
          // Ignorar error si no hay internet, se guardará luego por caché local
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _iniciarStreamGps(String nombre, String placa) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    final docRef = FirebaseFirestore.instance.collection('operadores_gps').doc(_conductorDocId);
    final historialRef = docRef.collection('historial');

    _trackingStream?.cancel();
    _trackingStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2,
      ),
    ).listen((Position pos) async {
      final double velocidadFiltrada = pos.speed < 0.5 ? 0.0 : pos.speed * 3.6;

      // 1. Escribir ubicación en vivo
      await docRef.set({
        'lat': pos.latitude,
        'lng': pos.longitude,
        'speed_kmh': velocidadFiltrada,
        'timestamp': FieldValue.serverTimestamp(),
        'nombre': nombre,
        'placa': placa,
        'conductor_id': _conductorDocId,
        'online': true,
      }, SetOptions(merge: true));

      // 2. Lógica de Historial (Paradas)
      final now = DateTime.now();

      if (velocidadFiltrada < 2.0) {
        // DETENIDO
        if (!_isStopped) {
          _isStopped = true;
          _stopStartTime = now;
          
          final newDoc = historialRef.doc();
          _currentStopDocId = newDoc.id;

          await newDoc.set({
            'inicio': FieldValue.serverTimestamp(),
            'fin': FieldValue.serverTimestamp(),
            'lat': pos.latitude,
            'lng': pos.longitude,
            'duracion_min': 0,
            'estado': 'detenido'
          });
          
          _iniciarTimerParada();
        } else {
          // Sigue detenido, pero el timer ya actualiza el tiempo.
          // Solo si recibimos un GPS update por "drift", refrescamos
          if (_currentStopDocId != null && _stopStartTime != null) {
            final duracionMin = now.difference(_stopStartTime!).inMinutes;
            await historialRef.doc(_currentStopDocId).set({
              'fin': FieldValue.serverTimestamp(),
              'duracion_min': duracionMin,
            }, SetOptions(merge: true));
          }
        }
      } else {
        // EN MOVIMIENTO
        if (_isStopped) {
          // Arrancó nuevamente
          if (_currentStopDocId != null && _stopStartTime != null) {
            final duracionMin = now.difference(_stopStartTime!).inMinutes;
            await historialRef.doc(_currentStopDocId).set({
              'fin': FieldValue.serverTimestamp(),
              'duracion_min': duracionMin,
              'estado': 'finalizado'
            }, SetOptions(merge: true));
          }
          
          _stopTimer?.cancel();
          _isStopped = false;
          _notifiedStop = false;
          _stopStartTime = null;
          _currentStopDocId = null;
        }
      }
    });
  }

  void detenerRastreo() {
    _stopTimer?.cancel();
    if (_isStopped && _currentStopDocId != null && _stopStartTime != null && _conductorDocId != null) {
      final duracionMin = DateTime.now().difference(_stopStartTime!).inMinutes;
      FirebaseFirestore.instance
          .collection('operadores_gps')
          .doc(_conductorDocId)
          .collection('historial')
          .doc(_currentStopDocId)
          .set({
            'fin': FieldValue.serverTimestamp(),
            'duracion_min': duracionMin,
            'estado': 'finalizado'
          }, SetOptions(merge: true));
    }
    
    _trackingStream?.cancel();
    _isStopped = false;
    _notifiedStop = false;
    _stopStartTime = null;
    _currentStopDocId = null;
  }
}