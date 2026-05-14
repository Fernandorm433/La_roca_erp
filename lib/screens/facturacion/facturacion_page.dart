// Archivo: lib/screens/facturacion/facturacion_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────
// MODELOS
// ─────────────────────────────────────────────────────────────

class Factura {
  final String id;
  final String numero;
  final String clienteId;
  final String clienteNombre;
  final String estado; // emitida | pagada | vencida | anulada
  final String fecha;
  final String fechaVencimiento;
  final double subtotal;
  final double igv;
  final double total;
  final String? serie;
  final String? pedidoId;

  Factura({
    required this.id,
    required this.numero,
    required this.clienteId,
    required this.clienteNombre,
    required this.estado,
    required this.fecha,
    required this.fechaVencimiento,
    required this.subtotal,
    required this.igv,
    required this.total,
    this.serie,
    this.pedidoId,
  });

  factory Factura.fromMap(Map<String, dynamic> m) => Factura(
    id: m['id']?.toString() ?? '',
    numero: m['numero_factura']?.toString() ?? m['numero']?.toString() ?? '—',
    clienteId: m['cliente_id']?.toString() ?? '',
    clienteNombre:
        (m['clientes'] as Map<String, dynamic>?)?['nombre_razon_social'] ??
        m['cliente']?.toString() ??
        '—',
    estado: m['estado']?.toString() ?? 'emitida',
    fecha: m['fecha']?.toString() ?? '',
    fechaVencimiento: m['fecha_vencimiento']?.toString() ?? '',
    subtotal: double.tryParse(m['subtotal']?.toString() ?? '0') ?? 0,
    igv: double.tryParse(m['igv']?.toString() ?? '0') ?? 0,
    total: double.tryParse(m['total']?.toString() ?? '0') ?? 0,
    serie: m['serie']?.toString(),
    pedidoId: m['pedido_id']?.toString(),
  );
}

class Pago {
  final String id;
  final String facturaId;
  final String facturaNumero;
  final String clienteNombre;
  final double monto;
  final String fecha;
  final String metodoPago;
  final String referencia;

  Pago({
    required this.id,
    required this.facturaId,
    required this.facturaNumero,
    required this.clienteNombre,
    required this.monto,
    required this.fecha,
    required this.metodoPago,
    required this.referencia,
  });

  factory Pago.fromMap(Map<String, dynamic> m) => Pago(
    id: m['id']?.toString() ?? '',
    facturaId: m['factura_id']?.toString() ?? '',
    facturaNumero:
        (m['facturas'] as Map<String, dynamic>?)?['numero_factura'] ?? '—',
    clienteNombre:
        ((m['facturas'] as Map<String, dynamic>?)?['clientes']
            as Map<String, dynamic>?)?['nombre_razon_social'] ??
        '—',
    monto: double.tryParse(m['monto']?.toString() ?? '0') ?? 0,
    fecha: m['fecha']?.toString() ?? '',
    metodoPago: m['metodo_pago']?.toString() ?? m['metodo']?.toString() ?? '—',
    referencia:
        m['referencia']?.toString() ?? m['numero_operacion']?.toString() ?? '',
  );
}

class NotaCreditoDebito {
  final String id;
  final String tipo; // credito | debito
  final String facturaId;
  final String facturaNumero;
  final double monto;
  final String motivo;
  final String fecha;
  final String estado;

  NotaCreditoDebito({
    required this.id,
    required this.tipo,
    required this.facturaId,
    required this.facturaNumero,
    required this.monto,
    required this.motivo,
    required this.fecha,
    required this.estado,
  });

  factory NotaCreditoDebito.fromMap(Map<String, dynamic> m) =>
      NotaCreditoDebito(
        id: m['id']?.toString() ?? '',
        tipo: m['tipo']?.toString() ?? 'credito',
        facturaId: m['factura_id']?.toString() ?? '',
        facturaNumero:
            (m['facturas'] as Map<String, dynamic>?)?['numero_factura'] ?? '—',
        monto: double.tryParse(m['monto']?.toString() ?? '0') ?? 0,
        motivo: m['motivo']?.toString() ?? '—',
        fecha: m['fecha']?.toString() ?? '',
        estado: m['estado']?.toString() ?? 'emitida',
      );
}

// ─────────────────────────────────────────────────────────────
// HELPERS DE COLOR
// ─────────────────────────────────────────────────────────────

Color _colorFactura(String estado) {
  switch (estado) {
    case 'pagada':
      return AppColors.success;
    case 'emitida':
      return const Color(0xFF6366F1);
    case 'vencida':
      return AppColors.error;
    case 'anulada':
      return Colors.grey;
    default:
      return AppColors.warning;
  }
}

Color _colorTipoNota(String tipo) =>
    tipo == 'credito' ? AppColors.success : AppColors.error;

// ─────────────────────────────────────────────────────────────
// PÁGINA PRINCIPAL
// ─────────────────────────────────────────────────────────────

class FacturacionPage extends StatefulWidget {
  const FacturacionPage({super.key});
  @override
  State<FacturacionPage> createState() => _FacturacionPageState();
}

class _FacturacionPageState extends State<FacturacionPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;

  List<Factura> _facturas = [];
  List<Pago> _pagos = [];
  List<NotaCreditoDebito> _notas = [];
  List<Map<String, dynamic>> _clientes = [];

  bool _loadingF = true, _loadingP = true, _loadingN = true;

  // Filtro facturas
  String _filtroEstado = 'todos';

  // Métricas
  double get _totalEmitido => _facturas
      .where((f) => f.estado == 'emitida')
      .fold(0, (s, f) => s + f.total);
  double get _totalCobrado => _pagos.fold(0, (s, p) => s + p.monto);
  double get _totalVencido => _facturas
      .where((f) => f.estado == 'vencida')
      .fold(0, (s, f) => s + f.total);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _cargarTodo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarTodo() async {
    await Future.wait([
      _cargarFacturas(),
      _cargarPagos(),
      _cargarNotas(),
      _cargarClientes(),
    ]);
  }

  Future<void> _cargarFacturas() async {
    setState(() => _loadingF = true);
    try {
      final data = await supabase
          .from('facturas')
          .select('*, clientes(nombre_razon_social)')
          .order('fecha', ascending: false);
      if (mounted) {
        setState(() {
          _facturas = (data as List).map((m) => Factura.fromMap(m)).toList();
          _loadingF = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingF = false);
    }
  }

  Future<void> _cargarPagos() async {
    setState(() => _loadingP = true);
    try {
      final data = await supabase
          .from('pagos')
          .select('*, facturas(numero_factura, clientes(nombre_razon_social))')
          .order('fecha', ascending: false);
      if (mounted) {
        setState(() {
          _pagos = (data as List).map((m) => Pago.fromMap(m)).toList();
          _loadingP = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingP = false);
    }
  }

  Future<void> _cargarNotas() async {
    setState(() => _loadingN = true);
    try {
      final data = await supabase
          .from('notas_credito_debito')
          .select('*, facturas(numero_factura)')
          .order('fecha', ascending: false);
      if (mounted) {
        setState(() {
          _notas = (data as List)
              .map((m) => NotaCreditoDebito.fromMap(m))
              .toList();
          _loadingN = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingN = false);
    }
  }

  Future<void> _cargarClientes() async {
    try {
      final data = await supabase
          .from('clientes')
          .select('id, nombre_razon_social')
          .order('nombre_razon_social');
      if (mounted) {
        setState(() => _clientes = List<Map<String, dynamic>>.from(data));
      }
    } catch (e) {
      debugPrint('clientes: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          _buildKpis(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_tabFacturas(), _tabPagos(), _tabNotas()],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildHeader() => Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0F172A), Color(0xFF1E40AF)],
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.receipt_outlined,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Facturación',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${_facturas.length} facturas · ${_pagos.length} pagos',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
          onPressed: _cargarTodo,
        ),
      ],
    ),
  ).animate().fade().slideY(begin: -0.05);

  Widget _buildKpis() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Row(
      children: [
        _kpi(
          'Por Cobrar',
          'S/ ${_fmt(_totalEmitido)}',
          const Color(0xFF6366F1),
        ),
        const SizedBox(width: 8),
        _kpi('Cobrado', 'S/ ${_fmt(_totalCobrado)}', AppColors.success),
        const SizedBox(width: 8),
        _kpi('Vencido', 'S/ ${_fmt(_totalVencido)}', AppColors.error),
      ],
    ),
  ).animate().fade(delay: 80.ms);

  Widget _kpi(String label, String valor, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            valor,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildTabBar() => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: TabBar(
      controller: _tabController,
      labelColor: AppColors.accent,
      unselectedLabelColor: Colors.grey,
      indicatorColor: AppColors.accent,
      dividerColor: Colors.transparent,
      tabs: [
        Tab(
          icon: const Icon(Icons.receipt_long_outlined, size: 18),
          text: 'Facturas (${_facturas.length})',
        ),
        Tab(
          icon: const Icon(Icons.payments_outlined, size: 18),
          text: 'Pagos (${_pagos.length})',
        ),
        Tab(
          icon: const Icon(Icons.note_alt_outlined, size: 18),
          text: 'Notas (${_notas.length})',
        ),
      ],
    ),
  );

  Widget _buildFAB() {
    final tabIdx = _tabController.index;
    if (tabIdx == 0) {
      return FloatingActionButton.extended(
        onPressed: _abrirFormFactura,
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva Factura'),
      );
    }
    if (tabIdx == 1) {
      return FloatingActionButton.extended(
        onPressed: _abrirFormPago,
        backgroundColor: AppColors.success,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.payments_outlined),
        label: const Text('Registrar Pago'),
      );
    }
    return FloatingActionButton.extended(
      onPressed: _abrirFormNota,
      backgroundColor: const Color(0xFF6366F1),
      foregroundColor: Colors.white,
      icon: const Icon(Icons.note_add_outlined),
      label: const Text('Nueva Nota'),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 1: FACTURAS
  // ─────────────────────────────────────────────────────────────

  Widget _tabFacturas() {
    if (_loadingF) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    final filtradas = _filtroEstado == 'todos'
        ? _facturas
        : _facturas.where((f) => f.estado == _filtroEstado).toList();

    return Column(
      children: [
        // Filtros
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              _filtroChip('todos', 'Todas'),
              _filtroChip(
                'emitida',
                'Emitidas',
                color: const Color(0xFF6366F1),
              ),
              _filtroChip('pagada', 'Pagadas', color: AppColors.success),
              _filtroChip('vencida', 'Vencidas', color: AppColors.error),
              _filtroChip('anulada', 'Anuladas', color: Colors.grey),
            ],
          ),
        ),
        Expanded(
          child: filtradas.isEmpty
              ? _emptyState(
                  'Sin facturas',
                  Icons.receipt_long_outlined,
                  accion: 'Nueva Factura',
                  onAccion: _abrirFormFactura,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: filtradas.length,
                  itemBuilder: (ctx, i) {
                    final f = filtradas[i];
                    final color = _colorFactura(f.estado);
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: color.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _verDetalleFactura(f),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.receipt_outlined,
                                  color: color,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          f.numero,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _badge(f.estado.toUpperCase(), color),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      f.clienteNombre,
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${f.fecha}${f.fechaVencimiento.isNotEmpty ? ' · Vence: ${f.fechaVencimiento}' : ''}',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'S/ ${_fmt(f.total)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                  Text(
                                    'IGV: S/ ${_fmt(f.igv)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ).animate().fade(delay: (i * 40).ms).slideX(begin: 0.04);
                  },
                ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 2: PAGOS
  // ─────────────────────────────────────────────────────────────

  Widget _tabPagos() {
    if (_loadingP) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    return _pagos.isEmpty
        ? _emptyState(
            'Sin pagos registrados',
            Icons.payments_outlined,
            accion: 'Registrar Pago',
            onAccion: _abrirFormPago,
          )
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            itemCount: _pagos.length,
            itemBuilder: (ctx, i) {
              final p = _pagos[i];
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: AppColors.success.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.payments_outlined,
                          color: AppColors.success,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.clienteNombre,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Factura: ${p.facturaNumero}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                            Row(
                              children: [
                                _badge(
                                  _metodoPagoLabel(p.metodoPago),
                                  const Color(0xFF6366F1),
                                ),
                                if (p.referencia.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    'Ref: ${p.referencia}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              p.fecha,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'S/ ${_fmt(p.monto)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fade(delay: (i * 40).ms).slideX(begin: 0.04);
            },
          );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 3: NOTAS C/D
  // ─────────────────────────────────────────────────────────────

  Widget _tabNotas() {
    if (_loadingN) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    return _notas.isEmpty
        ? _emptyState(
            'Sin notas registradas',
            Icons.note_alt_outlined,
            accion: 'Nueva Nota',
            onAccion: _abrirFormNota,
          )
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            itemCount: _notas.length,
            itemBuilder: (ctx, i) {
              final n = _notas[i];
              final color = _colorTipoNota(n.tipo);
              final label = n.tipo == 'credito'
                  ? 'NOTA CRÉDITO'
                  : 'NOTA DÉBITO';
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: color.withOpacity(0.3), width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          n.tipo == 'credito'
                              ? Icons.remove_circle_outline
                              : Icons.add_circle_outline,
                          color: color,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _badge(label, color),
                            const SizedBox(height: 4),
                            Text(
                              'Factura: ${n.facturaNumero}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              n.motivo,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              n.fecha,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'S/ ${_fmt(n.monto)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fade(delay: (i * 40).ms).slideX(begin: 0.04);
            },
          );
  }

  // ─────────────────────────────────────────────────────────────
  // FORMULARIO FACTURA
  // ─────────────────────────────────────────────────────────────

  void _abrirFormFactura() {
    String? clienteId;
    final serieCtrl = TextEditingController(text: 'F001');
    final numCtrl = TextEditingController();
    final subtCtrl = TextEditingController();
    final igvCtrl = TextEditingController();
    final totalCtrl = TextEditingController();
    final venceCtrl = TextEditingController(text: _fechaPlus30());
    bool guardando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    'Nueva Factura',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: clienteId,
                    decoration: InputDecoration(
                      labelText: 'Cliente *',
                      prefixIcon: const Icon(
                        Icons.person_outline,
                        color: AppColors.accent,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    items: _clientes
                        .map(
                          (c) => DropdownMenuItem(
                            value: c['id'].toString(),
                            child: Text(
                              c['nombre_razon_social'] ?? '',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setS(() => clienteId = v),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _field(serieCtrl, 'Serie', Icons.tag)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          numCtrl,
                          'Número',
                          Icons.confirmation_number_outlined,
                          kb: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          subtCtrl,
                          'Subtotal',
                          Icons.monetization_on_outlined,
                          kb: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (v) {
                            final sub = double.tryParse(v) ?? 0;
                            final ig = sub * 0.18;
                            setS(() {
                              igvCtrl.text = ig.toStringAsFixed(2);
                              totalCtrl.text = (sub + ig).toStringAsFixed(2);
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          igvCtrl,
                          'IGV (18%)',
                          Icons.percent,
                          kb: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          totalCtrl,
                          'Total',
                          Icons.account_balance_wallet_outlined,
                          kb: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          venceCtrl,
                          'Fecha Vencimiento',
                          Icons.event_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: (guardando || clienteId == null)
                          ? null
                          : () async {
                              setS(() => guardando = true);
                              try {
                                final hoy = DateTime.now()
                                    .toIso8601String()
                                    .split('T')[0];
                                await supabase.from('facturas').insert({
                                  'cliente_id': clienteId,
                                  'serie': serieCtrl.text.trim(),
                                  'numero_factura':
                                      '${serieCtrl.text.trim()}-${numCtrl.text.trim()}',
                                  'fecha': hoy,
                                  'fecha_vencimiento': venceCtrl.text.trim(),
                                  'subtotal':
                                      double.tryParse(subtCtrl.text) ?? 0,
                                  'igv': double.tryParse(igvCtrl.text) ?? 0,
                                  'total': double.tryParse(totalCtrl.text) ?? 0,
                                  'estado': 'emitida',
                                });
                                if (ctx.mounted) Navigator.pop(ctx);
                                _cargarFacturas();
                              } catch (e) {
                                debugPrint('factura: $e');
                                setS(() => guardando = false);
                              }
                            },
                      icon: guardando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('Emitir Factura'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FORMULARIO PAGO
  // ─────────────────────────────────────────────────────────────

  void _abrirFormPago() {
    String? facturaId;
    String metodoPago = 'efectivo';
    final montoCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    bool guardando = false;

    final facturasAbiertas = _facturas
        .where((f) => f.estado == 'emitida' || f.estado == 'vencida')
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    'Registrar Pago',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: facturaId,
                    decoration: InputDecoration(
                      labelText: 'Factura *',
                      prefixIcon: const Icon(
                        Icons.receipt_outlined,
                        color: AppColors.accent,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    items: facturasAbiertas
                        .map(
                          (f) => DropdownMenuItem(
                            value: f.id,
                            child: Text(
                              '${f.numero} · ${f.clienteNombre} · S/ ${_fmt(f.total)}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      final f = facturasAbiertas.firstWhere((f) => f.id == v);
                      setS(() {
                        facturaId = v;
                        montoCtrl.text = f.total.toStringAsFixed(2);
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _field(
                    montoCtrl,
                    'Monto',
                    Icons.monetization_on_outlined,
                    kb: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  // Método de pago
                  const Text(
                    'Método de Pago',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children:
                        ['efectivo', 'transferencia', 'cheque', 'deposito']
                            .map(
                              (m) => ChoiceChip(
                                label: Text(_metodoPagoLabel(m)),
                                selected: metodoPago == m,
                                onSelected: (_) => setS(() => metodoPago = m),
                                selectedColor: AppColors.accent.withOpacity(
                                  0.15,
                                ),
                                labelStyle: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: metodoPago == m
                                      ? AppColors.accent
                                      : Colors.grey.shade700,
                                ),
                              ),
                            )
                            .toList(),
                  ),
                  const SizedBox(height: 12),
                  _field(
                    refCtrl,
                    'Número de operación / Referencia',
                    Icons.numbers_outlined,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: (guardando || facturaId == null)
                          ? null
                          : () async {
                              setS(() => guardando = true);
                              try {
                                final hoy = DateTime.now()
                                    .toIso8601String()
                                    .split('T')[0];
                                await supabase.from('pagos').insert({
                                  'factura_id': facturaId,
                                  'monto': double.tryParse(montoCtrl.text) ?? 0,
                                  'fecha': hoy,
                                  'metodo_pago': metodoPago,
                                  'referencia': refCtrl.text.trim(),
                                });
                                // Marcar factura como pagada
                                await supabase
                                    .from('facturas')
                                    .update({'estado': 'pagada'})
                                    .eq('id', facturaId!);
                                if (ctx.mounted) Navigator.pop(ctx);
                                _cargarTodo();
                              } catch (e) {
                                debugPrint('pago: $e');
                                setS(() => guardando = false);
                              }
                            },
                      icon: guardando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: const Text('Confirmar Pago'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FORMULARIO NOTA
  // ─────────────────────────────────────────────────────────────

  void _abrirFormNota() {
    String? facturaId;
    String tipo = 'credito';
    final montoCtrl = TextEditingController();
    final motivoCtrl = TextEditingController();
    bool guardando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    'Nueva Nota de Crédito / Débito',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  // Tipo
                  Row(
                    children: [
                      Expanded(
                        child: _tipoBtn(
                          'credito',
                          'Nota Crédito',
                          Icons.remove_circle_outline,
                          AppColors.success,
                          tipo,
                          (v) => setS(() => tipo = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _tipoBtn(
                          'debito',
                          'Nota Débito',
                          Icons.add_circle_outline,
                          AppColors.error,
                          tipo,
                          (v) => setS(() => tipo = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: facturaId,
                    decoration: InputDecoration(
                      labelText: 'Factura relacionada *',
                      prefixIcon: const Icon(
                        Icons.receipt_outlined,
                        color: AppColors.accent,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    items: _facturas
                        .map(
                          (f) => DropdownMenuItem(
                            value: f.id,
                            child: Text(
                              '${f.numero} · ${f.clienteNombre}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setS(() => facturaId = v),
                  ),
                  const SizedBox(height: 12),
                  _field(
                    montoCtrl,
                    'Monto',
                    Icons.monetization_on_outlined,
                    kb: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  _field(
                    motivoCtrl,
                    'Motivo / Descripción',
                    Icons.note_alt_outlined,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: (guardando || facturaId == null)
                          ? null
                          : () async {
                              setS(() => guardando = true);
                              try {
                                await supabase
                                    .from('notas_credito_debito')
                                    .insert({
                                      'factura_id': facturaId,
                                      'tipo': tipo,
                                      'monto':
                                          double.tryParse(montoCtrl.text) ?? 0,
                                      'motivo': motivoCtrl.text.trim(),
                                      'fecha': DateTime.now()
                                          .toIso8601String()
                                          .split('T')[0],
                                      'estado': 'emitida',
                                    });
                                if (ctx.mounted) Navigator.pop(ctx);
                                _cargarNotas();
                              } catch (e) {
                                debugPrint('nota: $e');
                                setS(() => guardando = false);
                              }
                            },
                      icon: guardando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('Emitir Nota'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _colorTipoNota(tipo),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tipoBtn(
    String val,
    String label,
    IconData icon,
    Color color,
    String current,
    void Function(String) onTap,
  ) {
    final activo = current == val;
    return GestureDetector(
      onTap: () => onTap(val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: activo ? color.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: activo ? color : Colors.grey.shade300,
            width: activo ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: activo ? color : Colors.grey, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: activo ? color : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _verDetalleFactura(Factura f) async {
    final items = await supabase
        .from('factura_items')
        .select()
        .eq('factura_id', f.id);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.75,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.numero,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            f.clienteNombre,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    _badge(f.estado.toUpperCase(), _colorFactura(f.estado)),
                  ],
                ),
                const Divider(height: 24),
                // Resumen financiero
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      _fila('Fecha emisión', f.fecha),
                      if (f.fechaVencimiento.isNotEmpty)
                        _fila('Vencimiento', f.fechaVencimiento),
                      _fila('Subtotal', 'S/ ${_fmt(f.subtotal)}'),
                      _fila('IGV (18%)', 'S/ ${_fmt(f.igv)}'),
                      const Divider(height: 12),
                      _fila('TOTAL', 'S/ ${_fmt(f.total)}', bold: true),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if ((items as List).isNotEmpty) ...[
                  const Text(
                    'Ítems',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: items
                          .map(
                            (item) => Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item['descripcion'] ?? '—',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'S/ ${_fmt(double.tryParse(item['subtotal']?.toString() ?? '0') ?? 0)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
                if (f.estado == 'emitida') ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _abrirFormPago();
                      },
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Registrar Pago'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────

  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(2);
  }

  String _fechaPlus30() {
    final d = DateTime.now().add(const Duration(days: 30));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _metodoPagoLabel(String m) {
    const labels = {
      'efectivo': 'Efectivo',
      'transferencia': 'Transferencia',
      'cheque': 'Cheque',
      'deposito': 'Depósito',
    };
    return labels[m] ?? m;
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
    ),
  );

  Widget _fila(String label, String valor, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            fontSize: bold ? 15 : 13,
          ),
        ),
      ],
    ),
  );

  Widget _filtroChip(String estado, String label, {Color? color}) {
    final activo = _filtroEstado == estado;
    final c = color ?? AppColors.primaryDark;
    return GestureDetector(
      onTap: () => setState(() => _filtroEstado = estado),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: activo ? c : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: activo ? c : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: activo ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType kb = TextInputType.text,
    int maxLines = 1,
    void Function(String)? onChanged,
  }) => TextFormField(
    controller: ctrl,
    keyboardType: kb,
    maxLines: maxLines,
    onChanged: onChanged,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.accent, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    ),
  );

  Widget _emptyState(
    String msg,
    IconData icon, {
    String? accion,
    VoidCallback? onAccion,
  }) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text(msg, style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
        if (accion != null && onAccion != null) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAccion,
            icon: const Icon(Icons.add),
            label: Text(accion),
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
          ),
        ],
      ],
    ),
  );
}
