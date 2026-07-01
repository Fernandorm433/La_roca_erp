// lib/screens/ventas/cotizaciones_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/cotizacion_pdf_generator.dart';
import 'cotizacion_pdf_preview.dart';

// ─── MODELO LOCAL ─────────────────────────────────────────────────────────────
class _ItemLocal {
  final String tipo, descripcion, unidad, aditivo;
  final String resistencia, elemento, slump, huso, cemento, tipoVaciado;
  final List<String> detalles;
  final double cantidad, precioUnitario;

  _ItemLocal({
    required this.tipo, required this.descripcion, required this.unidad,
    required this.detalles, required this.cantidad, required this.precioUnitario,
    this.resistencia = '', this.elemento = '', this.slump = '',
    this.huso = '', this.cemento = '', this.tipoVaciado = '', this.aditivo = '',
  });

  double get subtotal => cantidad * precioUnitario;

  ItemCotizacion toPdf() => ItemCotizacion(
    tipo: tipo, descripcion: descripcion, detalles: detalles,
    cantidad: cantidad, unidad: unidad, precioUnitario: precioUnitario,
  );
}

// ─── STEPPER ──────────────────────────────────────────────────────────────────
class _Stepper extends StatelessWidget {
  final int paso;
  const _Stepper({required this.paso});

  @override
  Widget build(BuildContext context) {
    final labels = ['Recibo', 'Cliente', 'Productos'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Row(
        children: List.generate(3, (i) {
          final done = i < paso;
          final active = i == paso;
          return Expanded(
            child: Row(children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (done || active) ? AppColors.primaryDark : Colors.grey.shade300,
                ),
                child: Center(child: done
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : active
                        ? const Icon(Icons.edit, color: Colors.white, size: 16)
                        : Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12))),
              ),
              const SizedBox(width: 6),
              Text(labels[i], style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: (done || active) ? AppColors.primaryDark : Colors.grey.shade400,
              )),
              if (i < 2) Expanded(child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: done ? AppColors.primaryDark : Colors.grey.shade300,
              )),
            ]),
          );
        }),
      ),
    );
  }
}

// ─── MAIN PAGE ────────────────────────────────────────────────────────────────
class CotizacionesPage extends StatefulWidget {
  final Map<String, dynamic>? cotizacionExistente;
  final Map<String, dynamic>? datosParaDuplicar;

  const CotizacionesPage({super.key, this.cotizacionExistente, this.datosParaDuplicar});

  @override
  State<CotizacionesPage> createState() => _CotizacionesPageState();
}

class _CotizacionesPageState extends State<CotizacionesPage> {
  final _sb = Supabase.instance.client;

  int _paso = 0;

  // PASO 0
  String _tipoComprobante = 'Factura';
  Map<String, dynamic>? _asesorSel;
  DateTime? _fechaEntrega;
  List<Map<String, dynamic>> _asesores = [];

  // Usuario actual y rol
  Map<String, dynamic>? _empleadoActual;
  String _rolActual = '';

  // PASO 1 – Búsqueda de cliente
  final _searchClienteCtrl = TextEditingController();
  final _docCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _dirClienteCtrl = TextEditingController();
  final _dirObraCtrl = TextEditingController();
  final _mapsCtrl = TextEditingController();
  final _distritoCtrl = TextEditingController();

  List<Map<String, dynamic>> _sugerencias = [];
  bool _buscandoCliente = false;
  bool _clienteSeleccionado = false;
  bool _mostrarNuevo = false;

  // PASO 2
  List<_ItemLocal> _items = [];
  bool _guardando = false;
  bool _generandoReq = false;

  bool get _esEdicion => widget.cotizacionExistente != null;
  bool get _esAdmin => _rolActual == 'admin';

  static const String _GAS_URL =
      'https://script.google.com/macros/s/AKfycbzKlmfOBqCQSewWueYIdBwvjj_RP7uUty2qGRjGeS3i1XrS3a0qiLeUMl8I8SfT3ut2Fg/exec';

  @override
  void initState() {
    super.initState();
    _cargarUsuarioYAsesores();
    _precargar();
  }

  @override
  void dispose() {
    for (final c in [_searchClienteCtrl, _docCtrl, _nombreCtrl, _telCtrl,
        _dirClienteCtrl, _dirObraCtrl, _mapsCtrl, _distritoCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarUsuarioYAsesores() async {
    final user = _sb.auth.currentUser;
    try {
      // Cargar todos los asesores
      final asesores = await _sb.from('empleados')
          .select('id, nombres, apellidos, telefono, rol')
          .eq('activo', true)
          .order('nombres');
      setState(() => _asesores = List<Map<String, dynamic>>.from(asesores));

      // Cargar empleado actual por email o de la tabla usuarios si es admin externo
      if (user != null) {
        Map<String, dynamic>? emp;
        if (user.email != null) {
          emp = await _sb.from('empleados')
              .select()
              .eq('email', user.email!)
              .maybeSingle();
        }

        Map<String, dynamic>? usu;
        if (emp == null) {
          usu = await _sb.from('usuarios')
              .select('rol')
              .eq('id', user.id)
              .maybeSingle();
        }

        if (emp != null || usu != null) {
          setState(() {
            if (emp != null) {
              _empleadoActual = emp;
              _rolActual = (emp['rol'] ?? '').toString().toLowerCase();
              // Auto-asignar asesor al usuario actual por defecto
              if (_asesorSel == null) {
                _asesorSel = emp;
              }
            } else if (usu != null) {
              _rolActual = (usu['rol'] ?? '').toString().toLowerCase();
            }
          });
        }
      }
    } catch (_) {}
  }

  void _precargar() {
    final src = widget.cotizacionExistente ?? widget.datosParaDuplicar;
    if (src == null) return;
    _docCtrl.text = src['cliente_documento'] ?? '';
    _nombreCtrl.text = src['cliente_nombre'] ?? '';
    _telCtrl.text = src['cliente_telefono'] ?? '';
    _dirClienteCtrl.text = src['cliente_direccion'] ?? '';
    _dirObraCtrl.text = src['obra_direccion'] ?? '';
    _mapsCtrl.text = src['obra_maps_link'] ?? '';
    _distritoCtrl.text = src['obra_distrito'] ?? '';
    _tipoComprobante = src['tipo_comprobante'] ?? 'Factura';
    if (_nombreCtrl.text.isNotEmpty) {
      _searchClienteCtrl.text = _nombreCtrl.text;
      _clienteSeleccionado = true;
    }
    final rawItems = src['cotizacion_items'] as List? ?? [];
    _items = rawItems.map((i) => _ItemLocal(
      tipo: i['tipo'] ?? 'Concreto',
      descripcion: i['descripcion'] ?? '',
      detalles: List<String>.from(i['detalles'] ?? []),
      cantidad: double.tryParse(i['cantidad'].toString()) ?? 0,
      unidad: i['unidad'] ?? 'M³',
      precioUnitario: double.tryParse(i['precio_unitario'].toString()) ?? 0,
      resistencia: i['resistencia'] ?? '',
      elemento: i['elemento'] ?? '',
      slump: i['slump'] ?? '',
      huso: i['huso'] ?? '',
      cemento: i['tipo_cemento'] ?? '',
      tipoVaciado: i['bombeable'] == true ? 'BOMBEABLE' : 'DIRECTO',
      aditivo: i['aditivo'] ?? '',
    )).toList();
  }

  // ─── BÚSQUEDA INTELIGENTE DE CLIENTES ────────────────────────────────────
  Future<void> _buscarClientes(String q) async {
    if (q.trim().length < 2) {
      setState(() { _sugerencias = []; _mostrarNuevo = false; });
      return;
    }
    setState(() => _buscandoCliente = true);
    try {
      final q2 = q.trim();
      
      // Buscar en cotizaciones (tiene más datos de obra)
      final byNombreCot = await _sb.from('cotizaciones')
          .select('cliente_nombre, cliente_documento, cliente_telefono, cliente_direccion, obra_direccion, obra_maps_link, obra_distrito')
          .ilike('cliente_nombre', '%$q2%')
          .order('cliente_nombre')
          .limit(6);
      final byDocCot = await _sb.from('cotizaciones')
          .select('cliente_nombre, cliente_documento, cliente_telefono, cliente_direccion, obra_direccion, obra_maps_link, obra_distrito')
          .ilike('cliente_documento', '%$q2%')
          .order('cliente_nombre')
          .limit(4);

      // Buscar en ventas_programacion por si es un cliente antiguo que no tiene cotización
      final byNombreVP = await _sb.from('ventas_programacion')
          .select('nombre_razon_social, dni_ruc, telefono, direccion, distrito')
          .ilike('nombre_razon_social', '%$q2%')
          .order('nombre_razon_social')
          .limit(6);
      final byDocVP = await _sb.from('ventas_programacion')
          .select('nombre_razon_social, dni_ruc, telefono, direccion, distrito')
          .ilike('dni_ruc', '%$q2%')
          .order('nombre_razon_social')
          .limit(4);

      // Normalizar datos de cotizaciones
      final listCot = <Map<String, dynamic>>[...List.from(byNombreCot), ...List.from(byDocCot)].map((c) => {
        'nombre_razon_social': c['cliente_nombre'],
        'dni_ruc': c['cliente_documento'],
        'telefono': c['cliente_telefono'],
        'direccion': c['cliente_direccion'],
        'obra_direccion': c['obra_direccion'],
        'obra_maps_link': c['obra_maps_link'],
        'obra_distrito': c['obra_distrito'],
      }).toList();

      // Normalizar datos de ventas_programacion
      final listVP = <Map<String, dynamic>>[...List.from(byNombreVP), ...List.from(byDocVP)].map((c) => {
        'nombre_razon_social': c['nombre_razon_social'],
        'dni_ruc': c['dni_ruc'],
        'telefono': c['telefono'],
        'direccion': c['direccion'],
        'obra_direccion': c['direccion'],
        'obra_maps_link': '',
        'obra_distrito': c['distrito'] ?? '',
      }).toList();

      // Merge y deduplicar por dni_ruc (dando prioridad a cotizaciones porque tiene más datos)
      final merged = <Map<String, dynamic>>[...listCot, ...listVP];
      final seen = <String>{};
      final unique = merged.where((c) {
        final key = '${c['dni_ruc']}_${c['nombre_razon_social']}';
        return seen.add(key);
      }).toList();

      setState(() {
        _sugerencias = unique;
        _mostrarNuevo = unique.isEmpty;
      });
    } catch (_) {
      setState(() { _sugerencias = []; _mostrarNuevo = true; });
    } finally {
      setState(() => _buscandoCliente = false);
    }
  }

  void _seleccionarCliente(Map<String, dynamic> c) {
    setState(() {
      _searchClienteCtrl.text = c['nombre_razon_social'] ?? '';
      _nombreCtrl.text = c['nombre_razon_social'] ?? '';
      _docCtrl.text = c['dni_ruc'] ?? '';
      _telCtrl.text = c['telefono'] ?? '';
      _dirClienteCtrl.text = c['direccion'] ?? '';
      _dirObraCtrl.text = c['obra_direccion'] ?? '';
      _mapsCtrl.text = c['obra_maps_link'] ?? '';
      _distritoCtrl.text = c['obra_distrito'] ?? '';
      _clienteSeleccionado = true;
      _sugerencias = [];
      _mostrarNuevo = false;
    });
  }

  void _crearNuevoCliente() {
    setState(() {
      _nombreCtrl.text = _searchClienteCtrl.text;
      _docCtrl.text = '';
      _telCtrl.text = '';
      _dirClienteCtrl.text = '';
      _clienteSeleccionado = true;
      _sugerencias = [];
      _mostrarNuevo = false;
    });
  }

  void _limpiarCliente() {
    setState(() {
      _searchClienteCtrl.clear();
      _nombreCtrl.clear();
      _docCtrl.clear();
      _telCtrl.clear();
      _dirClienteCtrl.clear();
      _clienteSeleccionado = false;
      _sugerencias = [];
      _mostrarNuevo = false;
    });
  }

  // ─── TOTALES ─────────────────────────────────────────────────────────────
  double get _sub => _items.fold(0, (s, i) => s + i.subtotal);
  double get _igvPct => _tipoComprobante == 'Recibo' ? 0 : 18;
  double get _igvM => _sub * (_igvPct / 100);
  double get _total => _sub + _igvM;

  Future<String> _genNumero({int offset = 0}) async {
    final yr = DateTime.now().year;
    try {
      final d = await _sb.from('cotizaciones')
          .select('numero_cotizacion')
          .like('numero_cotizacion', 'COT-$yr-%')
          .order('numero_cotizacion', ascending: false)
          .limit(1);
      if ((d as List).isNotEmpty) {
        final last = d.first['numero_cotizacion'] as String;
        final n = int.tryParse(last.split('-').last) ?? 0;
        return 'COT-$yr-${(n + 1 + offset).toString().padLeft(5, '0')}';
      }
    } catch (_) {}
    return 'COT-$yr-${(1 + offset).toString().padLeft(5, '0')}';
  }

  void _snack(String m, {bool err = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m),
        backgroundColor: err ? Colors.red.shade700 : AppColors.primaryDark,
      ));

  bool _validarPaso() {
    if (_paso == 0) {
      if (_asesorSel == null) { _snack('Selecciona un asesor', err: true); return false; }
      if (_fechaEntrega == null) { _snack('Selecciona fecha y hora de entrega', err: true); return false; }
    }
    if (_paso == 1) {
      if (_nombreCtrl.text.trim().isEmpty) { _snack('Selecciona o ingresa un cliente', err: true); return false; }
      if (_dirObraCtrl.text.trim().isEmpty) { _snack('Ingresa la dirección de la obra', err: true); return false; }
    }
    return true;
  }

  Future<void> _guardar() async {
    if (_items.isEmpty) { _snack('Agrega al menos un producto', err: true); return; }
    setState(() => _guardando = true);
    try {
      final asesorNombre = _asesorSel != null
          ? '${_asesorSel!['nombres']} ${_asesorSel!['apellidos'] ?? ''}'.trim()
          : '';
      final payload = {
        'cliente_nombre': _nombreCtrl.text.toUpperCase().trim(),
        'cliente_documento': _docCtrl.text,
        'cliente_tipo_documento': _docCtrl.text.length == 11 ? 'RUC' : 'DNI',
        'cliente_telefono': _telCtrl.text,
        'cliente_direccion': _dirClienteCtrl.text,
        'obra_direccion': _dirObraCtrl.text,
        'obra_maps_link': _mapsCtrl.text,
        'obra_distrito': _distritoCtrl.text,
        'tipo_comprobante': _tipoComprobante,
        'asesor_id': _asesorSel?['id'],
        'asesor_nombre': asesorNombre,
        'asesor_telefono': _asesorSel?['telefono'] ?? '',
        'hora_entrega': _fechaEntrega?.toIso8601String(),
        'subtotal': _sub,
        'igv_porcentaje': _igvPct,
        'igv_monto': _igvM,
        'total': _total,
      };

      String cotId;
      if (_esEdicion) {
        await _sb.from('cotizaciones').update(payload).eq('id', widget.cotizacionExistente!['id']);
        cotId = widget.cotizacionExistente!['id'];
        await _sb.from('cotizacion_items').delete().eq('cotizacion_id', cotId);
      } else {
        payload['estado'] = 'borrador';
        int intento = 0;
        while (true) {
          try {
            payload['numero_cotizacion'] = await _genNumero(offset: intento);
            final r = await _sb.from('cotizaciones').insert(payload).select().single();
            cotId = r['id'];
            break;
          } on PostgrestException catch (e) {
            if (e.code == '23505' && intento < 5) { intento++; continue; }
            rethrow;
          }
        }
      }

      final itemsPayload = _items.asMap().entries.map((e) => {
        'cotizacion_id': cotId,
        'tipo': e.value.tipo,
        'descripcion': e.value.descripcion,
        'detalles': e.value.detalles,
        'cantidad': e.value.cantidad,
        'unidad': e.value.unidad,
        'precio_unitario': e.value.precioUnitario,
        'resistencia': e.value.resistencia,
        'elemento': e.value.elemento,
        'slump': e.value.slump,
        'huso': e.value.huso,
        'tipo_cemento': e.value.cemento,
        'bombeable': e.value.tipoVaciado == 'BOMBEABLE',
        'aditivo': e.value.aditivo,
        'orden': e.key,
      }).toList();

      await _sb.from('cotizacion_items').insert(itemsPayload);
      _snack(_esEdicion ? 'Cotización actualizada ✅' : 'Cotización creada ✅');
      if (mounted) Navigator.pop(context);
    } catch (e) { _snack('Error: $e', err: true); }
    finally { setState(() => _guardando = false); }
  }

  Future<void> _pdf() async {
    if (_items.isEmpty) { _snack('Agrega al menos un producto', err: true); return; }
    try {
      final asesorNombre = _asesorSel != null
          ? '${_asesorSel!['nombres']} ${_asesorSel!['apellidos'] ?? ''}'.trim()
          : (widget.cotizacionExistente?['asesor_nombre'] ?? '');
      final numero = widget.cotizacionExistente?['numero_cotizacion'] ?? await _genNumero();
      final nombre = _nombreCtrl.text.toUpperCase().trim().isEmpty ? 'CLIENTE' : _nombreCtrl.text.toUpperCase().trim();
      final datos = DatosCotizacion(
        numeroCotizacion: numero,
        fecha: DateTime.now(),
        clienteNombre: nombre,
        clienteDocumento: _docCtrl.text.isEmpty ? 'S/D' : _docCtrl.text,
        clienteDireccion: _dirObraCtrl.text.isEmpty ? 'S/D' : _dirObraCtrl.text,
        clienteTelefono: _telCtrl.text,
        asesorNombre: asesorNombre.toUpperCase(),
        asesorTelefono: _asesorSel?['telefono'] ?? '',
        igvPorcentaje: _igvPct,
        items: _items.map((i) => i.toPdf()).toList(),
      );
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CotizacionPdfPreview(cotizacion: datos),
          ),
        );
      }
    } catch (e) { _snack('Error PDF: $e', err: true); }
  }

  Future<void> _generarRequerimiento() async {
    if (_items.isEmpty) { _snack('Agrega al menos un producto', err: true); return; }
    if (_asesorSel == null) { _snack('Selecciona un asesor primero', err: true); return; }

    setState(() => _generandoReq = true);
    try {
      final asesorNombre = '${_asesorSel!['nombres']} ${_asesorSel!['apellidos'] ?? ''}'.trim();
      final fmt = DateFormat('dd/MM/yyyy');
      final fmtH = DateFormat('HH:mm');
      final fecha = _fechaEntrega ?? DateTime.now();

      final concreto = _items.firstWhere((i) => i.tipo == 'Concreto', orElse: () => _items.first);
      final hayBombeo = _items.any((i) =>
          i.tipoVaciado == 'BOMBEABLE' || (i.tipo == 'Servicio' && i.descripcion.contains('BOMBA')));

      final params = {
        'asesor': asesorNombre,
        'day': fmt.format(fecha),
        'hour': fmtH.format(fecha),
        'client': _nombreCtrl.text.toUpperCase().trim(),
        'tipoDocumento': _docCtrl.text.length == 11 ? 'RUC' : 'DNI',
        'document': _docCtrl.text,
        'address': _dirObraCtrl.text,
        'phone': _telCtrl.text,
        'distrito': _distritoCtrl.text,
        'volumen': concreto.cantidad.toString(),
        'fuerza': concreto.resistencia.isNotEmpty ? concreto.resistencia : concreto.descripcion,
        'elemento': concreto.elemento,
        'huso': concreto.huso,
        'slump': concreto.slump,
        'aditivo': concreto.aditivo,
        'cemento': concreto.cemento,
        'bombas': hayBombeo ? 'SI' : '',
        'extensiones': '',
        'selectedMixer': '',
        'selectedCapacity': '',
        'time': fmtH.format(fecha),
        'quality': '',
        'commentReturn': '',
        'location': _mapsCtrl.text,
        'urlVoucher': '',
        'emisionReq': DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
        'observaciones': '',
      };

      final body = params.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final res = await http.post(
        Uri.parse(_GAS_URL),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );

      if (res.statusCode == 200 && res.body.contains('SUCCESS')) {
        _snack('✅ Requerimiento enviado al Drive');
      } else {
        _snack('Error al enviar: ${res.statusCode}', err: true);
      }
    } catch (e) {
      _snack('Error: $e', err: true);
    } finally {
      setState(() => _generandoReq = false);
    }
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_esEdicion ? 'Editar Cotización' : 'Crear Cotización',
            style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(children: [
        Container(color: Colors.white, child: _Stepper(paso: _paso)),
        const Divider(height: 1, color: Color(0xFFE0EDE0)),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: [_buildPaso0(), _buildPaso1(), _buildPaso2()][_paso],
          ),
        ),
        _buildFooter(),
      ]),
    );
  }

  // ─── PASO 0: RECIBO ───────────────────────────────────────────────────────
  Widget _buildPaso0() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Campo(
        label: 'Tipo de comprobante',
        child: DropdownButtonFormField<String>(
          value: _tipoComprobante,
          decoration: _deco(''),
          items: ['Factura', 'Boleta', 'Recibo'].map((t) => DropdownMenuItem(
            value: t,
            child: Row(children: [
              const Icon(Icons.receipt_outlined, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Text(t),
            ]),
          )).toList(),
          onChanged: (v) => setState(() => _tipoComprobante = v!),
        ),
      ),
      const SizedBox(height: 14),

      // Asesor: solo visible para ADMIN
      _Campo(
        label: 'Asignar a nombre de',
        child: _esAdmin
            ? DropdownButtonFormField<String>(
                value: (_asesorSel != null && _asesores.any((a) => a['id'].toString() == _asesorSel!['id'].toString()))
                    ? _asesorSel!['id'].toString()
                    : null,
                decoration: _deco('Seleccione un asesor').copyWith(
                  prefixIcon: const Icon(Icons.person_outline, color: Colors.grey),
                ),
                isExpanded: true,
                items: _asesores.map((a) {
                  final nombre = '${a['nombres']} ${a['apellidos'] ?? ''}'.trim();
                  return DropdownMenuItem<String>(
                    value: a['id'].toString(), 
                    child: Text(nombre, style: const TextStyle(fontSize: 14)),
                  );
                }).toList(),
                onChanged: (id) {
                  if (id != null) {
                    setState(() {
                      _asesorSel = _asesores.firstWhere((a) => a['id'].toString() == id);
                    });
                  }
                },
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F7F0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(children: [
                  const Icon(Icons.person, color: AppColors.primaryDark, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    _asesorSel != null
                        ? '${_asesorSel!['nombres']} ${_asesorSel!['apellidos'] ?? ''}'.trim()
                        : 'Cargando...',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A2E1A)),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _rolActual.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ]),
              ),
      ),
      const SizedBox(height: 22),

      const Text('Fecha y hora de entrega',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A2E1A))),
      const SizedBox(height: 10),
      GestureDetector(
        onTap: _seleccionarFecha,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_today_outlined, color: Colors.grey, size: 20),
            const SizedBox(width: 12),
            Text(
              _fechaEntrega != null
                  ? DateFormat('dd MMM yyyy · HH:mm').format(_fechaEntrega!)
                  : 'Seleccione una fecha y hora',
              style: TextStyle(
                fontSize: 14,
                color: _fechaEntrega != null ? Colors.black87 : Colors.grey,
              ),
            ),
            const Spacer(),
            const Icon(Icons.access_time, color: Colors.grey, size: 20),
          ]),
        ),
      ),
    ]);
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaEntrega ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primaryDark)),
        child: child!,
      ),
    );
    if (fecha == null || !mounted) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fechaEntrega ?? DateTime.now()),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primaryDark)),
        child: child!,
      ),
    );
    if (hora == null || !mounted) return;
    setState(() => _fechaEntrega =
        DateTime(fecha.year, fecha.month, fecha.day, hora.hour, hora.minute));
  }

  // ─── PASO 1: CLIENTE CON BÚSQUEDA INTELIGENTE ────────────────────────────
  Widget _buildPaso1() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Buscar cliente',
          style: TextStyle(fontSize: 13, color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),

      // Campo de búsqueda
      if (!_clienteSeleccionado) ...[
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: TextField(
            controller: _searchClienteCtrl,
            autofocus: false,
            decoration: InputDecoration(
              hintText: 'Nombre, RUC o DNI...',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _buscandoCliente
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryDark)))
                  : _searchClienteCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                          onPressed: _limpiarCliente)
                      : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onChanged: (v) => _buscarClientes(v),
          ),
        ),
        const SizedBox(height: 4),

        // Lista de sugerencias
        if (_sugerencias.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: _sugerencias.asMap().entries.map((e) {
                final c = e.value;
                final isLast = e.key == _sugerencias.length - 1;
                return InkWell(
                  onTap: () => _seleccionarCliente(c),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: isLast ? null : Border(bottom: BorderSide(color: Colors.grey.shade100)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.person_outline, color: AppColors.primaryDark, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c['nombre_razon_social'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1A2E1A))),
                        if (c['dni_ruc'] != null)
                          Text(c['dni_ruc'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ])),
                      const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),

        // Crear cliente nuevo
        if (_mostrarNuevo && _searchClienteCtrl.text.trim().length >= 2)
          InkWell(
            onTap: _crearNuevoCliente,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA5D6A7)),
              ),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person_add, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Crear nuevo cliente',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A2E1A))),
                  Text('"${_searchClienteCtrl.text.trim()}"',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ])),
                const Icon(Icons.add_circle, color: AppColors.primaryDark, size: 20),
              ]),
            ),
          ),
      ] else ...[
        // Cliente seleccionado — mostrar tarjeta
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFA5D6A7)),
          ),
          child: Row(children: [
            const Icon(Icons.check_circle, color: AppColors.primaryDark, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_nombreCtrl.text.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A2E1A))),
              if (_docCtrl.text.isNotEmpty)
                Text(_docCtrl.text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              if (_telCtrl.text.isNotEmpty)
                Text('Tel: ${_telCtrl.text}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ])),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.primaryDark, size: 20),
              onPressed: _limpiarCliente,
            ),
          ]),
        ),
        const SizedBox(height: 10),

        // Campos adicionales para nuevo cliente (si doc está vacío = nuevo)
        if (_docCtrl.text.isEmpty) ...[
          const Text('Completar datos del nuevo cliente',
              style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          _Campo(label: 'DNI o RUC',
              child: TextField(controller: _docCtrl, keyboardType: TextInputType.number, decoration: _deco('Número de documento'))),
          const SizedBox(height: 10),
          _Campo(label: 'Nombre / Razón Social',
              child: TextField(controller: _nombreCtrl, textCapitalization: TextCapitalization.characters, decoration: _deco('Nombre completo'))),
          const SizedBox(height: 10),
          _Campo(label: 'Teléfono',
              child: TextField(controller: _telCtrl, keyboardType: TextInputType.phone, decoration: _deco('Número de contacto'))),
          const SizedBox(height: 10),
          _Campo(label: 'Dirección del cliente',
              child: TextField(controller: _dirClienteCtrl, decoration: _deco('Dirección fiscal / domicilio'))),
          const SizedBox(height: 10),
        ],
      ],

      const SizedBox(height: 20),
      const Text('Datos de la obra',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A2E1A))),
      const SizedBox(height: 10),
      _Campo(label: 'Dirección de obra',
          child: TextField(controller: _dirObraCtrl, decoration: _deco('Dirección exacta'))),
      const SizedBox(height: 10),
      _Campo(label: 'Ubicación (Google Maps)',
          child: TextField(controller: _mapsCtrl, decoration: _deco('https://maps.google.com/...'))),
      const SizedBox(height: 10),
      _Campo(label: 'Distrito',
          child: TextField(controller: _distritoCtrl, decoration: _deco('Cerro Colorado'))),
    ]);
  }

  // ─── PASO 2: PRODUCTOS ────────────────────────────────────────────────────
  Widget _buildPaso2() {
    final fmt = NumberFormat('#,##0.00', 'es_PE');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_items.isEmpty)
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text('No hay productos agregados',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54)),
              const SizedBox(height: 6),
              const Text('Toca "Agregar productos" para comenzar.',
                  style: TextStyle(color: Colors.grey)),
            ]),
          ),
        )
      else ...[
        ..._items.asMap().entries.map((e) => _ItemCard(
          item: e.value,
          onEdit: () => _modalProducto(editar: e.value, index: e.key),
          onDel: () => setState(() => _items.removeAt(e.key)),
        )),
        const SizedBox(height: 10),
      ],

      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Total:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text('S/ ${fmt.format(_total)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
      ]),
      const SizedBox(height: 16),

      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryDark,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Agregar Productos',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          onPressed: () => _modalProducto(),
        ),
      ),

      if (_items.isEmpty) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(10)),
          child: const Row(children: [
            Icon(Icons.info_outline, color: Colors.blueGrey, size: 18),
            SizedBox(width: 10),
            Expanded(child: Text('Agrega al menos un producto antes de continuar.',
                style: TextStyle(color: Colors.blueGrey, fontSize: 13))),
          ]),
        ),
      ],

    ]);
  }

  // ─── FOOTER ───────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      child: Row(children: [
        if (_paso > 0)
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => setState(() => _paso--),
              child: const Text('Atrás', style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
            ),
          ),
        if (_paso > 0) const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: _paso < 2
                ? () { if (_validarPaso()) setState(() => _paso++); }
                : (_guardando ? null : _guardar),
            child: _guardando
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Text(_paso < 2 ? 'Continuar' : 'Crear Cotización',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
        if (_paso == 2) ...[
          const SizedBox(width: 10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              side: const BorderSide(color: AppColors.primaryDark),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _pdf,
            child: const Icon(Icons.picture_as_pdf, color: AppColors.primaryDark),
          ),
        ],
      ]),
    );
  }

  // ─── MODAL AGREGAR PRODUCTO ───────────────────────────────────────────────
  void _modalProducto({_ItemLocal? editar, int? index}) {
    String tipo = editar?.tipo ?? 'Concreto';
    final resCtrl = TextEditingController(text: editar?.resistencia ?? '210');
    final elemCtrl = TextEditingController(text: editar?.elemento ?? '');
    final servNomCtrl = TextEditingController(text: editar?.tipo == 'Servicio' ? editar!.descripcion : '');
    final servDescCtrl = TextEditingController(
        text: editar?.detalles.isNotEmpty == true ? editar!.detalles.first : '');
    final cantCtrl = TextEditingController(text: editar != null ? editar.cantidad.toString() : '1');
    final precCtrl = TextEditingController(text: editar != null ? editar.precioUnitario.toString() : '0');
    String huso = editar?.huso ?? '57';
    String slump = editar?.slump ?? '4" - 6"';
    String cemento = editar?.cemento ?? 'YURA 1P';
    String tipoVaciado = editar?.tipoVaciado ?? 'Directo';
    final aditCtrl = TextEditingController(text: editar?.aditivo ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setM) {
        return Container(
          margin: EdgeInsets.only(top: MediaQuery.of(ctx).padding.top + 60),
          decoration: const BoxDecoration(
            color: Color(0xFFF2F5F2),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F5F0),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Agregar producto',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: tipo,
                      decoration: _deco('Tipo'),
                      items: ['Concreto', 'Adicional', 'Servicio']
                          .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setM(() => tipo = v!),
                    ),
                    const SizedBox(height: 14),

                    if (tipo == 'Concreto') ...[
                      const Text('DETALLES TÉCNICOS',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark, letterSpacing: .8)),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: TextFormField(
                          controller: resCtrl,
                          keyboardType: TextInputType.number,
                          decoration: _deco('Resistencia (fc)'),
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: DropdownButtonFormField<String>(
                          value: tipoVaciado,
                          decoration: _deco('Suministro'),
                          items: ['Directo', 'Bombeable']
                              .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                          onChanged: (v) => setM(() => tipoVaciado = v!),
                        )),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: DropdownButtonFormField<String>(
                          value: huso,
                          decoration: _deco('Huso'),
                          items: ['57', '67', '7', '467']
                              .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                          onChanged: (v) => setM(() => huso = v!),
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: DropdownButtonFormField<String>(
                          value: slump,
                          decoration: _deco('Slump'),
                          items: ['3" - 4"', '4" - 6"', '6" - 8"']
                              .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                          onChanged: (v) => setM(() => slump = v!),
                        )),
                      ]),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: cemento,
                        decoration: _deco('Cemento'),
                        items: ['YURA HE', 'YURA 1P', 'YURA IP', 'YURA HS', 'MISHKY']
                            .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (v) => setM(() => cemento = v!),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: elemCtrl,
                        decoration: _deco('Elemento'),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: aditCtrl,
                        decoration: _deco('Aditivo (opcional)'),
                      ),
                    ] else ...[
                      TextFormField(
                        controller: servNomCtrl,
                        decoration: _deco('Nombre'),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: servDescCtrl,
                        decoration: _deco('Descripción (opcional)'),
                        maxLines: 2,
                      ),
                    ],

                    const SizedBox(height: 14),
                    const Text('CANTIDAD Y PRECIO',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark, letterSpacing: .8)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: TextFormField(
                        controller: cantCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _deco('Cantidad').copyWith(
                          suffixText: tipo == 'Concreto' ? 'm³' : null,
                        ),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: TextFormField(
                        controller: precCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _deco('Precio unit.').copyWith(prefixText: 'S/ '),
                      )),
                    ]),
                    const SizedBox(height: 20),

                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancelar',
                            style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primaryDark,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: AppColors.primaryDark)),
                        ),
                        onPressed: () {
                          final cant = double.tryParse(cantCtrl.text) ?? 0;
                          final prec = double.tryParse(precCtrl.text) ?? 0;
                          if (cant <= 0 || prec <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Ingresa cantidad y precio válidos'),
                              backgroundColor: Colors.red,
                            ));
                            return;
                          }
                          late _ItemLocal item;
                          if (tipo == 'Concreto') {
                            if (resCtrl.text.isEmpty || elemCtrl.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('Completa resistencia y elemento'),
                                backgroundColor: Colors.red,
                              ));
                              return;
                            }
                            final cemPDF = cemento == 'YURA HE' ? 'YURA PRO' : cemento;
                            item = _ItemLocal(
                              tipo: 'Concreto',
                              descripcion: 'Concreto fc ${resCtrl.text} - $tipoVaciado',
                              detalles: [
                                'ELEMENTO: ${elemCtrl.text.toUpperCase()}',
                                'SLUMP: $slump',
                                'TIPO CEMENTO: $cemPDF',
                                'HUSO: $huso',
                                if (aditCtrl.text.isNotEmpty) 'ADITIVO: ${aditCtrl.text}',
                              ],
                              cantidad: cant, unidad: 'M³', precioUnitario: prec,
                              resistencia: resCtrl.text, elemento: elemCtrl.text.toUpperCase(),
                              slump: slump, huso: huso, cemento: cemPDF,
                              tipoVaciado: tipoVaciado.toUpperCase(),
                              aditivo: aditCtrl.text,
                            );
                          } else {
                            if (servNomCtrl.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('Ingresa el nombre del servicio'),
                                backgroundColor: Colors.red,
                              ));
                              return;
                            }
                            item = _ItemLocal(
                              tipo: tipo,
                              descripcion: servNomCtrl.text.toUpperCase(),
                              detalles: servDescCtrl.text.isNotEmpty ? [servDescCtrl.text] : [],
                              cantidad: cant, unidad: 'glb', precioUnitario: prec,
                            );
                          }
                          setState(() {
                            if (index != null) { _items[index] = item; }
                            else { _items.add(item); }
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Agregar', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ]),
                  ]),
                ),
              ),
            ),
          ]),
        );
      }),
    );
  }

  // Helpers UI
  InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.5)),
  );
}

// ─── WIDGETS AUXILIARES ───────────────────────────────────────────────────────
class _Campo extends StatelessWidget {
  final String label;
  final Widget child;
  const _Campo({required this.label, required this.child});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (label.isNotEmpty) ...[
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
      ],
      child,
    ],
  );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Text('$label $value', style: const TextStyle(fontSize: 13, color: Colors.black87)),
  );
}

class _ItemCard extends StatelessWidget {
  final _ItemLocal item;
  final VoidCallback onEdit, onDel;
  const _ItemCard({required this.item, required this.onEdit, required this.onDel});
  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'es_PE');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.descripcion,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A2E1A))),
          const SizedBox(height: 4),
          Text('Cantidad: ${item.cantidad}  |  Unit: S/ ${fmt.format(item.precioUnitario)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ])),
        IconButton(icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blueGrey), onPressed: onEdit),
        IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), onPressed: onDel),
      ]),
    );
  }
}