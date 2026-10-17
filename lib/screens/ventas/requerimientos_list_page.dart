// lib/screens/ventas/requerimientos_list_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class RequerimientosListPage extends StatefulWidget {
  const RequerimientosListPage({super.key});

  @override
  State<RequerimientosListPage> createState() => _RequerimientosListPageState();
}

class _RequerimientosListPageState extends State<RequerimientosListPage> {
  final supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _requerimientos = [];
  List<Map<String, dynamic>> _filtrados = [];
  RealtimeChannel? _subscription;

  final TextEditingController _searchCtrl = TextEditingController();
  DateTime _fechaFiltro = DateTime.now();
  String _filtroTiempo = 'Hoy'; // 'Hoy', 'Esta Semana', 'Este Mes', 'Todos'
  String _filtroEstado = 'Todos'; // 'Todos', 'Activos', 'Cancelados'

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_aplicarFiltros);
    _cargarRequerimientos();
    _suscribirRealtime();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _suscribirRealtime() {
    _subscription = supabase
        .channel('public:ventas_programacion_req')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ventas_programacion',
          callback: (payload) {
            _cargarRequerimientos(silent: true);
          },
        )
        .subscribe();
  }

  Future<void> _cargarRequerimientos({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      PostgrestFilterBuilder filter = supabase.from('ventas_programacion').select();

      if (_filtroTiempo == 'Hoy') {
        final hoyStr = DateFormat('yyyy-MM-dd').format(_fechaFiltro);
        final mananaStr = DateFormat('yyyy-MM-dd').format(_fechaFiltro.add(const Duration(days: 1)));
        filter = filter.gte('fecha_entrega', hoyStr).lt('fecha_entrega', mananaStr);
      } else if (_filtroTiempo == 'Esta Semana') {
        final ahora = DateTime.now();
        final inicioSemana = ahora.subtract(Duration(days: ahora.weekday - 1));
        final finSemana = inicioSemana.add(const Duration(days: 7));
        filter = filter
            .gte('fecha_entrega', DateFormat('yyyy-MM-dd').format(inicioSemana))
            .lt('fecha_entrega', DateFormat('yyyy-MM-dd').format(finSemana));
      } else if (_filtroTiempo == 'Este Mes') {
        final ahora = DateTime.now();
        final inicioMes = DateTime(ahora.year, ahora.month, 1);
        final finMes = DateTime(ahora.year, ahora.month + 1, 1);
        filter = filter
            .gte('fecha_entrega', DateFormat('yyyy-MM-dd').format(inicioMes))
            .lt('fecha_entrega', DateFormat('yyyy-MM-dd').format(finMes));
      }

      final res = await filter
          .order('fecha_entrega', ascending: false)
          .order('hora_entrega', ascending: true)
          .limit(300);

      if (mounted) {
        setState(() {
          _requerimientos = List<Map<String, dynamic>>.from(res);
          _aplicarFiltros();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar requerimientos: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _esCancelado(Map<String, dynamic> r) {
    final numAten = r['numero_atencion']?.toString().trim();
    if (numAten == '0') return true;
    final obs = (r['observaciones'] ?? '').toString().toUpperCase();
    if (obs.contains('CANCELADO')) return true;
    final estado = (r['estado'] ?? '').toString().toUpperCase();
    if (estado == 'CANCELADO') return true;
    return false;
  }

  void _aplicarFiltros() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filtrados = _requerimientos.where((r) {
        final cancelado = _esCancelado(r);

        // Filtro por estado
        if (_filtroEstado == 'Activos' && cancelado) return false;
        if (_filtroEstado == 'Cancelados' && !cancelado) return false;

        if (q.isEmpty) return true;

        final cliente = (r['nombre_razon_social'] ?? '').toString().toLowerCase();
        final doc = (r['dni_ruc'] ?? '').toString().toLowerCase();
        final asesor = (r['asesor_comercial'] ?? '').toString().toLowerCase();
        final direccion = (r['direccion'] ?? '').toString().toLowerCase();
        final distrito = (r['distrito'] ?? '').toString().toLowerCase();
        final diseno = (r['diseno'] ?? '').toString().toLowerCase();
        final orden = (r['orden_pedido'] ?? '').toString().toLowerCase();
        final clave = (r['clave_unica'] ?? '').toString().toLowerCase();

        return cliente.contains(q) ||
            doc.contains(q) ||
            asesor.contains(q) ||
            direccion.contains(q) ||
            distrito.contains(q) ||
            diseno.contains(q) ||
            orden.contains(q) ||
            clave.contains(q);
      }).toList();
    });
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaFiltro,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      builder: (c, w) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF0F172A)),
        ),
        child: w!,
      ),
    );
    if (picked != null) {
      setState(() {
        _fechaFiltro = picked;
        _filtroTiempo = 'Hoy';
      });
      _cargarRequerimientos();
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalActivos = 0;
    int totalCancelados = 0;
    double volTotal = 0.0;

    for (var r in _filtrados) {
      final cancel = _esCancelado(r);
      if (cancel) {
        totalCancelados++;
      } else {
        totalActivos++;
        volTotal += (double.tryParse(r['volumen']?.toString() ?? '0') ?? 0.0);
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Gris corporativo
      appBar: AppBar(
        title: const Text(
          'Requerimientos de Producción',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF0F172A), // Azul marino
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: () => _cargarRequerimientos(),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Seleccionar Fecha',
            onPressed: _seleccionarFecha,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de Filtros de Tiempo y Estado
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                // Chips de tiempo
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...['Hoy', 'Esta Semana', 'Este Mes', 'Todos'].map((t) {
                        final sel = _filtroTiempo == t;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              t == 'Hoy'
                                  ? 'Hoy (${DateFormat('dd/MM').format(_fechaFiltro)})'
                                  : t,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                                color: sel ? Colors.white : const Color(0xFF334155),
                              ),
                            ),
                            selected: sel,
                            selectedColor: const Color(0xFF1E3A8A),
                            backgroundColor: const Color(0xFFF1F5F9),
                            onSelected: (val) {
                              if (val) {
                                setState(() => _filtroTiempo = t);
                                _cargarRequerimientos();
                              }
                            },
                          ),
                        );
                      }),
                      const SizedBox(width: 8),
                      // Filtro Activos / Cancelados
                      ...['Todos', 'Activos', 'Cancelados'].map((est) {
                        final sel = _filtroEstado == est;
                        Color selCol = const Color(0xFF0284C7);
                        if (est == 'Cancelados') selCol = Colors.red.shade700;
                        if (est == 'Activos') selCol = Colors.green.shade700;

                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(
                              est,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                                color: sel ? Colors.white : const Color(0xFF475569),
                              ),
                            ),
                            selected: sel,
                            selectedColor: selCol,
                            backgroundColor: const Color(0xFFE2E8F0),
                            onSelected: (val) {
                              setState(() => _filtroEstado = est);
                              _aplicarFiltros();
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Buscador
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar cliente, RUC, asesor, obra, diseño...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF1E3A8A), size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
          ),

          // Resumen de Métricas
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetrica(
                  titulo: 'TOTAL',
                  valor: '${_filtrados.length}',
                  colorValor: Colors.white,
                  icono: Icons.list_alt,
                ),
                Container(height: 35, width: 1, color: Colors.white24),
                _buildMetrica(
                  titulo: 'ACTIVOS',
                  valor: '$totalActivos',
                  colorValor: const Color(0xFF4ADE80),
                  icono: Icons.check_circle_outline,
                ),
                Container(height: 35, width: 1, color: Colors.white24),
                _buildMetrica(
                  titulo: 'CANCELADOS',
                  valor: '$totalCancelados',
                  colorValor: const Color(0xFFF87171),
                  icono: Icons.cancel_outlined,
                ),
                Container(height: 35, width: 1, color: Colors.white24),
                _buildMetrica(
                  titulo: 'VOL. ACTIVO',
                  valor: '${volTotal.toStringAsFixed(1)} m³',
                  colorValor: const Color(0xFF38BDF8),
                  icono: Icons.water_drop,
                ),
              ],
            ),
          ),

          // Lista de Requerimientos
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
                  )
                : _filtrados.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.precision_manufacturing_outlined, size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'No hay requerimientos para mostrar.',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Los requerimientos generados desde Cotizaciones aparecerán aquí.',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        itemCount: _filtrados.length,
                        itemBuilder: (context, index) {
                          final req = _filtrados[index];
                          return _buildRequerimientoCard(req);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetrica({
    required String titulo,
    required String valor,
    required Color colorValor,
    required IconData icono,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, color: colorValor, size: 13),
            const SizedBox(width: 4),
            Text(
              titulo,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          valor,
          style: TextStyle(
            color: colorValor,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildRequerimientoCard(Map<String, dynamic> r) {
    final cancelado = _esCancelado(r);

    final cliente = r['nombre_razon_social']?.toString() ?? 'Sin Cliente';
    final doc = r['dni_ruc']?.toString() ?? 'S/N';
    final tipoDoc = r['tipo_documento']?.toString() ?? 'Factura';
    final orden = r['orden_pedido']?.toString() ?? r['clave_unica']?.toString() ?? 'S/N';
    final asesor = r['asesor_comercial']?.toString() ?? 'Sin Asesor';
    final tel = r['telefono']?.toString() ?? '';
    final direccion = r['direccion']?.toString() ?? 'Sin Dirección';
    final distrito = r['distrito']?.toString() ?? '';
    final fechaEntrega = r['fecha_entrega']?.toString() ?? '';
    final horaEntrega = r['hora_entrega']?.toString() ?? '';
    final diseno = r['diseno']?.toString() ?? 'Sin Diseño';
    final elemento = r['elemento']?.toString() ?? 'General';
    final volumen = double.tryParse(r['volumen']?.toString() ?? '0') ?? 0.0;
    final slump = r['slump']?.toString() ?? '';
    final huso = r['huso']?.toString() ?? '';
    final cemento = r['tipo_cemento']?.toString() ?? '';
    final aditivo = r['aditivo']?.toString() ?? '';
    final bombas = r['bombas']?.toString() ?? '';
    final mixer = r['mixers']?.toString() ?? '';
    final capacidad = r['capacidad_maxima']?.toString() ?? '';
    final tiempo = r['tiempo_estimado_vaciado']?.toString() ?? '';
    final calidad = r['personal_calidad']?.toString() ?? '';
    final obs = r['observaciones']?.toString() ?? '';

    // Colores según estado: SI ES CANCELADO SE TORNA DE COLOR ROJO
    final cardBg = cancelado ? const Color(0xFFFFF1F2) : Colors.white; // Soft Red vs White
    final cardBorder = cancelado ? const Color(0xFFF43F5E) : const Color(0xFFCBD5E1); // Red vs Gray
    final borderWidth = cancelado ? 2.0 : 1.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: cancelado ? 3 : 2,
      shadowColor: cancelado ? Colors.red.withOpacity(0.2) : Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cardBorder, width: borderWidth),
      ),
      color: cardBg,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: cancelado, // Mostrar cancelados expandidos para fácil verificación
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cancelado
                  ? Colors.red.shade100
                  : const Color(0xFF1E3A8A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: cancelado
                    ? Colors.red.shade400
                    : const Color(0xFF1E3A8A).withOpacity(0.2),
              ),
            ),
            child: Icon(
              cancelado ? Icons.cancel : Icons.precision_manufacturing_outlined,
              color: cancelado ? Colors.red.shade700 : const Color(0xFF1E3A8A),
              size: 24,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  cliente,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: cancelado ? Colors.red.shade900 : const Color(0xFF0F172A),
                    decoration: cancelado ? TextDecoration.lineThrough : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              // Badge de Estado
              if (cancelado)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cancel, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'CANCELADO',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$volumen m³',
                    style: const TextStyle(
                      color: Color(0xFF0284C7),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '$fechaEntrega · $horaEntrega',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: cancelado ? Colors.red.shade800 : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.person, size: 12, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        asesor,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$tipoDoc: $doc | OP: $orden',
                  style: TextStyle(
                    fontSize: 11,
                    color: cancelado ? Colors.red.shade600 : Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          children: [
            const Divider(color: Color(0xFFE2E8F0)),
            
            // Si está cancelado, mostrar alerta explicativa
            if (cancelado)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.red.shade800, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Este requerimiento fue marcado como CANCELADO en Despachos/Programación.',
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Ubicación y Contacto
            _buildInfoBloque(
              titulo: 'UBICACIÓN Y CONTACTO',
              icono: Icons.location_on_outlined,
              color: const Color(0xFF0F172A),
              campos: [
                _buildFila('Obra / Dirección:', direccion),
                if (distrito.isNotEmpty) _buildFila('Distrito:', distrito),
                if (tel.isNotEmpty) _buildFila('Teléfono:', tel),
                _buildFila('Asesor Comercial:', asesor),
              ],
            ),
            const SizedBox(height: 8),

            // Especificaciones del Concreto
            _buildInfoBloque(
              titulo: 'ESPECIFICACIONES DEL CONCRETO',
              icono: Icons.science_outlined,
              color: const Color(0xFF1E3A8A),
              campos: [
                _buildFila('Diseño (F\'c):', diseno),
                _buildFila('Volumen:', '$volumen m³'),
                _buildFila('Elemento:', elemento),
                if (slump.isNotEmpty) _buildFila('Slump:', slump),
                if (huso.isNotEmpty) _buildFila('Huso:', huso),
                if (cemento.isNotEmpty) _buildFila('Cemento:', cemento),
                if (aditivo.isNotEmpty) _buildFila('Aditivo:', aditivo),
              ],
            ),
            const SizedBox(height: 8),

            // Logística y Equipos
            _buildInfoBloque(
              titulo: 'LOGÍSTICA Y EQUIPOS SOLICITADOS',
              icono: Icons.fire_truck_outlined,
              color: const Color(0xFF0284C7),
              campos: [
                _buildFila('Bomba(s):', bombas.isNotEmpty ? bombas : 'DIRECTO'),
                _buildFila('Mixer sugerido:', mixer.isNotEmpty ? mixer : 'Disponible'),
                if (capacidad.isNotEmpty) _buildFila('Capacidad:', capacidad),
                if (tiempo.isNotEmpty) _buildFila('Tiempo vaciado:', '$tiempo hora(s)'),
                _buildFila('Personal de Calidad:', calidad.isNotEmpty ? calidad : 'NO'),
                if (obs.isNotEmpty) _buildFila('Observaciones:', obs),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBloque({
    required String titulo,
    required IconData icono,
    required Color color,
    required List<Widget> campos,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...campos,
        ],
      ),
    );
  }

  Widget _buildFila(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
