import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ← sigue para auth + perfil
import 'package:cloud_firestore/cloud_firestore.dart';   // ← NUEVO: GPS en vivo
import 'package:geolocator/geolocator.dart';
import '../../core/utils/google_sheets_service.dart';

class ChecklistPage extends StatefulWidget {
  final String? operadorNombre;
  final String? placaAsignada;

  const ChecklistPage({
    super.key,
    this.operadorNombre,
    this.placaAsignada,
  });

  @override
  State<ChecklistPage> createState() => _ChecklistPageState();
}

class _ChecklistPageState extends State<ChecklistPage> {
  final _formKey = GlobalKey<FormState>();
  bool _enviando = false;

  final TextEditingController _unidadController    = TextEditingController();
  final TextEditingController _operadorController  = TextEditingController();
  final TextEditingController _horometroController = TextEditingController();
  final TextEditingController _observacionesController = TextEditingController();

  // ── GPS ──────────────────────────────────────────────────────────────────
  // Usamos String porque el doc de Firestore es conductorId.toString()

  final Map<String, Map<String, String>> _checklistData = {
    "SISTEMA ELECTRICO": {
      "Luces Altas": "OK", "Luces Bajas": "OK", "Luces de Freno": "OK",
      "Luces de Estacionamiento": "OK", "Faros piratas": "OK", "Luces Direccionales": "OK",
      "Luces de Emergencia": "OK", "Panel instrumentos y marcadores": "OK", "Alzavidrios": "OK",
      "Alarma de retroceso": "OK", "Arnes (cables)": "OK", "Correa Alternador": "OK",
      "Baterias": "OK", "Bocina": "OK",
    },
    "SISTEMA MOTOR": {
      "Ruidos Extraños": "OK", "Potencia Motor": "OK", "Fugas hidraulicas": "OK",
      "Fuga de refrigerante": "OK", "Fuga de Combustible": "OK", "Estado del ventilador": "OK",
      "NIvel de aceite": "OK", "Nivel de refrigerante": "OK", "Alarmas": "OK",
      "Estado del tensor de la correo": "OK",
    },
    "SISTEMA DE TRANSMISION": {
      "Palanca selectora marcha": "OK", "Fuga de aceite de caja, diferencial o mandos": "OK",
      "Ruido extraño": "OK", "Toma de fuerza": "OK", "NIvel de aceite de caja": "OK",
      "Nivel de liquido de embrague": "OK", "Estado del embrague": "OK",
      "Estado de las crucetas": "OK", "Estado de cardan": "OK",
    },
    "SISTEMA DE FRENOS": {
      "Nivel de liquido de frenos": "OK", "Presencia de fugas de aire o liquido": "OK",
      "Capacidad de frenado": "OK", "Freno motor / retardador": "OK",
    },
    "SISTEMA HIDRAULICO Y TROMPO": {
      "Nivel aceite hidraulico": "OK", "Estado general del reductor hidraulico": "OK",
      "Estado de las mangueras hidraulicas": "OK", "Estado de los polines de giro": "OK",
      "Hermetecidad de las conexiones hidraulicas": "OK", "Estado de la bomba hidraulica": "OK",
      "Estado del trompo": "OK", "Estado del chute": "OK", "Estado Pistones de levante de chute": "OK",
      "Estado de los controles hidraulicos": "OK",
    },
    "SISTEMA DE DIRECCION Y NEUMATICOS": {
      "Nivel de aceite de direccion": "OK", "Estado de la direccion (juego excesivo)": "OK",
      "Estado de neumaticos": "OK", "Estado de llantas": "OK", "Pernos completos y tuercas torque": "OK",
      "Estado del parabrisas, luneta y laterales": "OK", "Estado del limpiaparabrisas / plumillas": "OK",
      "Estado de puertas": "OK", "Estado de asientos": "OK", "Sellado de cabina ": "OK",
      "Estado del cinturon de seguridad": "OK", "Golpes, choques": "OK",
    },
    "SEGURIDAD Y EQUIPAMIENTO": {
      "Extintor de 9kg": "OK", "Caja de proteccion de extintor": "OK",
      "Botiquin de primeros auxilios": "OK", "Cuñas (x2)": "OK", "Chaleco relfectante": "OK",
      "Conos de seguridad (x2)": "OK", "Logo de la empresa": "OK", "EPPs": "OK",
      "Otro (mencionar)": "OK",
    },
  };

  @override
  void initState() {
    super.initState();
    if (widget.operadorNombre != null) _operadorController.text = widget.operadorNombre!;
    if (widget.placaAsignada  != null) _unidadController.text   = widget.placaAsignada!;
    _cargarPerfilOperador();
  }

  @override
  void dispose() {

    _unidadController.dispose();
    _operadorController.dispose();
    _horometroController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────────────────
  // PERFIL: sigue usando Supabase (auth + tabla conductores)
  // ────────────────────────────────────────────────────────────────────────
  Future<void> _cargarPerfilOperador() async {
    final client = Supabase.instance.client;
    final user   = client.auth.currentUser;
    if (user == null) return;

    try {
      final userData = await client
          .from('usuarios')
          .select('rol, nombre')
          .eq('id', user.id)
          .single();

      if (userData['rol'] == 'operador') {
        final conductorData = await client
            .from('conductores')
            .select('id, nombre, marca')
            .eq('usuario_id', user.id)
            .maybeSingle();

        if (conductorData != null) {
          if (mounted) {
            setState(() {
              _operadorController.text = conductorData['nombre'] ?? userData['nombre'] ?? '';
              _unidadController.text   = conductorData['marca']  ?? '';
            
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error al cargar perfil de operador: $e");
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // CHECKLIST → GOOGLE SHEETS (sin cambios)
  // ────────────────────────────────────────────────────────────────────────
  Future<void> _guardarChecklist() async {
    if (_formKey.currentState?.validate() == true) {
      setState(() => _enviando = true);

      final Map<String, String> checklistPlano = {};
      _checklistData.forEach((seccion, items) {
        items.forEach((item, estado) => checklistPlano[item] = estado);
      });

      final Map<String, dynamic> datos = {
        "unidad"           : _unidadController.text,
        "operador"         : _operadorController.text,
        "placa"            : _unidadController.text,
        "horometro"        : _horometroController.text,
        "observaciones"    : _observacionesController.text,
        "checklist_detalle": checklistPlano,
      };

      final bool exito = await GoogleSheetsService.enviarChecklist(datos);

      if (!mounted) return;
      setState(() => _enviando = false);

      if (exito) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Checklist enviado correctamente'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _horometroController.clear();
        _observacionesController.clear();
        setState(() {
          _checklistData.forEach((s, items) {
            items.forEach((key, _) => items[key] = "OK");
          });
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('❌ Error al enviar. Revisa tu conexión.'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── UI helpers ───────────────────────────────────────────────────────────
  Widget _buildCheckRow(String seccion, String item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              item,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 5,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                padding: EdgeInsets.zero,
                visualDensity: const VisualDensity(horizontal: -4, vertical: -3),
                selectedBackgroundColor:
                    _getColorForState(_checklistData[seccion]![item]!),
                selectedForegroundColor: Colors.white,
              ),
              segments: const [
                ButtonSegment(value: 'OK', label: Text('OK', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: 'R',  label: Text('R',  style: TextStyle(fontSize: 11))),
                ButtonSegment(value: 'F',  label: Text('F',  style: TextStyle(fontSize: 11))),
                ButtonSegment(value: 'M',  label: Text('M',  style: TextStyle(fontSize: 11))),
              ],
              selected: {_checklistData[seccion]![item]!},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _checklistData[seccion]![item] = newSelection.first;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForState(String state) {
    switch (state) {
      case 'OK': return Colors.green.shade600;
      case 'R':  return Colors.orange.shade500;
      case 'F':  return Colors.deepOrange.shade400;
      case 'M':  return Colors.red.shade700;
      default:   return Colors.blue;
    }
  }

  IconData _getIconForSection(String seccion) {
    if (seccion.contains("ELECTRICO"))   return Icons.bolt;
    if (seccion.contains("MOTOR"))       return Icons.settings;
    if (seccion.contains("TRANSMISION")) return Icons.swap_horiz;
    if (seccion.contains("FRENOS"))      return Icons.car_crash;
    if (seccion.contains("HIDRAULICO"))  return Icons.water_drop;
    if (seccion.contains("DIRECCION"))   return Icons.tire_repair;
    if (seccion.contains("SEGURIDAD"))   return Icons.health_and_safety;
    return Icons.checklist;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Inspección Pre-Operacional',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        
      ),
      body: _enviando
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Enviando reporte...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'DATOS DE LA UNIDAD',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _operadorController,
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: 'Operador Asignado',
                                prefixIcon: const Icon(
                                  Icons.person,
                                  color: Colors.grey,
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _unidadController,
                                    decoration: InputDecoration(
                                      labelText: 'Placa / Unidad',
                                      prefixIcon: const Icon(
                                        Icons.local_shipping,
                                        color: Colors.grey,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    validator: (v) =>
                                        v == null || v.isEmpty ? 'Requerido' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _horometroController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Horómetro',
                                      prefixIcon: const Icon(
                                        Icons.timer,
                                        color: Colors.grey,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    validator: (v) =>
                                        v == null || v.isEmpty ? 'Requerido' : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'EVALUACIÓN TÉCNICA',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    Card(
                      elevation: 0,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: _checklistData.keys.map((seccion) {
                          final itemCount = _checklistData[seccion]!.length;
                          final failCount = _checklistData[seccion]!.values
                              .where((v) => v != 'OK')
                              .length;
                          return Theme(
                            data: theme.copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              backgroundColor:
                                  Colors.blue.shade50.withOpacity(0.3),
                              collapsedBackgroundColor: Colors.white,
                              leading: Icon(
                                _getIconForSection(seccion),
                                color: failCount > 0
                                    ? Colors.orange.shade700
                                    : Colors.blue.shade700,
                              ),
                              title: Text(
                                seccion,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (failCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$failCount fallas',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.orange.shade800,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$itemCount items',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const Icon(Icons.expand_more),
                                ],
                              ),
                              children: [
                                const Divider(height: 1),
                                const SizedBox(height: 4),
                                ..._checklistData[seccion]!.keys
                                    .map((item) => _buildCheckRow(seccion, item)),
                                const SizedBox(height: 8),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'OBSERVACIONES ADICIONALES',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    TextFormField(
                      controller: _observacionesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText:
                            'Escribe aquí si hay faltantes, golpes o requerimientos especiales...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.blue.shade800,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.cloud_upload_rounded),
                        label: const Text(
                          'ENVIAR CHECKLIST',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        onPressed: _guardarChecklist,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}