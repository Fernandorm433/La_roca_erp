// Archivo: lib/screens/calidad/granulometria_export_dialog.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GranulometriaExportDialog extends StatefulWidget {
  const GranulometriaExportDialog({super.key});
  @override
  State<GranulometriaExportDialog> createState() =>
      _GranulometriaExportDialogState();
}

class _GranulometriaExportDialogState extends State<GranulometriaExportDialog> {
  final _formKey = GlobalKey<FormState>();

  final _proyecto = TextEditingController();
  final _ubicacion = TextEditingController();
  final _cliente = TextEditingController();
  final _atencion = TextEditingController();
  final _material = TextEditingController();
  final _cantera = TextEditingController();
  final _muestraNro = TextEditingController(text: '1');
  final _muestreadoPor = TextEditingController();
  final _ensayadoPor = TextEditingController();
  final _responsable = TextEditingController();
  final _registro = TextEditingController();

  DateTime _fechaMuestreo = DateTime.now();
  DateTime _fechaAnalisis = DateTime.now();
  final _fmt = DateFormat('d/M/yyyy');

  static const _navy = Color(0xFF002244);
  static const _navyMid = Color(0xFF003366);
  static const _teal = Color(0xFF0284C7);
  static const _divider = Color(0xFFE2E8F0);
  static const _bg = Color(0xFFF8FAFC);
  static const _textLight = Color(0xFF94A3B8);
  static const _inputBg = Color(0xFFF8FAFC);

  @override
  void dispose() {
    for (final c in [
      _proyecto,
      _ubicacion,
      _cliente,
      _atencion,
      _material,
      _cantera,
      _muestraNro,
      _muestreadoPor,
      _ensayadoPor,
      _responsable,
      _registro,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(bool esMuestreo) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: esMuestreo ? _fechaMuestreo : _fechaAnalisis,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _navyMid,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(
      () => esMuestreo ? _fechaMuestreo = picked : _fechaAnalisis = picked,
    );
  }

  void _confirmar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop({
      'proyecto': _proyecto.text.trim(),
      'ubicacion': _ubicacion.text.trim(),
      'cliente': _cliente.text.trim(),
      'atencion': _atencion.text.trim(),
      'material': _material.text.trim(),
      'cantera': _cantera.text.trim(),
      'muestraNro': _muestraNro.text.trim(),
      'muestreadoPor': _muestreadoPor.text.trim(),
      'ensayadoPor': _ensayadoPor.text.trim(),
      'responsable': _responsable.text.trim(),
      'registro': _registro.text.trim(),
      'fechaMuestreo': _fmt.format(_fechaMuestreo),
      'fechaAnalisis': _fmt.format(_fechaAnalisis),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _navy.withOpacity(0.2),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _header(),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _section('PROYECTO'),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: _field(
                                  _proyecto,
                                  'Nombre del Proyecto',
                                  required: true,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: _field(_registro, 'Registro Nº')),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _field(_ubicacion, 'Ubicación del Proyecto'),
                          const SizedBox(height: 20),
                          _section('DATOS DEL CLIENTE'),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _field(
                                  _cliente,
                                  'Cliente',
                                  required: true,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: _field(_atencion, 'Atención')),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _field(
                                  _material,
                                  'Material',
                                  required: true,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _field(
                                  _cantera,
                                  'Cantera / Procedencia',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _section('DATOS DE LA MUESTRA'),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              SizedBox(
                                width: 90,
                                child: _field(
                                  _muestraNro,
                                  'Nº',
                                  required: true,
                                  kb: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _field(_muestreadoPor, 'Muestreado por'),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _field(_ensayadoPor, 'Ensayado por'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _datePick(
                                  'Fecha Muestreo',
                                  _fechaMuestreo,
                                  () => _pickDate(true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _datePick(
                                  'Fecha Análisis',
                                  _fechaAnalisis,
                                  () => _pickDate(false),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _field(_responsable, 'V°B° Responsable'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
                _footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [_navy, _navyMid]),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _teal.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.picture_as_pdf_rounded,
            color: _teal,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Exportar Informe PDF',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            Text(
              'Completa los datos del encabezado',
              style: TextStyle(color: Colors.white54, fontSize: 10.5),
            ),
          ],
        ),
        const Spacer(),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.close_rounded,
            color: Colors.white54,
            size: 20,
          ),
        ),
      ],
    ),
  );

  Widget _footer() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    decoration: const BoxDecoration(
      color: _bg,
      border: Border(top: BorderSide(color: _divider)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar', style: TextStyle(color: _textLight)),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: _confirmar,
          icon: const Icon(Icons.download_rounded, size: 16),
          label: const Text('Generar PDF'),
          style: FilledButton.styleFrom(
            backgroundColor: _navyMid,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _section(String t) => Row(
    children: [
      Container(
        width: 3,
        height: 14,
        decoration: BoxDecoration(
          color: _teal,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        t,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          color: _navyMid,
        ),
      ),
      const SizedBox(width: 12),
      const Expanded(child: Divider(color: _divider, height: 1)),
    ],
  );

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(fontSize: 11, color: _textLight),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    filled: true,
    fillColor: _inputBg,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(7),
      borderSide: const BorderSide(color: _divider),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(7),
      borderSide: const BorderSide(color: _divider),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(7),
      borderSide: const BorderSide(color: _navyMid, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(7),
      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
    ),
  );

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool required = false,
    TextInputType kb = TextInputType.text,
  }) => TextFormField(
    controller: ctrl,
    keyboardType: kb,
    style: const TextStyle(fontSize: 12, color: _navy),
    decoration: _dec(label),
    validator: required
        ? (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null
        : null,
  );

  Widget _datePick(String label, DateTime date, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: _inputBg,
            border: Border.all(color: _divider),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 13,
                color: _textLight,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontSize: 9.5, color: _textLight),
                    ),
                    Text(
                      _fmt.format(date),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _navy,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
