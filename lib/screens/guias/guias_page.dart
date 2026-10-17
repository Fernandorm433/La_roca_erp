import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../logistica/guia_pdf_preview.dart';
import '../logistica/cierre_diario_service.dart';

class GuiasDespachoPage extends StatefulWidget {
  const GuiasDespachoPage({super.key});

  @override
  State<GuiasDespachoPage> createState() => _GuiasDespachoPageState();
}

class _FilaGuiaData {
  String? id;
  String ordenCarga;
  String numeroGuia;
  String numeroCarguioCA;
  double volumen;
  String operadorNombre;
  String codigoMixer;
  String estado;
  String precinto;
  String horaSalida;
  
  TextEditingController numCtrl; 
  TextEditingController precCtrl; 
  TextEditingController hsCtrl; 
  
  FocusNode numFocus;
  FocusNode precFocus;
  FocusNode hsFocus;

  _FilaGuiaData({
    this.id,
    required this.ordenCarga,
    required this.numeroGuia,
    required this.numeroCarguioCA,
    required this.volumen,
    this.operadorNombre = '',
    this.codigoMixer = '',
    this.estado = 'Pendiente',
    this.precinto = '',
    this.horaSalida = '',
  })  : numCtrl = TextEditingController(text: numeroGuia),
        precCtrl = TextEditingController(text: precinto),
        hsCtrl = TextEditingController(text: horaSalida),
        numFocus = FocusNode(),
        precFocus = FocusNode(),
        hsFocus = FocusNode();

  void dispose() {
    numCtrl.dispose();
    precCtrl.dispose();
    hsCtrl.dispose();
    numFocus.dispose();
    precFocus.dispose();
    hsFocus.dispose();
  }
}

class _GuiasDespachoPageState extends State<GuiasDespachoPage> {
  final supabase = Supabase.instance.client;
  bool loading = true;
  bool cerrando = false;
  DateTime fechaSeleccionada = DateTime.now();
  bool diaCerrado = false;

  List<Map<String, dynamic>> ventas = [];
  Map<String, List<_FilaGuiaData>> carguiosPorVenta = {};
  Map<String, String> bombasPorVenta = {};

  Map<String, TextEditingController> opCtrls = {}; 
  Map<String, FocusNode> opFocus = {};

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    for (var list in carguiosPorVenta.values) {
      for (var c in list) { c.dispose(); }
    }
    for (var c in opCtrls.values) { c.dispose(); }
    for (var f in opFocus.values) { f.dispose(); }
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => loading = true);
    String fechaFiltro = fechaSeleccionada.toIso8601String().split('T')[0];

    try {
      diaCerrado = await CierreDiarioService.isDiaCerrado(fechaFiltro);

      final ventasDataRaw = await supabase
          .from("ventas_programacion")
          .select()
          .eq('fecha_entrega', fechaFiltro)
          .order("hora_entrega", ascending: true);

      final ventasData = ventasDataRaw.where((v) => v['numero_atencion']?.toString() != '0').toList();

      final asignaciones = await supabase.from("asignacion_bombas").select();
      Map<String, String> mapaBombas = {};
      for (var a in asignaciones) {
        mapaBombas[a['id_venta'].toString()] = a['bomba_asignada'].toString();
      }

      List<dynamic> carguiosData = [];
      try {
        carguiosData = await supabase.from("carguios_mixers").select();
      } catch (e) {
        debugPrint("Error al cargar carguios_mixers: $e");
      }

      Map<String, List<_FilaGuiaData>> agrupados = {};
      for (var c in carguiosData) {
        String idVenta = c['id_venta'].toString();
        if (!agrupados.containsKey(idVenta)) agrupados[idVenta] = [];
        agrupados[idVenta]!.add(_FilaGuiaData(
          id: c['id'].toString(),
          ordenCarga: c['orden_carga']?.toString() ?? '',
          numeroGuia: c['nro_guia']?.toString() ?? '', 
          numeroCarguioCA: c['numero_carguio']?.toString() ?? '',
          volumen: double.tryParse(c['volumen_carguio'].toString()) ?? 0.0,
          operadorNombre: c['operador_nombre']?.toString() ?? '',
          codigoMixer: c['codigo_mixer']?.toString() ?? '',
          estado: c['estado']?.toString() ?? 'Pendiente',
          precinto: c['precinto']?.toString() ?? '',
          horaSalida: c['hora_salida']?.toString() ?? '',
        ));
      }

      agrupados.forEach((key, list) {
        list.sort((a, b) {
          int aOrd = int.tryParse(a.ordenCarga) ?? 9999;
          int bOrd = int.tryParse(b.ordenCarga) ?? 9999;
          if (aOrd != bOrd) return aOrd.compareTo(bOrd);
          return (a.id ?? '').compareTo(b.id ?? '');
        });
      });

      for (var v in ventasData) {
        String idV = _obtenerIdSeguro(v);
        
        bool isRecibo = v['tipo_documento']?.toString().toUpperCase() == 'RECIBO';
        String opGuardada = v['orden_pedido']?.toString() ?? '';

        if (!opCtrls.containsKey(idV)) {
          opCtrls[idV] = TextEditingController(text: opGuardada);
          opFocus[idV] = FocusNode();
          opFocus[idV]!.addListener(() {
            if (!opFocus[idV]!.hasFocus) {
              _guardarOP(idV, v);
            }
          });
        }
        
        if (isRecibo && (opGuardada.isEmpty || opGuardada.toUpperCase() == 'PENDIENTE')) {
          if (!diaCerrado) {
            String newOP = await _generarOP();
            opCtrls[idV]!.text = newOP;
            v['orden_pedido'] = newOP;
            await supabase.from('ventas_programacion').update({'orden_pedido': newOP}).eq('id', idV);
          }
        }
        
        if (agrupados.containsKey(idV)) {
           for (var f in agrupados[idV]!) {
              f.numFocus.addListener(() { if (!f.numFocus.hasFocus) _guardarFilaUnica(f); });
              f.precFocus.addListener(() { if (!f.precFocus.hasFocus) _guardarFilaUnica(f); });
              f.hsFocus.addListener(() { if (!f.hsFocus.hasFocus) _guardarFilaUnica(f); });
           }
        }
      }

      if (mounted) {
        setState(() {
          ventas = List<Map<String, dynamic>>.from(ventasData);
          carguiosPorVenta = agrupados;
          bombasPorVenta = mapaBombas;
          loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  String _obtenerIdSeguro(Map<String, dynamic> v) {
    String id = v['id']?.toString() ?? '';
    if (id.isEmpty || id == 'null') id = v['numero_atencion']?.toString() ?? '';
    return id;
  }

  Future<String> _generarOP() async {
    int ano = DateTime.now().year;
    String prefix = 'OP-$ano-';
    try {
      final res = await supabase
          .from('ventas_programacion')
          .select('orden_pedido')
          .like('orden_pedido', '$prefix%')
          .order('orden_pedido', ascending: false)
          .limit(1)
          .maybeSingle();
      
      if (res != null && res['orden_pedido'] != null) {
        String lastOP = res['orden_pedido'];
        int num = int.tryParse(lastOP.split('-').last) ?? 3699;
        return '$prefix${num + 1}';
      }
    } catch (e) {
      debugPrint("Error buscando ultima OP: $e");
    }
    return '${prefix}3700'; 
  }
  
  Future<void> _guardarOP(String idVenta, Map<String, dynamic> v) async {
    if (diaCerrado) return;
    final nuevaOP = opCtrls[idVenta]!.text.trim();
    if (nuevaOP != (v['orden_pedido']?.toString() ?? '')) {
      try {
        await supabase.from('ventas_programacion').update({'orden_pedido': nuevaOP}).eq('id', idVenta);
        v['orden_pedido'] = nuevaOP;
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OP Guardada'), duration: Duration(milliseconds: 600)));
      } catch (e) {
        debugPrint("Error auto-guardando OP: $e");
      }
    }
  }

  Future<void> _guardarFilaUnica(_FilaGuiaData f) async {
    if (diaCerrado) return;
    if (f.id == null) return; 
    
    try {
      Map<String, dynamic> cData = {
        'nro_guia': f.numCtrl.text,
        'numero_carguio': f.numeroCarguioCA.isEmpty ? f.numCtrl.text : f.numeroCarguioCA, // Fallback if no CA generated yet
        'precinto': f.precCtrl.text,
        'hora_salida': f.hsCtrl.text,
      };
      await supabase.from('carguios_mixers').update(cData).eq('id', f.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado'), duration: Duration(milliseconds: 600)));
      }
    } catch (e) {
      debugPrint("Error auto-guardando fila Guia: $e");
    }
  }

  Future<void> _cerrarDia() async {
    setState(() => cerrando = true);
    try {
      String fechaFiltro = fechaSeleccionada.toIso8601String().split('T')[0];
      await CierreDiarioService.cerrarDia(fechaFiltro);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Día Cerrado y enviado a Historial', style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF0284C7)));
        setState(() {
          diaCerrado = true;
          cerrando = false;
        });
      }
    } catch (e) {
      debugPrint("Error cerrando: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al cerrar: $e"), backgroundColor: Colors.red));
        setState(() => cerrando = false);
      }
    }
  }

  Color _getColorEstado(String estado) {
    estado = estado.toUpperCase();
    if (estado == 'CARGANDO') return Colors.yellow.shade800;
    if (estado == 'REGULANDO') return Colors.blue.shade600;
    if (estado == 'DESPACHADO' || estado == 'EN OBRA' || estado == 'DESCARGANDO' || estado == 'SALIO DE PLANTA') return Colors.green.shade600;
    return Colors.grey.shade500; 
  }

  InputDecoration _softInput({Color? fillColor}) {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      filled: true,
      fillColor: fillColor ?? Colors.grey.shade100,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.primaryDark.withValues(alpha: 0.5), width: 1.5)),
    );
  }

  void _abrirPdfGuia(Map<String, dynamic> venta, _FilaGuiaData carguio) {
    if (carguio.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Este viaje aún no se ha guardado en planta.')));
      return;
    }
    
    Map<String, dynamic> cData = {
      'nro_guia': carguio.numCtrl.text,
      'operador_nombre': carguio.operadorNombre,
      'codigo_mixer': carguio.codigoMixer,
      'volumen': carguio.volumen.toString(),
      'hora_salida': carguio.hsCtrl.text,
      'precinto': carguio.precCtrl.text,
    };
    
    venta['orden_pedido'] = opCtrls[_obtenerIdSeguro(venta)]!.text;
    venta['bomba'] = bombasPorVenta[_obtenerIdSeguro(venta)];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GuiaPdfPreview(venta: venta, carguio: cData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isReadOnly = diaCerrado;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), 
      appBar: AppBar(
        title: Row(
          children: [
            const Text("Control de Guías", style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E293B), fontSize: 22, letterSpacing: -0.5)),
            if (diaCerrado)
              Container(
                margin: const EdgeInsets.only(left: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.lightBlue.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.lightBlue.shade200)),
                child: Row(
                  children: [
                    Icon(Icons.lock, size: 14, color: Colors.lightBlue.shade700),
                    const SizedBox(width: 4),
                    Text("HISTORIAL CERRADO", style: TextStyle(color: Colors.lightBlue.shade700, fontSize: 11, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: AppColors.primaryDark),
            tooltip: "Consultar Historial",
            onPressed: () async {
              final seleccion = await showDatePicker(
                context: context,
                initialDate: fechaSeleccionada,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (seleccion != null) {
                setState(() => fechaSeleccionada = seleccion);
                _cargarDatos();
              }
            },
          ),
          if (!diaCerrado)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: cerrando ? null : _cerrarDia,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue.shade700, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 16)),
                icon: cerrando ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.archive_outlined, size: 20),
                label: const Text("Cerrar Día", style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            )
        ],
      ),
      body: loading 
          ? const Center(child: CircularProgressIndicator()) 
          : ventas.isEmpty 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description_outlined, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text("No hay programación para esta fecha.", style: TextStyle(color: Colors.grey.shade500, fontSize: 18, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              : _buildModernList(isReadOnly),
    );
  }

  Widget _buildModernList(bool isReadOnly) {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: ventas.length,
      itemBuilder: (context, index) {
        var v = ventas[index];
        String idVenta = _obtenerIdSeguro(v);
        String bomba = bombasPorVenta[idVenta] ?? 'DIRECTO';
        List<_FilaGuiaData> carguios = carguiosPorVenta[idVenta] ?? [];

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // HEADER CARD (Venta)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Text(v['hora_entrega']?.toString().substring(0,5) ?? '00:00', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontSize: 20, letterSpacing: -0.5)),
                    const SizedBox(width: 24),
                    SizedBox(
                      width: 140,
                      child: TextField(
                        controller: opCtrls[idVenta],
                        focusNode: opFocus[idVenta],
                        enabled: !isReadOnly,
                        style: TextStyle(fontWeight: FontWeight.w900, color: Colors.blue.shade700, fontSize: 15),
                        decoration: _softInput().copyWith(hintText: 'OP...'),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v['nombre_razon_social'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E293B), fontSize: 15), overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text("${v['diseno']} / $bomba", style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Container(
                        alignment: Alignment.centerRight,
                        child: Text("${v['volumen']} m³", style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontSize: 20)),
                      ),
                    ),
                  ],
                ),
              ),
              // TRIPS (Carguios)
              if (carguios.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.hourglass_empty, size: 16, color: Colors.orange.shade300),
                        const SizedBox(width: 8),
                        Text("Esperando que Planta asigne viajes...", style: TextStyle(color: Colors.orange.shade800, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    children: carguios.map((f) => _buildTripRow(f, v, isReadOnly)).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTripRow(_FilaGuiaData f, Map<String, dynamic> venta, bool isReadOnly) {
    Color estadoColor = _getColorEstado(f.estado);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ORDEN
          SizedBox(
            width: 40,
            child: Text(
              f.ordenCarga.isEmpty ? "#" : "# ${f.ordenCarga}", 
              style: TextStyle(fontWeight: FontWeight.w900, color: Colors.green.shade700, fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 16),
          // CA-CODE BADGE
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: estadoColor.withValues(alpha: 0.1), 
              borderRadius: BorderRadius.circular(6), 
              border: Border.all(color: estadoColor.withValues(alpha: 0.3), width: 1.5)
            ),
            child: Text(
              f.numeroCarguioCA.isEmpty ? "Sin Asignar" : f.numeroCarguioCA, 
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: estadoColor, letterSpacing: 0.5)
            ),
          ),
          const SizedBox(width: 16),
          // GUIA
          SizedBox(
            width: 140,
            child: Text(
              f.numCtrl.text.isEmpty ? 'Sin Guía' : f.numCtrl.text,
              style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E293B), fontSize: 14),
            ),
          ),
          const SizedBox(width: 16),
          // VOLUMEN
          SizedBox(
            width: 70,
            child: Text(
              "${f.volumen.toStringAsFixed(2)} m³", 
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A))
            ),
          ),
          const SizedBox(width: 16),
          // OPERADOR
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(f.operadorNombre.isEmpty ? 'Sin Operador' : f.operadorNombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // PRECINTO
          SizedBox(
            width: 120,
            child: Text(
              f.precCtrl.text.isEmpty ? '---' : f.precCtrl.text,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
            ),
          ),
          const SizedBox(width: 12),
          // HORA SALIDA
          SizedBox(
            width: 90,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                f.hsCtrl.text.isEmpty ? '--:--' : f.hsCtrl.text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // PRINT PDF
          Container(
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
            child: IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 22),
              tooltip: 'Imprimir Guía Interna',
              onPressed: () => _abrirPdfGuia(venta, f),
            ),
          ),
        ],
      ),
    );
  }
}
