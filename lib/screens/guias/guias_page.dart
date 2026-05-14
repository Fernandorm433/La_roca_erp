// lib/screens/guias/guias_page.dart
// Guías de Despacho — La Roca Concretos
// Solo para órdenes con tipo_documento = RECIBO
// Guarda en Supabase + genera PDF con número correlativo global

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/pdf_generator.dart';

// ─────────────────────────────────────────────────────────────
// MODELOS LOCALES
// ─────────────────────────────────────────────────────────────

class OrdenProgramada {
  final String id;
  final String opNro; // "OP-2025-3428"
  final String cliente;
  final String rucDni;
  final String obra; // dirección
  final String diseno;
  final String cemento;
  final String slump;
  final String huso;
  final String aditivo;
  final double volumen;

  OrdenProgramada({
    required this.id,
    required this.opNro,
    required this.cliente,
    required this.rucDni,
    required this.obra,
    required this.diseno,
    required this.cemento,
    required this.slump,
    required this.huso,
    required this.aditivo,
    required this.volumen,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is OrdenProgramada && id == other.id;

  @override
  int get hashCode => id.hashCode;

  String get etiquetaDropdown =>
      '${opNro.isNotEmpty ? "$opNro | " : ""}$cliente';
}

class Conductor {
  final String id;
  final String nombre;
  final String placa;
  final String marca; // columna TIPO_LICENCIA se usa para inferir marca
  // Si tu tabla tiene columna 'marca', úsala directamente.

  Conductor({
    required this.id,
    required this.nombre,
    required this.placa,
    required this.marca,
  });
}

// ─────────────────────────────────────────────────────────────
// PÁGINA PRINCIPAL
// ─────────────────────────────────────────────────────────────

class GuiasDespachoPage extends StatefulWidget {
  const GuiasDespachoPage({super.key});

  @override
  State<GuiasDespachoPage> createState() => _GuiasDespachoPageState();
}

class _GuiasDespachoPageState extends State<GuiasDespachoPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  // ── Estado de carga ──────────────────────────────────────────
  bool _loading = true;
  bool _guardando = false;

  // ── Datos del servidor ───────────────────────────────────────
  List<OrdenProgramada> _ordenes = [];
  List<Conductor> _conductores = [];

  // ── Selecciones del formulario ───────────────────────────────
  OrdenProgramada? _ordenSeleccionada;
  Conductor? _conductorSeleccionado;
  String? _bombaAsignada;

  // ── Controladores ────────────────────────────────────────────
  final _volumenController = TextEditingController();
  final _precintoController = TextEditingController();
  TimeOfDay _horaSalida = TimeOfDay.now();

  // ── Búsqueda en dropdown ─────────────────────────────────────
  String _busquedaOrden = '';

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _volumenController.dispose();
    _precintoController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // CARGA DE DATOS
  // ─────────────────────────────────────────────────────────────

  Future<void> _cargarDatos() async {
    setState(() => _loading = true);
    await Future.wait([_cargarOrdenes(), _cargarConductores()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _cargarOrdenes() async {
    try {
      final hoy = DateTime.now().toIso8601String().split('T')[0];

      final data = await supabase
          .from('ventas_programacion')
          .select()
          .eq('fecha_entrega', hoy)
          .order('hora_entrega');

      // Cargar bomba asignada para cada orden
      final asignaciones = await supabase.from('asignacion_bombas').select();
      final mapaAsignaciones = <String, String>{
        for (var a in asignaciones)
          a['id_venta'].toString(): a['bomba_asignada'].toString(),
      };

      final List<OrdenProgramada> lista = [];

      for (final o in (data as List)) {
        final estado = o['estado']?.toString().toUpperCase() ?? '';
        final numAtencion = o['numero_atencion']?.toString() ?? '';
        final tipoDoc = o['tipo_documento']?.toString().toUpperCase() ?? '';
        final vol = double.tryParse(o['volumen']?.toString() ?? '0') ?? 0.0;

        // ✅ Solo RECIBO con número de atención válido y volumen > 0
        if (estado == 'CANCELADO') continue;
        if (numAtencion == '0' || numAtencion.isEmpty) continue;
        if (tipoDoc != 'RECIBO') continue;
        if (vol <= 0) continue;

        final id = o['id']?.toString() ?? numAtencion;
        final bomba = mapaAsignaciones[id] ?? '';

        lista.add(
          OrdenProgramada(
            id: id,
            opNro:
                o['codigo_op']?.toString() ??
                o['op_nro']?.toString() ??
                (o['numero_atencion'] != null
                    ? 'OP-${o['numero_atencion']}'
                    : ''),
            cliente: o['nombre_razon_social']?.toString() ?? 'Sin Cliente',
            rucDni:
                o['dni_ruc']?.toString() ??
                o['ruc_dni']?.toString() ??
                o['ruc']?.toString() ??
                '',
            obra: o['direccion']?.toString() ?? 'S/D',
            diseno: o['diseno']?.toString() ?? '',
            cemento: o['cemento']?.toString() ?? 'CEMENTO YURA HE',
            slump: o['slump']?.toString() ?? '',
            huso: o['huso']?.toString() ?? '',
            aditivo: o['aditivo']?.toString() ?? 'ADITIVO PLASTIFICANTE',
            volumen: vol,
          ),
        );

        // Pre-cargar bomba si ya estaba seleccionada
        if (bomba.isNotEmpty && _ordenSeleccionada?.id == id) {
          _bombaAsignada = bomba;
        }
      }

      if (mounted) setState(() => _ordenes = lista);
    } catch (e) {
      debugPrint('Error cargando órdenes: $e');
    }
  }

  Future<void> _cargarConductores() async {
    try {
      final data = await supabase.from('conductores').select().order('nombre');

      final List<Conductor> lista = [];
      for (final c in (data as List)) {
        final nombre = c['nombre']?.toString() ?? '';
        final placa = c['placa']?.toString() ?? '';
        if (nombre.isEmpty) continue;

        // La tabla no tiene columna marca — inferimos del campo TIPO_LICENCIA
        // o dejamos vacío. Si en el futuro agregas columna 'marca', cámbialo aquí.
        final marca =
            c['marca']?.toString() ??
            c['marca_vehiculo']?.toString() ??
            c['tipo_vehiculo']?.toString() ??
            '';

        lista.add(
          Conductor(
            id: c['id']?.toString() ?? '',
            nombre: nombre.toUpperCase(),
            placa: placa.toUpperCase(),
            marca: marca.toUpperCase(),
          ),
        );
      }
      if (mounted) setState(() => _conductores = lista);
    } catch (e) {
      debugPrint('Error cargando conductores: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // OBTENER NÚMERO CORRELATIVO DESDE SUPABASE RPC
  // ─────────────────────────────────────────────────────────────

  Future<String> _generarNumeroGuia() async {
    try {
      final resultado = await supabase.rpc(
        'generar_numero',
        params: {
          'prefijo': '001',
          'tabla': 'guias_despacho',
          'columna': 'numero_guia',
        },
      );
      return resultado.toString();
    } catch (e) {
      // Fallback: timestamp si la función RPC falla
      debugPrint('RPC generar_numero falló: $e');
      final ts = DateTime.now().millisecondsSinceEpoch;
      return '001-${ts.toString().substring(5)}';
    }
  }

  // ─────────────────────────────────────────────────────────────
  // GUARDAR GUÍA + ABRIR PDF
  // ─────────────────────────────────────────────────────────────

  Future<void> _guardarYGenerarGuia() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_ordenSeleccionada == null) {
      _snack('Selecciona una orden de programación', esError: true);
      return;
    }
    if (_conductorSeleccionado == null) {
      _snack('Selecciona un conductor', esError: true);
      return;
    }

    setState(() => _guardando = true);

    try {
      // 1. Obtener número correlativo
      final nroGuia = await _generarNumeroGuia();

      // 2. Preparar hora formateada
      final now = DateTime.now();
      final dtSalida = DateTime(
        now.year,
        now.month,
        now.day,
        _horaSalida.hour,
        _horaSalida.minute,
      );
      final horaFormateada = DateFormat('h:mm a').format(dtSalida);

      final double volDispatch =
          double.tryParse(_volumenController.text) ??
          _ordenSeleccionada!.volumen;

      // 3. Guardar en Supabase — tabla guias_despacho (del SQL que creamos)
      await supabase.from('guias_despacho').insert({
        'numero_guia': nroGuia,
        'fecha_despacho': now.toIso8601String().split('T')[0],
        'estado': 'programada',
        'op_nro': _ordenSeleccionada!.opNro,
        'nombre_cliente': _ordenSeleccionada!.cliente,
        'ruc_dni_cliente': _ordenSeleccionada!.rucDni,
        'obra_destino': _ordenSeleccionada!.obra,
        'm3_despachado': volDispatch,
        'diseno': _ordenSeleccionada!.diseno,
        'cemento': _ordenSeleccionada!.cemento,
        'slump': _ordenSeleccionada!.slump,
        'huso': _ordenSeleccionada!.huso,
        'aditivo': _ordenSeleccionada!.aditivo,
        'resistencia_mezcla': _ordenSeleccionada!.diseno,
        'conductor': _conductorSeleccionado!.nombre,
        'placa_vehiculo': _conductorSeleccionado!.placa,
        'marca_vehiculo': _conductorSeleccionado!.marca,
        'bomba': _bombaAsignada ?? '-',
        'hora_salida': horaFormateada,
        'nro_precinto': _precintoController.text,
        'facturado': false,
        'operador_id': supabase.auth.currentUser?.id,
      });

      // 4. Construir mapa de datos para el PDF
      final datosPdf = <String, dynamic>{
        'nro_guia': nroGuia,
        'fecha': now.toIso8601String(),
        'op_nro': _ordenSeleccionada!.opNro,
        'cliente': _ordenSeleccionada!.cliente,
        'ruc_dni': _ordenSeleccionada!.rucDni,
        'direccion_obra': _ordenSeleccionada!.obra,
        'diseno': _ordenSeleccionada!.diseno,
        'cemento': _ordenSeleccionada!.cemento,
        'slump': _ordenSeleccionada!.slump,
        'huso': _ordenSeleccionada!.huso,
        'aditivo': _ordenSeleccionada!.aditivo,
        'vol_m3': volDispatch,
        'bomba': _bombaAsignada ?? '-',
        'hora_salida': horaFormateada,
        'nro_precinto': _precintoController.text,
        'conductor': _conductorSeleccionado!.nombre,
        'marca_vehiculo': _conductorSeleccionado!.marca,
        'placa_vehiculo': _conductorSeleccionado!.placa,
      };

      if (!mounted) return;
      setState(() => _guardando = false);

      // 5. Navegar a previsualización PDF
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              _VistaPreviewGuia(nroGuia: nroGuia, datosPdf: datosPdf),
        ),
      );

      // 6. Limpiar formulario después de regresar
      _limpiarFormulario();
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        _snack('Error al guardar la guía: $e', esError: true);
      }
    }
  }

  void _limpiarFormulario() {
    setState(() {
      _ordenSeleccionada = null;
      _conductorSeleccionado = null;
      _bombaAsignada = null;
      _busquedaOrden = '';
      _horaSalida = TimeOfDay.now();
    });
    _volumenController.clear();
    _precintoController.clear();
  }

  // ─────────────────────────────────────────────────────────────
  // UI HELPERS
  // ─────────────────────────────────────────────────────────────

  void _snack(String msg, {bool esError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: esError ? AppColors.error : AppColors.success,
      ),
    );
  }

  Future<void> _seleccionarHora() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _horaSalida,
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.accent),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _horaSalida = picked);
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nueva Guía de Despacho'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.all(12),
          child: Icon(Icons.description, color: AppColors.accent, size: 24),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.accent),
            tooltip: 'Recargar órdenes',
            onPressed: _cargarDatos,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── PASO 1: ORDEN ──────────────────────────────
                  _buildSeccion(
                    titulo: 'Paso 1 — Orden de programación (solo RECIBO)',
                    icono: Icons.list_alt_outlined,
                    child: _buildSelectorOrden(),
                  ),

                  const SizedBox(height: 20),

                  // ── DATOS FIJOS ────────────────────────────────
                  if (_ordenSeleccionada != null) ...[
                    _buildSeccion(
                      titulo: 'Datos de la orden',
                      icono: Icons.lock_outline,
                      child: _buildDatosFijos(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── PASO 2: CONDUCTOR ──────────────────────────
                  _buildSeccion(
                    titulo: 'Paso 2 — Conductor y vehículo',
                    icono: Icons.person_outlined,
                    child: _buildSelectorConductor(),
                  ),

                  const SizedBox(height: 20),

                  // ── PASO 3: DETALLES MANUALES ──────────────────
                  _buildSeccion(
                    titulo: 'Paso 3 — Detalles del despacho',
                    icono: Icons.input_outlined,
                    child: _buildDetallesDespacho(),
                  ),

                  const SizedBox(height: 32),

                  // ── BOTÓN GENERAR ──────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _guardando ? null : _guardarYGenerarGuia,
                      icon: _guardando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.print, color: Colors.white),
                      label: Text(
                        _guardando
                            ? 'Guardando y generando...'
                            : 'GUARDAR Y PREVISUALIZAR GUÍA (PDF)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 3,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // WIDGETS DE SECCIÓN
  // ─────────────────────────────────────────────────────────────

  Widget _buildSeccion({
    required String titulo,
    required IconData icono,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icono, color: AppColors.primaryDark, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                titulo,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  // ── Selector de orden ──────────────────────────────────────

  Widget _buildSelectorOrden() {
    final ordenesFiltradas = _busquedaOrden.isEmpty
        ? _ordenes
        : _ordenes
              .where(
                (o) =>
                    o.cliente.toLowerCase().contains(
                      _busquedaOrden.toLowerCase(),
                    ) ||
                    o.opNro.toLowerCase().contains(
                      _busquedaOrden.toLowerCase(),
                    ),
              )
              .toList();

    return _cardContenido(
      child: Column(
        children: [
          // Buscador rápido
          TextField(
            onChanged: (v) => setState(() => _busquedaOrden = v),
            decoration: InputDecoration(
              hintText: 'Buscar cliente u OP...',
              prefixIcon: const Icon(Icons.search, color: AppColors.accent),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<OrdenProgramada>(
            isExpanded: true,
            initialValue: _ordenSeleccionada,
            decoration: InputDecoration(
              labelText: ordenesFiltradas.isEmpty
                  ? 'No hay órdenes RECIBO para hoy'
                  : 'Seleccionar orden...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(
                Icons.receipt_long_outlined,
                color: AppColors.accent,
              ),
            ),
            items: ordenesFiltradas
                .map(
                  (o) => DropdownMenuItem(
                    value: o,
                    child: Text(
                      o.etiquetaDropdown,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: ordenesFiltradas.isEmpty
                ? null
                : (val) {
                    setState(() {
                      _ordenSeleccionada = val;
                      // Pre-poblar volumen con el de la orden
                      if (val != null) {
                        _volumenController.text = val.volumen % 1 == 0
                            ? val.volumen.toInt().toString()
                            : val.volumen.toStringAsFixed(1);
                      }
                    });
                  },
            validator: (v) => v == null ? 'Campo requerido' : null,
          ),
        ],
      ),
    );
  }

  // ── Datos fijos de la orden ───────────────────────────────

  Widget _buildDatosFijos() {
    final o = _ordenSeleccionada!;
    return _cardContenido(
      color: AppColors.primaryDark.withOpacity(0.03),
      border: true,
      child: Wrap(
        spacing: 30,
        runSpacing: 8,
        children: [
          _datoFijo('Cliente', o.cliente),
          _datoFijo('RUC/DNI', o.rucDni),
          _datoFijo('Dirección obra', o.obra),
          _datoFijo('Diseño', o.diseno),
          _datoFijo('Slump', o.slump),
          _datoFijo('Huso', o.huso),
        ],
      ),
    );
  }

  Widget _datoFijo(String label, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          valor.isNotEmpty ? valor : '-',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }

  // ── Selector de conductor ─────────────────────────────────

  Widget _buildSelectorConductor() {
    return _cardContenido(
      child: Column(
        children: [
          DropdownButtonFormField<Conductor>(
            isExpanded: true,
            initialValue: _conductorSeleccionado,
            decoration: InputDecoration(
              labelText: _conductores.isEmpty
                  ? 'No hay conductores registrados'
                  : 'Seleccionar conductor...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(
                Icons.person_search_outlined,
                color: AppColors.accent,
              ),
            ),
            items: _conductores
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Text(c.nombre, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: _conductores.isEmpty
                ? null
                : (val) => setState(() => _conductorSeleccionado = val),
            validator: (v) => v == null ? 'Campo requerido' : null,
          ),

          // Mostrar placa y marca al seleccionar
          if (_conductorSeleccionado != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accent.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.directions_car,
                    color: AppColors.accent,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Placa: ${_conductorSeleccionado!.placa}'
                      '${_conductorSeleccionado!.marca.isNotEmpty ? "  |  Marca: ${_conductorSeleccionado!.marca}" : ""}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Detalles del despacho ─────────────────────────────────

  Widget _buildDetallesDespacho() {
    return _cardContenido(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final esMovil = constraints.maxWidth < 500;
          final mitad = esMovil
              ? constraints.maxWidth
              : (constraints.maxWidth / 2) - 8;

          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              // Columna izquierda
              SizedBox(
                width: mitad,
                child: Column(
                  children: [
                    // Volumen
                    TextFormField(
                      controller: _volumenController,
                      decoration: InputDecoration(
                        labelText: 'Volumen a despachar (m³)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(
                          Icons.local_shipping_outlined,
                          color: AppColors.accent,
                        ),
                        suffixText: 'm³',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Campo requerido';
                        if (double.tryParse(v) == null) {
                          return 'Debe ser un número';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Bomba (informativo, ya viene de asignacion_bombas)
                    TextFormField(
                      initialValue: _bombaAsignada ?? '',
                      decoration: InputDecoration(
                        labelText: 'Bomba asignada',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(
                          Icons.fire_truck_outlined,
                          color: AppColors.accent,
                        ),
                        hintText: 'CBP 15, DIRECTO...',
                      ),
                      onChanged: (v) => _bombaAsignada = v,
                    ),
                  ],
                ),
              ),

              // Columna derecha
              SizedBox(
                width: mitad,
                child: Column(
                  children: [
                    // Precinto
                    TextFormField(
                      controller: _precintoController,
                      decoration: InputDecoration(
                        labelText: 'Número de precinto',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(
                          Icons.vpn_key_outlined,
                          color: AppColors.accent,
                        ),
                        hintText: 'P-001350',
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Hora salida
                    InkWell(
                      onTap: _seleccionarHora,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black38),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              color: AppColors.accent,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hora de salida (planta)',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _horaSalida.format(context),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_drop_down,
                              color: AppColors.primaryDark,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Card contenedor ───────────────────────────────────────

  Widget _cardContenido({
    required Widget child,
    Color? color,
    bool border = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: border ? Border.all(color: Colors.black12) : null,
        boxShadow: border
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PANTALLA DE PREVISUALIZACIÓN PDF
// ─────────────────────────────────────────────────────────────

class _VistaPreviewGuia extends StatelessWidget {
  final String nroGuia;
  final Map<String, dynamic> datosPdf;

  const _VistaPreviewGuia({required this.nroGuia, required this.datosPdf});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Guía: $nroGuia'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
      ),
      body: PdfPreview(
        build: (format) => PdfGenerator.generarGuiaDespacho(datosPdf),
        allowSharing: true,
        allowPrinting: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        pdfFileName: 'Guia_$nroGuia.pdf',
        actions: [
          PdfPreviewAction(
            icon: const Icon(Icons.save_alt, color: Colors.white),
            onPressed: (context, build, pageFormat) async {
              // La acción de guardar ya la maneja allowSharing/allowPrinting
            },
          ),
        ],
      ),
    );
  }
}
