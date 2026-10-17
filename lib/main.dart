// Archivo: lib/main.dart
import 'dart:io';
import 'dart:ui'; // Necesario para el servicio en segundo plano
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:app_database/core/services/notificacion_service.dart';
import 'core/utils/map_utils.dart';

// NUEVOS IMPORTS PARA EL GPS EN SEGUNDO PLANO Y FIRESTORE
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ← Agregado para escribir en Firebase

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'package:provider/provider.dart';
import 'core/theme/theme_provider.dart';
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
  await Supabase.initialize(
    url: "http://167.233.215.224:8000",
    anonKey:
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE",
  );

  // Intentar inicializar notificaciones capturando el error
  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('⚠️ Advertencia: No se pudieron inicializar las notificaciones. Detalle: $e');
  }

  // INICIALIZAR EL MOTOR DEL GPS EN SEGUNDO PLANO
  // (Solo se activa en móviles nativos Android/iOS, nunca en Web ni Desktop)
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await initializeService();
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
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
      initialNotificationContent: 'Optimizando logística de Novaconcret',
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

// Variables globales para el isolate del GPS (Geofencing)
String? _currentCarguioId;
Map<String, double>? _obraCoords;
bool _notifiedArrival = false;

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
    url: "http://167.233.215.224:8000",
    anonKey:
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE",
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

                // ✅ GEOFENCING: Verificar proximidad a la obra
                try {
                  final viajeActivo = await client
                      .from('carguios_mixers')
                      .select()
                      .eq('operador_id', user.id)
                      .eq('estado', 'Salio de Planta')
                      .maybeSingle();

                  if (viajeActivo != null) {
                     final carguioId = viajeActivo['id'].toString();
                     if (_currentCarguioId != carguioId) {
                        _currentCarguioId = carguioId;
                        _notifiedArrival = false;
                        _obraCoords = null;
                        
                        final venta = await client
                            .from('ventas_programacion')
                            .select('obra_maps_link')
                            .eq('id', viajeActivo['id_venta'])
                            .maybeSingle();
                        
                        if (venta != null && venta['obra_maps_link'] != null) {
                            _obraCoords = await MapUtils.extractCoordinates(venta['obra_maps_link'].toString());
                        }
                     }

                     if (!_notifiedArrival && _obraCoords != null) {
                        final distancia = Geolocator.distanceBetween(
                          position.latitude, position.longitude,
                          _obraCoords!['lat']!, _obraCoords!['lng']!
                        );
                        
                        if (distancia < 500) { // 500 metros
                          _notifiedArrival = true;
                          
                          FlutterLocalNotificationsPlugin().show(
                            889,
                            '📍 Llegando a Obra',
                            'Estás a menos de 500m del destino.',
                            const NotificationDetails(
                              android: AndroidNotificationDetails(
                                'gps_service', 'Geofencing',
                                importance: Importance.max, priority: Priority.high,
                                playSound: true,
                              ),
                            )
                          );
                        }
                     }
                  } else {
                     _currentCarguioId = null;
                  }
                } catch(e) {
                   debugPrint('Error Geofencing: $e');
                }

                if (service is AndroidServiceInstance) {
                  service.setForegroundNotificationInfo(
                    title: "Ruta Novaconcret: ${conductor['marca']}",
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
// 🔧 MODO DEMO — Cambia a true para saltar el login y probar pantallas
// Cambia el rol abajo para ver las diferentes vistas:
// admin, programacion, calidad, ventas, asesor, operador, empleados
// ─────────────────────────────────────────────────────────────────────────
const bool kModoDemo = false; // ← CAMBIA A false PARA VOLVER AL LOGIN REAL
const String kDemoRol = 'admin'; // ← CAMBIA EL ROL AQUÍ PARA PROBAR
const String kDemoNombre = 'Usuario Demo';

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "ERP NOVACONCRET",
      scrollBehavior: AppScrollBehavior(), // ✅ Habilita arrastrar con mouse en PC
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'ES')],
      themeMode: themeProvider.themeMode,
      theme: AppColors.lightTheme,
      darkTheme: AppColors.darkTheme,
      home: kModoDemo
          ? HomePage(
              rol: RolUsuario.values.firstWhere(
                (e) => e.name == kDemoRol,
                orElse: () => RolUsuario.admin,
              ),
              nombreUsuario: kDemoNombre,
            )
          : const AuthGate(),
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
            .maybeSingle();

        debugPrint("🔍 [AuthGate] Datos recibidos: $data");
        final String rolString = data?['rol'] ?? 'operador';
        final String nombreDB = data?['nombre'] ?? 'Usuario'; 

        final RolUsuario rolAsignado = _obtenerRolDesdeString(rolString);
 
        if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
          final service = FlutterBackgroundService();
          if (rolAsignado == RolUsuario.operador) {
            // Ya no usamos el GPS del celular para el operador (se usa Teltonika físico).
            // Apagamos el servicio por si quedó encendido.
            service.invoke("stopService");
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