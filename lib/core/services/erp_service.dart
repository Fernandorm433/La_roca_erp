// Archivo: lib/core/services/erp_service.dart
// Versión con Firebase Storage (fotos/videos) + notificaciones FCM

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_storage_service.dart';
import 'notificacion_service.dart';

class ErpService {
  static final ErpService _instance = ErpService._internal();
  factory ErpService() => _instance;
  ErpService._internal();

  final _supabase = Supabase.instance.client;
  final _firebaseStorage = FirebaseStorageService();
  final _notifications = NotificationService();

  StreamSubscription<Position>? _positionSub;
  String? _asesorActivoId;
  String? _asesorActivoNombre;

  // ─── GPS ──────────────────────────────────────────────────────
  Future<bool> iniciarSeguimientoGPS(String asesorId, String nombre) async {
    _asesorActivoId = asesorId;
    _asesorActivoNombre = nombre;

    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return false;

    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    await _publicarUbicacion(asesorId, nombre, pos.latitude, pos.longitude, 'activo');

    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 15),
    ).listen((p) => _publicarUbicacion(asesorId, nombre, p.latitude, p.longitude, 'activo'));

    return true;
  }

  Future<void> _publicarUbicacion(
    String asesorId, String nombre, double lat, double lng, String estado,
  ) async {
    try {
      await _supabase.from('ubicaciones_asesores').upsert({
        'asesor_id': asesorId,
        'nombre_asesor': nombre,
        'latitud': lat,
        'longitud': lng,
        'estado': estado,
        'ultima_actualizacion': DateTime.now().toIso8601String(),
      }, onConflict: 'asesor_id');
    } catch (e) {
      debugPrint('GPS error: $e');
    }
  }

  Future<void> actualizarEstadoAsesor(String estado) async {
    if (_asesorActivoId == null) return;
    await _supabase
        .from('ubicaciones_asesores')
        .update({'estado': estado})
        .eq('asesor_id', _asesorActivoId!);
  }

  void detenerSeguimientoGPS() {
    _positionSub?.cancel();
    if (_asesorActivoId != null) {
      _supabase.from('ubicaciones_asesores')
          .update({'estado': 'inactivo'})
          .eq('asesor_id', _asesorActivoId!);
    }
    _asesorActivoId = null;
  }

  Future<void> actualizarPosicion(String asesorId, String nombre, double lat, double lng) async {
    try {
      await _supabase.from('ubicaciones_asesores').upsert({
        'asesor_id': asesorId,
        'nombre_asesor': nombre,
        'latitud': lat,
        'longitud': lng,
        'estado': 'activo',
        'ultima_actualizacion': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'asesor_id');
    } catch (e) {
      debugPrint('Tracking silencioso error: $e');
    }
  }

  Future<void> marcarAsesorInactivo(String asesorId) async {
    try {
      await _supabase.from('ubicaciones_asesores')
          .update({'estado': 'inactivo'})
          .eq('asesor_id', asesorId);
    } catch (e) {
      debugPrint('Error marcando inactivo: $e');
    }
  }

  // ─── Marcar punto en mapa + NOTIFICAR JEFA que llegó ─────────
  Future<void> marcarPuntoVisita({
    required String asesorId,
    required String nombre,
    required double latitud,
    required double longitud,
    String? nombreObra,
  }) async {
    final obra = (nombreObra == null || nombreObra.isEmpty) ? 'una obra' : nombreObra;
    try {
      await _supabase.from('marcas_visita').insert({
        'asesor_id': asesorId,
        'nombre_asesor': nombre,
        'latitud': latitud,
        'longitud': longitud,
        'nombre_obra': obra,
        'creado_en': DateTime.now().toIso8601String(),
      });

      // 🔔 Notificar a la jefa que el asesor llegó
      await _notifications.notificarJefes(
        titulo: '📍 Asesor llegó a obra',
        cuerpo: '$nombre llegó a $obra',
        datos: {'asesor_id': asesorId, 'tipo': 'llegada', 'obra': obra},
      );
    } catch (e) {
      debugPrint('Error marcando punto: $e');
    }
  }

  // ─── Streams ──────────────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> streamUbicacionesAsesores() {
    return _supabase.from('ubicaciones_asesores')
        .stream(primaryKey: ['asesor_id'])
        .order('ultima_actualizacion', ascending: false);
  }

  Stream<List<Map<String, dynamic>>> streamMarcasHoy() {
    final hoy = DateTime.now();
    final inicio = DateTime(hoy.year, hoy.month, hoy.day).toIso8601String();
    final fin = DateTime(hoy.year, hoy.month, hoy.day, 23, 59, 59).toIso8601String();
    return _supabase.from('marcas_visita')
        .stream(primaryKey: ['id'])
        .gte('creado_en', inicio)
        .order('creado_en', ascending: false)
        .map((lista) {
          final fechaFin = DateTime.parse(fin);
          return lista.where((m) {
            if (m['creado_en'] == null) return false;
            return !DateTime.parse(m['creado_en']).isAfter(fechaFin);
          }).toList();
        });
  }

  Stream<List<Map<String, dynamic>>> streamAsignaciones(String asesorId) {
    return _supabase.from('asignaciones_visitas')
        .stream(primaryKey: ['id'])
        .eq('asesor_id', asesorId)
        .order('fecha_asignacion', ascending: false);
  }

  Stream<List<Map<String, dynamic>>> streamActividadReciente() {
    return _supabase.from('asignaciones_visitas')
        .stream(primaryKey: ['id'])
        .order('fecha_asignacion', ascending: false)
        .map((list) => list.take(20).toList());
  }

  // ─── Asignar cliente ──────────────────────────────────────────
  Future<void> asignarCliente({
    required String asesorId,
    required String nombreAsesor,
    required String cliente,
    required String direccion,
    required String observaciones,
    required String contacto,
    required String telefono,
    String? enlaceMaps,
  }) async {
    await _supabase.from('asignaciones_visitas').insert({
      'asesor_id': asesorId,
      'nombre_asesor': nombreAsesor,
      'cliente': cliente,
      'direccion': direccion,
      'observaciones': observaciones,
      'contacto': contacto,
      'telefono': telefono,
      'enlace_maps': enlaceMaps,
      'estado': 'pendiente',
      'fecha_asignacion': DateTime.now().toIso8601String(),
    });
  }

  // ─── Actualizar estado de asignación + NOTIFICAR según estado ─
  Future<void> actualizarEstadoAsignacion(
    String id,
    String estado, {
    String? nombreAsesor, // pasar para las notificaciones
    String? nombreCliente,
  }) async {
    await _supabase.from('asignaciones_visitas').update({
      'estado': estado,
      if (estado == 'completada')
        'fecha_completada': DateTime.now().toIso8601String(),
    }).eq('id', id);

    // 🔔 Notificar a la jefa según el cambio de estado
    if (nombreAsesor != null && nombreCliente != null) {
      switch (estado) {
        case 'en_camino':
          await _notifications.notificarJefes(
            titulo: '🚗 Asesor en camino',
            cuerpo: '$nombreAsesor aceptó la visita y va hacia $nombreCliente',
            datos: {'tipo': 'en_camino', 'asesor': nombreAsesor},
          );
          break;
        case 'en_obra':
          // Este caso lo maneja marcarPuntoVisita con más info
          break;
        case 'completada':
          // Lo maneja finalizarVisita
          break;
      }
    }
  }

  // ─── Finalizar visita con Firebase Storage ────────────────────
  Future<void> finalizarVisita({
    required String asignacionId,
    required String asesorId,
    required String nombreAsesor,
    required String nombreObra,
    required String contacto,
    required String telefono,
    required String observaciones,
    required double latitud,
    required double longitud,
    File? fotoExterior,
    File? fotoInterior,
    File? videoEvidencia,
  }) async {
    String? urlExterior;
    String? urlInterior;
    String? urlVideo;

    // ✅ Subir archivos a FIREBASE STORAGE (no Supabase)
    if (fotoExterior != null) {
      urlExterior = await _firebaseStorage.subirArchivo(
        archivo: fotoExterior,
        asesorId: asesorId,
        tipo: 'exterior',
        extension: 'jpg',
      );
    }
    if (fotoInterior != null) {
      urlInterior = await _firebaseStorage.subirArchivo(
        archivo: fotoInterior,
        asesorId: asesorId,
        tipo: 'interior',
        extension: 'jpg',
      );
    }
    if (videoEvidencia != null) {
      urlVideo = await _firebaseStorage.subirArchivo(
        archivo: videoEvidencia,
        asesorId: asesorId,
        tipo: 'video',
        extension: 'mp4',
      );
    }

    // Guardar metadatos en Supabase (solo URLs, sin el archivo)
    await _supabase.from('evidencias_visitas').insert({
      'asignacion_id': asignacionId.isEmpty ? null : asignacionId,
      'asesor_id': asesorId,
      'nombre_obra': nombreObra,
      'contacto': contacto,
      'telefono': telefono,
      'observaciones': observaciones,
      'latitud': latitud,
      'longitud': longitud,
      'url_foto_exterior': urlExterior,
      'url_foto_interior': urlInterior,
      'url_video': urlVideo,
      'creado_en': DateTime.now().toIso8601String(),
    });

    if (asignacionId.isNotEmpty) {
      await _supabase.from('asignaciones_visitas').update({
        'estado': 'completada',
        'fecha_completada': DateTime.now().toIso8601String(),
      }).eq('id', asignacionId);
    }

    await actualizarEstadoAsesor('activo');

    // 🔔 Notificar a la jefa que hay fotos/video nuevos
    final tieneVideo = urlVideo != null;
    await _notifications.notificarJefes(
      titulo: '✅ Visita completada con evidencia',
      cuerpo: '$nombreAsesor registró $nombreObra'
          '${tieneVideo ? ' — con fotos y video 🎥' : ' — con fotos 📷'}',
      datos: {
        'tipo': 'visita_completada',
        'asesor': nombreAsesor,
        'obra': nombreObra,
        'tiene_video': tieneVideo.toString(),
      },
    );
  }

  Future<List<Map<String, dynamic>>> getAsesoresRegistrados() async {
    try {
      final res = await _supabase
          .from('usuarios')
          .select('id, nombre, rol')
          .eq('rol', 'asesor')
          .order('nombre');
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error obteniendo asesores: $e');
      return [];
    }
  }

  Stream<List<Map<String, dynamic>>> streamEvidenciasPorDia(DateTime fecha) {
    final inicio = DateTime(fecha.year, fecha.month, fecha.day).toIso8601String();
    final fin = DateTime(fecha.year, fecha.month, fecha.day, 23, 59, 59).toIso8601String();
    return _supabase.from('evidencias_visitas')
        .stream(primaryKey: ['id'])
        .gte('creado_en', inicio)
        .order('creado_en', ascending: false)
        .map((lista) {
          final fechaFin = DateTime.parse(fin);
          return lista.where((ev) {
            if (ev['creado_en'] == null) return false;
            final f = DateTime.parse(ev['creado_en']);
            return f.isBefore(fechaFin) || f.isAtSameMomentAs(fechaFin);
          }).toList();
        });
  }
}