import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';

class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key});

  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  
  // --- SECCIÓN COBRANZAS (Cotizaciones) ---
  Map<String, List<Map<String, dynamic>>> _facturasPorCliente = {};
  Map<String, List<Map<String, dynamic>>> _otrosPorCliente = {};
  Map<String, List<Map<String, dynamic>>> _facturasFiltradas = {};
  Map<String, List<Map<String, dynamic>>> _otrosFiltrados = {};

  // --- SECCIÓN DESPACHOS GENERALES (Ventas Programación) ---
  List<Map<String, dynamic>> _facturadosVentasAll = [];
  List<Map<String, dynamic>> _recibosVentasAll = [];
  List<Map<String, dynamic>> _facturadosVentasFiltrados = [];
  List<Map<String, dynamic>> _recibosVentasFiltrados = [];

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 4 Tabs: 2 de Cobranzas, 2 de Despachos
    _tabController = TabController(length: 4, vsync: this);
    _searchCtrl.addListener(_onSearchChanged);
    _cargarTodaLaData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      // Filtrar Cobranzas
      _facturasFiltradas = _filtrarMapaCotizaciones(_facturasPorCliente, query);
      _otrosFiltrados = _filtrarMapaCotizaciones(_otrosPorCliente, query);

      // Filtrar Despachos (Antiguo)
      _facturadosVentasFiltrados = _facturadosVentasAll.where((c) {
        final nombre = (c['nombre_razon_social'] ?? '').toString().toLowerCase();
        final doc = (c['dni_ruc'] ?? '').toString().toLowerCase();
        return nombre.contains(query) || doc.contains(query);
      }).toList();

      _recibosVentasFiltrados = _recibosVentasAll.where((c) {
        final nombre = (c['nombre_razon_social'] ?? '').toString().toLowerCase();
        final doc = (c['dni_ruc'] ?? '').toString().toLowerCase();
        return nombre.contains(query) || doc.contains(query);
      }).toList();
    });
  }

  Map<String, List<Map<String, dynamic>>> _filtrarMapaCotizaciones(Map<String, List<Map<String, dynamic>>> mapa, String query) {
    if (query.isEmpty) return mapa;
    
    Map<String, List<Map<String, dynamic>>> filtrado = {};
    for (var entry in mapa.entries) {
      final cliente = entry.key.toLowerCase();
      final tieneDoc = entry.value.any((c) => (c['cliente_documento'] ?? '').toString().toLowerCase().contains(query));
      
      if (cliente.contains(query) || tieneDoc) {
        filtrado[entry.key] = entry.value;
      }
    }
    return filtrado;
  }

  Future<void> _cargarTodaLaData() async {
    setState(() => _loading = true);
    await Future.wait([
      _fetchCotizaciones(),
      _fetchClientesVentas(),
    ]);
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchCotizaciones() async {
    try {
      final res = await Supabase.instance.client
          .from('cotizaciones')
          .select()
          .order('fecha', ascending: false);

      Map<String, List<Map<String, dynamic>>> facturasMap = {};
      Map<String, List<Map<String, dynamic>>> otrosMap = {};

      for (var row in res) {
        final nombreRaw = row['cliente_nombre'];
        if (nombreRaw == null || nombreRaw.toString().trim().isEmpty) continue;
        
        final nombre = nombreRaw.toString().trim().toUpperCase();
        final tipo = (row['tipo_comprobante'] ?? '').toString().trim().toUpperCase();
        
        if (tipo.contains('FACTURA') || tipo == 'FACTURA') {
           facturasMap.putIfAbsent(nombre, () => []);
           facturasMap[nombre]!.add(row);
        } else {
           otrosMap.putIfAbsent(nombre, () => []);
           otrosMap[nombre]!.add(row);
        }
      }

      if (mounted) {
        setState(() {
          _facturasPorCliente = facturasMap;
          _otrosPorCliente = otrosMap;
          _facturasFiltradas = facturasMap;
          _otrosFiltrados = otrosMap;
        });
      }
    } catch (e) {
      debugPrint('Error Cotizaciones: $e');
    }
  }

  Future<void> _fetchClientesVentas() async {
    try {
      final res = await Supabase.instance.client
          .from('ventas_programacion')
          .select('nombre_razon_social, tipo_documento, dni_ruc, telefono, direccion, distrito, fecha_entrega')
          .order('fecha_entrega', ascending: false);

      List<Map<String, dynamic>> facturas = [];
      List<Map<String, dynamic>> recibos = [];
      Set<String> processedFacturas = {};
      Set<String> processedRecibos = {};

      for (var row in res) {
        final nombreRaw = row['nombre_razon_social'];
        if (nombreRaw == null || nombreRaw.toString().trim().isEmpty) continue;
        
        final nombre = nombreRaw.toString().trim().toUpperCase();
        final tipo = (row['tipo_documento'] ?? '').toString().trim().toUpperCase();
        
        if (tipo.contains('FACTURA') || tipo == 'FACTURA') {
           if (!processedFacturas.contains(nombre)) {
             processedFacturas.add(nombre);
             facturas.add(row);
           }
        } else if (tipo.contains('RECIBO') || tipo == 'RECIBO') {
           if (!processedRecibos.contains(nombre)) {
             processedRecibos.add(nombre);
             recibos.add(row);
           }
        }
      }

      if (mounted) {
        setState(() {
          _facturadosVentasAll = facturas;
          _recibosVentasAll = recibos;
          _facturadosVentasFiltrados = facturas;
          _recibosVentasFiltrados = recibos;
        });
      }
    } catch (e) {
      debugPrint('Error Ventas: $e');
    }
  }

  Future<void> _registrarAbono(Map<String, dynamic> cotizacion, double abono, BuildContext ctx) async {
    final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    final total = double.tryParse(cotizacion['total']?.toString() ?? '0') ?? 0;
    final pagadoActual = double.tryParse(cotizacion['monto_pagado']?.toString() ?? '0') ?? 0;
    
    final nuevoPagado = pagadoActual + abono;
    String nuevoEstado = 'SALDO PENDIENTE';
    if (nuevoPagado >= total) {
      nuevoEstado = 'CANCELADO';
    }

    try {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primaryDark)));

      await Supabase.instance.client.from('cotizaciones').update({
        'monto_pagado': nuevoPagado,
        'estado_pago': nuevoEstado,
      }).eq('id', cotizacion['id']);

      final numCot = cotizacion['numero_cotizacion'] ?? 'S/N';
      final cliente = cotizacion['cliente_nombre'] ?? 'Desconocido';
      
      await Supabase.instance.client.from('tesoreria_caja').insert({
        'fecha': DateTime.now().toIso8601String().substring(0, 10),
        'tipo': 'INGRESO',
        'monto': abono,
        'descripcion': 'Abono Cotización $numCot - Cliente: $cliente',
      });

      if (mounted) {
        Navigator.pop(ctx); 
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Abono registrado con éxito por ${fmt.format(abono)}. Enviado a Tesorería Caja.'), backgroundColor: Colors.green));
        _cargarTodaLaData(); 
      }
    } catch (e) {
      debugPrint('Error al registrar abono: $e');
      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al procesar abono.'), backgroundColor: Colors.red));
      }
    }
  }

  void _mostrarDialogoAbono(Map<String, dynamic> cotizacion) {
    final total = double.tryParse(cotizacion['total']?.toString() ?? '0') ?? 0;
    final pagadoActual = double.tryParse(cotizacion['monto_pagado']?.toString() ?? '0') ?? 0;
    final deuda = total - pagadoActual;
    final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);

    final _abonoCtrl = TextEditingController(text: deuda.toStringAsFixed(2));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.payments_outlined, color: AppColors.accent, size: 28),
                    const SizedBox(width: 12),
                    const Text('Registrar Abono', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Cotización: ${cotizacion['numero_cotizacion'] ?? 'S/N'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Cliente: ${cotizacion['cliente_nombre'] ?? ''}'),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Precio Total:', style: TextStyle(color: Colors.grey)),
                    Text(fmt.format(total), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Pagado Hasta Ahora:', style: TextStyle(color: Colors.grey)),
                    Text(fmt.format(pagadoActual), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Saldo Pendiente:', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    Text(fmt.format(deuda), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _abonoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Monto a Abonar (S/)',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.monetization_on_outlined, color: AppColors.primaryDark),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      final val = double.tryParse(_abonoCtrl.text.replaceAll(',', '')) ?? 0;
                      if (val <= 0) return;
                      _registrarAbono(cotizacion, val, ctx);
                    },
                    child: const Text('Confirmar Abono y Enviar a Tesorería', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                )
              ],
            ),
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cartera de Clientes y Cobranzas'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppColors.accent,
          indicatorWeight: 4,
          isScrollable: true,
          tabs: [
            Tab(icon: const Icon(Icons.account_balance_wallet), text: 'FACTURA (Cot) (${_facturasFiltradas.length})'),
            Tab(icon: const Icon(Icons.account_balance_wallet_outlined), text: 'RECIBO (Cot) (${_otrosFiltrados.length})'),
            Tab(icon: const Icon(Icons.local_shipping), text: 'FACTURA (${_facturadosVentasFiltrados.length})'),
            Tab(icon: const Icon(Icons.local_shipping_outlined), text: 'RECIBO (${_recibosVentasFiltrados.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Barra de búsqueda dinámica
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por cliente o documento...',
                prefixIcon: const Icon(Icons.search, color: AppColors.primaryDark),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchCtrl.clear();
                          FocusScope.of(context).unfocus();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryDark))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildListaCobranzasAgrupada(_facturasFiltradas),
                      _buildListaCobranzasAgrupada(_otrosFiltrados),
                      _buildListaClientesVentas(_facturadosVentasFiltrados),
                      _buildListaClientesVentas(_recibosVentasFiltrados),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // UI COBRANZAS (COTIZACIONES)
  // =========================================================================

  Widget _buildListaCobranzasAgrupada(Map<String, List<Map<String, dynamic>>> clientesMap) {
    if (clientesMap.isEmpty) return _buildEmptyState('No hay cobranzas pendientes en esta categoría.');

    final clientesNombres = clientesMap.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: clientesNombres.length,
      itemBuilder: (context, index) {
        final nombre = clientesNombres[index];
        final cotizaciones = clientesMap[nombre]!;
        final documento = cotizaciones.first['cliente_documento'] ?? 'S/N Doc';
        
        double deudaGlobal = 0;
        int cancelados = 0;
        for (var c in cotizaciones) {
          final t = double.tryParse(c['total']?.toString() ?? '0') ?? 0;
          final p = double.tryParse(c['monto_pagado']?.toString() ?? '0') ?? 0;
          deudaGlobal += (t - p);
          if (p >= t && t > 0) cancelados++;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: Colors.black12,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryDark.withValues(alpha: 0.1),
                child: const Icon(Icons.business, color: AppColors.primaryDark),
              ),
              title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Text('Doc: $documento | Ctz: ${cotizaciones.length} | Pagadas: $cancelados', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Deuda', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(
                    NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2).format(deudaGlobal),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: deudaGlobal <= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
              children: [
                Container(
                  color: Colors.grey[50],
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cotizaciones.length,
                    itemBuilder: (ctx, idx) => _buildCotizacionTile(cotizaciones[idx]),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCotizacionTile(Map<String, dynamic> cot) {
    final numCot = cot['numero_cotizacion'] ?? 'S/N';
    final total = double.tryParse(cot['total']?.toString() ?? '0') ?? 0;
    final pagado = double.tryParse(cot['monto_pagado']?.toString() ?? '0') ?? 0;
    final estado = cot['estado_pago'] ?? 'POR CANCELAR';
    final fecha = cot['fecha'] != null ? DateTime.tryParse(cot['fecha']) : null;
    final fechaStr = fecha != null ? DateFormat('dd MMM yyyy').format(fecha) : '';

    final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);

    Color colorEstado = Colors.red;
    IconData iconEstado = Icons.warning_amber_rounded;
    if (estado == 'CANCELADO' || pagado >= total) {
      colorEstado = Colors.green;
      iconEstado = Icons.check_circle;
    } else if (estado == 'SALDO PENDIENTE' || pagado > 0) {
      colorEstado = Colors.amber.shade700;
      iconEstado = Icons.hourglass_bottom;
    }

    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.request_quote_outlined, color: Colors.blueGrey, size: 18),
              const SizedBox(width: 8),
              Text(numCot, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              Text(fechaStr, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetric('Total', fmt.format(total), Colors.black87),
              _buildMetric('Pagado', fmt.format(pagado), Colors.green),
              _buildMetric('Resta', fmt.format(total - pagado), Colors.red),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorEstado.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorEstado.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(iconEstado, size: 14, color: colorEstado),
                    const SizedBox(width: 6),
                    Text(estado, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorEstado)),
                  ],
                ),
              ),
              if (pagado < total)
                ElevatedButton.icon(
                  onPressed: () => _mostrarDialogoAbono(cot),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Abono'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    minimumSize: const Size(0, 36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }

  // =========================================================================
  // UI DESPACHOS GENERALES (VENTAS)
  // =========================================================================

  Widget _buildListaClientesVentas(List<Map<String, dynamic>> clientes) {
    if (clientes.isEmpty) return _buildEmptyState('No se encontraron clientes de despachos.');

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: clientes.length,
      itemBuilder: (context, index) {
        final c = clientes[index];
        final nombre = c['nombre_razon_social'] ?? 'Sin Nombre';
        final doc = c['dni_ruc'] ?? 'S/N Doc';
        final telefono = c['telefono'] ?? 'Sin teléfono';
        final direccion = c['direccion'] ?? 'Sin dirección';
        final distrito = c['distrito'] ?? '';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primaryDark.withValues(alpha: 0.1),
                  child: const Icon(Icons.business, color: AppColors.primaryDark),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 6),
                      _infoRow(Icons.badge_outlined, doc),
                      const SizedBox(height: 4),
                      _infoRow(Icons.phone_outlined, telefono),
                      const SizedBox(height: 4),
                      _infoRow(Icons.location_on_outlined, '$direccion ${distrito.isNotEmpty ? ' - $distrito' : ''}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 13, color: Colors.grey[700]), overflow: TextOverflow.ellipsis, maxLines: 2),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(msg, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
        ],
      ),
    );
  }
}
