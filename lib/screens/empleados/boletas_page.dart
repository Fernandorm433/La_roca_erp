import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';

class BoletasPage extends StatefulWidget {
  final String empleadoId;
  const BoletasPage({super.key, required this.empleadoId});

  @override
  State<BoletasPage> createState() => _BoletasPageState();
}

class _BoletasPageState extends State<BoletasPage> {
  final _supabase = Supabase.instance.client;
  List<FileObject> _boletas = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchBoletas();
  }

  Future<void> _fetchBoletas() async {
    try {
      final List<FileObject> objects = await _supabase.storage.from('boletas').list();
      
      // Filtrar boletas del usuario: formato esperado boleta_{empleadoId}_{mesAnio}.pdf
      final userBoletas = objects.where((obj) => obj.name.contains(widget.empleadoId) && obj.name.endsWith('.pdf')).toList();
      
      // Ordenar por nombre descendente (asumiendo que el nombre tiene el mes/año)
      userBoletas.sort((a, b) => b.name.compareTo(a.name));

      if (mounted) {
        setState(() {
          _boletas = userBoletas;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetch boletas: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _descargarBoleta(String fileName) async {
    try {
      final url = _supabase.storage.from('boletas').getPublicUrl(fileName);
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'No se pudo abrir el enlace';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al descargar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String _formatearNombreMes(String filename) {
    // boleta_id_YYYY-MM.pdf -> extraer YYYY-MM
    final regex = RegExp(r'(\d{4}-\d{2})');
    final match = regex.firstMatch(filename);
    if (match != null) {
      final dateStr = match.group(0)!; // 2026-05
      final parts = dateStr.split('-');
      if (parts.length == 2) {
        const meses = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
        int? m = int.tryParse(parts[1]);
        if (m != null && m >= 1 && m <= 12) {
          return '${meses[m - 1]} ${parts[0]}';
        }
      }
    }
    return filename;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Mis Boletas de Pago', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _boletas.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _boletas.length,
                  itemBuilder: (context, index) {
                    final boleta = _boletas[index];
                    final isActual = index == 0;
                    final nombreFormateado = _formatearNombreMes(boleta.name);

                    return _buildBoletaCard(boleta.name, nombreFormateado, isActual);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No hay boletas disponibles',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'RRHH aún no ha subido tus boletas de pago.',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildBoletaCard(String fileName, String nombreFormateado, bool isActual) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _descargarBoleta(fileName),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isActual
                          ? [AppColors.accent, AppColors.primary]
                          : [Colors.grey.shade300, Colors.grey.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombreFormateado,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isActual ? 'Última boleta' : 'Boleta archivada',
                        style: TextStyle(
                          color: isActual ? AppColors.accent : AppColors.grey,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.celesteLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.download_rounded, color: AppColors.primary, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
