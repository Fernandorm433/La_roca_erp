// Archivo: lib/screens/comercial/comercial_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────
// MODELOS
// ─────────────────────────────────────────────────────────────

class Cliente {
  final String id;
  final String nombre;
  final String ruc;
  final String telefono;
  final String email;
  final String direccion;
  final String contacto;

  Cliente({
    required this.id,
    required this.nombre,
    required this.ruc,
    required this.telefono,
    required this.email,
    required this.direccion,
    required this.contacto,
  });

  factory Cliente.fromMap(Map<String, dynamic> m) => Cliente(
    id: m['id']?.toString() ?? '',
    nombre:
        m['nombre_razon_social']?.toString() ?? m['nombre']?.toString() ?? '',
    ruc: m['ruc']?.toString() ?? m['dni_ruc']?.toString() ?? '—',
    telefono: m['telefono']?.toString() ?? '—',
    email: m['email']?.toString() ?? '—',
    direccion: m['direccion']?.toString() ?? '—',
    contacto:
        m['contacto']?.toString() ?? m['nombre_contacto']?.toString() ?? '—',
  );

  Map<String, dynamic> toInsert() => {
    'nombre_razon_social': nombre,
    'ruc': ruc,
    'telefono': telefono,
    'email': email,
    'direccion': direccion,
    'contacto': contacto,
  };
}

class PrecioItem {
  final String id;
  final String diseno;
  final double precioM3;
  final String descripcion;

  PrecioItem({
    required this.id,
    required this.diseno,
    required this.precioM3,
    required this.descripcion,
  });

  factory PrecioItem.fromMap(Map<String, dynamic> m) => PrecioItem(
    id: m['id']?.toString() ?? '',
    diseno:
        m['diseno']?.toString() ??
        m['fc']?.toString() ??
        m['nombre']?.toString() ??
        '—',
    precioM3:
        double.tryParse(
          m['precio_m3']?.toString() ?? m['precio']?.toString() ?? '0',
        ) ??
        0,
    descripcion:
        m['descripcion']?.toString() ??
        m['descripcion_mezcla']?.toString() ??
        '',
  );
}

class Cotizacion {
  final String id;
  final String numero;
  final String clienteId;
  final String clienteNombre;
  final String estado;
  final String fecha;
  final double total;
  final String notas;

  Cotizacion({
    required this.id,
    required this.numero,
    required this.clienteId,
    required this.clienteNombre,
    required this.estado,
    required this.fecha,
    required this.total,
    required this.notas,
  });

  factory Cotizacion.fromMap(Map<String, dynamic> m) => Cotizacion(
    id: m['id']?.toString() ?? '',
    numero:
        m['numero_cotizacion']?.toString() ?? m['numero']?.toString() ?? '—',
    clienteId: m['cliente_id']?.toString() ?? '',
    clienteNombre:
        (m['clientes'] as Map<String, dynamic>?)?['nombre_razon_social'] ?? '—',
    estado: m['estado']?.toString() ?? 'borrador',
    fecha:
        m['fecha']?.toString() ??
        m['created_at']?.toString().split('T')[0] ??
        '',
    total: double.tryParse(m['total']?.toString() ?? '0') ?? 0,
    notas: m['notas']?.toString() ?? '',
  );
}

// ─────────────────────────────────────────────────────────────
// COLORES POR ESTADO
// ─────────────────────────────────────────────────────────────

Color _colorEstadoCot(String estado) {
  switch (estado) {
    case 'aprobada':
      return AppColors.success;
    case 'enviada':
      return const Color(0xFF6366F1);
    case 'rechazada':
      return AppColors.error;
    default:
      return Colors.grey;
  }
}

// ─────────────────────────────────────────────────────────────
// PÁGINA PRINCIPAL
// ─────────────────────────────────────────────────────────────

class ComercialPage extends StatefulWidget {
  const ComercialPage({super.key});
  @override
  State<ComercialPage> createState() => _ComercialPageState();
}

class _ComercialPageState extends State<ComercialPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;

  List<Cliente> _clientes = [];
  List<PrecioItem> _precios = [];
  List<Cotizacion> _cotizaciones = [];

  bool _loadingClientes = true;
  bool _loadingPrecios = true;
  bool _loadingCots = true;

  String _busquedaCliente = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarTodo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarTodo() async {
    await Future.wait([
      _cargarClientes(),
      _cargarPrecios(),
      _cargarCotizaciones(),
    ]);
  }

  Future<void> _cargarClientes() async {
    setState(() => _loadingClientes = true);
    try {
      final data = await supabase
          .from('clientes')
          .select()
          .order('nombre_razon_social');
      if (mounted) {
        setState(() {
          _clientes = (data as List).map((m) => Cliente.fromMap(m)).toList();
          _loadingClientes = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingClientes = false);
    }
  }

  Future<void> _cargarPrecios() async {
    setState(() => _loadingPrecios = true);
    try {
      final data = await supabase
          .from('lista_precios')
          .select()
          .order('diseno');
      if (mounted) {
        setState(() {
          _precios = (data as List).map((m) => PrecioItem.fromMap(m)).toList();
          _loadingPrecios = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingPrecios = false);
    }
  }

  Future<void> _cargarCotizaciones() async {
    setState(() => _loadingCots = true);
    try {
      final data = await supabase
          .from('cotizaciones')
          .select('*, clientes(nombre_razon_social)')
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _cotizaciones = (data as List)
              .map((m) => Cotizacion.fromMap(m))
              .toList();
          _loadingCots = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingCots = false);
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
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_tabClientes(), _tabCotizaciones(), _tabPrecios()],
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
        colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)],
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
            Icons.storefront_outlined,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Comercial',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${_clientes.length} clientes · ${_cotizaciones.length} cotizaciones',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
        const Spacer(),
        Row(
          children: [
            _kpiMini('Precios', '${_precios.length}', Colors.white),
            const SizedBox(width: 16),
            _kpiMini('Clientes', '${_clientes.length}', AppColors.success),
          ],
        ),
      ],
    ),
  ).animate().fade().slideY(begin: -0.05);

  Widget _kpiMini(String label, String val, Color c) => Column(
    children: [
      Text(
        val,
        style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 18),
      ),
      Text(label, style: TextStyle(color: c.withOpacity(0.8), fontSize: 10)),
    ],
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
      tabs: const [
        Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Clientes'),
        Tab(
          icon: Icon(Icons.description_outlined, size: 18),
          text: 'Cotizaciones',
        ),
        Tab(
          icon: Icon(Icons.price_change_outlined, size: 18),
          text: 'Lista Precios',
        ),
      ],
    ),
  );

  Widget _buildFAB() {
    final tabIdx = _tabController.index;
    final labels = ['Nuevo Cliente', 'Nueva Cotización', null];
    final icons = [Icons.person_add_outlined, Icons.add_box_outlined, null];
    if (labels[tabIdx] == null) return const SizedBox.shrink();
    return FloatingActionButton.extended(
      onPressed: () {
        if (tabIdx == 0) _abrirFormCliente();
        if (tabIdx == 1) _abrirFormCotizacion();
      },
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      icon: Icon(icons[tabIdx]),
      label: Text(labels[tabIdx]!),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 1: CLIENTES
  // ─────────────────────────────────────────────────────────────

  Widget _tabClientes() {
    if (_loadingClientes) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    final filtrados = _clientes
        .where(
          (c) =>
              _busquedaCliente.isEmpty ||
              c.nombre.toLowerCase().contains(_busquedaCliente.toLowerCase()) ||
              c.ruc.contains(_busquedaCliente),
        )
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o RUC...',
              prefixIcon: const Icon(Icons.search, color: AppColors.accent),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            onChanged: (v) => setState(() => _busquedaCliente = v),
          ),
        ),
        Expanded(
          child: filtrados.isEmpty
              ? _emptyState(
                  'Sin clientes registrados',
                  Icons.people_outline,
                  accion: 'Agregar cliente',
                  onAccion: _abrirFormCliente,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: filtrados.length,
                  itemBuilder: (ctx, i) {
                    final c = filtrados[i];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(14),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.accent.withOpacity(0.1),
                          child: Text(
                            c.nombre.isNotEmpty
                                ? c.nombre[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          c.nombre,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 3),
                            Text(
                              'RUC: ${c.ruc}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                            if (c.telefono != '—')
                              Text(
                                c.telefono,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            if (c.contacto != '—')
                              Text(
                                'Contacto: ${c.contacto}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.edit_outlined,
                            color: Colors.grey.shade400,
                          ),
                          onPressed: () => _abrirFormCliente(cliente: c),
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
  // TAB 2: COTIZACIONES
  // ─────────────────────────────────────────────────────────────

  Widget _tabCotizaciones() {
    if (_loadingCots) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    return _cotizaciones.isEmpty
        ? _emptyState(
            'Sin cotizaciones registradas',
            Icons.description_outlined,
            accion: 'Nueva cotización',
            onAccion: _abrirFormCotizacion,
          )
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            itemCount: _cotizaciones.length,
            itemBuilder: (ctx, i) {
              final cot = _cotizaciones[i];
              final color = _colorEstadoCot(cot.estado);
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: color.withOpacity(0.25), width: 1.5),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _verDetalleCotizacion(cot),
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
                            Icons.description_outlined,
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
                                    cot.numero,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      cot.estado.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                cot.clienteNombre,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                cot.fecha,
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
                              'S/ ${cot.total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.grey.shade400,
                              size: 16,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ).animate().fade(delay: (i * 40).ms).slideX(begin: 0.04);
            },
          );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 3: LISTA DE PRECIOS
  // ─────────────────────────────────────────────────────────────

  Widget _tabPrecios() {
    if (_loadingPrecios) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.accent.withOpacity(0.1),
                AppColors.accent.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accent.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.accent, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_precios.length} diseños de mezcla en la lista actual',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _precios.isEmpty
              ? _emptyState(
                  'Sin precios registrados',
                  Icons.price_change_outlined,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: _precios.length,
                  itemBuilder: (ctx, i) {
                    final p = _precios[i];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'f\'c',
                                    style: TextStyle(
                                      color: AppColors.accent.withOpacity(0.7),
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    p.diseno
                                            .replaceAll(RegExp(r'[^0-9]'), '')
                                            .isNotEmpty
                                        ? p.diseno.replaceAll(
                                            RegExp(r'[^0-9]'),
                                            '',
                                          )
                                        : '—',
                                    style: const TextStyle(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.diseno,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  if (p.descripcion.isNotEmpty)
                                    Text(
                                      p.descripcion,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'S/ ${p.precioM3.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                Text(
                                  'por m³',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ).animate().fade(delay: (i * 50).ms).slideX(begin: 0.04);
                  },
                ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FORMULARIO CLIENTE
  // ─────────────────────────────────────────────────────────────

  void _abrirFormCliente({Cliente? cliente}) {
    final nombreCtrl = TextEditingController(text: cliente?.nombre);
    final rucCtrl = TextEditingController(
      text: cliente?.ruc == '—' ? '' : cliente?.ruc,
    );
    final telCtrl = TextEditingController(
      text: cliente?.telefono == '—' ? '' : cliente?.telefono,
    );
    final emailCtrl = TextEditingController(
      text: cliente?.email == '—' ? '' : cliente?.email,
    );
    final dirCtrl = TextEditingController(
      text: cliente?.direccion == '—' ? '' : cliente?.direccion,
    );
    final contCtrl = TextEditingController(
      text: cliente?.contacto == '—' ? '' : cliente?.contacto,
    );
    final formKey = GlobalKey<FormState>();
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
              child: Form(
                key: formKey,
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
                    Text(
                      cliente == null ? 'Nuevo Cliente' : 'Editar Cliente',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _inputField(
                      nombreCtrl,
                      'Razón Social / Nombre *',
                      Icons.business_outlined,
                      requerido: true,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _inputField(
                            rucCtrl,
                            'RUC / DNI',
                            Icons.badge_outlined,
                            kb: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _inputField(
                            telCtrl,
                            'Teléfono',
                            Icons.phone_outlined,
                            kb: TextInputType.phone,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _inputField(
                      emailCtrl,
                      'Email',
                      Icons.email_outlined,
                      kb: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    _inputField(dirCtrl, 'Dirección', Icons.place_outlined),
                    const SizedBox(height: 12),
                    _inputField(
                      contCtrl,
                      'Persona de Contacto',
                      Icons.contact_phone_outlined,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: guardando
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setS(() => guardando = true);
                                try {
                                  final datos = {
                                    'nombre_razon_social': nombreCtrl.text
                                        .trim(),
                                    'ruc': rucCtrl.text.trim(),
                                    'telefono': telCtrl.text.trim(),
                                    'email': emailCtrl.text.trim(),
                                    'direccion': dirCtrl.text.trim(),
                                    'contacto': contCtrl.text.trim(),
                                  };
                                  if (cliente == null) {
                                    await supabase
                                        .from('clientes')
                                        .insert(datos);
                                  } else {
                                    await supabase
                                        .from('clientes')
                                        .update(datos)
                                        .eq('id', cliente.id);
                                  }
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  _cargarClientes();
                                } catch (e) {
                                  debugPrint('save cliente: $e');
                                  setS(() => guardando = false);
                                }
                              },
                        icon: guardando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          cliente == null
                              ? 'Guardar Cliente'
                              : 'Actualizar Cliente',
                        ),
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
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FORMULARIO COTIZACIÓN
  // ─────────────────────────────────────────────────────────────

  void _abrirFormCotizacion() {
    if (_clientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero registra al menos un cliente'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    String? clienteId;
    final notasCtrl = TextEditingController();
    final items = <Map<String, dynamic>>[];
    bool guardando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          double total = items.fold(
            0,
            (s, i) => s + ((i['subtotal'] as double?) ?? 0),
          );

          void agregarItem() {
            setS(
              () => items.add({
                'precio_id': null,
                'diseno': '',
                'volumen': 0.0,
                'precio_unitario': 0.0,
                'subtotal': 0.0,
              }),
            );
          }

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.92,
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Handle + título
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                        const Text(
                          'Nueva Cotización',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Selector de cliente
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
                                  value: c.id,
                                  child: Text(
                                    c.nombre,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setS(() => clienteId = v),
                        ),
                      ],
                    ),
                  ),
                  // Items
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Ítems',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: agregarItem,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Agregar'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                        if (items.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Text(
                                'Sin ítems. Toca "Agregar" para añadir diseños.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),
                        ...items.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final item = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              children: [
                                // Diseño
                                DropdownButtonFormField<String>(
                                  initialValue: item['precio_id'],
                                  decoration: InputDecoration(
                                    labelText: 'Diseño / F\'c',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    isDense: true,
                                  ),
                                  items: _precios
                                      .map(
                                        (p) => DropdownMenuItem(
                                          value: p.id,
                                          child: Text(
                                            '${p.diseno} - S/ ${p.precioM3.toStringAsFixed(2)}/m³',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) {
                                    final precio = _precios.firstWhere(
                                      (p) => p.id == v,
                                    );
                                    setS(() {
                                      item['precio_id'] = v;
                                      item['diseno'] = precio.diseno;
                                      item['precio_unitario'] = precio.precioM3;
                                      item['subtotal'] =
                                          precio.precioM3 *
                                          ((item['volumen'] as double?) ?? 0);
                                    });
                                  },
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        initialValue:
                                            item['volumen']?.toString() ?? '',
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: InputDecoration(
                                          labelText: 'Volumen (m³)',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          isDense: true,
                                          suffixText: 'm³',
                                        ),
                                        onChanged: (v) => setS(() {
                                          item['volumen'] =
                                              double.tryParse(v) ?? 0;
                                          item['subtotal'] =
                                              (item['precio_unitario']
                                                      as double? ??
                                                  0) *
                                              (item['volumen'] as double? ?? 0);
                                        }),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'S/ ${(item['subtotal'] as double? ?? 0).toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: AppColors.accent,
                                          ),
                                        ),
                                        const Text(
                                          'subtotal',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: AppColors.error,
                                        size: 20,
                                      ),
                                      onPressed: () =>
                                          setS(() => items.removeAt(idx)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                        _inputField(
                          notasCtrl,
                          'Notas adicionales',
                          Icons.notes_outlined,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  // Footer con total + botón
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TOTAL',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'S/ ${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FilledButton(
                            onPressed:
                                (guardando ||
                                    clienteId == null ||
                                    items.isEmpty)
                                ? null
                                : () async {
                                    setS(() => guardando = true);
                                    try {
                                      final fecha = DateTime.now()
                                          .toIso8601String()
                                          .split('T')[0];
                                      final cotResult = await supabase
                                          .from('cotizaciones')
                                          .insert({
                                            'cliente_id': clienteId,
                                            'fecha': fecha,
                                            'estado': 'borrador',
                                            'total': total,
                                            'notas': notasCtrl.text.trim(),
                                          })
                                          .select()
                                          .single();
                                      final cotId = cotResult['id'];
                                      for (final item in items) {
                                        await supabase
                                            .from('cotizacion_items')
                                            .insert({
                                              'cotizacion_id': cotId,
                                              'diseno': item['diseno'],
                                              'volumen': item['volumen'],
                                              'precio_unitario':
                                                  item['precio_unitario'],
                                              'subtotal': item['subtotal'],
                                            });
                                      }
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      _cargarCotizaciones();
                                    } catch (e) {
                                      debugPrint('cot: $e');
                                      setS(() => guardando = false);
                                    }
                                  },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: guardando
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Guardar Cotización',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _verDetalleCotizacion(Cotizacion cot) async {
    final items = await supabase
        .from('cotizacion_items')
        .select()
        .eq('cotizacion_id', cot.id);
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
                      child: Text(
                        cot.numero,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _colorEstadoCot(cot.estado).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        cot.estado.toUpperCase(),
                        style: TextStyle(
                          color: _colorEstadoCot(cot.estado),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  cot.clienteNombre,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                Text(
                  cot.fecha,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
                const Divider(height: 24),
                const Text(
                  'Ítems',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: (items as List).map((item) {
                      final vol =
                          double.tryParse(item['volumen']?.toString() ?? '0') ??
                          0;
                      final pu =
                          double.tryParse(
                            item['precio_unitario']?.toString() ?? '0',
                          ) ??
                          0;
                      final sub =
                          double.tryParse(
                            item['subtotal']?.toString() ?? '0',
                          ) ??
                          0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['diseno'] ?? '—',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${vol.toStringAsFixed(1)} m³ × S/ ${pu.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'S/ ${sub.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'S/ ${cot.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
                // Acciones de estado
                const SizedBox(height: 12),
                if (cot.estado == 'borrador')
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              _cambiarEstadoCot(ctx, cot.id, 'enviada'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF6366F1)),
                          ),
                          child: const Text(
                            'Enviar',
                            style: TextStyle(color: Color(0xFF6366F1)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () =>
                              _cambiarEstadoCot(ctx, cot.id, 'aprobada'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.success,
                          ),
                          child: const Text('Aprobar'),
                        ),
                      ),
                    ],
                  ),
                if (cot.estado == 'enviada')
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              _cambiarEstadoCot(ctx, cot.id, 'rechazada'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.error),
                          ),
                          child: const Text(
                            'Rechazar',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () =>
                              _cambiarEstadoCot(ctx, cot.id, 'aprobada'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.success,
                          ),
                          child: const Text('Aprobar'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _cambiarEstadoCot(
    BuildContext ctx,
    String id,
    String estado,
  ) async {
    try {
      await supabase
          .from('cotizaciones')
          .update({'estado': estado})
          .eq('id', id);
      if (ctx.mounted) Navigator.pop(ctx);
      _cargarCotizaciones();
    } catch (e) {
      debugPrint('estado cot: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────

  Widget _inputField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool requerido = false,
    TextInputType kb = TextInputType.text,
    int maxLines = 1,
  }) => TextFormField(
    controller: ctrl,
    keyboardType: kb,
    maxLines: maxLines,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.accent, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    ),
    validator: requerido
        ? (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null
        : null,
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
