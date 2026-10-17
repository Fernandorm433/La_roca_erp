// lib/screens/calidad/historial_carguios_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';

class HistorialCarguiosPage extends StatefulWidget {
  const HistorialCarguiosPage({super.key});

  @override
  State<HistorialCarguiosPage> createState() => _HistorialCarguiosPageState();
}

class _HistorialCarguiosPageState extends State<HistorialCarguiosPage> {
  final supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _carguios = [];
  List<Map<String, dynamic>> _filtrados = [];

  final TextEditingController _searchCtrl = TextEditingController();
  DateTime _fechaFiltro = DateTime.now();
  String _filtroTiempo = 'Hoy'; // 'Hoy', 'Esta Semana', 'Este Mes', 'Todos'

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_aplicarFiltros);
    _cargarHistorial();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarHistorial() async {
    setState(() => _loading = true);
    try {
      PostgrestFilterBuilder filter = supabase.from('despachos_produccion').select();

      if (_filtroTiempo == 'Hoy') {
        final hoyStr = DateFormat('yyyy-MM-dd').format(_fechaFiltro);
        final mananaStr = DateFormat('yyyy-MM-dd').format(_fechaFiltro.add(const Duration(days: 1)));
        filter = filter.gte('fecha', hoyStr).lt('fecha', mananaStr);
      } else if (_filtroTiempo == 'Esta Semana') {
        final ahora = DateTime.now();
        final inicioSemana = ahora.subtract(Duration(days: ahora.weekday - 1));
        final finSemana = inicioSemana.add(const Duration(days: 7));
        filter = filter
            .gte('fecha', DateFormat('yyyy-MM-dd').format(inicioSemana))
            .lt('fecha', DateFormat('yyyy-MM-dd').format(finSemana));
      } else if (_filtroTiempo == 'Este Mes') {
        final ahora = DateTime.now();
        final inicioMes = DateTime(ahora.year, ahora.month, 1);
        final finMes = DateTime(ahora.year, ahora.month + 1, 1);
        filter = filter
            .gte('fecha', DateFormat('yyyy-MM-dd').format(inicioMes))
            .lt('fecha', DateFormat('yyyy-MM-dd').format(finMes));
      }

      final res = await filter.order('fecha', ascending: false).limit(200);

      if (mounted) {
        setState(() {
          _carguios = List<Map<String, dynamic>>.from(res);
          _aplicarFiltros();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar historial de carguios: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _aplicarFiltros() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filtrados = _carguios.where((c) {
        if (q.isEmpty) return true;
        final cliente = (c['cliente'] ?? '').toString().toLowerCase();
        final mixer = (c['mixer'] ?? '').toString().toLowerCase();
        final operador = (c['operador'] ?? '').toString().toLowerCase();
        final diseno = (c['diseno'] ?? '').toString().toLowerCase();
        final orden = (c['orden_carguio'] ?? '').toString().toLowerCase();
        return cliente.contains(q) ||
            mixer.contains(q) ||
            operador.contains(q) ||
            diseno.contains(q) ||
            orden.contains(q);
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
      _cargarHistorial();
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalVolumen = _filtrados.fold<double>(
      0.0,
      (sum, item) => sum + (double.tryParse(item['volumen']?.toString() ?? '0') ?? 0.0),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Gris claro corporativo
      appBar: AppBar(
        title: const Text(
          'Historial de Carguíos',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF0F172A), // Azul marino
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _cargarHistorial,
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
          // Barra de Filtros de Tiempo
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['Hoy', 'Esta Semana', 'Este Mes', 'Todos'].map((t) {
                        final sel = _filtroTiempo == t;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
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
                            selectedColor: const Color(0xFF1E3A8A), // Azul corporativo
                            backgroundColor: const Color(0xFFF1F5F9),
                            onSelected: (val) {
                              if (val) {
                                setState(() => _filtroTiempo = t);
                                _cargarHistorial();
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
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
                hintText: 'Buscar por cliente, mixer, operador, diseño...',
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
            padding: const EdgeInsets.all(12),
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
                  titulo: 'TOTAL VIAJES',
                  valor: '${_filtrados.length}',
                  icono: Icons.local_shipping,
                ),
                Container(height: 35, width: 1, color: Colors.white24),
                _buildMetrica(
                  titulo: 'VOLUMEN CARGADO',
                  valor: '${totalVolumen.toStringAsFixed(1)} m³',
                  icono: Icons.water_drop,
                ),
                Container(height: 35, width: 1, color: Colors.white24),
                _buildMetrica(
                  titulo: 'FECHA ACTIVA',
                  valor: DateFormat('dd/MM/yyyy').format(_fechaFiltro),
                  icono: Icons.event,
                ),
              ],
            ),
          ),

          // Lista de Carguíos
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
                            Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'No hay registros de carguío en este periodo',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Los viajes cargados en tolva aparecerán automáticamente aquí.',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        itemCount: _filtrados.length,
                        itemBuilder: (context, index) {
                          final c = _filtrados[index];
                          return _buildCarguioCard(c);
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
    required IconData icono,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, color: const Color(0xFF38BDF8), size: 14),
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
        const SizedBox(height: 4),
        Text(
          valor,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCarguioCard(Map<String, dynamic> c) {
    final fechaRaw = c['fecha']?.toString() ?? '';
    final fechaParsed = DateTime.tryParse(fechaRaw)?.toLocal();
    final horaStr = fechaParsed != null ? DateFormat('HH:mm · dd/MM/yyyy').format(fechaParsed) : fechaRaw;

    final cliente = c['cliente']?.toString() ?? 'Cliente no registrado';
    final mixer = c['mixer']?.toString() ?? 'S/Mixer';
    final operador = c['operador']?.toString() ?? 'S/Operador';
    final diseno = c['diseno']?.toString() ?? 'Diseño Estándar';
    final volumen = double.tryParse(c['volumen']?.toString() ?? '0') ?? 0.0;
    final orden = c['orden_carguio']?.toString() ?? '1';

    // Pesos Reales
    final cementoReal = double.tryParse(c['cemento']?.toString() ?? '0') ?? 0.0;
    final arenaReal = double.tryParse(c['arena']?.toString() ?? '0') ?? 0.0;
    final piedra12Real = double.tryParse(c['piedra_12']?.toString() ?? '0') ?? 0.0;
    final piedra34Real = double.tryParse(c['piedra_34']?.toString() ?? '0') ?? 0.0;
    final piedra38Real = double.tryParse(c['piedra_38']?.toString() ?? '0') ?? 0.0;
    final aguaReal = double.tryParse(c['agua']?.toString() ?? '0') ?? 0.0;
    final aditivoReal = double.tryParse(c['aditivo']?.toString() ?? '0') ?? 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: Colors.white,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1E3A8A).withOpacity(0.2)),
            ),
            child: Center(
              child: Text(
                '#$orden',
                style: const TextStyle(
                  color: Color(0xFF1E3A8A),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  cliente,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
            child: Row(
              children: [
                Icon(Icons.local_shipping_outlined, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  mixer,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    operador,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  horaStr.split('·').first.trim(),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          children: [
            const Divider(color: Color(0xFFE2E8F0)),
            // Fila de datos del concreto
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.science_outlined, size: 16, color: Color(0xFF1E3A8A)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Diseño: $diseno',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                  ),
                  Text(
                    'Hora: $horaStr',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Tabla de Dosificación Real cargada en la Tolva
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'DOSIFICACIÓN REAL CARGADA (KG / L)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF475569),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 6),

            Table(
              border: TableBorder.all(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(6)),
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1.5),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(1.5),
              },
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(6),
                      child: Text('Material', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(6),
                      child: Text('Real', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(6),
                      child: Text('Material', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(6),
                      child: Text('Real', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    const Padding(padding: EdgeInsets.all(6), child: Text('Cemento', style: TextStyle(fontSize: 11))),
                    Padding(padding: const EdgeInsets.all(6), child: Text('${cementoReal.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                    const Padding(padding: EdgeInsets.all(6), child: Text('Arena', style: TextStyle(fontSize: 11))),
                    Padding(padding: const EdgeInsets.all(6), child: Text('${arenaReal.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                  ],
                ),
                TableRow(
                  children: [
                    const Padding(padding: EdgeInsets.all(6), child: Text('Piedra 1/2"', style: TextStyle(fontSize: 11))),
                    Padding(padding: const EdgeInsets.all(6), child: Text('${piedra12Real.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                    const Padding(padding: EdgeInsets.all(6), child: Text('Piedra 3/4"', style: TextStyle(fontSize: 11))),
                    Padding(padding: const EdgeInsets.all(6), child: Text('${piedra34Real.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                  ],
                ),
                TableRow(
                  children: [
                    const Padding(padding: EdgeInsets.all(6), child: Text('Piedra 3/8"', style: TextStyle(fontSize: 11))),
                    Padding(padding: const EdgeInsets.all(6), child: Text('${piedra38Real.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                    const Padding(padding: EdgeInsets.all(6), child: Text('Agua', style: TextStyle(fontSize: 11))),
                    Padding(padding: const EdgeInsets.all(6), child: Text('${aguaReal.toStringAsFixed(1)} L', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                  ],
                ),
                TableRow(
                  children: [
                    const Padding(padding: EdgeInsets.all(6), child: Text('Aditivo', style: TextStyle(fontSize: 11))),
                    Padding(padding: const EdgeInsets.all(6), child: Text('${aditivoReal.toStringAsFixed(2)} kg', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                    const Padding(padding: EdgeInsets.all(6), child: Text('Total Tolva', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        '${(cementoReal + arenaReal + piedra12Real + piedra34Real + piedra38Real + aguaReal).toStringAsFixed(0)} kg',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
