import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_database/core/theme/app_colors.dart';
import 'package:app_database/core/services/notificacion_service.dart';
import 'package:app_database/screens/logistica/guia_pdf_preview.dart';

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
  String precinto;
  String horaSalida;
  bool mostrarOptRep = false;
  bool yaNotificado = false;
  
  TextEditingController volCtrl;
  TextEditingController optCtrl;
  TextEditingController repCtrl;
  TextEditingController numCtrl; 
  TextEditingController ordCtrl; 
  TextEditingController hpCtrl; 
  TextEditingController precCtrl;
  TextEditingController hsCtrl;
  
  FocusNode volFocus;
  FocusNode optFocus;
  FocusNode repFocus;
  FocusNode ordFocus;
  FocusNode hpFocus;
  FocusNode numFocus;
  FocusNode precFocus;
  FocusNode hsFocus;

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
    this.precinto = '',
    this.horaSalida = '',
  })  : volCtrl = TextEditingController(text: volumen > 0 ? volumen.toStringAsFixed(2) : ''),
        optCtrl = TextEditingController(text: optVol > 0 ? optVol.toStringAsFixed(2) : ''),
        repCtrl = TextEditingController(text: repVol > 0 ? repVol.toStringAsFixed(2) : ''),
        numCtrl = TextEditingController(text: numeroGuia),
        ordCtrl = TextEditingController(text: ordenCarga),
        hpCtrl = TextEditingController(text: horaPlanta),
        precCtrl = TextEditingController(text: precinto),
        hsCtrl = TextEditingController(text: horaSalida),
        volFocus = FocusNode(),
        optFocus = FocusNode(),
        repFocus = FocusNode(),
        ordFocus = FocusNode(),
        hpFocus = FocusNode(),
        numFocus = FocusNode(),
        precFocus = FocusNode(),
        hsFocus = FocusNode();

  void dispose() {
    volCtrl.dispose(); optCtrl.dispose(); repCtrl.dispose();
    numCtrl.dispose(); ordCtrl.dispose(); hpCtrl.dispose();
    precCtrl.dispose(); hsCtrl.dispose();
    volFocus.dispose(); optFocus.dispose(); repFocus.dispose();
    ordFocus.dispose(); hpFocus.dispose(); numFocus.dispose();
    precFocus.dispose(); hsFocus.dispose();
  }
}

class _GestorMixersPageState extends State<GestorMixersPage> {
  final supabase = Supabase.instance.client;
  bool loading = true;
  DateTime fechaSeleccionada = DateTime.now();
  bool esJefeOperaciones = false; 
  bool pantallaOculta = false;
  bool ocultoGlobal = false;
  String currentUserId = '';
  List<String> usuariosPermitidos = [];

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
      final user = supabase.auth.currentUser;
      if (user != null) {
        currentUserId = user.id;
        final userData = await supabase.from('usuarios').select('rol').eq('id', user.id).maybeSingle();
        if (userData != null) {
          String rol = (userData['rol'] ?? '').toString().toLowerCase();
          esJefeOperaciones = (rol == 'jefe' || rol == 'admin');
        }
      }

      try {
        final perm = await supabase.from('permisos_pantallas').select().eq('pantalla_id', 'despachos').maybeSingle();
        if (perm != null) {
          ocultoGlobal = perm['oculto_global'] == true;
          usuariosPermitidos = List<String>.from((perm['usuarios_permitidos'] as List?)?.map((e) => e.toString()) ?? []);
          
          if (ocultoGlobal && !esJefeOperaciones && !usuariosPermitidos.contains(currentUserId)) {
            setState(() {
              pantallaOculta = true;
              loading = false;
            });
            return;
          } else {
            pantallaOculta = false;
          }
        }
      } catch (e) {
        debugPrint("Error leyendo permisos_pantallas: $e");
      }

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
          .select("id, nombre, marca, usuario_id")
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
        
        // AUTO GENERACION (Solo 1 vez si esta vacio)
        bool requiresAutoGenerate = !agrupados.containsKey(idV) || agrupados[idV]!.isEmpty;
        if (requiresAutoGenerate) {
          double volTotal = double.tryParse(v['volumen']?.toString() ?? '0') ?? 0;
          List<_FilaCarguioData> autoCreated = _autoGenerarCarguiosInteligente(volTotal);
          agrupados[idV] = autoCreated;
          
          if (true) {
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
    f.precFocus.addListener(() { if (!f.precFocus.hasFocus) _guardarFilaUnica(idVenta, f); });
    f.hsFocus.addListener(() { if (!f.hsFocus.hasFocus) _guardarFilaUnica(idVenta, f); });
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

    
    var v = ventas.firstWhere((x) => x['id'].toString() == idVenta, orElse: () => {});
    double volTotalOP = double.tryParse(v['volumen']?.toString() ?? '0') ?? 0.0;
    double volAsignado = 0.0;
    for (var c in (carguiosPorVenta[idVenta] ?? [])) {
      volAsignado += c.volumen;
    }
    double remaining = volTotalOP - volAsignado;
    if (remaining < 0) remaining = 0.0;
    
    var nf = _FilaCarguioData(
      ordenCarga: "", numeroGuia: "", numeroCarguioCA: "", volumen: double.parse(remaining.toStringAsFixed(2)),
    );
    _attachFocusListeners(idVenta, nf);
    
    setState(() {
      carguiosPorVenta[idVenta]?.add(nf);
    });
    await _guardarFilaUnica(idVenta, nf, silently: true);
  }

  void _eliminarViaje(String idVenta, _FilaCarguioData f) async {

    
    if (f.id != null) {
      bool confirm = await showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: const Text('¿Estás seguro de eliminar este viaje?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            TextButton(
              onPressed: () => Navigator.pop(c, true), 
              child: const Text('Eliminar', style: TextStyle(color: Colors.red))
            ),
          ],
        ),
      ) ?? false;
      
      if (!confirm) return;

      try {
        await supabase.from('carguios_mixers').delete().eq('id', f.id!);
      } catch (e) {
        debugPrint("Error al eliminar: $e");
      }
    }
    
    setState(() {
      carguiosPorVenta[idVenta]?.remove(f);
    });
    
    Future.delayed(const Duration(milliseconds: 100), () {
      f.dispose();
    });
  }

  void _abrirPdfGuia(Map<String, dynamic> venta, _FilaCarguioData carguio) {
    if (carguio.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Este viaje aún no se ha guardado.')));
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
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GuiaPdfPreview(venta: venta, carguio: cData),
      ),
    );
  }

  Future<void> _actualizarHoraVenta(String idVenta, String nuevaHora) async {

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
        'precinto': f.precCtrl.text,
        'hora_salida': f.hsCtrl.text,
      };

      if (f.id != null) {
        await supabase.from('carguios_mixers').update(cData).eq('id', f.id!);
      } else {
        final res = await supabase.from('carguios_mixers').insert(cData).select().single();
        f.id = res['id'].toString();
      }
      
      if (!silently && f.volumen > 0 && !f.yaNotificado) {
        try {
          await NotificationService().notificarPorRoles(
            roles: ['produccion', 'calidad'],
            titulo: 'Nuevo Carguío Asignado',
            cuerpo: 'Orden ${f.ordCtrl.text} - Vol: ${f.volumen} m³',
          );
          f.yaNotificado = true;
        } catch (e) {
          debugPrint("Error al enviar notificacion a produccion: $e");
        }
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
    bool isReadOnly = false;

    if (pantallaOculta) {
      return Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(backgroundColor: Colors.white, title: const Text("Despachos", style: TextStyle(color: Colors.black))),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.visibility_off, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text("Vista Restringida", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.grey.shade700)),
              const SizedBox(height: 8),
              Text("El Jefe de Operaciones ha ocultado temporalmente esta vista.", style: TextStyle(color: Colors.grey.shade500)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), 
      appBar: AppBar(
        title: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          children: [
            const Text("PLANIFICACION Y DISTRIBUCION DE CONCRETO", style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E293B), fontSize: 16, letterSpacing: -0.5)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
        actions: [
          if (esJefeOperaciones)
            IconButton(
              icon: Icon(ocultoGlobal ? Icons.visibility_off : Icons.visibility, color: ocultoGlobal ? Colors.red : Colors.green),
              tooltip: "Configurar Visibilidad",
              onPressed: _abrirDialogoVisibilidad,
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

  Widget _buildClientInfo(Map<String, dynamic> v, String bomba) {
    bool hasHuso = v['huso'] != null && v['huso'].toString().trim().isNotEmpty;
    bool hasSlump = v['slump'] != null && v['slump'].toString().trim().isNotEmpty;
    bool hasAditivo = v['aditivo'] != null && v['aditivo'].toString().trim().isNotEmpty && v['aditivo'].toString() != '-';
    bool hasObs = v['observaciones'] != null && v['observaciones'].toString().trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(v['nombre_razon_social'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E293B), fontSize: 15), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text("${v['diseno']} / $bomba", style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            if (hasHuso)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                child: Text("Huso: ${v['huso']}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
              ),
            if (hasSlump)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                child: Text("Slump: ${v['slump']}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
              ),
          ],
        ),
        if (hasAditivo || hasObs) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (hasAditivo)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.orange.shade200)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.science, size: 12, color: Colors.orange.shade800),
                      const SizedBox(width: 4),
                      Text("Aditivo: ${v['aditivo']}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.orange.shade800)),
                    ],
                  ),
                ),
              if (hasObs)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red.shade200)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 12, color: Colors.red.shade700),
                      const SizedBox(width: 4),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: Text("Obs: ${v['observaciones']}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.red.shade700), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    bool isMobile = constraints.maxWidth < 600;
                    if (isMobile) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
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
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text("${volTotalMeta.toStringAsFixed(1)} m³", style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontSize: 20)),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(balanceado ? "✓ Completo" : "Saldo: ${saldo > 0 ? '+' : ''}${saldo.toStringAsFixed(1)} m³", 
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: balanceado ? Colors.green.shade600 : Colors.red.shade600)
                                      ),
                                    ],
                                  )
                                ],
                              )
                            ],
                          ),
                          const SizedBox(height: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildClientInfo(v, bomba),
                            ],
                          ),
                        ],
                      );
                    }
                    return Row(
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
                              _buildClientInfo(v, bomba),
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
                    );
                  },
                ),
              ),
              // TRIPS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  children: [
                    ...carguios.map((f) => _buildTripRow(f, v, idVenta, isReadOnly)).toList(),
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

  Widget _buildTripRow(_FilaCarguioData f, Map<String, dynamic> v, String idVenta, bool isReadOnly) {
    Color estadoColor = _getColorEstado(f.estado);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
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
              // GUIA
              SizedBox(
                width: 140,
                child: TextField(
                  controller: f.numCtrl,
                  enabled: false, 
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF475569), fontSize: 13),
                  decoration: _softInput(fillColor: Colors.grey.shade100).copyWith(hintText: 'Sin Guía'),
                ),
              ),
              // VOLUMEN
              SizedBox(
                width: 90,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: f.volCtrl,
                      focusNode: f.volFocus,
                      enabled: !isReadOnly,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A)),
                      decoration: _softInput().copyWith(suffixText: 'm³', suffixStyle: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ),
                    if (f.optVol > 0 || f.repVol > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          (f.optVol > 0 ? "Opt: ${f.optVol.toStringAsFixed(1)} " : "") + 
                          (f.repVol > 0 ? "Rep: ${f.repVol.toStringAsFixed(1)}" : "").trim(),
                          style: TextStyle(fontSize: 10, color: Colors.blue.shade700, fontWeight: FontWeight.bold),
                        ),
                      )
                  ],
                ),
              ),
              // OPERADOR
              SizedBox(
                width: 180,
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
                      bool isNew = f.operadorId != val;
                      var cond = conductores.firstWhere((e) => e['id'].toString() == val);
                      f.operadorId = val;
                      f.operadorNombre = cond['nombre'];
                      f.codigoMixer = cond['marca'];
                      setState((){});
                      _guardarFilaUnica(idVenta, f);
                      if (isNew) {
                         String? uId = cond['usuario_id']?.toString();
                         if (uId != null && uId.isNotEmpty) {
                            NotificationService().notificarUsuario(
                              userId: uId, 
                              titulo: '🚚 Nueva Ruta Asignada', 
                              cuerpo: 'Tienes un viaje a ${v['nombre_razon_social'] ?? 'obra'} en ${v['direccion'] ?? 'el destino asignado'}.'
                            );
                         }
                      }
                    }
                  },
                ),
              ),
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
                    mainAxisSize: MainAxisSize.min,
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
              // PRECINTO
              SizedBox(
                width: 100,
                child: TextField(
                  controller: f.precCtrl,
                  focusNode: f.precFocus,
                  enabled: !isReadOnly,
                  decoration: _softInput().copyWith(hintText: 'Precinto...'),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              // HORA SALIDA
              SizedBox(
                width: 70,
                child: TextField(
                  controller: f.hsCtrl,
                  focusNode: f.hsFocus,
                  enabled: !isReadOnly,
                  textAlign: TextAlign.center,
                  decoration: _softInput().copyWith(hintText: '00:00'),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
              // PRINT PDF
              Container(
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                child: IconButton(
                  icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 22),
                  tooltip: 'Imprimir Guía Interna',
                  onPressed: () {
                    // Inject orden_pedido and bomba into v before sending to PDF generator
                    Map<String, dynamic> ventaParaPdf = Map.from(v);
                    ventaParaPdf['orden_pedido'] = v['orden_pedido'] ?? opCtrls[idVenta]?.text ?? '';
                    ventaParaPdf['bomba'] = bombasPorVenta[idVenta] ?? '';
                    _abrirPdfGuia(ventaParaPdf, f);
                  },
                ),
              ),
              // ACCIONES
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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

  Future<void> _abrirDialogoVisibilidad() async {
    bool tempOculto = ocultoGlobal;
    List<String> tempPermitidos = List.from(usuariosPermitidos);
    bool cargandoUsuarios = true;
    List<Map<String, dynamic>> listaUsuarios = [];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            if (cargandoUsuarios && listaUsuarios.isEmpty) {
              supabase.from('usuarios').select('id, nombre, rol').then((res) {
                if (mounted) {
                  setStateDialog(() {
                    listaUsuarios = List<Map<String, dynamic>>.from(res);
                    cargandoUsuarios = false;
                  });
                }
              }).catchError((e) {
                if (mounted) {
                  setStateDialog(() { cargandoUsuarios = false; });
                }
              });
            }

            return AlertDialog(
              title: const Text("Control de Visibilidad"),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      title: const Text("Ocultar vista para todos", style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text("Solo Admin y Jefe OP podrán ver esta pantalla."),
                      activeColor: Colors.red,
                      value: tempOculto,
                      onChanged: (val) {
                        setStateDialog(() => tempOculto = val);
                      },
                    ),
                    if (tempOculto) ...[
                      const Divider(),
                      const Text("Excepciones (Usuarios que sí pueden ver):", style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      cargandoUsuarios
                          ? const Center(child: CircularProgressIndicator())
                          : Container(
                              constraints: const BoxConstraints(maxHeight: 300),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: listaUsuarios.length,
                                itemBuilder: (context, i) {
                                  final u = listaUsuarios[i];
                                  final uid = u['id'].toString();
                                  final rol = u['rol'].toString();
                                  if (rol == 'admin' || rol == 'jefe') return const SizedBox.shrink(); 

                                  return CheckboxListTile(
                                    title: Text(u['nombre'] ?? 'Sin nombre'),
                                    subtitle: Text("Rol: $rol"),
                                    value: tempPermitidos.contains(uid),
                                    onChanged: (val) {
                                      setStateDialog(() {
                                        if (val == true) {
                                          tempPermitidos.add(uid);
                                        } else {
                                          tempPermitidos.remove(uid);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                  onPressed: () async {
                    Navigator.pop(context);
                    setState(() => loading = true);
                    try {
                      await supabase.from('permisos_pantallas').upsert({
                        'pantalla_id': 'despachos',
                        'oculto_global': tempOculto,
                        'usuarios_permitidos': tempPermitidos
                      });
                      setState(() {
                        ocultoGlobal = tempOculto;
                        usuariosPermitidos = tempPermitidos;
                      });
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Visibilidad guardada."), backgroundColor: Colors.green));
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                    } finally {
                      setState(() => loading = false);
                    }
                  },
                  child: const Text("Guardar", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
