// Archivo: lib/screens/auth/login_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// 👉 1. NUEVO IMPORT PARA FIREBASE MESSAGING
import 'package:firebase_messaging/firebase_messaging.dart'; 

import '../../core/theme/app_colors.dart';
import '../home/home_page.dart';
import 'change_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

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
            .select('rol, nombre, requiere_cambio_password')
            .eq('id', user.id) 
            .maybeSingle();

        final String rolString = data?['rol'] ?? 'operador';
        final String nombreDB = data?['nombre'] ?? 'Usuario';
        final bool requiereCambio = data?['requiere_cambio_password'] ?? false;

        final RolUsuario rolAsignado = _obtenerRolDesdeString(rolString);

        if (mounted) {
          if (requiereCambio) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ChangePasswordPage(
                  rolAsignado: rolAsignado,
                  nombreUsuario: nombreDB,
                ),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    HomePage(rol: rolAsignado, nombreUsuario: nombreDB),
              ),
            );
          }
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
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.greyBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Image.asset(
                    'assets/images/LOGO_NOVA.png',
                    height: 140,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset(
                        'assets/images/logo.png',
                        height: 140,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/LOGO_NOVA.png',
                          height: 140,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.local_shipping_rounded,
                            size: 100,
                            color: AppColors.primary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'NOVACON ERP',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24, 
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sistema Integral de Gestión Concretera',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13, 
                    color: AppColors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 36),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Correo Electrónico',
                    labelStyle: const TextStyle(color: AppColors.grey),
                    prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primary),
                    filled: true,
                    fillColor: AppColors.greyLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.greyBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.greyBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.accent, width: 2),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onSubmitted: (_) => _iniciarSesion(),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    labelStyle: const TextStyle(color: AppColors.grey),
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary),
                    filled: true,
                    fillColor: AppColors.greyLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.greyBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.greyBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.accent, width: 2),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                  onSubmitted: (_) => _iniciarSesion(),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _iniciarSesion,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    shadowColor: AppColors.primary.withValues(alpha: 0.3),
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
                      : const Text(
                          'Ingresar al Sistema', 
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}