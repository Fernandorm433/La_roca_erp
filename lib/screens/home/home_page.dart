// Archivo: lib/screens/home/home_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/theme/app_colors.dart';
import '../dashboard/dashboard_page.dart';
import '../guias/guias_main_page.dart';
import '../programacion/programacion_page.dart';
import '../bombas/bombas_page.dart';
import '../calidad/calidad_page.dart';
import '../calidad/granulometria_page.dart';
import '../checklists/checklist_page.dart';
import '../auth/login_page.dart';
import '../rrhh/recursos_humanos_page.dart';
import '../logistica/logistica_page.dart';
import '../comercial/comercial_page.dart';
import '../facturacion/facturacion_page.dart';
import '../mapa/mapa_page.dart';
import '../comercial/liquidaciones_page.dart';
import '../costos/costos_page.dart';
import '../tesoreria/tesoreria_page.dart';
import '../logistica/gestor_mixers_page.dart';
import '../planta/mis_carguios_page.dart';
import '../ventas/ventas_page.dart';
import '../ventas/asesores_page.dart';
import '../ventas/cotizaciones_page.dart';
import '../ventas/requerimientos_list_page.dart';
import '../ventas/ordenes_pedido_page.dart';
import '../calidad/disenos_mezcla_page.dart';
import '../calidad/registro_carguio_page.dart';
import '../clientes/clientes_page.dart';
import '../empleados/perfil_page.dart';
import '../empleados/comunicados_page.dart';

import '../gestion/control_cochera_page.dart';
import '../gestion/control_combustible_page.dart';

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
import '../comercial/liquidaciones_page.dart';

// ── [NUEVO] Módulo de Costos ────────────────────────────────────
import '../costos/costos_page.dart';

// ── [NUEVO] Módulo de Tesorería ─────────────────────────────────
import '../tesoreria/tesoreria_page.dart';

// ── [NUEVO] Módulo de Carguíos (Mixers) ───────────────────────
import '../logistica/gestor_mixers_page.dart';
import '../planta/mis_carguios_page.dart';

// ── Módulos Ventas y Seguimiento ────────────────────────────────
import '../ventas/ventas_page.dart';
import '../ventas/asesores_page.dart';
import '../ventas/cotizaciones_page.dart';
import '../ventas/requerimientos_list_page.dart'; // <-- [NUEVO]
import '../ventas/ordenes_pedido_page.dart'; // <-- [NUEVO] Órdenes de pedido externas
// ── [NUEVO] Módulo Diseños de Mezcla y Registro Carguío ─────────
import '../calidad/disenos_mezcla_page.dart';
import '../calidad/registro_carguio_page.dart';

// ── [NUEVO] Módulo de Clientes ──────────────────────────────────
import '../clientes/clientes_page.dart';

// ── Módulos Empleados ──────────────────────────────────────────
import '../empleados/perfil_page.dart';
import '../empleados/comunicados_page.dart';

import 'dart:io';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../../core/services/gps_service.dart'; // ← [NUEVO] GPS Service

// ─────────────────────────────────────────────────────────────
// ENUMS Y MODELO
// ─────────────────────────────────────────────────────────────

enum RolUsuario {
  admin,
  rrhh,
  programacion,
  calidad,
  ventas,
  asesor,
  operador, // Personal de planta / mixer
  jefe_operadores, // Jefe de operadores
  empleados, // Personal administrativo general / otros
  produccion, // Personal de planta/produccion
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
    
    // Inicializar el motor de rastreo en primer plano + historial (si es operador)
    if (widget.rol == RolUsuario.operador) {
      GpsService().inicializarRastreoSiEsOperador();
    }
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
      // ─────────────────────────────────────────────────────────
      // ROL: PRODUCCIÓN — Personal de planta/produccion.
      // ─────────────────────────────────────────────────────────
      case RolUsuario.produccion:
        itemsPermitidos = [
          ...modulosBaseEmpleado,
          AppMenuItem(
            titulo: 'Registro de Carguío',
            icono: Icons.app_registration,
            pagina: const RegistroCarguioPage(),
          ),
        ];
        break;

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
            pagina: const CotizacionesPage(),
          ),
          AppMenuItem(
            titulo: 'Requerimientos',
            icono: Icons.precision_manufacturing_outlined,
            pagina: const RequerimientosListPage(),
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
            titulo: 'Mis Carguíos',
            icono: Icons.local_shipping_outlined,
            pagina: const MisCarguiosPage(),
            seccion: 'OPERACIONES',
          ),
          AppMenuItem(
            titulo: 'Checklists',
            icono: Icons.checklist_outlined,
            pagina: const ChecklistPage(),
          ),
        ];
        break;

      // ─────────────────────────────────────────────────────────
      // ROL: JEFE DE OPERADORES
      // ─────────────────────────────────────────────────────────
      case RolUsuario.jefe_operadores:
        itemsPermitidos = [
          ...modulosBaseEmpleado,
          AppMenuItem(
            titulo: 'GPS Flota',
            icono: Icons.satellite_alt_outlined,
            pagina: const MapaPage(),
            seccion: 'OPERACIONES',
          ),
          AppMenuItem(
            titulo: 'Despachos',
            icono: Icons.local_shipping_outlined,
            pagina: const GestorMixersPage(),
          ),
          AppMenuItem(
            titulo: 'Registro de Carguío',
            icono: Icons.app_registration,
            pagina: const RegistroCarguioPage(),
          ),
          AppMenuItem(
            titulo: 'Bombas',
            icono: Icons.fire_truck_outlined,
            pagina: const GestorBombasPage(),
          ),
          AppMenuItem(
            titulo: 'Prog.',
            icono: Icons.table_chart_outlined,
            pagina: const ProgramacionPage(),
          ),
          AppMenuItem(
            titulo: 'Guías',
            icono: Icons.description_outlined,
            pagina: const GuiasMainPage(),
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
            titulo: 'Clientes',
            icono: Icons.people_alt_outlined,
            pagina: const ClientesPage(),
          ),
          AppMenuItem(
            titulo: 'Cotizaciones',
            icono: Icons.request_quote_outlined,
            pagina: const CotizacionesPage(),
          ),
          AppMenuItem(
            titulo: 'Requerimientos',
            icono: Icons.precision_manufacturing_outlined,
            pagina: const RequerimientosListPage(),
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
            pagina: const GuiasMainPage(),
          ),
          AppMenuItem(
            titulo: 'Prog.',
            icono: Icons.table_chart_outlined,
            pagina: const ProgramacionPage(),
          ),
          AppMenuItem(
            titulo: 'Requerimientos',
            icono: Icons.precision_manufacturing_outlined,
            pagina: const RequerimientosListPage(),
          ),
          AppMenuItem(
            titulo: 'Bombas',
            icono: Icons.fire_truck_outlined,
            pagina: const GestorBombasPage(),
          ),
          AppMenuItem(
            titulo: 'Despachos',
            icono: Icons.local_shipping_outlined,
            pagina: const GestorMixersPage(),
          ),
          AppMenuItem(
            titulo: 'Registro de Carguío',
            icono: Icons.app_registration,
            pagina: const RegistroCarguioPage(),
          ),
          AppMenuItem(
            titulo: 'Liquidaciones',
            icono: Icons.account_balance_wallet_outlined,
            pagina: const LiquidacionesPage(),
            seccion: 'GESTIÓN',
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
            titulo: 'Diseños de Mezcla',
            icono: Icons.science_outlined,
            pagina: const DisenosMezclaPage(),
          ),
          AppMenuItem(
            titulo: 'Registro de Carguío',
            icono: Icons.app_registration,
            pagina: const RegistroCarguioPage(),
          ),
          AppMenuItem(
            titulo: 'Granulometría',
            icono: Icons.grain,
            pagina: const GranulometriaPage(),
          ),
        ];
        break;

      //   • Checklists    (sección OPERACIONES)  ← antes solo en operador
      //   • Granulometría (sección CALIDAD)      ← antes solo en calidad
      //   • Facturación   (sección GESTIÓN)      ← ya importado, ahora visible
      //   • Control Cochera y Combustible (sección GESTIÓN)
      // ─────────────────────────────────────────────────────────
      case RolUsuario.admin:
        itemsPermitidos = [
          ...modulosBaseEmpleado,
          // MI ESPACIO
          AppMenuItem(
            titulo: 'GPS Flota',
            icono: Icons.satellite_alt_outlined,
            pagina: const MapaPage(),
            seccion: 'MI ESPACIO',
          ),
          
          // GERENCIA
          AppMenuItem(
            titulo: 'Dashboard',
            icono: Icons.dashboard_outlined,
            pagina: const DashboardGerencial(),
            seccion: 'GERENCIA',
          ),
          AppMenuItem(
            titulo: 'Costos Generales',
            icono: Icons.payments_outlined,
            pagina: const CostosPage(),
          ),
          
          // VENTAS
          AppMenuItem(
            titulo: 'Comercial',
            icono: Icons.storefront_outlined,
            pagina: const ComercialPage(),
            seccion: 'VENTAS',
          ),
          AppMenuItem(
            titulo: 'Clientes',
            icono: Icons.people_outline,
            pagina: const ClientesPage(),
          ),
          AppMenuItem(
            titulo: 'Cotizaciones',
            icono: Icons.request_quote_outlined,
            pagina: const CotizacionesPage(),
          ),
          AppMenuItem(
            titulo: 'Requerimientos',
            icono: Icons.precision_manufacturing_outlined,
            pagina: const RequerimientosListPage(),
          ),
          
          // OPERACIONES
          AppMenuItem(
            titulo: 'Programación',
            icono: Icons.table_chart_outlined,
            pagina: const ProgramacionPage(),
            seccion: 'OPERACIONES',
          ),
          AppMenuItem(
            titulo: 'Bombas',
            icono: Icons.fire_truck_outlined,
            pagina: const GestorBombasPage(),
          ),
          AppMenuItem(
            titulo: 'Despachos',
            icono: Icons.local_shipping_outlined,
            pagina: const GestorMixersPage(),
          ),
          AppMenuItem(
            titulo: 'Checklists',
            icono: Icons.fact_check_outlined,
            pagina: const ChecklistPage(),
          ),
          
          // CALIDAD
          AppMenuItem(
            titulo: 'Dosificación',
            icono: Icons.history_edu,
            pagina: const ControlCalidadPage(),
            seccion: 'CALIDAD',
          ),
          AppMenuItem(
            titulo: 'Diseños de Mezcla',
            icono: Icons.science_outlined,
            pagina: const DisenosMezclaPage(),
          ),
          AppMenuItem(
            titulo: 'Registro de Carguío',
            icono: Icons.app_registration,
            pagina: const RegistroCarguioPage(),
          ),
          AppMenuItem(
            titulo: 'Granulometría',
            icono: Icons.grain,
            pagina: const GranulometriaPage(),
          ),
          
          // GESTIÓN
          AppMenuItem(
            titulo: 'Logística',
            icono: Icons.local_shipping_outlined,
            pagina: const LogisticaPage(),
            seccion: 'GESTIÓN',
          ),
          AppMenuItem(
            titulo: 'RRHH',
            icono: Icons.people_alt_outlined,
            pagina: const RecursosHumanosPage(),
          ),
          AppMenuItem(
            titulo: 'Facturación',
            icono: Icons.receipt_long_outlined,
            pagina: const FacturacionPage(),
          ),
          AppMenuItem(
            titulo: 'Liquidaciones',
            icono: Icons.account_balance_wallet_outlined,
            pagina: const LiquidacionesPage(),
          ),
          AppMenuItem(
            titulo: 'Control de Cochera',
            icono: Icons.garage_outlined,
            pagina: const ControlCocheraPage(),
          ),
          AppMenuItem(
            titulo: 'Control Combustible',
            icono: Icons.local_gas_station_outlined,
            pagina: const ControlCombustiblePage(),
          ),
        ];
        break;
      case RolUsuario.rrhh:
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
            pagina: const GuiasMainPage(),
          ),
          // [NUEVO] Órdenes de Pedido (externas)
          AppMenuItem(
            titulo: 'Órdenes de Pedido',
            icono: Icons.list_alt_rounded,
            pagina: const OrdenesPedidoPage(),
          ),
          // [NUEVO] Costos: control de gastos y presupuestos
          AppMenuItem(
            titulo: 'Costos',
            icono: Icons.attach_money_rounded,
            pagina: const CostosPage(),
          ),
          // [NUEVO] Tesorería: control financiero, legal, caja chica
          AppMenuItem(
            titulo: 'Tesorería',
            icono: Icons.account_balance_outlined,
            pagina: const TesoreriaPage(),
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
            titulo: 'Clientes',
            icono: Icons.people_alt_outlined,
            pagina: const ClientesPage(),
          ),
          AppMenuItem(
            titulo: 'Cotizaciones',
            icono: Icons.request_quote_outlined,
            pagina: const CotizacionesPage(),
          ),
          AppMenuItem(
            titulo: 'Requerimientos',
            icono: Icons.precision_manufacturing_outlined,
            pagina: const RequerimientosListPage(),
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
          AppMenuItem(
            titulo: 'Despachos',
            icono: Icons.local_shipping_outlined,
            pagina: const GestorMixersPage(),
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
          AppMenuItem(
            titulo: 'Diseños de Mezcla',
            icono: Icons.science_outlined,
            pagina: const DisenosMezclaPage(),
          ),
          AppMenuItem(
            titulo: 'Registro de Carguío',
            icono: Icons.app_registration,
            pagina: const RegistroCarguioPage(),
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
          AppMenuItem(
            titulo: 'Liquidaciones',
            icono: Icons.account_balance_wallet_outlined,
            pagina: const LiquidacionesPage(),
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
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                          : Theme.of(context).textTheme.bodyLarge?.color,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Colores dinámicos
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final sidebarColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final sidebarTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final sidebarIconColor = isDark ? Colors.blueGrey.shade300 : Colors.blueGrey.shade700;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // TOP HEADER CUSTOMIZADO (Ultra Premium)
            Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: sidebarColor,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))
                ]
              ),
              child: Row(
                children: [
                  if (!esEscritorio)
                    Image.asset('assets/images/LOGO2023.png', height: 32, fit: BoxFit.contain)
                  else
                    const SizedBox.shrink(),
                  const Spacer(),
                  
                  // Role Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.2))
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined, size: 14, color: AppColors.accent),
                        const SizedBox(width: 6),
                        Text(
                          widget.rol.name.toUpperCase(),
                          style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Theme Toggle
                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, child) {
                      return InkWell(
                        onTap: () => themeProvider.toggleTheme(!themeProvider.isDarkMode),
                        borderRadius: BorderRadius.circular(50),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade200),
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50
                          ),
                          child: Icon(
                            themeProvider.isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                            color: themeProvider.isDarkMode ? Colors.yellow.shade600 : AppColors.primaryDark,
                            size: 20,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  
                  // Logout
                  InkWell(
                    onTap: () => _cerrarSesion(context),
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.withValues(alpha: 0.05),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.1))
                      ),
                      child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            
            // CONTENIDO PRINCIPAL
            Expanded(
              child: Row(
                children: [
                  if (esEscritorio)
                    _buildCustomNavigationRail(esExtendido, sidebarColor, sidebarTextColor, sidebarIconColor),
                  
                  Expanded(
                    child: ClipRRect(
                      borderRadius: esEscritorio ? const BorderRadius.only(topLeft: Radius.circular(20)) : BorderRadius.zero,
                      child: Container(
                        color: bgColor,
                        child: itemsPermitidos[indiceActual].pagina,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: esEscritorio || itemsPermitidos.length <= 1
          ? null
          : _buildFloatingBottomBar(necesitaMenuExtra),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FLOATING BOTTOM BAR (Móvil)
  // ─────────────────────────────────────────────────────────────
  Widget _buildFloatingBottomBar(bool necesitaMenuExtra) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      color: Colors.transparent, // Flotante real
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: NavigationBar(
            height: 65,
            elevation: 0,
            backgroundColor: Colors.transparent,
            indicatorColor: AppColors.accent.withValues(alpha: 0.15),
            selectedIndex: necesitaMenuExtra && indiceActual >= 3 ? 3 : indiceActual,
            onDestinationSelected: (i) {
              if (necesitaMenuExtra && i == 3) {
                _mostrarMenuExtra(context);
              } else {
                setState(() => indiceActual = i);
              }
            },
            destinations: _construirDestinosMovil(necesitaMenuExtra),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CUSTOM NAVIGATION RAIL (PC)
  // ─────────────────────────────────────────────────────────────
  Widget _buildCustomNavigationRail(bool extendido, Color bgColor, Color textColor, Color iconColor) {
    return Container(
      width: extendido ? 240 : 80,
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 15, offset: const Offset(5, 0))
        ]
      ),
      child: Column(
        children: [
          if (extendido)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              alignment: Alignment.centerLeft,
              child: Image.asset(
                'assets/images/LOGO2023.png',
                height: 40,
                width: 170, // Constraints para evitar overflow
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
              ),
            )
          else 
            const SizedBox(height: 24),
            
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(vertical: extendido ? 8 : 12, horizontal: 16),
              physics: const BouncingScrollPhysics(),
              children: _buildCustomRailItems(extendido, textColor, iconColor),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCustomRailItems(bool extendido, Color textColor, Color iconColor) {
    final widgets = <Widget>[];
    String? lastSeccion;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    for (int i = 0; i < itemsPermitidos.length; i++) {
      final item = itemsPermitidos[i];
      final esSeleccionado = indiceActual == i;

      if (extendido && item.seccion != null && item.seccion != lastSeccion) {
        if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 16));
        widgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Text(
              item.seccion!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.blueGrey.shade400 : Colors.blueGrey.shade300,
                letterSpacing: 1.5,
              ),
            ),
          ),
        );
        lastSeccion = item.seccion;
      }

      final colorHover = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03);
      final colorSelectedBg = isDark ? AppColors.accent.withValues(alpha: 0.15) : AppColors.accent.withValues(alpha: 0.1);

      widgets.add(
        Tooltip(
          message: extendido ? '' : item.titulo,
          preferBelow: false,
          child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            child: Material(
              color: esSeleccionado ? colorSelectedBg : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                hoverColor: colorHover,
                onTap: () => setState(() => indiceActual = i),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: extendido ? 12 : 0, vertical: extendido ? 12 : 14),
                  child: extendido
                      ? Row(
                          children: [
                            Icon(item.icono, size: 22, color: esSeleccionado ? AppColors.accent : iconColor),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                item.titulo,
                                style: TextStyle(
                                  fontWeight: esSeleccionado ? FontWeight.w800 : FontWeight.w600,
                                  fontSize: 14,
                                  color: esSeleccionado ? AppColors.accent : textColor.withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(item.icono, size: 24, color: esSeleccionado ? AppColors.accent : iconColor),
                            const SizedBox(height: 6),
                            Text(
                              item.titulo,
                              style: TextStyle(
                                fontSize: 9,
                                color: esSeleccionado ? AppColors.accent : iconColor,
                                fontWeight: esSeleccionado ? FontWeight.bold : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
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