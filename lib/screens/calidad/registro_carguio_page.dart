import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../core/services/notificacion_service.dart';

class RegistroCarguioPage extends StatefulWidget {
  const RegistroCarguioPage({super.key});

  @override
  State<RegistroCarguioPage> createState() => _RegistroCarguioPageState();
}

class _RegistroCarguioPageState extends State<RegistroCarguioPage> {
  final supabase = Supabase.instance.client;
  bool loading = true;
  bool guardando = false;

  List ventasDelDia = [];
  Map<String, dynamic>? ventaSeleccionada;
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

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  Future _cargarDatosIniciales() async {
    setState(() => loading = true);
    try {
      String hoy = DateTime.now().toIso8601String().split('T')[0];
      String manana = DateTime.now().add(const Duration(days: 1)).toIso8601String().split('T')[0];

      // 1. Cargar Ventas del día
      final vData = await supabase
          .from('ventas_programacion')
          .select()
          .gte('fecha_entrega', hoy)
          .lt('fecha_entrega', manana);

      // Solo pedidos con volumen asignado
      List filtradas = [];
      for (var v in vData) {
        String volStr = v['volumen']?.toString() ?? '0';
        double vol = double.tryParse(volStr.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
        if (vol > 0) filtradas.add(v);
      }

      await _cargarDisenos();

      // CARGAR BOMBAS
      final asignaciones = await supabase.from("asignacion_bombas").select();
      Map<String, String> mapaBombas = {};
      for (var a in asignaciones) {
        mapaBombas[a['id_venta'].toString()] = a['bomba_asignada'].toString();
      }

      if (mounted) {
        setState(() {
          ventasDelDia = filtradas;
          bombasPorVenta = mapaBombas;
          loading = false;
        });
      }
    } catch (e) {
      Helpers.showSnackBar(context, 'Error al cargar datos: $e', isError: true);
      if (mounted) setState(() => loading = false);
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

  Future<void> _seleccionarVenta(Map<String, dynamic> venta) async {
    setState(() {
      ventaSeleccionada = venta;
      cVolumen.text = venta['volumen']?.toString() ?? "";
      cMixer.clear();
      cOperador.clear();
      cOrdenCarguio.clear();
    });

    try {
      // Buscar el mixer y operador asignados en la hoja "Despachos" (carguios_mixers)
      final carguios = await supabase
          .from('carguios_mixers')
          .select()
          .eq('id_venta', venta['id'])
          .order('id', ascending: true); // Podríamos buscar el primero que esté 'Pendiente', por ahora el último o primero
      
      if (carguios.isNotEmpty) {
        // Buscar el primer carguío que no esté Entregado/Finalizado, o el primero por defecto
        final activo = carguios.firstWhere(
          (c) => c['estado'] != 'Entregado' && c['estado'] != 'Terminado',
          orElse: () => carguios.last,
        );

        if (mounted) {
          setState(() {
            cMixer.text = activo['codigo_mixer']?.toString() ?? '';
            cOperador.text = activo['operador_nombre']?.toString() ?? '';
            cOrdenCarguio.text = activo['orden_carga']?.toString() ?? '1';
            if (activo['volumen'] != null && double.tryParse(activo['volumen'].toString()) != null && double.parse(activo['volumen'].toString()) > 0) {
               cVolumen.text = activo['volumen'].toString();
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error al cargar detalles de despacho: $e");
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
    if (ventaSeleccionada == null) return;
    
    double vol = double.tryParse(cVolumen.text) ?? 0;
    if (vol <= 0) {
      _limpiarCalculos();
      return;
    }

    String huso = (ventaSeleccionada!['huso'] ?? '').toString().trim();
    String resistenciaRaw = (ventaSeleccionada!['diseno'] ?? '').toString().trim();
    
    // Determinar si es BOMBEABLE o DIRECTO a partir de la columna 'bombas' o 'tipo_vaciado'
    String tipoVaciado = _getTipoVaciado(ventaSeleccionada!);

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
    if (ventaSeleccionada == null) {
      Helpers.showSnackBar(context, 'Seleccione un pedido primero', isError: true);
      return;
    }
    double vol = double.tryParse(cVolumen.text) ?? 0;
    if (vol <= 0) {
      Helpers.showSnackBar(context, 'Ingrese un volumen válido', isError: true);
      return;
    }

    setState(() => guardando = true);

    try {
      final payload = {
        'fecha': DateTime.now().toIso8601String(),
        'orden_carguio': int.tryParse(cOrdenCarguio.text) ?? 1,
        'cliente': ventaSeleccionada!['nombre_razon_social'],
        'ubicacion': ventaSeleccionada!['direccion'],
        'operador': cOperador.text.trim(),
        'mixer': cMixer.text.trim(),
        'volumen': vol,
        'diseno': ventaSeleccionada!['diseno'],
        'huso': ventaSeleccionada!['huso'],
        'tipo_vaciado': ventaSeleccionada!['tipo_vaciado'],
        'estado': 'programada',
        
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
          cuerpo: 'El carguío del Mixer ${cMixer.text.trim()} para ${ventaSeleccionada!['nombre_razon_social']} presenta variaciones fuera de norma.',
        );
      }

      Helpers.showSnackBar(context, 'Carguío registrado exitosamente');
      
      setState(() {
        ventaSeleccionada = null;
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

  Widget _buildListaPedidos({required bool isMobile}) {
    Widget content = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ventasDelDia.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: Text("No hay pedidos programados para hoy.", style: TextStyle(color: Colors.grey, fontSize: 16))),
            )
          : ListView.separated(
              shrinkWrap: isMobile,
              physics: isMobile ? const NeverScrollableScrollPhysics() : null,
              padding: const EdgeInsets.all(16),
              itemCount: ventasDelDia.length,
              separatorBuilder: (context, index) => const Divider(height: 24),
              itemBuilder: (context, i) {
                final v = ventasDelDia[i];
                bool seleccionado = ventaSeleccionada != null && ventaSeleccionada!['id'] == v['id'];
                return InkWell(
                  onTap: () => _seleccionarVenta(v),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: seleccionado ? AppColors.accent.withOpacity(0.05) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: seleccionado ? AppColors.accent : Colors.grey.shade200, width: seleccionado ? 2 : 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(v['nombre_razon_social'] ?? 'Desconocido', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryDark))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                              child: Text("${v['volumen']} m³", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.accent)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(child: Text("${v['direccion']}", style: const TextStyle(color: Colors.grey, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
