// Archivo: lib/screens/ventas/asesores_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../home/home_page.dart';
import 'vista_jefe_page.dart';
import 'vista_asesor_page.dart';

class AsesoresPage extends StatefulWidget {
  final RolUsuario rol;
  final String nombreUsuario;

  const AsesoresPage({
    super.key,
    required this.rol,
    required this.nombreUsuario,
  });

  @override
  State<AsesoresPage> createState() => _AsesoresPageState();
}

class _AsesoresPageState extends State<AsesoresPage> {
  late bool esVistaJefe;

  // Obtiene el ID del usuario logueado desde Supabase Auth.
  // Si el usuario no está autenticado, se usa el nombre como fallback.
  String get asesorId {
    final user = Supabase.instance.client.auth.currentUser;
    return user?.id ?? widget.nombreUsuario.toLowerCase().replaceAll(' ', '_');
  }

  @override
  void initState() {
    super.initState();
    esVistaJefe =
        widget.rol == RolUsuario.ventas || widget.rol == RolUsuario.admin;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              esVistaJefe
                  ? "Monitoreo de Fuerza de Ventas"
                  : "Mi Ruta y Visitas",
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              esVistaJefe
                  ? "Vista Gerencial — Tiempo Real"
                  : "Vista Asesor — GPS Activo",
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            ),
          ],
        ),
        // Badge de rol
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: esVistaJefe
                  ? AppColors.primaryDark.withOpacity(0.1)
                  : AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  esVistaJefe ? Icons.manage_accounts : Icons.badge_outlined,
                  size: 14,
                  color: esVistaJefe ? AppColors.primaryDark : AppColors.accent,
                ),
                const SizedBox(width: 6),
                Text(
                  esVistaJefe
                      ? 'Gerente'
                      : widget.nombreUsuario.split(' ').first,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: esVistaJefe
                        ? AppColors.primaryDark
                        : AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: esVistaJefe
            ? const VistaJefePage()
            : VistaAsesorPage(nombre: widget.nombreUsuario, asesorId: asesorId),
      ),
    );
  }
}
