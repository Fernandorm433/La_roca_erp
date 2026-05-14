// gps_service.dart
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class GpsService {
  static final GpsService _instance = GpsService._internal();
  factory GpsService() => _instance;
  GpsService._internal();

  StreamSubscription<Position>? _trackingStream;
  String? _conductorDocId;

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
    _iniciarStreamGps(conductorData['nombre'], conductorData['marca']);
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

    _trackingStream?.cancel();
    _trackingStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2,
      ),
    ).listen((Position pos) async {
      final double velocidadFiltrada = pos.speed < 0.5 ? 0.0 : pos.speed * 3.6;
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
    });
  }

  void detenerRastreo() {
    _trackingStream?.cancel();
  }
}