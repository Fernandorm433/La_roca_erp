// Archivo: lib/screens/home/home_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';

// ── Módulos existentes ──────────────────────────────────────────
import '../dashboard/dashboard_page.dart';
import '../guias/guias_page.dart';
import '../programacion/programacion_page.dart';
import '../bombas/bombas_page.dart';
import '../calidad/calidad_page.dart';
import '../calidad/granulometria_page.dart';
import '../checklists/checklist_page.dart';
import '../auth/login_page.dart';

// ── Módulos Gestión ─────────────────────────────────────────────
import '../rrhh/recursos_humanos_page.dart';
import '../logistica/logistica_page.dart';
import '../comercial/comercial_page.dart';
import '../facturacion/facturacion_page.dart';
import '../mapa/mapa_page.dart';

// ── [NUEVO] Módulo de Costos ────────────────────────────────────
import '../costos/costos_page.dart';

// ── Módulos Ventas y Seguimiento ────────────────────────────────
import '../ventas/ventas_page.dart';
import '../ventas/asesores_page.dart';
import '../ventas/cotizaciones_list_page.dart';

// ── Módulos Empleados ──────────────────────────────────────────
import '../empleados/perfil_page.dart';
import '../empleados/comunicados_page.dart';

import 'dart:io';
import 'package:flutter_background_service/flutter_background_service.dart';

// ─────────────────────────────────────────────────────────────
// ENUMS Y MODELO
// ─────────────────────────────────────────────────────────────

enum RolUsuario {
  admin,
  programacion,
  calidad,
  ventas,
  asesor,
  operador, // Personal de planta / mixer
  empleados, // Personal administrativo general / otros
}

class AppMenuItem {
  final String titulo;
  final IconData icono;
  final Widget pagina;
  final String? seccion;

  AppMenuItem({
    required this.titulo,
    required this.icono,
    required this.pagina,
    this.seccion,
  });
}

// ─────────────────────────────────────────────────────────────
// HOME PAGE
// ─────────────────────────────────────────────────────────────

class HomePage extends StatefulWidget {
  final RolUsuario rol;
  final String nombreUsuario; // <--- Agregamos la variable

  const HomePage({super.key, required this.rol, required this.nombreUsuario});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int indiceActual = 0;
  late List<AppMenuItem> itemsPermitidos;

  @override
  void initState() {
    super.initState();
    print(
      "DEBUG: Entrando como ${widget.nombreUsuario} con rol: ${widget.rol.name}",
    );
    _configurarAccesos();
  }

  void _configurarAccesos() {
    // 1. CREAMOS LA LISTA BASE: Lo que todo empleado debe ver sí o sí.
    final modulosBaseEmpleado = [
      AppMenuItem(
        titulo: 'Mi Perfil',
        icono: Icons.person_outline,
        pagina: PerfilPage(
          nombre: widget.nombreUsuario,
          rol: widget.rol,
        ),
        seccion: 'MI ESPACIO',
      ),
      AppMenuItem(
        titulo: 'Comunicados',
        icono: Icons.campaign_outlined,
        pagina: const ComunicadosPage(),
      ),
    ];

    // 2. EVALUAMOS EL ROL Y SUMAMOS MÓDULOS
    switch (widget.rol) {
      // ─────────────────────────────────────────────────────────
      // ROL: EMPLEADOS — Solo ve Mi Perfil y Comunicados.
      // También aplica automáticamente a cualquier rol específico
      // (asesor, calidad, operador, etc.) gracias al spread
      // `...modulosBaseEmpleado` que todos los demás casos incluyen.
      // ─────────────────────────────────────────────────────────
      case RolUsuario.empleados:
        itemsPermitidos = [...modulosBaseEmpleado];
        break;

      // ─────────────────────────────────────────────────────────
      // ROL: ASESOR — Trabajo de campo: ve su propio seguimiento GPS.
      // Hereda automáticamente los módulos base de empleado.
      // ─────────────────────────────────────────────────────────
      case RolUsuario.asesor:
        itemsPermitidos = [
          ...modulosBaseEmpleado,
          AppMenuItem(
            titulo: 'Mi Seguimiento',
            icono: Icons.person_pin_circle_outlined,
            pagina: AsesoresPage(
              rol: widget.rol,
              nombreUsuario: widget.nombreUsuario,
            ),
            seccion: 'TRABAJO DE CAMPO',
          ),
          // 👇 AGREGAR AQUÍ 👇
          AppMenuItem(
            titulo: 'Cotizaciones',
            icono: Icons.request_quote_outlined,
            pagina: const CotizacionesListPage(),
          ),
        ];
        break;

      // ─────────────────────────────────────────────────────────
      // ROL: OPERADOR — Personal de planta/mixer.
      // Hereda automáticamente los módulos base de empleado.
      // ─────────────────────────────────────────────────────────
      case RolUsuario.operador:
        itemsPermitidos = [
          ...modulosBaseEmpleado,
          AppMenuItem(
            titulo: 'Checklists',
            icono: Icons.checklist_outlined,
            pagina: const ChecklistPage(),
            seccion: 'OPERACIONES',
          ),
        ];
        break;

      // ─────────────────────────────────────────────────────────
      // ROL: VENTAS — Jefatura de ventas.
      // Ve el panel global de ventas, el mapa de asesores y
      // [NUEVO] el módulo Comercial (gestión de clientes).
      // Hereda automáticamente los módulos base de empleado.
      // ─────────────────────────────────────────────────────────
      case RolUsuario.ventas:
        itemsPermitidos = [
          ...modulosBaseEmpleado,
          AppMenuItem(
            titulo: 'Ventas Global',
            icono: Icons.point_of_sale_outlined,
            pagina: const VentasPage(),
            seccion: 'JEFATURA DE VENTAS',
          ),
          AppMenuItem(
            titulo: 'Mapa Asesores',
            icono: Icons.person_pin_circle_outlined,
            pagina: AsesoresPage(
              rol: widget.rol,
              nombreUsuario: widget.nombreUsuario,
            ),
          ),
          // [NUEVO] Comercial: gestión de cartera de clientes
          AppMenuItem(
            titulo: 'Comercial',
            icono: Icons.business_center_outlined,
            pagina: const ComercialPage(),
          ),
          AppMenuItem(
            titulo: 'Cotizaciones',
            icono: Icons.request_quote_outlined,
            pagina: const CotizacionesListPage(),
          ),
        ];
        break;

      // ─────────────────────────────────────────────────────────
      // ROL: PROGRAMACION — Logística y operaciones de despacho.
      // Hereda automáticamente los módulos base de empleado.
      // ─────────────────────────────────────────────────────────
      case RolUsuario.programacion:
        itemsPermitidos = [
          ...modulosBaseEmpleado,
          AppMenuItem(
            titulo: 'GPS Flota',
            icono: Icons.satellite_alt_outlined,
            pagina: const MapaPage(),
            seccion: 'LOGÍSTICA',
          ),
          AppMenuItem(
            titulo: 'Guías',
            icono: Icons.description_outlined,
            pagina: const GuiasDespachoPage(),
          ),
          AppMenuItem(
            titulo: 'Prog.',
            icono: Icons.table_chart_outlined,
            pagina: const ProgramacionPage(),
          ),
          AppMenuItem(
            titulo: 'Bombas',
            icono: Icons.fire_truck_outlined,
            pagina: const GestorBombasPage(),
          ),
        ];
        break;

      // ─────────────────────────────────────────────────────────
      // ROL: CALIDAD — Laboratorio de control de calidad.
      // Hereda automáticamente los módulos base de empleado.
      // ─────────────────────────────────────────────────────────
      case RolUsuario.calidad:
        itemsPermitidos = [
          ...modulosBaseEmpleado,
          AppMenuItem(
            titulo: 'Dosificación',
            icono: Icons.history_edu,
            pagina: const ControlCalidadPage(),
            seccion: 'LABORATORIO',
          ),
          AppMenuItem(
            titulo: 'Granulometría',
            icono: Icons.grain,
            pagina: const GranulometriaPage(),
          ),
        ];
        break;

      // ─────────────────────────────────────────────────────────
      // ROL: ADMIN — Acceso total a todos los módulos del ERP.
      // Organizado por secciones: MI ESPACIO → GERENCIA →
      // VENTAS → OPERACIONES → CALIDAD → GESTIÓN
      //
      // Módulos nuevos añadidos respecto a la versión anterior:
      //   • Costos        (sección GERENCIA)
      //   • Comercial     (sección VENTAS)
      //   • Programación  (sección OPERACIONES)  ← antes solo estaba
      //   • Bombas        (sección OPERACIONES)     en rol programacion
      //   • Checklists    (sección OPERACIONES)  ← antes solo en operador
      //   • Granulometría (sección CALIDAD)      ← antes solo en calidad
      //   • Facturación   (sección GESTIÓN)      ← ya importado, ahora visible
      // ─────────────────────────────────────────────────────────
      case RolUsuario.admin:
      default:
        itemsPermitidos = [
          // ── MI ESPACIO ──────────────────────────────────────
          ...modulosBaseEmpleado,

          // ── GERENCIA ────────────────────────────────────────
          AppMenuItem(
            titulo: 'Dashboard',
            icono: Icons.analytics_outlined,
            pagina: const DashboardGerencial(),
            seccion: 'GERENCIA',
          ),
          AppMenuItem(
            titulo: 'GPS Flota',
            icono: Icons.satellite_alt_outlined,
            pagina: const MapaPage(),
          ),
          AppMenuItem(
            titulo: 'Guías',
            icono: Icons.description_outlined,
            pagina: const GuiasDespachoPage(),
          ),
          // [NUEVO] Costos: control de gastos y presupuestos
          AppMenuItem(
            titulo: 'Costos',
            icono: Icons.attach_money_rounded,
            pagina: const CostosPage(),
          ),
          

          // ── VENTAS ──────────────────────────────────────────
          AppMenuItem(
            titulo: 'Ventas',
            icono: Icons.point_of_sale_outlined,
            pagina: const VentasPage(),
            seccion: 'VENTAS',
          ),
          AppMenuItem(
            titulo: 'Asesores',
            icono: Icons.person_pin_circle_outlined,
            pagina: AsesoresPage(
              rol: widget.rol,
              nombreUsuario: widget.nombreUsuario,
            ),
          ),
          // [NUEVO] Comercial: CRM y gestión de cartera de clientes
          AppMenuItem(
            titulo: 'Comercial',
            icono: Icons.business_center_outlined,
            pagina: const ComercialPage(),
          ),
          AppMenuItem(
            titulo: 'Cotizaciones',
            icono: Icons.request_quote_outlined,
            pagina: const CotizacionesListPage(),
          ),

          // ── OPERACIONES ─────────────────────────────────────
          // [NUEVO] Programación: antes solo visible para rol programacion
          AppMenuItem(
            titulo: 'Programación',
            icono: Icons.table_chart_outlined,
            pagina: const ProgramacionPage(),
            seccion: 'OPERACIONES',
          ),
          // [NUEVO] Bombas: antes solo visible para rol programacion
          AppMenuItem(
            titulo: 'Bombas',
            icono: Icons.fire_truck_outlined,
            pagina: const GestorBombasPage(),
          ),
          // [NUEVO] Checklists: antes solo visible para rol operador
          AppMenuItem(
            titulo: 'Checklists',
            icono: Icons.checklist_outlined,
            pagina: const ChecklistPage(),
          ),

          // ── CALIDAD ─────────────────────────────────────────
          AppMenuItem(
            titulo: 'Dosificación',
            icono: Icons.history_edu,
            pagina: const ControlCalidadPage(),
            seccion: 'CALIDAD',
          ),
          // [NUEVO] Granulometría: antes solo visible para rol calidad
          AppMenuItem(
            titulo: 'Granulometría',
            icono: Icons.grain,
            pagina: const GranulometriaPage(),
          ),

          // ── GESTIÓN ─────────────────────────────────────────
          AppMenuItem(
            titulo: 'Logística',
            icono: Icons.local_shipping_outlined,
            pagina: const LogisticaPage(),
            seccion: 'GESTIÓN',
          ),
          AppMenuItem(
            titulo: 'RRHH',
            icono: Icons.people_outline,
            pagina: const RecursosHumanosPage(),
          ),
          // [NUEVO] Facturación: ya estaba importado pero no asignado a ningún rol
          AppMenuItem(
            titulo: 'Facturación',
            icono: Icons.receipt_long_outlined,
            pagina: const FacturacionPage(),
          ),
        ];
        break;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // CERRAR SESIÓN
  // ─────────────────────────────────────────────────────────────

  Future<void> _cerrarSesion(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro que deseas salir del ERP?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      // ✅ PASO 1: Detener el GPS en segundo plano antes de matar la sesión
      if (Platform.isAndroid || Platform.isIOS) {
        final service = FlutterBackgroundService();
        bool isRunning = await service.isRunning();
        if (isRunning) {
          service.invoke("stopService");
        }
      }
      
      // Le damos un respiro al Isolate para que se apague correctamente
      await Future.delayed(const Duration(milliseconds: 300));

      // ✅ PASO 2: Cerrar sesión en Supabase
      await Supabase.instance.client.auth.signOut();
      
      // ✅ PASO 3: Redirigir al Login
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // MENÚ EXTRA (móvil)
  // ─────────────────────────────────────────────────────────────

  void _mostrarMenuExtra(BuildContext context) {
    final itemsExtra = itemsPermitidos.sublist(3);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.80,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    Text(
                      'Módulos',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  shrinkWrap: true,
                  children: _buildMenuExtraItems(itemsExtra, context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMenuExtraItems(List<AppMenuItem> items, BuildContext ctx) {
    final widgets = <Widget>[];
    String? lastSeccion;

    for (int k = 0; k < items.length; k++) {
      final item = items[k];
      final realIndex = k + 3;

      if (item.seccion != null && item.seccion != lastSeccion) {
        if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 4));
        widgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Text(
              item.seccion!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade500,
                letterSpacing: 1.2,
              ),
            ),
          ),
        );
        lastSeccion = item.seccion;
      }

      final esSeleccionado = indiceActual == realIndex;
      widgets.add(
        Material(
          color: esSeleccionado
              ? AppColors.accent.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.pop(ctx);
              setState(() => indiceActual = realIndex);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: esSeleccionado
                          ? AppColors.accent.withOpacity(0.12)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      item.icono,
                      size: 20,
                      color: esSeleccionado
                          ? AppColors.accent
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    item.titulo,
                    style: TextStyle(
                      fontWeight: esSeleccionado
                          ? FontWeight.bold
                          : FontWeight.w600,
                      fontSize: 15,
                      color: esSeleccionado
                          ? AppColors.accent
                          : AppColors.primaryDark,
                    ),
                  ),
                  if (esSeleccionado) ...[
                    const Spacer(),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  // ─────────────────────────────────────────────────────────────
  // NAVIGATION DESTINATIONS (móvil)
  // ─────────────────────────────────────────────────────────────

  List<NavigationDestination> _construirDestinosMovil(bool necesitaMenuExtra) {
    if (!necesitaMenuExtra) {
      return itemsPermitidos
          .map(
            (item) => NavigationDestination(
              icon: Icon(item.icono),
              selectedIcon: Icon(item.icono, color: AppColors.accent),
              label: item.titulo,
            ),
          )
          .toList();
    }

    final dests = itemsPermitidos
        .take(3)
        .map(
          (item) => NavigationDestination(
            icon: Icon(item.icono),
            selectedIcon: Icon(item.icono, color: AppColors.accent),
            label: item.titulo,
          ),
        )
        .toList();

    dests.add(
      const NavigationDestination(
        icon: Icon(Icons.apps_outlined),
        selectedIcon: Icon(Icons.apps, color: AppColors.accent),
        label: 'Más',
      ),
    );
    return dests;
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final esEscritorio = MediaQuery.of(context).size.width >= 800;
    final esExtendido = MediaQuery.of(context).size.width >= 1100;
    final necesitaMenuExtra = itemsPermitidos.length > 4;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
          Image.asset('assets/images/LOGO2023.png',height: 30, // Altura del logo
          fit: BoxFit.contain,
        ),
],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.rol.name.toUpperCase(),
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.logout_outlined,
              color: Colors.redAccent,
              size: 20,
            ),
            tooltip: 'Cerrar Sesión',
            onPressed: () => _cerrarSesion(context),
          ),
          const SizedBox(width: 4),
        ],
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primaryDark,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: esEscritorio
            ? Row(
                children: [
                  _buildNavigationRail(esExtendido),
                  const VerticalDivider(
                    thickness: 1,
                    width: 1,
                    color: Colors.black12,
                  ),
                  Expanded(child: itemsPermitidos[indiceActual].pagina),
                ],
              )
            : itemsPermitidos[indiceActual].pagina,
      ),
      bottomNavigationBar: esEscritorio
          ? null
          : itemsPermitidos.length <= 1
          ? null
          : Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: NavigationBar(
                selectedIndex: necesitaMenuExtra && indiceActual >= 3
                    ? 3
                    : indiceActual,
                onDestinationSelected: (i) {
                  if (necesitaMenuExtra && i == 3) {
                    _mostrarMenuExtra(context);
                  } else {
                    setState(() => indiceActual = i);
                  }
                },
                backgroundColor: Colors.white,
                indicatorColor: AppColors.accent.withOpacity(0.1),
                destinations: _construirDestinosMovil(necesitaMenuExtra),
              ),
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // NAVIGATION RAIL con secciones visuales
  // ─────────────────────────────────────────────────────────────

  Widget _buildNavigationRail(bool extendido) {
    return SizedBox(
      width: extendido ? 220 : 72,
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            if (extendido)
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.business_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'La Roca',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(
                  vertical: extendido ? 0 : 8,
                  horizontal: 6,
                ),
                children: _buildRailItems(extendido),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRailItems(bool extendido) {
    final widgets = <Widget>[];
    String? lastSeccion;

    for (int i = 0; i < itemsPermitidos.length; i++) {
      final item = itemsPermitidos[i];
      final esSeleccionado = indiceActual == i;

      if (extendido && item.seccion != null && item.seccion != lastSeccion) {
        if (widgets.isNotEmpty) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
              child: Divider(color: Colors.grey.shade200, height: 1),
            ),
          );
        }
        widgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
            child: Text(
              item.seccion!,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade400,
                letterSpacing: 1.2,
              ),
            ),
          ),
        );
        lastSeccion = item.seccion;
      }

      widgets.add(
        Tooltip(
          message: extendido ? '' : item.titulo,
          preferBelow: false,
          child: Material(
            color: esSeleccionado
                ? AppColors.accent.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => indiceActual = i),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: extendido ? 12 : 0,
                  vertical: 10,
                ),
                child: extendido
                    ? Row(
                        children: [
                          Icon(
                            item.icono,
                            size: 20,
                            color: esSeleccionado
                                ? AppColors.accent
                                : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.titulo,
                              style: TextStyle(
                                fontWeight: esSeleccionado
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                fontSize: 14,
                                color: esSeleccionado
                                    ? AppColors.accent
                                    : AppColors.primaryDark,
                              ),
                            ),
                          ),
                          if (esSeleccionado)
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.icono,
                            size: 22,
                            color: esSeleccionado
                                ? AppColors.accent
                                : Colors.grey.shade600,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.titulo,
                            style: TextStyle(
                              fontSize: 9,
                              color: esSeleccionado
                                  ? AppColors.accent
                                  : Colors.grey.shade600,
                              fontWeight: esSeleccionado
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }
}