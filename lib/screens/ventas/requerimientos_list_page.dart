import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';

class RequerimientosListPage extends StatefulWidget {
  const RequerimientosListPage({super.key});

  @override
  State<RequerimientosListPage> createState() => _RequerimientosListPageState();
}

class _RequerimientosListPageState extends State<RequerimientosListPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _requerimientos = [];
  List<Map<String, dynamic>> _filtrados = [];
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _fetchRequerimientos();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filtrados = _requerimientos.where((c) {
        final nombre = (c['cliente_nombre'] ?? '').toString().toLowerCase();
        final doc = (c['cliente_documento'] ?? '').toString().toLowerCase();
        final numCot = (c['numero_cotizacion'] ?? '').toString().toLowerCase();
        return nombre.contains(query) || doc.contains(query) || numCot.contains(query);
      }).toList();
    });
  }

  Future<void> _fetchRequerimientos() async {
    try {
      // Obtenemos solo las cotizaciones que ya fueron convertidas a requerimientos
      // Según el flujo, el estado cambia a "enviada" cuando se crea el requerimiento.
      final res = await Supabase.instance.client
          .from('cotizaciones')
          .select()
          .eq('estado', 'enviada')
          .order('fecha', ascending: false);

      if (mounted) {
        setState(() {
          _requerimientos = List<Map<String, dynamic>>.from(res);
          _filtrados = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error Requerimientos: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Requerimientos Activos'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
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
                hintText: 'Buscar cliente, cotización o DNI/RUC...',
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
                : _buildListaRequerimientos(),
          ),
        ],
      ),
    );
  }

  Widget _buildListaRequerimientos() {
    if (_filtrados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.precision_manufacturing_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No hay requerimientos activos.',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Las cotizaciones enviadas aparecerán aquí.',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _filtrados.length,
      itemBuilder: (context, index) {
        final req = _filtrados[index];
        final cliente = req['cliente_nombre'] ?? 'Sin Cliente';
        final doc = req['cliente_documento'] ?? 'S/N Doc';
        final numCot = req['numero_cotizacion'] ?? 'S/N Cot';
        final direccion = req['obra_direccion'] ?? 'Sin Dirección';
        final distrito = req['obra_distrito'] ?? '';
        final horaReq = req['hora_entrega'] != null ? DateTime.tryParse(req['hora_entrega']) : null;
        final horaStr = horaReq != null ? DateFormat('dd MMM yyyy - hh:mm a').format(horaReq.toLocal()) : 'Sin hora programada';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          elevation: 3,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.primaryDark.withValues(alpha: 0.1), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.request_quote_outlined, size: 14, color: Colors.blue.shade700),
                          const SizedBox(width: 4),
                          Text(numCot, style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
                          const SizedBox(width: 4),
                          Text('EN PRODUCCIÓN', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primaryDark.withValues(alpha: 0.05),
                      child: const Icon(Icons.business_center, color: AppColors.primaryDark, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cliente, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                          const SizedBox(height: 4),
                          Text('RUC/DNI: $doc', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _infoRow(Icons.location_on_outlined, '$direccion ${distrito.isNotEmpty ? ' - $distrito' : ''}'),
                const SizedBox(height: 8),
                _infoRow(Icons.access_time, 'Entrega Prog: $horaStr', color: AppColors.accent),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String text, {Color? color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color ?? Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text, 
            style: TextStyle(fontSize: 13, color: color ?? Colors.grey[700], fontWeight: color != null ? FontWeight.bold : FontWeight.normal), 
            overflow: TextOverflow.ellipsis, 
            maxLines: 2
          ),
        ),
      ],
    );
  }
}
