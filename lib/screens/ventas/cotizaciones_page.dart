// lib/screens/ventas/cotizaciones_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/cotizacion_pdf_generator.dart';

class CotizacionesPage extends StatefulWidget {
  final Map<String, dynamic>? cotizacionExistente;
  final Map<String, dynamic>? datosParaDuplicar;

  const CotizacionesPage({super.key, this.cotizacionExistente, this.datosParaDuplicar});

  @override
  State<CotizacionesPage> createState() => _CotizacionesPageState();
}

class _CotizacionesPageState extends State<CotizacionesPage> {
  final _supabase = Supabase.instance.client;
  final PageController _pageController = PageController();
  int _pasoActual = 0;

  // ─── Controladores Cliente ───
  final _busquedaCtrl = TextEditingController(); // Nuevo controlador general
  final _docCtrl = TextEditingController();
  final _nombresCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _direccionObraCtrl = TextEditingController();
  final _mapsObraCtrl = TextEditingController();
  final _distritoCtrl = TextEditingController();

  // ─── Controladores Producto ───
  String _tipoProducto = 'Concreto';
  final _nombreProdCtrl = TextEditingController();
  final _descProdCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController(text: '1');
  final _precioCtrl = TextEditingController(text: '0');
  
  String _husoValor = '57';
  String _slumpValor = '4" - 6"';
  String _cementoValor = 'YURA 1P';
  final _elementoCtrl = TextEditingController();

  // ─── Estado General ───
  String _tipoComprobante = 'Boleta';
  DateTime? _fechaEntrega;
  bool _buscandoCliente = false;
  bool _guardando = false;
  List<ItemCotizacion> _items = [];

  List<Map<String, dynamic>> _asesores = [];
  Map<String, dynamic>? _asesorSeleccionado;

  bool get _esEdicion => widget.cotizacionExistente != null;
  double get _total => _items.fold(0, (s, i) => s + (i.cantidad * i.precioUnitario));

  @override
  void initState() {
    super.initState();
    _cargarAsesores();
    _precargarDatos();
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    _docCtrl.dispose();
    _nombresCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _direccionCtrl.dispose();
    _direccionObraCtrl.dispose();
    _mapsObraCtrl.dispose();
    _distritoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarAsesores() async {
    try {
      final data = await _supabase.from('empleados').select('id, nombres, apellidos, telefono, rol')
          .filter('rol', 'in', '("asesor","ventas")').eq('activo', true).order('nombres');
      setState(() => _asesores = List<Map<String, dynamic>>.from(data));
    } catch (_) {}
  }

  void _precargarDatos() {
    final src = widget.cotizacionExistente ?? widget.datosParaDuplicar;
    if (src == null) return;
    _docCtrl.text = src['cliente_documento'] ?? '';
    _nombresCtrl.text = src['cliente_nombre'] ?? '';
    _telefonoCtrl.text = src['cliente_telefono'] ?? '';
    _direccionCtrl.text = src['cliente_direccion'] ?? '';
    _direccionObraCtrl.text = src['obra_direccion'] ?? '';
    _mapsObraCtrl.text = src['obra_maps_link'] ?? '';
    _distritoCtrl.text = src['obra_distrito'] ?? '';
    _tipoComprobante = src['tipo_comprobante'] ?? 'Boleta';
    if (src['hora_entrega'] != null) _fechaEntrega = DateTime.parse(src['hora_entrega']).toLocal();

    final itemsList = src['cotizacion_items'] as List? ?? [];
    _items = itemsList.map((i) => ItemCotizacion(
      tipo: i['tipo'] ?? 'Concreto', descripcion: i['descripcion'] ?? '',
      detalles: List<String>.from(i['detalles'] ?? []),
      cantidad: double.tryParse(i['cantidad'].toString()) ?? 0,
      unidad: i['unidad'] ?? 'M³', precioUnitario: double.tryParse(i['precio_unitario'].toString()) ?? 0,
    )).toList();
  }

  // ─── LÓGICA DE BÚSQUEDA INTELIGENTE ───
  // ─── LÓGICA DE BÚSQUEDA INTELIGENTE ───
  Future<void> _buscarCliente(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    
    setState(() => _buscandoCliente = true);
    
    try {
      final esNumero = RegExp(r'^[0-9]+$').hasMatch(q);
      
      // SOLUCIÓN: Quitamos 'correo' del select porque no existe en tu tabla de Supabase
      var request = _supabase.from('ventas_programacion')
          .select('dni_ruc, nombre_razon_social, telefono, direccion');
          
      if (esNumero && (q.length == 8 || q.length == 11)) {
        request = request.eq('dni_ruc', q);
      } else {
        request = request.ilike('nombre_razon_social', '%$q%');
      }
      
      final data = await request.order('created_at', ascending: false).limit(1);
          
      if (data != null && (data as List).isNotEmpty) {
        final c = data.first;
        setState(() {
          _docCtrl.text = c['dni_ruc'] ?? '';
          _nombresCtrl.text = c['nombre_razon_social'] ?? '';
          _telefonoCtrl.text = c['telefono'] ?? '';
          _direccionCtrl.text = c['direccion'] ?? '';
          _emailCtrl.clear(); // Lo limpiamos porque no viene de tu BD
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Cliente encontrado'), backgroundColor: Color(0xFF2E7D32)));
      } else {
        setState(() {
          if (esNumero) {
             _docCtrl.text = q;
             _nombresCtrl.clear();
          } else {
             _docCtrl.clear();
             _nombresCtrl.text = q;
          }
          _telefonoCtrl.clear(); 
          _direccionCtrl.clear(); 
          _emailCtrl.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No encontrado. Por favor, crea el cliente.'), backgroundColor: Colors.orange));
        _mostrarFormularioCliente();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _buscandoCliente = false);
    }
  }

  void _mostrarFormularioCliente() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFF1F5EB),
        title: const Text('Datos del Cliente', style: TextStyle(color: Color(0xFF2C3E50), fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CustomTextField(label: 'DNI o RUC', ctrl: _docCtrl, keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              _CustomTextField(label: 'Nombre / Razón Social', ctrl: _nombresCtrl),
              const SizedBox(height: 12),
              _CustomTextField(label: 'Dirección', ctrl: _direccionCtrl),
              const SizedBox(height: 12),
              _CustomTextField(label: 'Teléfono', ctrl: _telefonoCtrl, keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _CustomTextField(label: 'Email (Opcional)', ctrl: _emailCtrl, keyboardType: TextInputType.emailAddress),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF388E3C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              setState(() {}); 
              Navigator.pop(ctx);
            },
            child: const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─── RESTO DE LÓGICA DE COTIZACIÓN ───
  Future<void> _seleccionarFechaHora() async {
    final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (date == null) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;
    setState(() => _fechaEntrega = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  void _avanzarPaso() {
    if (_pasoActual < 2) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _pasoActual++);
    } else {
      _guardar();
    }
  }

  void _retrocederPaso() {
    if (_pasoActual > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _pasoActual--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<String> _genNumero() async {
    final yr = DateTime.now().year;
    try {
      final data = await _supabase.from('cotizaciones').select('numero_cotizacion')
          .like('numero_cotizacion', 'COT-$yr-%').order('numero_cotizacion', ascending: false).limit(1);
      if ((data as List).isNotEmpty) {
        final n = int.tryParse((data.first['numero_cotizacion'] as String).split('-').last) ?? 99;
        return 'COT-$yr-${(n + 1).toString().padLeft(5, '0')}';
      }
    } catch (_) {}
    return 'COT-$yr-00100';
  }

  Future<void> _guardar() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agrega al menos un producto')));
      return;
    }
    setState(() => _guardando = true);
    try {
      final subtotal = _total;
      final igvMonto = _tipoComprobante == 'Recibo' ? 0.0 : subtotal * 0.18;

      final payload = {
        'cliente_nombre': _nombresCtrl.text.toUpperCase().trim(),
        'cliente_documento': _docCtrl.text,
        'cliente_telefono': _telefonoCtrl.text,
        'cliente_direccion': _direccionCtrl.text,
        'obra_direccion': _direccionObraCtrl.text,
        'obra_maps_link': _mapsObraCtrl.text,
        'obra_distrito': _distritoCtrl.text,
        'tipo_comprobante': _tipoComprobante,
        'asesor_id': _asesorSeleccionado?['id'],
        'asesor_nombre': _asesorSeleccionado != null ? '${_asesorSeleccionado!['nombres']} ${_asesorSeleccionado!['apellidos'] ?? ''}'.trim() : '',
        'hora_entrega': _fechaEntrega?.toIso8601String(),
        'subtotal': subtotal,
        'igv_porcentaje': _tipoComprobante == 'Recibo' ? 0.0 : 18.0,
        'igv_monto': igvMonto,
        'total': subtotal + igvMonto,
      };

      String cotId;
      if (_esEdicion) {
        await _supabase.from('cotizaciones').update(payload).eq('id', widget.cotizacionExistente!['id']);
        cotId = widget.cotizacionExistente!['id'];
        await _supabase.from('cotizacion_items').delete().eq('cotizacion_id', cotId);
      } else {
        payload['numero_cotizacion'] = await _genNumero();
        payload['estado'] = 'borrador';
        final res = await _supabase.from('cotizaciones').insert(payload).select().single();
        cotId = res['id'];
      }

      final itemsPayload = _items.asMap().entries.map((e) => {
        'cotizacion_id': cotId, 'tipo': e.value.tipo, 'descripcion': e.value.descripcion, 'detalles': e.value.detalles,
        'cantidad': e.value.cantidad, 'unidad': e.value.unidad, 'precio_unitario': e.value.precioUnitario, 'orden': e.key,
      }).toList();

      await _supabase.from('cotizacion_items').insert(itemsPayload);
      if (mounted) Navigator.pop(context);
    } finally {
      setState(() => _guardando = false);
    }
  }

  void _mostrarModalProducto() {
    _tipoProducto = 'Adicional';
    _nombreProdCtrl.clear(); _descProdCtrl.clear(); _elementoCtrl.clear(); _cantidadCtrl.text = '1'; _precioCtrl.text = '0';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: const Color(0xFFF1F5EB),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Agregar producto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _tipoProducto, isExpanded: true,
                        items: ['Concreto', 'Adicional', 'Servicio'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setModalState(() => _tipoProducto = v!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_tipoProducto == 'Concreto') ...[
                    Row(children: [
                      Expanded(child: _CustomDropdown(label: 'Huso', value: _husoValor, items: const ['57', '67', '87', '7'], onChanged: (v) => setModalState(()=>_husoValor=v!))), const SizedBox(width: 12),
                      Expanded(child: _CustomDropdown(label: 'Slump', value: _slumpValor, items: const ['4" - 6"', '6" - 8"'], onChanged: (v) => setModalState(()=>_slumpValor=v!))),
                    ]), const SizedBox(height: 12),
                    _CustomDropdown(label: 'Cemento', value: _cementoValor, items: const ['YURA 1P', 'YURA HE', 'YURA HS'], onChanged: (v) => setModalState(()=>_cementoValor=v!)), const SizedBox(height: 12),
                    _CustomTextField(label: 'Elemento', ctrl: _elementoCtrl),
                  ] else ...[
                    _CustomTextField(label: 'Nombre', ctrl: _nombreProdCtrl), const SizedBox(height: 12),
                    _CustomTextField(label: 'Descripción (opcional)', ctrl: _descProdCtrl),
                  ],

                  const SizedBox(height: 16),
                  const Text('CANTIDAD Y PRECIO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _CustomTextField(label: 'Cantidad', ctrl: _cantidadCtrl, suffix: _tipoProducto == 'Concreto' ? 'm³' : null, keyboardType: TextInputType.number)), const SizedBox(width: 12),
                    Expanded(child: _CustomTextField(label: 'Precio unit.', ctrl: _precioCtrl, prefix: 'S/ ', keyboardType: TextInputType.number)),
                  ]),
                  
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold))), const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF1F8E9), foregroundColor: const Color(0xFF2E7D32), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () {
                          final cant = double.tryParse(_cantidadCtrl.text) ?? 1; final prec = double.tryParse(_precioCtrl.text) ?? 0;
                          late ItemCotizacion item;
                          if (_tipoProducto == 'Concreto') {
                            item = ItemCotizacion(tipo: 'Concreto', descripcion: 'CONCRETO - $_cementoValor', detalles: ['Elemento: ${_elementoCtrl.text}', 'Huso: $_husoValor', 'Slump: $_slumpValor'], cantidad: cant, unidad: 'm³', precioUnitario: prec);
                          } else {
                            item = ItemCotizacion(tipo: _tipoProducto, descripcion: _nombreProdCtrl.text, detalles: _descProdCtrl.text.isNotEmpty ? [_descProdCtrl.text] : [], cantidad: cant, unidad: 'und', precioUnitario: prec);
                          }
                          setState(() => _items.add(item)); Navigator.pop(ctx);
                        },
                        child: const Text('Agregar'),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── BUILD PRINCIPAL ───
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: _retrocederPaso),
        title: const Text('Crear Cotización', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF8F9FA), elevation: 0, centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StepIndicator(titulo: 'Recibo', activo: _pasoActual >= 0, esActual: _pasoActual == 0), _LineaStep(activo: _pasoActual >= 1),
                _StepIndicator(titulo: 'Cliente', activo: _pasoActual >= 1, esActual: _pasoActual == 1), _LineaStep(activo: _pasoActual >= 2),
                _StepIndicator(titulo: 'Productos', activo: _pasoActual >= 2, esActual: _pasoActual == 2),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.black12),
          Expanded(child: PageView(controller: _pageController, physics: const NeverScrollableScrollPhysics(), children: [_buildPaso1(), _buildPaso2(), _buildPaso3()])),
          Container(
            padding: const EdgeInsets.all(16), color: const Color(0xFFF8F9FA),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_pasoActual > 0) ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE8ECE5), foregroundColor: const Color(0xFF2E7D32), elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _retrocederPaso, child: const Text('Atrás', style: TextStyle(fontWeight: FontWeight.bold))) else const SizedBox(),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF388E3C), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: _guardando ? null : _avanzarPaso,
                  child: _guardando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Continuar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── PASOS ───
  Widget _buildPaso1() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      _Etiqueta('Tipo de comprobante'),
      Container(
        decoration: _boxDeco(),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _tipoComprobante, isExpanded: true, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            items: ['Boleta', 'Factura', 'Recibo'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _tipoComprobante = v!),
          ),
        ),
      ),
      const SizedBox(height: 20),
      _Etiqueta('Asignar a nombre de'),
      Container(
        decoration: _boxDeco(bordeActivo: true),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<Map<String, dynamic>>(
            value: _asesorSeleccionado, hint: const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Seleccione un asesor')), isExpanded: true, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            items: _asesores.map((a) => DropdownMenuItem(value: a, child: Text('${a['nombres']} ${a['apellidos'] ?? ''}'))).toList(), onChanged: (v) => setState(() => _asesorSeleccionado = v),
          ),
        ),
      ),
      const SizedBox(height: 20),
      const Text('Fecha y hora de entrega', style: TextStyle(fontSize: 16, color: Colors.black87)), const SizedBox(height: 8),
      InkWell(
        onTap: _seleccionarFechaHora,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), decoration: _boxDeco(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [const Icon(Icons.calendar_today_outlined, color: Colors.grey, size: 20), const SizedBox(width: 12), Text(_fechaEntrega != null ? DateFormat('dd MMM yyyy · HH:mm', 'es').format(_fechaEntrega!) : 'Seleccione una fecha y hora', style: TextStyle(color: _fechaEntrega != null ? Colors.black87 : Colors.grey))]),
              const Icon(Icons.access_time, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _buildPaso2() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      _Etiqueta('Buscar Cliente (DNI, RUC o Nombre)'),
      TextField(
        controller: _busquedaCtrl,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Ej: 76096724 o Juan Perez',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          filled: true, fillColor: Colors.white,
          suffixIcon: _buscandoCliente
              ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2E7D32)))
              : IconButton(
                  icon: const Icon(Icons.search, color: Color(0xFF2E7D32)),
                  onPressed: () => _buscarCliente(_busquedaCtrl.text),
                ),
        ),
        onSubmitted: (v) => _buscarCliente(v), 
      ),
      const SizedBox(height: 16),
      
      // Tarjeta Info Cliente
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Datos del Cliente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                TextButton.icon(
                  icon: const Icon(Icons.edit_note, size: 18),
                  label: const Text('Editar / Crear'),
                  onPressed: _mostrarFormularioCliente,
                )
              ],
            ),
            const Divider(),
            _InfoRow('Documento', _docCtrl.text),
            _InfoRow('Nombre', _nombresCtrl.text),
            _InfoRow('Dirección', _direccionCtrl.text),
            _InfoRow('Teléfono', _telefonoCtrl.text),
            _InfoRow('Email', _emailCtrl.text),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const Text('Datos de obra (solo cotización)', style: TextStyle(fontSize: 16, color: Colors.black87)),
      const SizedBox(height: 12),
      _CustomTextField(label: 'Dirección de obra', ctrl: _direccionObraCtrl), const SizedBox(height: 12),
      _CustomTextField(label: 'Ubicación (Google Maps)', ctrl: _mapsObraCtrl), const SizedBox(height: 12),
      _CustomTextField(label: 'Distrito', ctrl: _distritoCtrl, bordeActivo: true),
    ],
  );

  Widget _buildPaso3() => Column(
    children: [
      Expanded(
        child: _items.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_cart_outlined, size: 60, color: Colors.grey.shade400), const SizedBox(height: 16),
                    const Text('No hay productos agregados', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 4),
                    Text('Toca "Agregar productos" para comenzar.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(20), itemCount: _items.length,
                itemBuilder: (ctx, i) {
                  final it = _items[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12), elevation: 0, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                    child: ListTile(
                      title: Text(it.descripcion, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${it.cantidad} ${it.unidad} x S/ ${it.precioUnitario}'),
                      trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => setState(() => _items.removeAt(i))),
                    ),
                  );
                },
              ),
      ),
      Container(
        padding: const EdgeInsets.all(20), color: const Color(0xFFF8F9FA),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total:', style: TextStyle(fontSize: 18)), Text('S/ ${_total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, color: Color(0xFF2E7D32)))]),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF388E3C), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                icon: const Icon(Icons.add, color: Colors.white), label: const Text('Agregar Productos', style: TextStyle(color: Colors.white)),
                onPressed: _mostrarModalProducto,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFD4E6F1), borderRadius: BorderRadius.circular(8)),
              child: const Row(children: [Icon(Icons.info_outline, color: Color(0xFF154360)), SizedBox(width: 8), Expanded(child: Text('Agrega al menos un producto antes de poder enviar la cotización.', style: TextStyle(color: Color(0xFF154360), fontSize: 12)))]),
            )
          ],
        ),
      ),
    ],
  );
}

// ─── UI Helpers ───
Widget _Etiqueta(String t) => Padding(padding: const EdgeInsets.only(left: 8, bottom: 4, top: 8), child: Text(t, style: const TextStyle(fontSize: 11, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)));

BoxDecoration _boxDeco({bool bordeActivo = false}) => BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: bordeActivo ? const Color(0xFF2E7D32) : Colors.black12, width: bordeActivo ? 1.5 : 1));

Widget _InfoRow(String lbl, String val) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('$lbl: ${val.isEmpty ? '-' : val}', style: const TextStyle(fontSize: 14, color: Colors.black87)));

class _CustomTextField extends StatelessWidget {
  final String label; final TextEditingController ctrl; final bool bordeActivo; final String? prefix; final String? suffix; final TextInputType keyboardType;
  const _CustomTextField({required this.label, required this.ctrl, this.bordeActivo = false, this.prefix, this.suffix, this.keyboardType = TextInputType.text});

  @override
  Widget build(BuildContext context) => Container(
    decoration: _boxDeco(bordeActivo: bordeActivo),
    child: TextField(
      controller: ctrl, keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, labelStyle: TextStyle(color: bordeActivo ? const Color(0xFF2E7D32) : Colors.grey.shade600, fontSize: 14), prefixText: prefix, suffixText: suffix, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
    ),
  );
}

class _CustomDropdown extends StatelessWidget {
  final String label, value; final List<String> items; final Function(String?) onChanged;
  const _CustomDropdown({required this.label, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), decoration: _boxDeco(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        DropdownButtonHideUnderline(child: DropdownButton<String>(value: value, isExpanded: true, isDense: true, items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(), onChanged: onChanged)),
      ],
    ),
  );
}

class _StepIndicator extends StatelessWidget {
  final String titulo; final bool activo, esActual;
  const _StepIndicator({required this.titulo, required this.activo, required this.esActual});

  @override
  Widget build(BuildContext context) => Row(children: [Container(width: 24, height: 24, decoration: BoxDecoration(color: activo ? const Color(0xFF2E7D32) : Colors.grey.shade300, shape: BoxShape.circle), child: Icon(esActual ? Icons.edit : Icons.check, color: Colors.white, size: 14)), const SizedBox(width: 8), Text(titulo, style: TextStyle(color: activo ? Colors.black87 : Colors.grey.shade500, fontWeight: activo ? FontWeight.bold : FontWeight.normal, fontSize: 13))]);
}

class _LineaStep extends StatelessWidget {
  final bool activo;
  const _LineaStep({required this.activo});
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.symmetric(horizontal: 8), width: 20, height: 2, color: activo ? const Color(0xFF2E7D32) : Colors.grey.shade300);
}