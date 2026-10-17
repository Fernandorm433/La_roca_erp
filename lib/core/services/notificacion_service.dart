// Archivo: lib/core/services/notification_service.dart
// Maneja FCM: permisos, token, notificaciones locales y envío a la jefa.

import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Handler en segundo plano (DEBE ser función top-level) ────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase ya está inicializado porque usamos firebase_core
  debugPrint('📬 Notificación en background: ${message.notification?.title}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  final _supabase = Supabase.instance.client;

  // Canal de notificaciones Android
  static const _channel = AndroidNotificationChannel(
    'erp_visitas',
    'Visitas ERP',
    description: 'Notificaciones de la fuerza de ventas',
    importance: Importance.max,
    playSound: true,
  );

  // ─── Inicializar (llamar en main.dart DESPUÉS de Firebase.initializeApp) ──
  Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint('ℹ️ FCM y notificaciones locales móviles omitidas en Web.');
      return;
    }

    // Registrar handler de background
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Pedir permisos al usuario
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('FCM permiso: ${settings.authorizationStatus}');

    // Configurar notificaciones locales (para cuando la app está en primer plano)
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false, // Ya se pidió arriba
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    // Crear canal Android (obligatorio para Android 8+)
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Mostrar notificación local cuando la app está en PRIMER PLANO
    FirebaseMessaging.onMessage.listen(_mostrarNotificacionLocal);

    // Configurar FCM para que muestre en primer plano en iOS
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  void _mostrarNotificacionLocal(RemoteMessage message) {
    final notif = message.notification;
    if (notif == null) return;

    _localNotifications.show(
      notif.hashCode,
      notif.title,
      notif.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  void mostrarNotificacionLocalDirecta(String titulo, String cuerpo) {
    _localNotifications.show(
      DateTime.now().millisecond,
      titulo,
      cuerpo,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  // ─── Guardar token del dispositivo en Supabase ────────────────
  // Llamar al hacer login (tanto asesor como jefa)
  Future<void> guardarToken(String userId) async {
    if (kIsWeb) return;
    try {
      // En iOS y macOS, requerimos obtener primero el APNS Token.
      // Si estamos en simulador o sin la capacidad Push configurada, esto evitará el crasheo.
      if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken == null) {
          debugPrint('⚠️ [FCM] APNS token no disponible (¿simulador o falta capacidad Push?). Saltando FCM.');
          return;
        }
      }

      final token = await _messaging.getToken();
      if (token == null) return;

      await _supabase
          .from('usuarios')
          .update({'fcm_token': token})
          .eq('id', userId);

      debugPrint('✅ FCM token guardado para $userId');

      // Actualizar automáticamente si el token cambia
      _messaging.onTokenRefresh.listen((nuevoToken) async {
        await _supabase
            .from('usuarios')
            .update({'fcm_token': nuevoToken})
            .eq('id', userId);
        debugPrint('🔄 FCM token actualizado');
      });
    } catch (e) {
      debugPrint('Error guardando token FCM: $e');
    }
  }

  // ─── Enviar notificación por Roles Específicos ─────────────
  Future<void> notificarPorRoles({
    required List<String> roles,
    required String titulo,
    required String cuerpo,
    Map<String, String>? datos,
  }) async {
    try {
      final destinatarios = await _supabase
          .from('usuarios')
          .select('fcm_token')
          .inFilter('rol', roles)
          .not('fcm_token', 'is', null);

      for (final dest in destinatarios) {
        final token = dest['fcm_token'] as String?;
        if (token == null || token.isEmpty) continue;

        await _supabase.functions.invoke(
          'send-notification',
          body: {
            'token': token,
            'title': titulo,
            'body': cuerpo,
            'data': datos ?? {},
          },
        );
      }
      debugPrint('📤 Notificación enviada a roles $roles: $titulo');
    } catch (e) {
      debugPrint('Error enviando notificación a roles $roles: $e');
    }
  }

  // ─── Enviar notificación a todos los usuarios ─────────────
  Future<void> notificarATodos({
    required String titulo,
    required String cuerpo,
    Map<String, String>? datos,
  }) async {
    try {
      final destinatarios = await _supabase
          .from('usuarios')
          .select('fcm_token')
          .not('fcm_token', 'is', null);

      for (final dest in destinatarios) {
        final token = dest['fcm_token'] as String?;
        if (token == null || token.isEmpty) continue;

        await _supabase.functions.invoke(
          'send-notification',
          body: {
            'token': token,
            'title': titulo,
            'body': cuerpo,
            'data': datos ?? {},
          },
        );
      }
      debugPrint('📤 Notificación enviada a TODOS: $titulo');
    } catch (e) {
      debugPrint('Error enviando notificación a todos: $e');
    }
  }

  // ─── Enviar notificación a un usuario específico ─────────────
  Future<void> notificarUsuario({
    required String userId,
    required String titulo,
    required String cuerpo,
    Map<String, String>? datos,
  }) async {
    try {
      final dest = await _supabase
          .from('usuarios')
          .select('fcm_token')
          .eq('id', userId)
          .maybeSingle();

      if (dest == null) return;
      final token = dest['fcm_token'] as String?;
      if (token == null || token.isEmpty) return;

      await _supabase.functions.invoke(
        'send-notification',
        body: {
          'token': token,
          'title': titulo,
          'body': cuerpo,
          'data': datos ?? {},
        },
      );
      debugPrint('📤 Notificación enviada al usuario $userId: $titulo');
    } catch (e) {
      debugPrint('Error enviando notificación a usuario $userId: $e');
    }
  }

  // Wrapper para compatibilidad hacia atrás
  Future<void> notificarJefes({
    required String titulo,
    required String cuerpo,
    Map<String, String>? datos,
  }) async {
    await notificarPorRoles(
      roles: ['ventas', 'admin', 'jefe'],
      titulo: titulo,
      cuerpo: cuerpo,
      datos: datos,
    );
  }
}