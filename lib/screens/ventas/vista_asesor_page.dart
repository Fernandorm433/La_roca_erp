// Archivo: lib/screens/ventas/vista_asesor_page.dart
// Actualizado: pasa nombreAsesor/nombreCliente para notificaciones FCM

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/erp_service.dart';

class VistaAsesorPage extends StatefulWidget {
  final String nombre;
  final String asesorId;

  const VistaAsesorPage({
    super.key,
    required this.nombre,
    required this.asesorId,
  });

  @override
  State<VistaAsesorPage> createState() => _VistaAsesorPageState();
}

class _VistaAsesorPageState extends State<VistaAsesorPage> {
  bool modoVisitasActivo = false;
  StreamSubscription<Position>? _trackingSilenciosoStream;

  Position? ubicacionActual;
  bool estaGuardando = false;
  Map<String, dynamic>? tareaSeleccionada;
  File? fotoExterior;
  File? fotoInterior;
  File? videoEvidencia;

  final _nombreObraCtrl = TextEditingController();
  final _contactoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final ErpService _erp = ErpService();

  @override
  void dispose() {
    _trackingSilenciosoStream?.cancel();
    if (modoVisitasActivo) _erp.marcarAsesorInactivo(widget.asesorId);
    _nombreObraCtrl.dispose();
    _contactoCtrl.dispose();
    _telefonoCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleModoVisitas(bool activado) async {
    if (activado) {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _mostrarMensaje('Activa el GPS de tu celular primero', Colors.orange);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _mostrarMensaje('Permiso de ubicación denegado', Colors.red);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _mostrarMensaje('Activa los permisos en Ajustes del teléfono', Colors.red);
        return;
      }

      setState(() => modoVisitasActivo = true);

      try {
        final posInicial = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        await _erp.actualizarPosicion(
          widget.asesorId, widget.nombre, posInicial.latitude, posInicial.longitude,
        );
        _mostrarMensaje('✅ Modo visitas activado', Colors.green);
      } catch (e) {
        _mostrarMensaje('⚠️ GPS activo, posición inicial no obtenida', Colors.orange);
      }

      _trackingSilenciosoStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((pos) {
        _erp.actualizarPosicion(widget.asesorId, widget.nombre, pos.latitude, pos.longitude);
      });
    } else {
      _trackingSilenciosoStream?.cancel();
      _trackingSilenciosoStream = null;
      await _erp.marcarAsesorInactivo(widget.asesorId);
      setState(() => modoVisitasActivo = false);
      _mostrarMensaje('Modo visitas desactivado', Colors.grey.shade700);
    }
  }

  void _seleccionarTarea(Map<String, dynamic> tarea) {
    setState(() {
      tareaSeleccionada = tarea;
      _nombreObraCtrl.text = tarea['cliente'] ?? '';
      _contactoCtrl.text = tarea['contacto'] ?? '';
      _telefonoCtrl.text = tarea['telefono'] ?? '';
      _observacionesCtrl.text = 'REF JEFE: ${tarea['observaciones'] ?? ''}';
    });

    // 🔔 Notifica a la jefa que el asesor aceptó y va en camino
    _erp.actualizarEstadoAsignacion(
      tarea['id'],
      'en_camino',
      nombreAsesor: widget.nombre,
      nombreCliente: tarea['cliente'],
    );

    _mostrarMensaje('📍 Ruta cargada: ${tarea['cliente']}', AppColors.accent);
  }

  Future<void> _abrirNavegacion(Map<String, dynamic> tarea) async {
    final enlaceMaps = tarea['enlace_maps'];
    Uri uri;
    if (enlaceMaps != null && enlaceMaps.toString().isNotEmpty) {
      uri = Uri.parse(enlaceMaps.toString().trim());
    } else {
      final dir = Uri.encodeComponent(tarea['direccion'] ?? tarea['cliente'] ?? '');
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$dir');
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _mostrarMensaje('No se pudo abrir el mapa', Colors.red);
    }
  }

  Future<void> _tomarFoto(bool esExterior) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
    );
    if (image != null) {
      setState(() {
        if (esExterior) fotoExterior = File(image.path);
        else fotoInterior = File(image.path);
      });
    }
  }

  Future<void> _tomarVideo() async {
    final XFile? video = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 30),
    );
    if (video != null) setState(() => videoEvidencia = File(video.path));
  }

  Future<void> _guardarCoordenadasObra() async {
    if (!modoVisitasActivo) {
      _mostrarMensaje('Debes activar el "Modo Visitas" primero', Colors.orange);
      return;
    }

    _mostrarMensaje('⏳ Capturando coordenadas...', Colors.blue);
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() => ubicacionActual = pos);

      // Pin en mapa + notificación "llegó a obra"
      await _erp.marcarPuntoVisita(
        asesorId: widget.asesorId,
        nombre: widget.nombre,
        latitud: pos.latitude,
        longitud: pos.longitude,
        nombreObra: _nombreObraCtrl.text.trim().isEmpty
            ? (tareaSeleccionada?['cliente'] ?? 'obra')
            : _nombreObraCtrl.text.trim(),
      );

      if (tareaSeleccionada != null) {
        await _erp.actualizarEstadoAsignacion(tareaSeleccionada!['id'], 'en_obra');
      }
      _mostrarMensaje('✅ Coordenadas guardadas — jefa notificada', Colors.green);
    } catch (e) {
      _mostrarMensaje('❌ Error: $e', Colors.red);
    }
  }

  Future<void> _finalizarVisita() async {
    if (ubicacionActual == null) {
      _mostrarMensaje('⚠️ Guarda las coordenadas primero (Paso 1)', Colors.orange);
      return;
    }
    if (fotoExterior == null || fotoInterior == null) {
      _mostrarMensaje('⚠️ Sube ambas fotos (Paso 2)', Colors.orange);
      return;
    }
    if (_nombreObraCtrl.text.trim().isEmpty) {
      _mostrarMensaje('⚠️ Completa los datos del cliente (Paso 3)', Colors.orange);
      return;
    }

    setState(() => estaGuardando = true);
    try {
      await _erp.finalizarVisita(
        asignacionId: tareaSeleccionada?['id'] ?? '',
        asesorId: widget.asesorId,
        nombreAsesor: widget.nombre, // ← para notificación
        nombreObra: _nombreObraCtrl.text.trim(),
        contacto: _contactoCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim(),
        observaciones: _observacionesCtrl.text.trim(),
        latitud: ubicacionActual!.latitude,
        longitud: ubicacionActual!.longitude,
        fotoExterior: fotoExterior,
        fotoInterior: fotoInterior,
        videoEvidencia: videoEvidencia,
      );
      if (!mounted) return;
      setState(() {
        estaGuardando = false;
        tareaSeleccionada = null;
        fotoExterior = null;
        fotoInterior = null;
        videoEvidencia = null;
        ubicacionActual = null;
        _nombreObraCtrl.clear();
        _contactoCtrl.clear();
        _telefonoCtrl.clear();
        _observacionesCtrl.clear();
      });
      _mostrarMensaje('🎉 Visita guardada — jefa notificada', Colors.green);
    } catch (e) {
      setState(() => estaGuardando = false);
      _mostrarMensaje('❌ Error al guardar: $e', Colors.red);
    }
  }

  void _mostrarMensaje(String texto, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSwitchVisitas(),
              const SizedBox(height: 20),
              _buildRutaAsignada(),
              const SizedBox(height: 28),
              _buildSeccionTitulo("Registro de Visita"),
              const SizedBox(height: 14),
              _buildPaso1GuardarCoordenadas(),
              _buildPaso2Evidencias(),
              _buildPaso3DatosCliente(),
              _buildBotonFinalizar(),
              const SizedBox(height: 60),
            ],
          ),
        ),
        if (estaGuardando) _buildOverlayCarga(),
      ],
    );
  }

  Widget _buildSwitchVisitas() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: modoVisitasActivo ? AppColors.primaryDark.withOpacity(0.4) : Colors.grey.shade200,
          width: modoVisitasActivo ? 1.5 : 1,
        ),
      ),
      child: SwitchListTile(
        activeColor: AppColors.primaryDark,
        title: const Text("Modo Visitas", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(
          modoVisitasActivo
              ? "✅ Activo — puedes registrar tus visitas"
              : "Actívalo al iniciar tu ruta para guardar evidencias.",
          style: TextStyle(
            fontSize: 12,
            color: modoVisitasActivo ? Colors.green.shade700 : Colors.grey,
          ),
        ),
        value: modoVisitasActivo,
        onChanged: _toggleModoVisitas,
      ),
    );
  }

  Widget _buildRutaAsignada() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSeccionTitulo("Tus Rutas Pendientes"),
        const SizedBox(height: 12),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _erp.streamAsignaciones(widget.asesorId),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
            }
            final tareas = (snap.data ?? [])
                .where((t) => t['estado'] != 'completada' && t['estado'] != 'cancelada')
                .toList();
            if (tareas.isEmpty) {
              return _buildEstadoVacio('Sin pendientes', 'No tienes clientes asignados.', Icons.inbox);
            }
            return SizedBox(
              height: 165,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: tareas.length,
                itemBuilder: (_, i) => _buildTareaCard(tareas[i]),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTareaCard(Map<String, dynamic> tarea) {
    final bool esActiva = tareaSeleccionada?['id'] == tarea['id'];
    return Container(
      width: 290,
      margin: const EdgeInsets.only(right: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: esActiva ? AppColors.accent.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: esActiva ? AppColors.accent : Colors.grey.shade200, width: esActiva ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(tarea['cliente'] ?? 'Sin nombre',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                icon: const Icon(Icons.navigation, color: Colors.blue, size: 20),
                onPressed: () => _abrirNavegacion(tarea),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if ((tarea['observaciones'] ?? '').isNotEmpty)
            Text(tarea['observaciones'],
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: esActiva ? AppColors.accent : AppColors.primaryDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () => _seleccionarTarea(tarea),
              child: Text(esActiva ? 'SELECCIONADO' : 'SELECCIONAR',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaso1GuardarCoordenadas() {
    return _buildPasoCard(
      numero: "1", titulo: "Ubicación", completado: ubicacionActual != null,
      contenido: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: ubicacionActual != null ? Colors.green.shade50 : Colors.blue.shade50,
          foregroundColor: ubicacionActual != null ? Colors.green.shade700 : Colors.blue.shade700,
          minimumSize: const Size(double.infinity, 50),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: Icon(ubicacionActual != null ? Icons.check_circle : Icons.location_on),
        label: Text(ubicacionActual != null ? "Coordenadas Guardadas ✓" : "Guardar Coordenadas de Obra"),
        onPressed: _guardarCoordenadasObra,
      ),
    );
  }

  Widget _buildPaso2Evidencias() {
    return _buildPasoCard(
      numero: "2", titulo: "Fotografías",
      completado: fotoExterior != null && fotoInterior != null,
      contenido: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SizedBox(width: 130, child: _buildBotonFoto("Exterior", Icons.camera_outdoor, fotoExterior, () => _tomarFoto(true))),
            const SizedBox(width: 12),
            SizedBox(width: 130, child: _buildBotonFoto("Interior / Obra", Icons.camera_indoor, fotoInterior, () => _tomarFoto(false))),
            const SizedBox(width: 12),
            SizedBox(width: 130, child: _buildBotonFoto("Video (Opcional)", Icons.videocam, videoEvidencia, _tomarVideo)),
          ],
        ),
      ),
    );
  }

  Widget _buildBotonFoto(String label, IconData icono, File? file, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: file != null ? Colors.green.shade400 : Colors.grey.shade300, width: file != null ? 2 : 1),
          image: file != null ? DecorationImage(image: FileImage(file), fit: BoxFit.cover) : null,
        ),
        child: file == null
            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icono, color: Colors.grey.shade500, size: 30),
                const SizedBox(height: 6),
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ])
            : Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  margin: const EdgeInsets.all(6),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                ),
              ),
      ),
    );
  }

  Widget _buildPaso3DatosCliente() {
    return _buildPasoCard(
      numero: "3", titulo: "Datos Generales",
      completado: _nombreObraCtrl.text.isNotEmpty && _contactoCtrl.text.isNotEmpty,
      contenido: Column(
        children: [
          _buildTextField(_nombreObraCtrl, "Nombre del Cliente / Obra", Icons.business, "Ej: Constructora..."),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(flex: 2, child: _buildTextField(_contactoCtrl, "Contacto", Icons.person_outline, "Nombre")),
            const SizedBox(width: 10),
            Expanded(child: _buildTextField(_telefonoCtrl, "Teléfono", Icons.phone_outlined, "9XXXXXXXX")),
          ]),
          const SizedBox(height: 12),
          _buildTextField(_observacionesCtrl, "Anotaciones", Icons.notes_outlined, "Detalles...", maxLines: 3),
        ],
      ),
    );
  }

  Widget _buildBotonFinalizar() {
    final bool listo = ubicacionActual != null && fotoExterior != null &&
        fotoInterior != null && _nombreObraCtrl.text.isNotEmpty;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: listo ? AppColors.primaryDark : Colors.grey.shade300,
          foregroundColor: listo ? Colors.white : Colors.grey.shade500,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: listo ? 4 : 0,
        ),
        icon: const Icon(Icons.save),
        label: const Text("GUARDAR REGISTRO", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        onPressed: listo ? _finalizarVisita : null,
      ),
    );
  }

  Widget _buildOverlayCarga() {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('Subiendo a Firebase...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionTitulo(String titulo) {
    return Text(titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryDark));
  }

  Widget _buildPasoCard({required String numero, required String titulo, required bool completado, required Widget contenido}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: completado ? Colors.green.shade200 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: completado ? Colors.green : AppColors.primaryDark,
              child: completado
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : Text(numero, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryDark)),
          ]),
          const SizedBox(height: 14),
          contenido,
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icono, String hint, {int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        prefixIcon: Icon(icono, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true, fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildEstadoVacio(String titulo, String sub, IconData icono) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(children: [
        Icon(icono, size: 36, color: Colors.grey.shade400),
        const SizedBox(height: 8),
        Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
        Text(sub, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
      ]),
    );
  }
}