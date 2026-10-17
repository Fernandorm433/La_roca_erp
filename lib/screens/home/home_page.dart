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
import '../ventas/cotizaciones_list_page.dart';
import '../ventas/requerimientos_list_page.dart';
import '../ventas/ordenes_pedido_page.dart';
import '../calidad/disenos_mezcla_page.dart';
import '../calidad/registro_carguio_page.dart';
import '../calidad/historial_carguios_page.dart';
import '../calidad/formulario_probetas_page.dart';
import '../calidad/control_calidad_probetas_page.dart';
import '../calidad/certificados_calidad_page.dart';
import '../clientes/clientes_page.dart';
import '../empleados/perfil_page.dart';
import '../empleados/comunicados_page.dart';

import '../gestion/control_cochera_page.dart';
import '../gestion/control_combustible_page.dart';



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
  logistica,
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

  Future<void> _configurarAccesos() async {
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
          AppMenuItem(
            titulo: 'Historial de Carguíos',
            icono: Icons.history,
            pagina: const HistorialCarguiosPage(),
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
            pagina: CotizacionesListPage(
              rol: widget.rol,
              nombreUsuario: widget.nombreUsuario,
            ),
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
            pagina: CotizacionesListPage(
              rol: widget.rol,
              nombreUsuario: widget.nombreUsuario,
            ),
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
        ];
        break;

      // ─────────────────────────────────────────────────────────
      // ROL: LOGÍSTICA — Liquidaciones y control.
      // ─────────────────────────────────────────────────────────
      case RolUsuario.logistica:
        itemsPermitidos = [
          ...modulosBaseEmpleado,
          AppMenuItem(
            titulo: 'Logística',
            icono: Icons.local_shipping_outlined,
            pagina: const LogisticaPage(),
            seccion: 'GESTIÓN',
          ),
          AppMenuItem(
            titulo: 'Liquidaciones',
            icono: Icons.account_balance_wallet_outlined,
            pagina: const LiquidacionesPage(),
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
            titulo: 'Historial de Carguíos',
            icono: Icons.history,
            pagina: const HistorialCarguiosPage(),
          ),
          AppMenuItem(
            titulo: 'Granulometría',
            icono: Icons.grain,
            pagina: const GranulometriaPage(),
          ),
          AppMenuItem(
            titulo: 'Control de Calidad',
            icono: Icons.analytics_outlined,
            pagina: const ControlCalidadProbetasPage(),
          ),
          AppMenuItem(
            titulo: 'Formulario de Probetas',
            icono: Icons.assignment_outlined,
            pagina: const FormularioProbetasPage(),
          ),
          AppMenuItem(
            titulo: 'Certificados',
            icono: Icons.verified_outlined,
            pagina: const CertificadosCalidadPage(),
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
            pagina: CotizacionesListPage(
              rol: widget.rol,
              nombreUsuario: widget.nombreUsuario,
            ),
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
            titulo: 'Historial de Carguíos',
            icono: Icons.history,
            pagina: const HistorialCarguiosPage(),
          ),
          AppMenuItem(
            titulo: 'Granulometría',
            icono: Icons.grain,
            pagina: const GranulometriaPage(),
          ),
          AppMenuItem(
            titulo: 'Control de Calidad',
            icono: Icons.analytics_outlined,
            pagina: const ControlCalidadProbetasPage(),
          ),
          AppMenuItem(
            titulo: 'Formulario de Probetas',
            icono: Icons.assignment_outlined,
            pagina: const FormularioProbetasPage(),
          ),
          AppMenuItem(
            titulo: 'Certificados',
            icono: Icons.verified_outlined,
            pagina: const CertificadosCalidadPage(),
          ),
          
          // GESTIÓN
          AppMenuItem(
            titulo: 'Logística',
            icono: Icons.local_shipping_outlined,
            pagina: const LogisticaPage(),
            seccion: 'GESTIÓN',
          ),
          AppMenuItem(
            titulo: 'Guías',
            icono: Icons.description_outlined,
            pagina: const GuiasMainPage(),
          ),
          AppMenuItem(
            titulo: 'RRHH',
            icono: Icons.people_alt_outlined,
            pagina: const RecursosHumanosPage(),
          ),
          AppMenuItem(
            titulo: 'Tesorería',
            icono: Icons.account_balance_outlined,
            pagina: const TesoreriaPage(),
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
            pagina: CotizacionesListPage(
              rol: widget.rol,
              nombreUsuario: widget.nombreUsuario,
            ),
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
          AppMenuItem(
            titulo: 'Control de Calidad',
            icono: Icons.analytics_outlined,
            pagina: const ControlCalidadProbetasPage(),
          ),
          AppMenuItem(
            titulo: 'Formulario de Probetas',
            icono: Icons.assignment_outlined,
            pagina: const FormularioProbetasPage(),
          ),
          AppMenuItem(
            titulo: 'Certificados',
            icono: Icons.verified_outlined,
            pagina: const CertificadosCalidadPage(),
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

    // 3. AGREGAR MÓDULOS EXTRA POR PERMISOS DE PANTALLAS
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final data = await Supabase.instance.client.from('permisos_pantallas').select();
        List<AppMenuItem> extraItems = [];
        
        final modulosMap = {
          'dashboard': AppMenuItem(titulo: 'Dashboard', icono: Icons.analytics_outlined, pagina: const DashboardGerencial(), seccion: 'EXTRAS'),
          'ventas': AppMenuItem(titulo: 'Ventas y Seguimiento', icono: Icons.point_of_sale_outlined, pagina: const VentasPage(), seccion: 'EXTRAS'),
          'asesores': AppMenuItem(titulo: 'Asesores', icono: Icons.person_pin_circle_outlined, pagina: AsesoresPage(rol: widget.rol, nombreUsuario: widget.nombreUsuario), seccion: 'EXTRAS'),
          'comercial': AppMenuItem(titulo: 'Comercial', icono: Icons.business_center_outlined, pagina: const ComercialPage(), seccion: 'EXTRAS'),
          'cotizaciones': AppMenuItem(titulo: 'Cotizaciones', icono: Icons.request_quote_outlined, pagina: CotizacionesListPage(rol: widget.rol, nombreUsuario: widget.nombreUsuario), seccion: 'EXTRAS'),
          'requerimientos': AppMenuItem(titulo: 'Requerimientos', icono: Icons.precision_manufacturing_outlined, pagina: const RequerimientosListPage(), seccion: 'EXTRAS'),
          'ordenes_pedido': AppMenuItem(titulo: 'Órdenes de Pedido', icono: Icons.list_alt_rounded, pagina: const OrdenesPedidoPage(), seccion: 'EXTRAS'),
          'clientes': AppMenuItem(titulo: 'Directorio Clientes', icono: Icons.people_alt_outlined, pagina: const ClientesPage(), seccion: 'EXTRAS'),
          'programacion': AppMenuItem(titulo: 'Programación', icono: Icons.table_chart_outlined, pagina: const ProgramacionPage(), seccion: 'EXTRAS'),
          'bombas': AppMenuItem(titulo: 'Bombas', icono: Icons.fire_truck_outlined, pagina: const GestorBombasPage(), seccion: 'EXTRAS'),
          'despachos': AppMenuItem(titulo: 'Gestor Mixers (Despachos)', icono: Icons.local_shipping_outlined, pagina: const GestorMixersPage(), seccion: 'EXTRAS'),
          'mis_carguios': AppMenuItem(titulo: 'Mis Carguíos', icono: Icons.local_shipping_outlined, pagina: const MisCarguiosPage(), seccion: 'EXTRAS'),
          'checklist': AppMenuItem(titulo: 'Checklists', icono: Icons.checklist_outlined, pagina: const ChecklistPage(), seccion: 'EXTRAS'),
          'registro_carguio': AppMenuItem(titulo: 'Registro de Carguío', icono: Icons.app_registration, pagina: const RegistroCarguioPage(), seccion: 'EXTRAS'),
          'dosificacion': AppMenuItem(titulo: 'Dosificación', icono: Icons.history_edu, pagina: const ControlCalidadPage(), seccion: 'EXTRAS'),
          'disenos_mezcla': AppMenuItem(titulo: 'Diseños de Mezcla', icono: Icons.science_outlined, pagina: const DisenosMezclaPage(), seccion: 'EXTRAS'),
          'granulometria': AppMenuItem(titulo: 'Granulometría', icono: Icons.grain, pagina: const GranulometriaPage(), seccion: 'EXTRAS'),
          'control_calidad_probetas': AppMenuItem(titulo: 'Control de Calidad', icono: Icons.analytics_outlined, pagina: const ControlCalidadProbetasPage(), seccion: 'EXTRAS'),
          'formulario_probetas': AppMenuItem(titulo: 'Formulario de Probetas', icono: Icons.assignment_outlined, pagina: const FormularioProbetasPage(), seccion: 'EXTRAS'),
          'certificados_calidad': AppMenuItem(titulo: 'Certificados', icono: Icons.verified_outlined, pagina: const CertificadosCalidadPage(), seccion: 'EXTRAS'),
          'costos': AppMenuItem(titulo: 'Costos', icono: Icons.attach_money_rounded, pagina: const CostosPage(), seccion: 'EXTRAS'),
          'tesoreria': AppMenuItem(titulo: 'Tesorería', icono: Icons.account_balance_outlined, pagina: const TesoreriaPage(), seccion: 'EXTRAS'),
          'logistica': AppMenuItem(titulo: 'Logística', icono: Icons.local_shipping_outlined, pagina: const LogisticaPage(), seccion: 'EXTRAS'),
          'rrhh': AppMenuItem(titulo: 'RRHH', icono: Icons.people_outline, pagina: const RecursosHumanosPage(), seccion: 'EXTRAS'),
          'facturacion': AppMenuItem(titulo: 'Facturación', icono: Icons.receipt_long_outlined, pagina: const FacturacionPage(), seccion: 'EXTRAS'),
          'liquidaciones': AppMenuItem(titulo: 'Liquidaciones', icono: Icons.account_balance_wallet_outlined, pagina: const LiquidacionesPage(), seccion: 'EXTRAS'),
          'control_cochera': AppMenuItem(titulo: 'Control de Cochera', icono: Icons.garage_outlined, pagina: const ControlCocheraPage(), seccion: 'EXTRAS'),
          'control_combustible': AppMenuItem(titulo: 'Control Combustible', icono: Icons.local_gas_station_outlined, pagina: const ControlCombustiblePage(), seccion: 'EXTRAS'),
          'gps_flota': AppMenuItem(titulo: 'GPS Flota', icono: Icons.satellite_alt_outlined, pagina: const MapaPage(), seccion: 'EXTRAS'),
          'guias': AppMenuItem(titulo: 'Guías', icono: Icons.description_outlined, pagina: const GuiasMainPage(), seccion: 'EXTRAS'),
        };
        
        for (var row in data) {
          var permitidos = List<String>.from((row['usuarios_permitidos'] as List?)?.map((e) => e.toString()) ?? []);
          var denegados = List<String>.from((row['usuarios_denegados'] as List?)?.map((e) => e.toString()) ?? []);
          String mId = row['pantalla_id'].toString();
          
          if (denegados.contains(userId)) {
            // Remove from itemsPermitidos if it exists (meaning their role gave it by default)
            itemsPermitidos.removeWhere((item) => item.pagina.runtimeType == modulosMap[mId]?.pagina.runtimeType);
          } else if (permitidos.contains(userId)) {
            if (modulosMap.containsKey(mId)) {
              // Evitar duplicados (por si su rol base ya lo incluye)
              bool yaExiste = itemsPermitidos.any((item) => item.pagina.runtimeType == modulosMap[mId]!.pagina.runtimeType);
              if (!yaExiste) {
                extraItems.add(modulosMap[mId]!);
              }
            }
          }
        }
        
        if (extraItems.isNotEmpty && mounted) {
          setState(() {
            itemsPermitidos.addAll(extraItems);
          });
        }
      }
    } catch (e) {
      debugPrint('Error cargando permisos extra: $e');
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
            // TOP HEADER CUSTOMIZADO (NovaConcret Enterprise)
            Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: sidebarColor,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (!esEscritorio)
                    Image.asset(
                      'assets/images/LOGO_NOVA.png',
                      height: 42,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/images/logo.png',
                        height: 42,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/LOGO_NOVA.png',
                          height: 42,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(Icons.local_shipping, size: 36, color: AppColors.primary),
                        ),
                      ),
                    )
                  else ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        itemsPermitidos[indiceActual].icono,
                        size: 20,
                        color: isDark ? const Color(0xFF38BDF8) : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          itemsPermitidos[indiceActual].titulo,
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (itemsPermitidos[indiceActual].seccion != null)
                          Text(
                            itemsPermitidos[indiceActual].seccion!,
                            style: const TextStyle(
                              color: Color(0xFF0284C7),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                      ],
                    ),
                  ],
                  const Spacer(),
                  
                  // Role Badge corporativo NovaConcret
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF1E3A8A), const Color(0xFF0284C7)]
                            : [const Color(0xFF002244), const Color(0xFF004899)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF004899).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_user_rounded, size: 14, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 6),
                        Text(
                          widget.rol.name.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white, 
                            fontSize: 11, 
                            fontWeight: FontWeight.w900, 
                            letterSpacing: 1.0
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  
                  // Theme Toggle
                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, child) {
                      return InkWell(
                        onTap: () => themeProvider.toggleTheme(!themeProvider.isDarkMode),
                        borderRadius: BorderRadius.circular(50),
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          ),
                          child: Icon(
                            themeProvider.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                            color: themeProvider.isDarkMode ? Colors.amber : const Color(0xFF475569),
                            size: 19,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  
                  // Logout
                  InkWell(
                    onTap: () => _cerrarSesion(context),
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.withValues(alpha: 0.08),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 19),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: extendido ? 275 : 82,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          right: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 15,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          if (extendido)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              alignment: Alignment.centerLeft,
              child: Image.asset(
                'assets/images/LOGO_NOVA.png',
                height: 48,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/images/logo.png',
                  height: 48,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/LOGO_NOVA.png',
                    height: 48,
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                  ),
                ),
              ),
            )
          else 
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Image.asset(
                'assets/images/LOGO_NOVA.png',
                height: 38,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/images/logo.png',
                  height: 38,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/LOGO_NOVA.png',
                    height: 38,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(vertical: extendido ? 6 : 10, horizontal: 14),
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
        if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 14));
        widgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: Text(
              item.seccion!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                letterSpacing: 1.3,
              ),
            ),
          ),
        );
        lastSeccion = item.seccion;
      }

      final colorHover = isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9);
      final colorSelectedBg = isDark
          ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
          : const Color(0xFFEFF6FF);

      widgets.add(
        Tooltip(
          message: extendido ? '' : item.titulo,
          preferBelow: false,
          child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            child: Material(
              color: esSeleccionado ? colorSelectedBg : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                hoverColor: colorHover,
                onTap: () => setState(() => indiceActual = i),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: extendido ? 12 : 0, vertical: extendido ? 11 : 13),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: esSeleccionado 
                        ? Border(
                            left: BorderSide(
                              color: isDark ? const Color(0xFF38BDF8) : AppColors.primary,
                              width: 3.5,
                            ),
                          )
                        : null,
                  ),
                  child: extendido
                      ? Row(
                          children: [
                            Icon(
                              item.icono, 
                              size: 21, 
                              color: esSeleccionado 
                                  ? (isDark ? const Color(0xFF38BDF8) : AppColors.primary) 
                                  : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.titulo,
                                style: TextStyle(
                                  fontWeight: esSeleccionado ? FontWeight.w800 : FontWeight.w600,
                                  fontSize: 13.5,
                                  color: esSeleccionado 
                                      ? (isDark ? const Color(0xFF38BDF8) : AppColors.primary) 
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.icono, 
                              size: 23, 
                              color: esSeleccionado 
                                  ? (isDark ? const Color(0xFF38BDF8) : AppColors.primary) 
                                  : const Color(0xFF64748B),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              item.titulo,
                              style: TextStyle(
                                fontSize: 9,
                                color: esSeleccionado 
                                    ? (isDark ? const Color(0xFF38BDF8) : AppColors.primary) 
                                    : const Color(0xFF64748B),
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