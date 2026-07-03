import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async'; // NUEVO
import '../../core/theme/app_colors.dart';
import '../../core/utils/helpers.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../core/services/notificacion_service.dart';

class _CarguioItem {
  final Map<String, dynamic> carguioRaw;
  final Map<String, dynamic> ventaRaw;
  final int ordenCarga;
  final String estado;
  final DateTime? fechaRegistro;

  _CarguioItem({
    required this.carguioRaw,
    required this.ventaRaw,
    required this.ordenCarga,
    required this.estado,
    this.fechaRegistro,
  });
}

class RegistroCarguioPage extends StatefulWidget {
  const RegistroCarguioPage({super.key});

  @override
  State<RegistroCarguioPage> createState() => _RegistroCarguioPageState();
}

class _RegistroCarguioPageState extends State<RegistroCarguioPage> {
  final supabase = Supabase.instance.client;
  bool loading = true;
  bool guardando = false;
  RealtimeChannel? _subscription;
  Timer? _timer;

  List<_CarguioItem> carguiosDelDia = [];
  _CarguioItem? carguioSeleccionado;
  
  Map<String, dynamic>? disenoActual;
  List disenosMezcla = [];
  Map<String, String> bombasPorVenta = {}; // <-- NUEVO PARA BOMBAS

  final cOrdenCarguio = TextEditingController();
  final cVolumen = TextEditingController();
  final cMixer = TextEditingController();
  final cOperador = TextEditingController();

  // Pesos Reales
  final cRealCemento = TextEditingController();
  final cRealArena = TextEditingController();
  final cRealPiedra12 = TextEditingController();
  final cRealPiedra34 = TextEditingController();
  final cRealPiedra38 = TextEditingController();
  final cRealAgua = TextEditingController();
  final cRealAditivo = TextEditingController();

  // Pesos Diseño (Calculados)
  double disenoCemento = 0;
  double disenoArena = 0;
  double disenoPiedra12 = 0;
  double disenoPiedra34 = 0;
  double disenoPiedra38 = 0;
  double disenoAgua = 0;
  double disenoAditivo = 0;

  double optSeleccionado = 0;
  double repSeleccionado = 0;

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
    _suscribirseACarguios();
    // Use a 5-second polling timer as a fallback for realtime
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _cargarDatosIniciales(silent: true);
    });
  }

  void _suscribirseACarguios() {
    _subscription = supabase
        .channel('public:carguios_mixers')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'carguios_mixers',
          callback: (payload) {
            _cargarDatosIniciales(silent: true);
          },
        )
        .subscribe();
  }

  void _procesarActualizacionCarguio(PostgresChangePayload payload) async {
    // Ya no se usa directamente, recarga silenciosa en su lugar
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    _timer?.cancel();
    cOrdenCarguio.dispose();
    cVolumen.dispose();
    cMixer.dispose();
    cOperador.dispose();
    cRealCemento.dispose();
    cRealArena.dispose();
    cRealPiedra12.dispose();
    cRealPiedra34.dispose();
    cRealPiedra38.dispose();
    cRealAgua.dispose();
    cRealAditivo.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future _cargarDatosIniciales({bool silent = false}) async {
    if (!silent) setState(() => loading = true);
    try {
      String hoy = DateTime.now().toIso8601String().split('T')[0];
      String manana = DateTime.now().add(const Duration(days: 1)).toIso8601String().split('T')[0];

      final vData = await supabase
          .from('ventas_programacion')
          .select()
          .gte('fecha_entrega', hoy)
          .lt('fecha_entrega', manana);

      final asignaciones = await supabase.from("asignacion_bombas").select();
      Map<String, String> mapaBombas = {};
      for (var a in asignaciones) {
        mapaBombas[a['id_venta'].toString()] = a['bomba_asignada'].toString();
      }

      final cData = await supabase.from('carguios_mixers').select();
      
      final dData = await supabase
          .from('despachos_produccion')
          .select('orden_carguio, cliente, fecha')
          .gte('fecha', hoy);

      List<_CarguioItem> listaFinal = [];

      for (var c in cData) {
        String idVenta = c['id_venta']?.toString() ?? '';
        String ordenCargaStr = c['orden_carga']?.toString() ?? '';
        int? ordenCarga = int.tryParse(ordenCargaStr);
        
        if (ordenCarga != null && idVenta.isNotEmpty) {
          final ventaList = vData.where((v) => v['id'].toString() == idVenta).toList();
          if (ventaList.isNotEmpty) {
            var venta = ventaList.first;
            String cliente = venta['nombre_razon_social'] ?? '';
            String estado = c['estado']?.toString() ?? 'Pendiente';
            
            final despList = dData.where((d) => 
               d['cliente'] == cliente && 
               d['orden_carguio']?.toString() == ordenCarga.toString()
            ).toList();
            
            DateTime? fechaReg;
            if (despList.isNotEmpty) {
              String fechaStr = despList.last['fecha'];
              fechaReg = DateTime.tryParse(fechaStr);
            }

            listaFinal.add(_CarguioItem(
              carguioRaw: c,
              ventaRaw: venta,
              ordenCarga: ordenCarga,
              estado: estado,
              fechaRegistro: fechaReg,
            ));
          }
        }
      }

      listaFinal.sort((a, b) => a.ordenCarga.compareTo(b.ordenCarga));
      await _cargarDisenos();

      if (mounted) {
        // Check for new carguios to play notification
        if (silent && listaFinal.length > carguiosDelDia.length && carguiosDelDia.isNotEmpty) {
          try {
            _audioPlayer.play(AssetSource('sounds/notification.mp3'));
          } catch (e) {
            debugPrint('Error playing sound: $e');
          }
        }

        setState(() {
          carguiosDelDia = listaFinal;
          bombasPorVenta = mapaBombas;
          loading = false;
        });
      }
    } catch (e) {
      if (!context.mounted) return;
      if (!silent) Helpers.showSnackBar(context, 'Error al cargar datos: $e', isError: true);
      if (mounted && !silent) setState(() => loading = false);
    }
  }

  Future<void> _cargarDisenos() async {
    try {
      final data = await supabase.from('disenos_mezcla').select();
      
      final prefs = await SharedPreferences.getInstance();
      List<String> activos = prefs.getStringList('disenos_activos') ?? [];

      if (mounted) {
        setState(() {
          disenosMezcla = data;
          // Ordenar para que los activos queden primero. Así firstWhere los encontrará prioritariamente.
          disenosMezcla.sort((a, b) {
            bool aActivo = activos.contains(a['id'].toString());
            bool bActivo = activos.contains(b['id'].toString());
            if (aActivo && !bActivo) return -1;
            if (!aActivo && bActivo) return 1;
            return 0;
          });
        });
      }
    } catch (e) {
      debugPrint("Error al cargar diseños: $e");
    }
  }

  Future<void> _seleccionarCarguio(_CarguioItem item) async {
    setState(() {
      carguioSeleccionado = item;
      cVolumen.text = item.ventaRaw['volumen']?.toString() ?? "";
      cMixer.clear();
      cOperador.clear();
      cOrdenCarguio.clear();
    });

    try {
      final activo = item.carguioRaw;
      if (mounted) {
        setState(() {
          cMixer.text = activo['codigo_mixer']?.toString() ?? '';
          cOperador.text = activo['operador_nombre']?.toString() ?? '';
          cOrdenCarguio.text = activo['orden_carga']?.toString() ?? '1';
          
          double volBase = double.tryParse(activo['volumen_carguio']?.toString() ?? '0') ?? 0.0;
          double opt = double.tryParse(activo['optimizado_vol']?.toString() ?? '0') ?? 0.0;
          double rep = double.tryParse(activo['reprocesado_vol']?.toString() ?? '0') ?? 0.0;
          
          optSeleccionado = opt;
          repSeleccionado = rep;
          
          if (volBase > 0) {
             double volNeto = volBase - opt - rep;
             cVolumen.text = volNeto.toStringAsFixed(2);
          }
        });
      }
    } catch (e) {
      debugPrint("Error al seleccionar carguío: $e");
    }

    _calcularDiseno();
  }

  String _getTipoVaciado(Map v) {
    String idVenta = v['id']?.toString() ?? '';
    String bombaAsignada = bombasPorVenta[idVenta] ?? 'DIRECTO'; // Lógica idéntica a gestor_mixers
    
    if (bombaAsignada.trim().toUpperCase() == 'DIRECTO') {
      return 'DIRECTO';
    }
    return 'BOMBEABLE';
  }

  void _calcularDiseno() {
    if (carguioSeleccionado == null) return;
    
    double vol = double.tryParse(cVolumen.text) ?? 0;
    if (vol <= 0) {
      _limpiarCalculos();
      return;
    }

    final ventaSel = carguioSeleccionado!.ventaRaw;
    String huso = (ventaSel['huso'] ?? '').toString().trim();
    String resistenciaRaw = (ventaSel['diseno'] ?? '').toString().trim();
    
    // Determinar si es BOMBEABLE o DIRECTO a partir de la columna 'bombas' o 'tipo_vaciado'
    String tipoVaciado = _getTipoVaciado(ventaSel);

    // Limpiar la resistencia porque ventas puede traer "F'c= 175" y en BD es solo "175"
    String resistenciaClean = resistenciaRaw.replaceAll(RegExp(r"f'c=?\s*", caseSensitive: false), "").trim();

    // 1. Intentar coincidencia exacta (Huso, Resistencia y Tipo Vaciado)
    try {
      disenoActual = disenosMezcla.firstWhere((d) => 
        (d['huso']?.toString().trim().toLowerCase() == huso.toLowerCase() || huso.isEmpty) &&
        (d['resistencia']?.toString().trim().toLowerCase() == resistenciaClean.toLowerCase()) &&
        (d['tipo_vaciado']?.toString().trim().toUpperCase() == tipoVaciado.toUpperCase())
      );
    } catch (e) {
      disenoActual = null;
    }

    // 2. FALLBACK 1: Ignorar tipo de vaciado si no encuentra el exacto
    if (disenoActual == null) {
      try {
        disenoActual = disenosMezcla.firstWhere((d) => 
          (d['huso']?.toString().trim().toLowerCase() == huso.toLowerCase() || huso.isEmpty) &&
          (d['resistencia']?.toString().trim().toLowerCase() == resistenciaClean.toLowerCase())
        );
        Helpers.showSnackBar(context, "Se usó diseño ${disenoActual!['tipo_vaciado']} (no había $tipoVaciado).");
      } catch (e) {
        disenoActual = null;
      }
    }

    // 3. FALLBACK 2: Ignorar el Huso (ej. escribieron Huso "7" en vez de "67") y buscar SOLO por Resistencia
    if (disenoActual == null) {
      try {
        disenoActual = disenosMezcla.firstWhere((d) => 
          (d['resistencia']?.toString().trim().toLowerCase() == resistenciaClean.toLowerCase())
        );
        // Mostrar aviso discreto de que se usó un huso aproximado
        Helpers.showSnackBar(context, "Huso '$huso' no encontrado. Se cargó diseño de ${disenoActual!['huso']} para f'c $resistenciaClean.");
      } catch (e) {
        disenoActual = null;
      }
    }

    if (disenoActual != null) {
      double baseCemento = double.tryParse(disenoActual!['cemento_kg']?.toString() ?? '0') ?? 0;
      double baseArena = double.tryParse(disenoActual!['arena_kg']?.toString() ?? '0') ?? 0;
      double basePiedraTotal = double.tryParse(disenoActual!['piedra_total_kg']?.toString() ?? '0') ?? 0;
      double baseAgua = double.tryParse(disenoActual!['agua_lt']?.toString() ?? '0') ?? 0;
      double baseAditivo = double.tryParse(disenoActual!['aditivo_kg']?.toString() ?? '0') ?? 0;

      double pctPiedra12 = double.tryParse(disenoActual!['piedra_12_porcentaje']?.toString() ?? '0') ?? 0;
      double pctPiedra34 = double.tryParse(disenoActual!['piedra_34_porcentaje']?.toString() ?? '0') ?? 0;
      double pctPiedra38 = double.tryParse(disenoActual!['piedra_38_porcentaje']?.toString() ?? '0') ?? 0;

      setState(() {
        disenoCemento = baseCemento * vol;
        disenoArena = baseArena * vol;
        disenoPiedra12 = (basePiedraTotal * (pctPiedra12 / 100.0)) * vol;
        disenoPiedra34 = (basePiedraTotal * (pctPiedra34 / 100.0)) * vol;
        disenoPiedra38 = (basePiedraTotal * (pctPiedra38 / 100.0)) * vol;
        disenoAgua = baseAgua * vol;
        disenoAditivo = baseAditivo * vol;
      });
    } else {
      _limpiarCalculos();
      Helpers.showSnackBar(context, "No se encontró el diseño para Huso: $huso, Resistencia: $resistenciaRaw", isError: true);
    }
  }

  void _limpiarCalculos() {
    setState(() {
      disenoActual = null;
      disenoCemento = 0;
      disenoArena = 0;
      disenoPiedra12 = 0;
      disenoPiedra34 = 0;
      disenoPiedra38 = 0;
      disenoAgua = 0;
      disenoAditivo = 0;
    });
  }

  Future _guardarCarguio() async {
    if (carguioSeleccionado == null) {
      Helpers.showSnackBar(context, 'Seleccione un viaje primero', isError: true);
      return;
    }
    double vol = double.tryParse(cVolumen.text) ?? 0;
    if (vol <= 0) {
      Helpers.showSnackBar(context, 'Ingrese un volumen válido', isError: true);
      return;
    }

    setState(() => guardando = true);

    try {
      final v = carguioSeleccionado!.ventaRaw;
      final payload = {
        'fecha': DateTime.now().toIso8601String(),
        'orden_carguio': int.tryParse(cOrdenCarguio.text) ?? 1,
        'cliente': v['nombre_razon_social'],
        'ubicacion': v['direccion'],
        'operador': cOperador.text.trim(),
        'mixer': cMixer.text.trim(),
        'volumen': vol,
        'diseno': v['diseno'],
        'huso': v['huso'],
        'tipo_vaciado': v['tipo_vaciado'],
        'estado': 'programada',
        'optimizado': optSeleccionado,
        'reprocesado': repSeleccionado,
        
        // Pesos Reales
        'cemento': double.tryParse(cRealCemento.text) ?? 0,
        'arena': double.tryParse(cRealArena.text) ?? 0,
        'piedra_12': double.tryParse(cRealPiedra12.text) ?? 0,
        'piedra_34': double.tryParse(cRealPiedra34.text) ?? 0,
        'piedra_38': double.tryParse(cRealPiedra38.text) ?? 0,
        'agua': double.tryParse(cRealAgua.text) ?? 0,
        'aditivo': double.tryParse(cRealAditivo.text) ?? 0,

        // Pesos Diseño
        'diseno_cemento': disenoCemento,
        'diseno_arena': disenoArena,
        'diseno_piedra_12': disenoPiedra12,
        'diseno_piedra_34': disenoPiedra34,
        'diseno_piedra_38': disenoPiedra38,
        'diseno_agua': disenoAgua,
        'diseno_aditivo': disenoAditivo,
      };

      await supabase.from('despachos_produccion').insert(payload);
      
      String idCarguio = carguioSeleccionado!.carguioRaw['id'].toString();
      await supabase.from('carguios_mixers').update({
        'estado': 'REGISTRADO'
      }).eq('id', idCarguio);
      
      // Verificación de tolerancia (Calidad)
      bool isFueraDeTolerancia(double realVal, double disenoVal) {
        if (disenoVal == 0) return realVal > 0;
        final diff = (realVal - disenoVal).abs();
        return (diff / disenoVal) > 0.05; // > 5%
      }

      final c = payload['cemento'] as double;
      final a = payload['arena'] as double;
      final p12 = payload['piedra_12'] as double;
      final p34 = payload['piedra_34'] as double;
      final p38 = payload['piedra_38'] as double;
      final ag = payload['agua'] as double;

      final fueraTol = isFueraDeTolerancia(c, disenoCemento) || 
                       isFueraDeTolerancia(a, disenoArena) ||
                       isFueraDeTolerancia(p12, disenoPiedra12) ||
                       isFueraDeTolerancia(p34, disenoPiedra34) ||
                       isFueraDeTolerancia(p38, disenoPiedra38) ||
                       isFueraDeTolerancia(ag, disenoAgua);

      if (fueraTol) {
        await NotificationService().notificarPorRoles(
          roles: ['calidad', 'jefe_op'],
          titulo: '⚠️ Alerta de Calidad (> 5%)',
          cuerpo: 'El carguío del Mixer ${cMixer.text.trim()} para ${v['nombre_razon_social']} presenta variaciones fuera de norma.',
        );
      }

      if (!context.mounted) return;
      Helpers.showSnackBar(context, 'Carguío registrado exitosamente');
      
      setState(() {
        carguioSeleccionado = null;
        cVolumen.clear();
        cRealCemento.clear();
        cRealArena.clear();
        cRealPiedra12.clear();
        cRealPiedra34.clear();
        cRealPiedra38.clear();
        cRealAgua.clear();
        cRealAditivo.clear();
        _limpiarCalculos();
      });
    } catch (e) {
      if (!context.mounted) return;
      Helpers.showSnackBar(context, 'Error al guardar: $e', isError: true);
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Registro de Carguío", style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold, fontSize: 24)),
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black12,
        iconTheme: const IconThemeData(color: AppColors.primaryDark),
        centerTitle: false,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : isMobile 
              ? _buildMobileLayout()
              : _buildDesktopLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Columna Izquierda: Selección de Pedido
          Expanded(
            flex: 2,
            child: _buildListaPedidos(isMobile: false),
          ),
          const SizedBox(width: 24),
          // Columna Derecha: Formulario y Pesos
          Expanded(
            flex: 3,
            child: _buildFormulario(isMobile: false),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildListaPedidos(isMobile: true),
          const SizedBox(height: 24),
          _buildFormulario(isMobile: true),
        ],
      ),
    );
  }

  Color _getColorForCarguio(_CarguioItem item) {
    String estado = item.estado.toUpperCase();
    if (estado == 'CARGANDO') return Colors.yellow.shade100;
    
    if (item.fechaRegistro != null) {
      final diff = DateTime.now().difference(item.fechaRegistro!).inMinutes;
      if (diff < 10) return Colors.blue.shade100;
      return Colors.green.shade100;
    }
    
    if (estado == 'REGISTRADO' || estado == 'DESPACHADO' || estado == 'EN OBRA') {
      return Colors.green.shade50;
    }
    
    return Colors.white;
  }

  Widget _buildListaPedidos({required bool isMobile}) {
    Widget content = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: carguiosDelDia.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: Text("No hay viajes programados con número de orden.", style: TextStyle(color: Colors.grey, fontSize: 16))),
            )
          : ListView.separated(
              shrinkWrap: isMobile,
              physics: isMobile ? const NeverScrollableScrollPhysics() : null,
              padding: const EdgeInsets.all(16),
              itemCount: carguiosDelDia.length,
              separatorBuilder: (context, index) => const Divider(height: 24),
              itemBuilder: (context, i) {
                final item = carguiosDelDia[i];
                final v = item.ventaRaw;
                bool seleccionado = carguioSeleccionado != null && carguioSeleccionado!.carguioRaw['id'] == item.carguioRaw['id'];
                
                Color cardColor = _getColorForCarguio(item);

                return InkWell(
                  onTap: () => _seleccionarCarguio(item),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: seleccionado ? AppColors.accent.withOpacity(0.1) : cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: seleccionado ? AppColors.accent : (cardColor == Colors.white ? Colors.grey.shade200 : cardColor.withOpacity(0.8)), 
                        width: seleccionado ? 2 : 1
                      ),
                      boxShadow: cardColor != Colors.white && !seleccionado ? [BoxShadow(color: cardColor.withOpacity(0.5), blurRadius: 4, offset: const Offset(0, 2))] : [],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                              child: Text("#${item.ordenCarga}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(v['nombre_razon_social'] ?? 'Desconocido', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryDark), overflow: TextOverflow.ellipsis)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                              child: Text("${item.carguioRaw['volumen_carguio'] ?? '0'} m³", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.accent)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.fire_truck, size: 16, color: Colors.grey.shade700),
                            const SizedBox(width: 4),
                            Text("Mixer ${item.carguioRaw['codigo_mixer'] ?? '-'} | ${item.carguioRaw['operador_nombre'] ?? '-'}", style: TextStyle(color: Colors.grey.shade800, fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _badge("Diseño: ${v['diseno'] ?? '-'}"),
                            _badge("Huso: ${v['huso'] ?? '-'}"),
                            _badge("Tipo: ${_getTipoVaciado(v)}"),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
          ),
          child: const Row(
            children: [
              Icon(Icons.list_alt, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text("1. Seleccione Pedido a Cargar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))),
            ],
          ),
        ),
        isMobile ? content : Expanded(child: content),
      ],
    );
  }

  Widget _buildFormulario({required bool isMobile}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: SingleChildScrollView(
        physics: isMobile ? const NeverScrollableScrollPhysics() : null,
        padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("2. Detalles del Despacho", Icons.local_shipping),
            if (optSeleccionado > 0 || repSeleccionado > 0)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200)
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "${optSeleccionado > 0 ? 'Optimizado: ${optSeleccionado}m³ ' : ''}"
                        "${repSeleccionado > 0 ? 'Reprocesado: ${repSeleccionado}m³' : ''}".trim(),
                        style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            if (isMobile) ...[
              _buildModernInput("Orden N°", cOrdenCarguio, Icons.tag, true),
              const SizedBox(height: 12),
              _buildModernInput("Mixer", cMixer, Icons.fire_truck),
              const SizedBox(height: 12),
              _buildModernInput("Operador", cOperador, Icons.person),
              const SizedBox(height: 12),
              TextFormField(
                controller: cVolumen,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 16,
                  color: (optSeleccionado > 0 || repSeleccionado > 0) ? Colors.orange.shade800 : null,
                ),
                decoration: InputDecoration(
                  labelText: "Volumen (m³)",
                  prefixIcon: const Icon(Icons.water_drop, color: AppColors.accent),
                  filled: true,
                  fillColor: AppColors.accent.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                ),
                onChanged: (v) => _calcularDiseno(),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(child: _buildModernInput("Orden N°", cOrdenCarguio, Icons.tag, true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildModernInput("Mixer", cMixer, Icons.fire_truck)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildModernInput("Operador", cOperador, Icons.person)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: cVolumen,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 16,
                        color: (optSeleccionado > 0 || repSeleccionado > 0) ? Colors.orange.shade800 : null,
                      ),
                      decoration: InputDecoration(
                        labelText: "Volumen (m³)",
                        prefixIcon: const Icon(Icons.water_drop, color: AppColors.accent),
                        filled: true,
                        fillColor: AppColors.accent.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      ),
                      onChanged: (v) => _calcularDiseno(),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 40),
            
            _buildSectionHeader("3. Control de Pesos (Balanza)", Icons.monitor_weight),
            const SizedBox(height: 20),
            if (disenoActual != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 20, left: 4),
                child: Text(
                  "Diseño Extraído Automáticamente: f'c=${disenoActual!['resistencia']} • Huso ${disenoActual!['huso']} • ${disenoActual!['tipo_vaciado']}", 
                  style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 13)
                ),
              ),
            
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    constraints: BoxConstraints(
                      minWidth: isMobile ? 600 : constraints.maxWidth,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200, width: 2), 
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(2),
                          1: FlexColumnWidth(1.5),
                          2: FlexColumnWidth(1.5),
                        },
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: Colors.grey.shade50),
                            children: const [
                              Padding(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16), child: Text("MATERIAL", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                              Padding(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16), child: Text("PESO DISEÑO", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                              Padding(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16), child: Text("PESO BALANZA", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                            ]
                          ),
                          _buildTableRow("Cemento", "kg", Icons.square, Colors.blueGrey, disenoCemento, cRealCemento),
                          _buildTableRow("Arena", "kg", Icons.grain, Colors.amber.shade700, disenoArena, cRealArena),
                          _buildTableRow("Piedra 1/2", "kg", Icons.terrain, Colors.brown.shade400, disenoPiedra12, cRealPiedra12),
                          _buildTableRow("Piedra 3/4", "kg", Icons.terrain, Colors.brown.shade600, disenoPiedra34, cRealPiedra34),
                          _buildTableRow("Piedra 3/8", "kg", Icons.terrain, Colors.brown.shade800, disenoPiedra38, cRealPiedra38),
                          _buildTableRow("Agua", "Lt", Icons.water_drop, Colors.blue, disenoAgua, cRealAgua),
                          _buildTableRow("Aditivo", "kg", Icons.science, Colors.purple, disenoAditivo, cRealAditivo, isLast: true),
                        ],
                      ),
                    ),
                  ),
                );
              }
            ),
            
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.success, Color(0xFF059669)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: AppColors.success.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: guardando ? null : _guardarCarguio,
                  icon: guardando ? const SizedBox() : const Icon(Icons.send, color: Colors.white, size: 24),
                  label: guardando 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("GUARDAR REGISTRO Y ENVIAR", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: AppColors.accent),
        ),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
      ],
    );
  }

  Widget _buildModernInput(String label, TextEditingController controller, IconData icon, [bool isNumeric = false]) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: const TextStyle(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black54),
        prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
    );
  }

  TableRow _buildTableRow(String material, String unidad, IconData icon, Color color, double diseno, TextEditingController controller, {bool isLast = false}) {
    return TableRow(
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Text("$material ($unidad)", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
              child: Text(diseno.toStringAsFixed(2), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.accent),
            decoration: InputDecoration(
              hintText: "0.00",
              hintStyle: TextStyle(color: Colors.grey.shade400),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent, width: 2)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}
