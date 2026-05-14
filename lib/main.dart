// Archivo: lib/main.dart
import 'dart:io';
import 'dart:ui'; // Necesario para el servicio en segundo plano
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';
import 'package:app_database/core/services/notificacion_service.dart';

// NUEVOS IMPORTS PARA EL GPS EN SEGUNDO PLANO Y FIRESTORE
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ← Agregado para escribir en Firebase

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'core/theme/app_colors.dart';
import 'screens/home/home_page.dart';
import 'screens/auth/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // INICIALIZAR FIREBASE PRIMERO
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // INICIALIZAR SUPABASE DESPUÉS
  // INICIALIZAR SUPABASE DESPUÉS
  await Supabase.initialize(
    url: "https://rppchistprnodthwtuxt.supabase.co",
    anonKey:
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJwcGNoaXN0cHJub2R0aHd0dXh0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI2MzkzODIsImV4cCI6MjA4ODIxNTM4Mn0.w-6cx-VTGPs-y5rlLh48nrPlQtVoo2FMF6KwfH52YeE",
  );

  // Intentar inicializar notificaciones capturando el error
  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('⚠️ Advertencia: No se pudieron inicializar las notificaciones. Detalle: $e');
  }

  // INICIALIZAR EL MOTOR DEL GPS EN SEGUNDO PLANO
  // (Solo se activa en móviles, no en Windows/Mac)
  if (Platform.isAndroid || Platform.isIOS) {
    await initializeService();
  }

  runApp(const MyApp());
}

// ─────────────────────────────────────────────────────────────────────────
// LÓGICA DEL SERVICIO EN SEGUNDO PLANO (BACKGROUND SERVICE)
// ─────────────────────────────────────────────────────────────────────────

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'gps_service',
      initialNotificationTitle: 'Ruta Activa',
      initialNotificationContent: 'Optimizando logística de La Roca',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // ✅ INICIALIZAR FIREBASE EN ESTE HILO PARA USAR FIRESTORE
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // IMPORTANTE: El servicio corre en un hilo aislado, por lo que 
  // debemos inicializar Supabase de nuevo solo para este hilo.
  await Supabase.initialize(
    url: "https://rppchistprnodthwtuxt.supabase.co",
    anonKey:
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJwcGNoaXN0cHJub2R0aHd0dXh0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI2MzkzODIsImV4cCI6MjA4ODIxNTM4Mn0.w-6cx-VTGPs-y5rlLh48nrPlQtVoo2FMF6KwfH52YeE",
  );

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // RUTINA DE RASTREO
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (serviceEnabled) {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation, // ✅ Mejor precisión para vehículos
        distanceFilter: 2, // ✅ Envía a Firestore cada 2 metros
      );

      Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) async {
        final client = Supabase.instance.client;
        final user = client.auth.currentUser;

        if (user != null) {
          try {
            // Verificamos que sea un operador
            final userData = await client.from('usuarios').select('rol, nombre').eq('id', user.id).single();
            if (userData['rol'] == 'operador') {
              
              final conductor = await client.from('conductores').select('id, marca').eq('usuario_id', user.id).maybeSingle();

              if (conductor != null) {
                final conductorId = conductor['id'].toString();
                final double velocidadFiltrada = position.speed < 0.5 ? 0.0 : position.speed * 3.6;

                // ✅ ENVIAR A FIRESTORE (Como lo espera tu MapaPage)
                final docRef = FirebaseFirestore.instance.collection('operadores_gps').doc(conductorId);
                
                await docRef.set({
                  'lat': position.latitude,
                  'lng': position.longitude,
                  'speed_kmh': velocidadFiltrada,
                  'timestamp': FieldValue.serverTimestamp(),
                  'nombre': userData['nombre'] ?? '',
                  'placa': conductor['marca'] ?? '',
                  'conductor_id': conductorId,
                  'online': true,
                }, SetOptions(merge: true));

                if (service is AndroidServiceInstance) {
                  service.setForegroundNotificationInfo(
                    title: "Ruta La Roca: ${conductor['marca']}",
                    content: "Actualizando en tiempo real... (${velocidadFiltrada.toStringAsFixed(1)} km/h)",
                  );
                }
              }
            }
          } catch (e) {
            print('Error GPS Background: $e');
          }
        }
      });
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// RESTO DE TU APLICACIÓN (MyApp y AuthGate)
// ─────────────────────────────────────────────────────────────────────────

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "ERP Operaciones",
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'ES')],
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          background: AppColors.background,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: AppColors.primaryDark,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    _verificarSesion();
  }

  RolUsuario _obtenerRolDesdeString(String rolDB) {
    return RolUsuario.values.firstWhere(
      (e) => e.name == rolDB.toLowerCase(),
      orElse: () {
        debugPrint(
          '⚠️ Rol no reconocido: $rolDB. Asignando operador por defecto.',
        );
        return RolUsuario.operador;
      },
    );
  }

  Future<void> _verificarSesion() async {
    debugPrint("🔍 [AuthGate] Iniciando verificación...");
    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      debugPrint("🔍 [AuthGate] Sesión activa encontrada para: ${session.user.email}");
      try {
        debugPrint("🔍 [AuthGate] Intentando guardar token FCM...");
        NotificationService().guardarToken(session.user.id);

        debugPrint("🔍 [AuthGate] Consultando datos del usuario en la tabla 'usuarios'...");
        final data = await Supabase.instance.client
            .from('usuarios')
            .select('rol, nombre')
            .eq('id', session.user.id) 
            .single();

        debugPrint("🔍 [AuthGate] Datos recibidos: $data");
        final String rolString = data['rol'] ?? 'operador';
        final String nombreDB = data['nombre'] ?? 'Usuario'; 

        final RolUsuario rolAsignado = _obtenerRolDesdeString(rolString);
 
        if (Platform.isAndroid || Platform.isIOS) {
          final service = FlutterBackgroundService();
          if (rolAsignado == RolUsuario.operador) {
            // 🚨 SOLUCIÓN AL CRASHEO: Pedir permisos ANTES de iniciar el servicio
            LocationPermission permission = await Geolocator.checkPermission();
            if (permission == LocationPermission.denied) {
              permission = await Geolocator.requestPermission();
            }
            
            // Solo iniciamos si el usuario dio permiso
            if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
              bool isRunning = await service.isRunning();
              if (!isRunning) {
                await service.startService();
              }
            } else {
              debugPrint("⚠️ Permiso de ubicación denegado. No se puede rastrear.");
            }
          } else {
            // Si entra un admin, nos aseguramos de apagar el servicio
            service.invoke("stopService");
          }
        }

        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    HomePage(rol: rolAsignado, nombreUsuario: nombreDB),
              ),
            );
          });
        }
      } catch (e) {
        debugPrint("❌ [AuthGate] ERROR en verificación: $e");
        _irALogin();
      }
    } else {
      debugPrint("🔍 [AuthGate] No hay sesión. Yendo a Login...");
      _irALogin();
    }
  }

  void _irALogin() {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
    );
  }
}