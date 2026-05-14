// Archivo: lib/screens/auth/login_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// 👉 1. NUEVO IMPORT PARA FIREBASE MESSAGING
import 'package:firebase_messaging/firebase_messaging.dart'; 

import '../../core/theme/app_colors.dart';
import '../home/home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  final supabase = Supabase.instance.client;

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

  // 👉 2. NUEVA FUNCIÓN: Captura y guarda el Token FCM en Supabase
  Future<void> _registrarTokenDispositivo() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return; 

      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? fcmToken = await messaging.getToken();

        if (fcmToken != null) {
          await supabase
              .from('usuarios')
              .update({'fcm_token': fcmToken})
              .eq('id', user.id);
              
          debugPrint('✅ Token FCM guardado con éxito: $fcmToken');
        }
      } else {
        debugPrint('⚠️ El usuario denegó los permisos de notificación.');
      }
    } catch (e) {
      debugPrint('❌ Error al guardar el Token FCM: $e');
    }
  }

  Future<void> _iniciarSesion() async {
    setState(() => _isLoading = true);

    try {
      final AuthResponse res = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = res.user;

      if (user != null) {
        // 👉 3. LLAMADA A LA FUNCIÓN AQUÍ (Antes de redirigir al Home)
        await _registrarTokenDispositivo();

        final data = await supabase
            .from('usuarios')
            .select('rol, nombre')
            .eq('id', user.id) 
            .single();

        final String rolString = data['rol'] ?? 'operador';
        final String nombreDB = data['nombre'] ?? 'Usuario';

        final RolUsuario rolAsignado = _obtenerRolDesdeString(rolString);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  HomePage(rol: rolAsignado, nombreUsuario: nombreDB),
            ),
          );
        }
      }
    } on AuthException catch (e) {
      _mostrarError(e.message);
    } catch (e) {
      _mostrarError('Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  'assets/images/LOGO2023.png',
                  height: 120,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.fire_truck,
                      size: 80,
                      color: AppColors.accent,
                    );
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'Bienvenido al ERP',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Correo Electrónico',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _iniciarSesion,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Ingresar', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}