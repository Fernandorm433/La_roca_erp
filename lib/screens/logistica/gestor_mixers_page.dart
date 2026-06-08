import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import 'cierre_diario_service.dart';

class GestorMixersPage extends StatefulWidget {
  const GestorMixersPage({super.key});

  @override
  State<GestorMixersPage> createState() => _GestorMixersPageState();
}

class _FilaCarguioData {
  String? id;
  String ordenCarga;
  String numeroGuia;
  String numeroCarguioCA;
  double volumen;
  String? operadorId;
  String operadorNombre;
  String codigoMixer;
  String estado;
  double optVol;
  double repVol;
  String comentario;
  String horaPlanta;
  bool mostrarOptRep;
  
  TextEditingController volCtrl;
  TextEditingController optCtrl;
  TextEditingController repCtrl;
  TextEditingController numCtrl; 
  TextEditingController ordCtrl; 
  TextEditingController hpCtrl; 
  
  FocusNode volFocus;
  FocusNode optFocus;
  FocusNode repFocus;
  FocusNode ordFocus;
  FocusNode hpFocus;
  FocusNode numFocus;

  _FilaCarguioData({
    this.id,
    required this.ordenCarga,
    required this.numeroGuia,
    required this.numeroCarguioCA,
    required this.volumen,
    this.operadorId,
    this.operadorNombre = '',
    this.codigoMixer = '',
    this.estado = 'Pendiente',
    this.optVol = 0.0,
    this.repVol = 0.0,
    this.comentario = '',
    this.horaPlanta = '',
    this.mostrarOptRep = false,
  })  : volCtrl = TextEditingController(text: volumen > 0 ? volumen.toStringAsFixed(2) : ''),
        optCtrl = TextEditingController(text: optVol > 0 ? optVol.toStringAsFixed(2) : ''),
        repCtrl = TextEditingController(text: repVol > 0 ? repVol.toStringAsFixed(2) : ''),
        numCtrl = TextEditingController(text: numeroGuia),
        ordCtrl = TextEditingController(text: ordenCarga),
        hpCtrl = TextEditingController(text: horaPlanta),
        volFocus = FocusNode(),
        optFocus = FocusNode(),
        repFocus = FocusNode(),
        ordFocus = FocusNode(),
        hpFocus = FocusNode(),
        numFocus = FocusNode();

  void dispose() {
    volCtrl.dispose(); optCtrl.dispose(); repCtrl.dispose();
    numCtrl.dispose(); ordCtrl.dispose(); hpCtrl.dispose();
    volFocus.dispose(); optFocus.dispose(); repFocus.dispose();
    ordFocus.dispose(); hpFocus.dispose(); numFocus.dispose();
  }
}

class _GestorMixersPageState extends State<GestorMixersPage> {
  final supabase = Supabase.instance.client;
  bool loading = true;
  bool cerrando = false;
  DateTime fechaSeleccionada = DateTime.now();
  bool diaCerrado = false;
  bool esJefeOperaciones = true; 

  List<Map<String, dynamic>> ventas = [];
  Map<String, List<_FilaCarguioData>> carguiosPorVenta = {};
  Map<String, String> bombasPorVenta = {};
  List<Map<String, dynamic>> conductores = [];

  Map<String, TextEditingController> horaCtrls = {};
  Map<String, FocusNode> horaFocus = {};
  Map<String, TextEditingController> opCtrls = {}; 

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
    for (var c in horaCtrls.values) { c.dispose(); }
    for (var f in horaFocus.values) { f.dispose(); }
    for (var c in opCtrls.values) { c.dispose(); }
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

      final conductoresData = await supabase
          .from("conductores")
          .select("id, nombre, marca")
          .order("nombre");

      List<dynamic> carguiosData = [];
      try {
        carguiosData = await supabase.from("carguios_mixers").select();
      } catch (e) {
        debugPrint("Error al cargar carguios_mixers: $e");
      }

      Map<String, List<_FilaCarguioData>> agrupados = {};
      for (var c in carguiosData) {
        String idVenta = c['id_venta'].toString();
        if (!agrupados.containsKey(idVenta)) agrupados[idVenta] = [];
        agrupados[idVenta]!.add(_FilaCarguioData(
          id: c['id'].toString(),
          ordenCarga: c['orden_carga']?.toString() ?? '',
          numeroGuia: c['nro_guia']?.toString() ?? '', 
          numeroCarguioCA: c['numero_carguio']?.toString() ?? '',
          volumen: double.tryParse(c['volumen_carguio'].toString()) ?? 0.0,
          operadorId: c['operador_id']?.toString(),
          operadorNombre: c['operador_nombre']?.toString() ?? '',
          codigoMixer: c['codigo_mixer']?.toString() ?? '',
          estado: c['estado']?.toString() ?? 'Pendiente',
          optVol: double.tryParse(c['optimizado_vol']?.toString() ?? '0') ?? 0.0,
          repVol: double.tryParse(c['reprocesado_vol']?.toString() ?? '0') ?? 0.0,
          comentario: c['comentario']?.toString() ?? '',
          horaPlanta: c['hora_carguio']?.toString() ?? '',
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
        
        // AUTO GENERACION (Solo 1 vez si esta vacio)
        bool requiresAutoGenerate = !agrupados.containsKey(idV) || agrupados[idV]!.isEmpty;
        if (requiresAutoGenerate) {
          double volTotal = double.tryParse(v['volumen']?.toString() ?? '0') ?? 0;
          List<_FilaCarguioData> autoCreated = _autoGenerarCarguiosInteligente(volTotal);
          agrupados[idV] = autoCreated;
          
          if (!diaCerrado || esJefeOperaciones) {
            for (var f in autoCreated) {
              await _guardarFilaUnica(idV, f, silently: true);
            }
          }
        }
        
        for (var f in agrupados[idV]!) {
          _attachFocusListeners(idV, f);
        }
        
        if (!horaCtrls.containsKey(idV)) {
          String horaStr = v['hora_entrega']?.toString() ?? '';
          if (horaStr.length >= 5) horaStr = horaStr.substring(0, 5);
          horaCtrls[idV] = TextEditingController(text: horaStr);
          horaFocus[idV] = FocusNode();
          horaFocus[idV]!.addListener(() {
            if (!horaFocus[idV]!.hasFocus) {
              _actualizarHoraVenta(idV, horaCtrls[idV]!.text);
            }
          });
        }
        
        if (!opCtrls.containsKey(idV)) {
          opCtrls[idV] = TextEditingController(text: v['orden_pedido']?.toString() ?? '');
        }
      }

      if (mounted) {
        setState(() {
          ventas = List<Map<String, dynamic>>.from(ventasData);
          conductores = List<Map<String, dynamic>>.from(conductoresData);
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

  void _attachFocusListeners(String idVenta, _FilaCarguioData f) {
    f.volFocus.addListener(() {
      if (!f.volFocus.hasFocus) {
        setState((){ f.volumen = double.tryParse(f.volCtrl.text) ?? 0.0; });
        _guardarFilaUnica(idVenta, f);
      }
    });
    f.optFocus.addListener(() { if (!f.optFocus.hasFocus) _guardarFilaUnica(idVenta, f); });
    f.repFocus.addListener(() { if (!f.repFocus.hasFocus) _guardarFilaUnica(idVenta, f); });
    f.ordFocus.addListener(() { if (!f.ordFocus.hasFocus) _guardarFilaUnica(idVenta, f); });
    f.hpFocus.addListener(() { if (!f.hpFocus.hasFocus) _guardarFilaUnica(idVenta, f); });
    f.numFocus.addListener(() { if (!f.numFocus.hasFocus) _guardarFilaUnica(idVenta, f); });
  }

  List<_FilaCarguioData> _autoGenerarCarguiosInteligente(double volTotal) {
    List<_FilaCarguioData> res = [];
    if (volTotal <= 0) return res;

    if (volTotal <= 12.0) {
      res.add(_FilaCarguioData(
        ordenCarga: "", numeroGuia: "", numeroCarguioCA: "", 
        volumen: double.parse(volTotal.toStringAsFixed(2)),
      ));
      return res;
    }

    int numTrucks = (volTotal / 8.0).ceil();
    double remaining = volTotal;

    for (int i = 0; i < numTrucks; i++) {
      if (i == numTrucks - 1) {
        res.add(_FilaCarguioData(
          ordenCarga: "", numeroGuia: "", numeroCarguioCA: "", 
          volumen: double.parse(remaining.toStringAsFixed(2)),
        ));
      } else {
        int trucksLeft = numTrucks - i;
        double target = remaining / trucksLeft;
        double truckVol = (target * 2).round() / 2.0; 
        if (truckVol > 12.0) truckVol = 12.0; 
        
        res.add(_FilaCarguioData(
          ordenCarga: "", numeroGuia: "", numeroCarguioCA: "", 
          volumen: double.parse(truckVol.toStringAsFixed(2)),
        ));
        remaining -= truckVol;
      }
    }
    return res;
  }

  void _agregarViajeManual(String idVenta) async {
    if (diaCerrado && !esJefeOperaciones) return;
    
    var nf = _FilaCarguioData(
      ordenCarga: "", numeroGuia: "", numeroCarguioCA: "", volumen: 0.0,
    );
    _attachFocusListeners(idVenta, nf);
    
    setState(() {
      carguiosPorVenta[idVenta]?.add(nf);
    });
    await _guardarFilaUnica(idVenta, nf, silently: true);
  }

  void _eliminarViaje(String idVenta, _FilaCarguioData f) async {
    if (diaCerrado && !esJefeOperaciones) return;
    
    setState(() {
      carguiosPorVenta[idVenta]?.remove(f);
    });
    
    if (f.id != null && f.id!.isNotEmpty) {
      try {
        await supabase.from('carguios_mixers').delete().eq('id', f.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Viaje eliminado'), backgroundColor: Colors.orange));
        }
      } catch (e) {
        debugPrint("Error eliminando viaje: $e");
      }
    }
    f.dispose();
  }

  Future<void> _actualizarHoraVenta(String idVenta, String nuevaHora) async {
    if (diaCerrado && !esJefeOperaciones) return;
    try {
      String horaGuardar = nuevaHora.trim();
      if (horaGuardar.length == 4 && horaGuardar.contains(':')) {
        horaGuardar = '0$horaGuardar'; // 7:30 -> 07:30
      }
      if (horaGuardar.length == 5) {
        horaGuardar = '$horaGuardar:00'; // 07:30 -> 07:30:00
      }
      
      await supabase.from('ventas_programacion').update({'hora_entrega': horaGuardar}).eq('id', idVenta);
      
      if (mounted) {
        int idx = ventas.indexWhere((v) => v['id'].toString() == idVenta);
        if (idx != -1) {
          ventas[idx]['hora_entrega'] = horaGuardar;
          ventas.sort((a, b) {
            String hA = a['hora_entrega']?.toString() ?? '99:99';
            String hB = b['hora_entrega']?.toString() ?? '99:99';
            return hA.compareTo(hB);
          });
          setState(() {});
        }
        
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hora actualizada correctamente'), backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint("Error actualizando hora: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al actualizar hora: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<String> _generarCA() async {
    int ano = DateTime.now().year;
    String prefix = 'CA-$ano-';
    try {
      final res = await supabase
          .from('carguios_mixers')
          .select('numero_carguio')
          .like('numero_carguio', '$prefix%')
          .order('numero_carguio', ascending: false)
          .limit(1)
          .maybeSingle();
      
      if (res != null && res['numero_carguio'] != null && res['numero_carguio'].toString().isNotEmpty) {
        String lastCA = res['numero_carguio'];
        int num = int.tryParse(lastCA.split('-').last) ?? 1599;
        return '$prefix${num + 1}';
      }
    } catch (e) {
      debugPrint("Error buscando ultimo CA: $e");
    }
    return '${prefix}1600'; 
  }

  Future<String> _generarNroGuia() async {
    try {
      final res = await supabase
          .from('carguios_mixers')
          .select('nro_guia')
          .like('nro_guia', '001-%')
          .order('nro_guia', ascending: false)
          .limit(1)
          .maybeSingle();
      
      if (res != null && res['nro_guia'] != null && res['nro_guia'].toString().trim().isNotEmpty) {
        String lastGuia = res['nro_guia'].toString().trim();
        List<String> parts = lastGuia.split('-');
        if (parts.length == 2) {
          int num = int.tryParse(parts[1]) ?? 8399;
          return '001-${(num + 1).toString().padLeft(7, '0')}';
        }
      }
    } catch (e) {
      debugPrint("Error buscando ultima Guia: $e");
    }
    return '001-0008400'; 
  }

  Future<void> _guardarFilaUnica(String idVenta, _FilaCarguioData f, {bool silently = false}) async {
    if (diaCerrado && !esJefeOperaciones) return;
    try {
      if (f.numeroCarguioCA.isEmpty && f.ordCtrl.text.trim().isNotEmpty) {
        f.numeroCarguioCA = await _generarCA();
        if (mounted) setState(() {});
      }
      
      if (f.ordCtrl.text.trim().isNotEmpty && (f.numCtrl.text.isEmpty || f.numCtrl.text == 'Sin Guía')) {
        f.numCtrl.text = await _generarNroGuia();
        if (mounted) setState(() {});
      }

      f.volumen = double.tryParse(f.volCtrl.text) ?? 0.0;
      f.optVol = double.tryParse(f.optCtrl.text) ?? 0.0;
      f.repVol = double.tryParse(f.repCtrl.text) ?? 0.0;
      
      int? ordVal = int.tryParse(f.ordCtrl.text);

      Map<String, dynamic> cData = {
        'id_venta': idVenta.toString(), 
        'orden_carga': ordVal,
        'nro_guia': f.numCtrl.text,
        'numero_carguio': f.numeroCarguioCA, 
        'volumen_carguio': f.volumen,
        'operador_id': f.operadorId,
        'operador_nombre': f.operadorNombre,
        'codigo_mixer': f.codigoMixer,
        'hora_carguio': f.hpCtrl.text, 
        'estado': f.estado,
        'optimizado_vol': f.optVol,
        'reprocesado_vol': f.repVol,
      };

      if (f.id != null) {
        await supabase.from('carguios_mixers').update(cData).eq('id', f.id!);
      } else {
        final res = await supabase.from('carguios_mixers').insert(cData).select().single();
        f.id = res['id'].toString();
      }
      
      if (!silently && mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Viaje guardado'), duration: Duration(milliseconds: 600)));
      }
    } catch (e) {
      debugPrint("Error crítico auto-guardando fila: $e");
      if (!silently && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar en BD: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _cerrarDia() async {
    setState(() => cerrando = true);
    try {
      String fechaFiltro = fechaSeleccionada.toIso8601String().split('T')[0];
      await CierreDiarioService.cerrarDia(fechaFiltro);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Día Cerrado y enviado a Historial', style: TextStyle(color: Colors.white)), backgroundColor: Colors.purple));
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

  @override
  Widget build(BuildContext context) {
    bool isReadOnly = diaCerrado && !esJefeOperaciones;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), 
      appBar: AppBar(
        title: Row(
          children: [
            const Text("PLANIFICACION, PRODUCCION Y DISTRIBUCION DE CONCRETO DIARIO", style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E293B), fontSize: 22, letterSpacing: -0.5)),
            if (diaCerrado)
              Container(
                margin: const EdgeInsets.only(left: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.purple.shade200)),
                child: Row(
                  children: [
                    Icon(Icons.lock, size: 14, color: Colors.purple.shade700),
                    const SizedBox(width: 4),
                    Text("HISTORIAL CERRADO", style: TextStyle(color: Colors.purple.shade700, fontSize: 11, fontWeight: FontWeight.w800)),
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
          Row(
            children: [
              const Text("Jefe de OP", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
              Switch(
                value: esJefeOperaciones,
                activeThumbColor: Colors.purple,
                onChanged: (val) => setState(() => esJefeOperaciones = val),
              ),
            ],
          ),
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
          if (!diaCerrado || esJefeOperaciones)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: cerrando ? null : _cerrarDia,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 16)),
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
                      Icon(Icons.fire_truck_outlined, size: 80, color: Colors.grey.shade300),
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
        List<_FilaCarguioData> carguios = carguiosPorVenta[idVenta] ?? [];
        
        double volTotalMeta = double.tryParse(v['volumen']?.toString() ?? '0') ?? 0;
        double volAcumulado = 0;
        for (var c in carguios) {
          volAcumulado += c.volumen;
        }
        double saldo = volTotalMeta - volAcumulado;
        bool balanceado = (saldo.abs() < 0.05);

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
              // HEADER CARD
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: horaCtrls[idVenta],
                        focusNode: horaFocus[idVenta],
                        enabled: !isReadOnly,
                        style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontSize: 20, letterSpacing: -0.5),
                        decoration: const InputDecoration(border: InputBorder.none, hintText: '00:00', isDense: true, contentPadding: EdgeInsets.zero),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.blue.shade100)),
                      child: Text(opCtrls[idVenta]?.text.isEmpty ?? true ? 'Sin OP' : opCtrls[idVenta]!.text, style: TextStyle(fontWeight: FontWeight.w800, color: Colors.blue.shade700, fontSize: 13)),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("${volTotalMeta.toStringAsFixed(1)} m³", style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontSize: 20)),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(balanceado ? "✓ Completo" : "Saldo: ${saldo > 0 ? '+' : ''}${saldo.toStringAsFixed(1)} m³", 
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: balanceado ? Colors.green.shade600 : Colors.red.shade600)
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // TRIPS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  children: [
                    ...carguios.map((f) => _buildTripRow(f, idVenta, isReadOnly)).toList(),
                    if (!isReadOnly)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => _agregarViajeManual(idVenta),
                            icon: const Icon(Icons.add_circle_outline, size: 18),
                            label: const Text("Agregar Viaje", style: TextStyle(fontWeight: FontWeight.w700)),
                            style: TextButton.styleFrom(foregroundColor: AppColors.primaryDark),
                          ),
                        ),
                      )
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTripRow(_FilaCarguioData f, String idVenta, bool isReadOnly) {
    Color estadoColor = _getColorEstado(f.estado);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ORDEN
              SizedBox(
                width: 50,
                child: TextField(
                  controller: f.ordCtrl,
                  focusNode: f.ordFocus,
                  enabled: !isReadOnly,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800, color: Colors.green.shade700, fontSize: 14),
                  decoration: _softInput(fillColor: Colors.green.shade50).copyWith(hintText: '#', hintStyle: TextStyle(color: Colors.green.shade200)),
                ),
              ),
              const SizedBox(width: 12),
              // GUIA
              SizedBox(
                width: 120,
                child: TextField(
                  controller: f.numCtrl,
                  enabled: false, 
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF475569), fontSize: 13),
                  decoration: _softInput(fillColor: Colors.grey.shade100).copyWith(hintText: 'Sin Guía'),
                ),
              ),
              const SizedBox(width: 12),
              // VOLUMEN
              SizedBox(
                width: 80,
                child: TextField(
                  controller: f.volCtrl,
                  focusNode: f.volFocus,
                  enabled: !isReadOnly,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A)),
                  decoration: _softInput().copyWith(suffixText: 'm³', suffixStyle: const TextStyle(fontSize: 10, color: Colors.grey)),
                ),
              ),
              const SizedBox(width: 12),
              // OPERADOR
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: conductores.any((c) => c['id'].toString() == f.operadorId) ? f.operadorId : null,
                  decoration: _softInput(),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.w700),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                  items: conductores.map((c) => DropdownMenuItem<String>(
                    value: c['id'].toString(),
                    child: Text("${c['marca']} - ${c['nombre']}", overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: isReadOnly ? null : (val) {
                    if (val != null) {
                      var cond = conductores.firstWhere((e) => e['id'].toString() == val);
                      f.operadorId = val;
                      f.operadorNombre = cond['nombre'];
                      f.codigoMixer = cond['marca'];
                      setState((){});
                      _guardarFilaUnica(idVenta, f);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              // ESTADO BADGE
              GestureDetector(
                onTap: isReadOnly ? null : () {
                  if (f.numeroCarguioCA.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coloca el # Ord primero para generar el CA.')));
                    return;
                  }
                  if (f.estado.toUpperCase() == 'PENDIENTE') {
                    f.estado = 'Cargando';
                  } else if (f.estado.toUpperCase() == 'CARGANDO') {
                    f.estado = 'Regulando';
                  } else if (f.estado.toUpperCase() == 'REGULANDO') {
                    f.estado = 'Salio de Planta';
                  } else {
                    f.estado = 'Pendiente';
                  }
                  setState(() {});
                  _guardarFilaUnica(idVenta, f);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: estadoColor.withValues(alpha: 0.1), 
                    borderRadius: BorderRadius.circular(8), 
                    border: Border.all(color: estadoColor.withValues(alpha: 0.3), width: 1.5)
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.local_shipping, size: 14, color: estadoColor),
                      const SizedBox(width: 6),
                      Text(
                        f.numeroCarguioCA.isEmpty ? "Sin Asignar" : f.numeroCarguioCA, 
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: estadoColor, letterSpacing: 0.5)
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // HORA PLANTA
              SizedBox(
                width: 80,
                child: TextField(
                  controller: f.hpCtrl,
                  focusNode: f.hpFocus,
                  enabled: !isReadOnly,
                  textAlign: TextAlign.center,
                  decoration: _softInput().copyWith(hintText: '00:00', prefixIcon: const Icon(Icons.access_time, size: 14), prefixIconConstraints: const BoxConstraints(minWidth: 24)),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 4),
              // DELETE ROW
              if (!isReadOnly)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  tooltip: 'Eliminar este viaje',
                  onPressed: () => _eliminarViaje(idVenta, f),
                ),
              // OPT/REP TOGGLE
              IconButton(
                icon: Icon(f.mostrarOptRep ? Icons.keyboard_arrow_up : Icons.more_horiz, color: Colors.grey.shade400, size: 20),
                onPressed: () {
                  setState(() => f.mostrarOptRep = !f.mostrarOptRep);
                },
              ),
            ],
          ),
          if (f.mostrarOptRep)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 62, right: 62),
              child: Row(
                children: [
                  const Text("Opt:", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    child: TextField(
                      controller: f.optCtrl,
                      focusNode: f.optFocus,
                      enabled: !isReadOnly,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      decoration: _softInput(),
                    ),
                  ),
                  const SizedBox(width: 24),
                  const Text("Rep:", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    child: TextField(
                      controller: f.repCtrl,
                      focusNode: f.repFocus,
                      enabled: !isReadOnly,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      decoration: _softInput(),
                    ),
                  ),
                ],
              ),
            )
        ],
      ),
    );
  }
}
