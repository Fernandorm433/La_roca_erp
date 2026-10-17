import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_database/services/sunat_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:app_database/core/utils/sunat_pdf_generator.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';

class FacturacionSunatPage extends StatefulWidget {
  const FacturacionSunatPage({super.key});

  @override
  State<FacturacionSunatPage> createState() => _FacturacionSunatPageState();
}

class _FacturacionSunatPageState extends State<FacturacionSunatPage> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final SunatService _sunatService = SunatService();
  late TabController _tabController;
  
  bool _isLoading = false;
  List<dynamic> _pendientes = [];
  List<dynamic> _emitidas = [];
  List<dynamic> _conError = [];
  
  // Métricas
  double _totalPendiente = 0.0;
  double _totalFacturadoMes = 0.0;
  int _cantidadPendientes = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarOrdenesYMetricas();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarOrdenesYMetricas() async {
    setState(() => _isLoading = true);
    try {
      final cotizacionesData = await _supabase
          .from('cotizaciones')
          .select()
          .order('created_at', ascending: false)
          .limit(100);

      final facturasData = await _supabase
          .from('facturacion_sunat')
          .select()
          .order('created_at', ascending: false);
      
      final Map<String, dynamic> facturasPorCotizacion = {};
      for (var f in facturasData) {
        if (f['cotizacion_id'] != null) {
          facturasPorCotizacion[f['cotizacion_id'].toString()] = f;
        }
      }

      double pendiente = 0.0;
      double facturado = 0.0;
      int cantPend = 0;
      List<dynamic> listaPendientes = [];
      List<dynamic> listaEmitidas = [];
      List<dynamic> listaError = [];

      for (var o in cotizacionesData) {
        double total = (o['total'] ?? 0.0).toDouble();
        final factura = facturasPorCotizacion[o['id'].toString()];

        if (factura == null) {
          pendiente += total;
          cantPend++;
          listaPendientes.add(o);
        } else {
          final estadoSunat = (factura['estado_sunat'] ?? '').toString().toUpperCase();
          final map = Map<String, dynamic>.from(o);
          map['factura_data'] = factura;

          if (estadoSunat == 'ACEPTADO') {
            facturado += total;
            listaEmitidas.add(map);
          } else if (estadoSunat == 'ERROR') {
            listaError.add(map);
          } else {
            // PENDIENTE de envío
            pendiente += total;
            cantPend++;
            listaPendientes.add(map);
          }
        }
      }

      setState(() {
        _pendientes = listaPendientes;
        _emitidas = listaEmitidas;
        _conError = listaError;
        _totalPendiente = pendiente;
        _totalFacturadoMes = facturado;
        _cantidadPendientes = cantPend;
      });
    } catch (e) {
      debugPrint("Error cargando facturación: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // PASO 1: GENERAR REGISTRO LOCAL Y DESCARGAR PDF PARA EL CLIENTE
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _prepararYDescargarPdf(Map<String, dynamic> orden) async {
    final cotizacionId = orden['id'].toString();
    var facturaData = orden['factura_data'];

    // Si aún no está registrada localmente, obtener el próximo correlativo de APISUNAT y crearla
    if (facturaData == null) {
      final docCliente = (orden['cliente_documento'] ?? '').toString().trim();
      final tipoDoc = (docCliente.length == 11) ? '01' : '03'; // Factura o Boleta
      final serie = (tipoDoc == '01') ? 'F001' : 'B001';

      final correlativo = await _sunatService.obtenerSiguienteCorrelativo(tipoDoc: tipoDoc, serie: serie);
      final nuevaFactura = await _sunatService.registrarFacturaLocal(
        cotizacionId: cotizacionId,
        tipoDoc: tipoDoc,
        serie: serie,
        correlativo: correlativo,
        montoTotal: (orden['total'] ?? 0.0).toDouble(),
      );

      if (nuevaFactura != null) {
        facturaData = nuevaFactura;
      }
    }

    // Generar PDF preliminar para enviar al cliente
    await _generarPdfLocal(orden, facturaData);
    _cargarOrdenesYMetricas();
  }

  Future<void> _generarPdfLocal(Map<String, dynamic> orden, Map<String, dynamic>? facturaData) async {
    final correlativo = (facturaData != null && facturaData['correlativo'] != null)
        ? facturaData['correlativo'].toString().padLeft(8, '0')
        : '00000000';
    final serie = facturaData?['serie'] ?? 'F001';
    final tipoDoc = facturaData?['tipo_comprobante'] ?? '01';

    final total = (orden['total'] ?? 0.0).toDouble();
    final subtotal = total / 1.18;
    final igv = total - subtotal;
    final volumen = (orden['volumen'] ?? 0.0).toDouble();
    final unitario = volumen > 0 ? (subtotal / volumen) : 0.0;

    final dataPDF = {
      'tipo_doc': tipoDoc,
      'serie_correlativo': '$serie - $correlativo',
      'fecha_emision': DateTime.now().toIso8601String().split('T').first,
      'cliente_nombre': orden['cliente_nombre'] ?? 'CLIENTE GENERAL',
      'cliente_documento': orden['cliente_documento'] ?? orden['documento'] ?? '',
      'cliente_direccion': orden['cliente_direccion'] ?? orden['direccion'] ?? 'AREQUIPA',
      'descripcion': 'CONCRETO PREMEZCLADO\\nRESISTENCIA ${orden['resistencia'] ?? '210'} KG/CM2',
      'volumen': volumen.toStringAsFixed(2),
      'unitario': unitario.toStringAsFixed(2),
      'total_item': subtotal.toStringAsFixed(2),
      'subtotal': subtotal,
      'igv': igv,
      'total': total,
    };

    try {
      final pdfBytes = await SunatPdfGenerator.generarFactura(dataPDF);
      await Printing.sharePdf(bytes: pdfBytes, filename: '${serie}_$correlativo.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generando PDF: $e')));
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // PASO 2: ENVIAR A SUNAT (AL FINAL DEL DÍA O POR BOTÓN INDIVIDUAL)
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _enviarASunat(Map<String, dynamic> orden) async {
    final cotizacionId = orden['id'].toString();
    var facturaData = orden['factura_data'];

    // Asegurar que exista el registro en la tabla facturacion_sunat antes de enviar
    if (facturaData == null) {
      final docCliente = (orden['cliente_documento'] ?? '').toString().trim();
      final tipoDoc = (docCliente.length == 11) ? '01' : '03';
      final serie = (tipoDoc == '01') ? 'F001' : 'B001';

      final correlativo = await _sunatService.obtenerSiguienteCorrelativo(tipoDoc: tipoDoc, serie: serie);
      facturaData = await _sunatService.registrarFacturaLocal(
        cotizacionId: cotizacionId,
        tipoDoc: tipoDoc,
        serie: serie,
        correlativo: correlativo,
        montoTotal: (orden['total'] ?? 0.0).toDouble(),
      );
    }

    if (facturaData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo inicializar la factura'), backgroundColor: Colors.red),
      );
      return;
    }

    final facturaId = facturaData['id'].toString();

    // Diálogo de confirmación de envío
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.cloud_upload_rounded, color: AppColors.primary, size: 28),
            SizedBox(width: 12),
            Text('Enviar a SUNAT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          '¿Estás seguro de enviar la ${facturaData['serie']}-${facturaData['correlativo']} a SUNAT en PRODUCCIÓN?\\n\\n'
          'Esta acción generará valor tributario oficial.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Sí, Enviar a SUNAT'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    // Mostrar diálogo de carga no cancelable
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text('Firmando y enviando a SUNAT...', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Validando con APISUNAT', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
    );

    final res = await _sunatService.enviarFacturaASunat(facturaId);

    if (mounted) Navigator.pop(context); // Cerrar diálogo de carga

    if (res['exito'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text(res['mensaje'] ?? 'Comprobante Aceptado por SUNAT')),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      _cargarOrdenesYMetricas();
    } else {
      // Mostrar ventana de error detallada
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.error_outline_rounded, color: AppColors.error, size: 28),
                SizedBox(width: 12),
                Text('Rechazado por SUNAT', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SUNAT no pudo validar el comprobante debido al siguiente motivo:', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    res['mensaje'] ?? 'Error desconocido',
                    style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Puedes corregir los datos de la cotización o cliente y volver a presionar "Enviar a SUNAT".', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Entendido / Corregir'),
              ),
            ],
          ),
        );
      }
      _cargarOrdenesYMetricas();
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ABRIR PDF OFICIAL GENERADO POR APISUNAT
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _abrirPdfOficial(Map<String, dynamic> orden) async {
    final facturaData = orden['factura_data'] ?? {};
    final pdfUrl = facturaData['pdf_url'];

    if (pdfUrl != null && pdfUrl.toString().isNotEmpty) {
      final uri = Uri.parse(pdfUrl.toString());
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    // Si no está disponible la URL de APISUNAT, generar PDF local como respaldo
    _generarPdfLocal(orden, facturaData);
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 250,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.grey, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(color: AppColors.primaryDark, fontSize: 20, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          )
        ],
      ),
    ).animate().fade().slideY(begin: 0.1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // HEADER Y MÉTRICAS
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.greyBorder)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.blueLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 30),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tesorería & Facturación', style: TextStyle(color: AppColors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                        Text('Comprobantes SUNAT (APISUNAT)', style: TextStyle(color: AppColors.primaryDark, fontSize: 22, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const Spacer(),
                    // Badge de Producción
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.check_circle_rounded, color: AppColors.success, size: 14),
                          SizedBox(width: 6),
                          Text('PRODUCCIÓN ACTIVA', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ).animate().fade().slideX(),
                const SizedBox(height: 20),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildMetricCard('Pendientes de Envío', 'S/ ${_totalPendiente.toStringAsFixed(2)}', Icons.hourglass_empty_rounded, AppColors.warning),
                      _buildMetricCard('Facturado Aceptado', 'S/ ${_totalFacturadoMes.toStringAsFixed(2)}', Icons.check_circle_outline_rounded, AppColors.success),
                      _buildMetricCard('Órdenes por Facturar', '$_cantidadPendientes', Icons.receipt_rounded, AppColors.primary),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.grey,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  tabs: [
                    Tab(text: 'Pendientes (${_pendientes.length})'),
                    Tab(text: 'Aceptadas SUNAT (${_emitidas.length})'),
                    Tab(text: 'Con Error (${_conError.length})'),
                  ],
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: PENDIENTES DE ENVÍO
                      _pendientes.isEmpty 
                          ? _buildEmptyState("Todo al día", "No hay comprobantes pendientes de emisión.", Icons.check_circle_outline, AppColors.success)
                          : _buildListaPendientes(),

                      // TAB 2: ACEPTADAS POR SUNAT
                      _emitidas.isEmpty 
                          ? _buildEmptyState("Sin comprobantes aceptados", "Aún no se han enviado comprobantes aprobados por SUNAT hoy.", Icons.receipt_long_outlined, AppColors.grey)
                          : _buildListaEmitidas(),

                      // TAB 3: CON ERROR O RECHAZADAS
                      _conError.isEmpty 
                          ? _buildEmptyState("Sin errores", "No hay comprobantes rechazados ni con errores.", Icons.thumb_up_alt_outlined, AppColors.success)
                          : _buildListaErrores(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String titulo, String subtitulo, IconData icon, Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: color),
          const SizedBox(height: 16),
          Text(titulo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
          const SizedBox(height: 6),
          Text(subtitulo, style: const TextStyle(color: AppColors.grey, fontSize: 14)),
        ],
      ).animate().fade(),
    );
  }

  Widget _buildListaPendientes() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: _pendientes.length,
      itemBuilder: (context, index) {
        final orden = _pendientes[index];
        final nroOrden = orden['numero'] ?? orden['id'].toString().substring(0, 8);
        final monto = (orden['total'] ?? 0.0).toDouble();
        final facturaData = orden['factura_data'];
        final tieneRegistroLocal = facturaData != null;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.greyBorder),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.pending_actions_rounded, color: AppColors.warning, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('ORDEN #$nroOrden', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.primaryDark)),
                          Text('S/ ${monto.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.primary)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(orden['cliente_nombre'] ?? 'Sin cliente', style: const TextStyle(color: AppColors.greyDark, fontSize: 14, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _badge(tieneRegistroLocal ? 'BORRADOR CREADO' : 'LISTO PARA EMITIR', AppColors.accent),
                          const SizedBox(width: 8),
                          _badge('Volumen: ${orden['volumen'] ?? 0} m³', AppColors.grey),
                          if (facturaData != null) ...[
                            const SizedBox(width: 8),
                            _badge('${facturaData['serie']}-${facturaData['correlativo']}', AppColors.primaryDark),
                          ],
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Botón 1: Descargar PDF para el cliente
                    OutlinedButton.icon(
                      onPressed: () => _prepararYDescargarPdf(orden),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                      label: const Text('Descargar PDF'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Botón 2: Enviar a SUNAT (al final del día o cuando se verifique)
                    ElevatedButton.icon(
                      onPressed: () => _enviarASunat(orden),
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text('Enviar a SUNAT'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ).animate().fade(delay: Duration(milliseconds: 40 * index)).slideY(begin: 0.05);
      },
    );
  }

  Widget _buildListaEmitidas() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: _emitidas.length,
      itemBuilder: (context, index) {
        final orden = _emitidas[index];
        final facturaData = orden['factura_data'] ?? {};
        final nroOrden = orden['numero'] ?? orden['id'].toString().substring(0, 8);
        final monto = (orden['total'] ?? 0.0).toDouble();
        final correlativo = facturaData['correlativo'] ?? '00000000';
        final serie = facturaData['serie'] ?? 'F001';

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$serie-$correlativo', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.primaryDark)),
                          Text('S/ ${monto.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.success)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('ORDEN #$nroOrden · ${orden['cliente_nombre'] ?? 'Sin cliente'}', style: const TextStyle(color: AppColors.greyDark, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _badge('ACEPTADO POR SUNAT', AppColors.success),
                          const SizedBox(width: 8),
                          if (facturaData['created_at'] != null)
                            _badge(facturaData['created_at'].toString().split('T').first, AppColors.grey),
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _abrirPdfOficial(orden),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                  label: const Text('Ver PDF SUNAT'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blueLight,
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    side: const BorderSide(color: AppColors.accent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )
              ],
            ),
          ),
        ).animate().fade(delay: Duration(milliseconds: 40 * index)).slideY(begin: 0.05);
      },
    );
  }

  Widget _buildListaErrores() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: _conError.length,
      itemBuilder: (context, index) {
        final orden = _conError[index];
        final facturaData = orden['factura_data'] ?? {};
        final nroOrden = orden['numero'] ?? orden['id'].toString().substring(0, 8);
        final monto = (orden['total'] ?? 0.0).toDouble();
        final mensajeError = facturaData['mensaje_sunat'] ?? 'Error desconocido';

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('ORDEN #$nroOrden', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.error)),
                          Text('S/ ${monto.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.error)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(orden['cliente_nombre'] ?? 'Sin cliente', style: const TextStyle(color: AppColors.greyDark, fontSize: 13)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
                        child: Text(mensajeError, style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _enviarASunat(orden),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Reintentar Envío'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )
              ],
            ),
          ),
        ).animate().fade(delay: Duration(milliseconds: 40 * index)).slideY(begin: 0.05);
      },
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
