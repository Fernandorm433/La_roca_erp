// Archivo: lib/screens/ventas/vista_jefe_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart'; // Asegúrate de tener intl en pubspec.yaml
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/services/erp_service.dart';

class VistaJefePage extends StatefulWidget {
  const VistaJefePage({super.key});

  @override
  State<VistaJefePage> createState() => _VistaJefePageState();
}

class _VistaJefePageState extends State<VistaJefePage>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final ErpService _erp = ErpService();

  List<Marker> _marcadores = [];
  Map<String, dynamic>? _asesorSeleccionadoMapa;
  late TabController _tabController;

  // Estado para el filtro histórico
  DateTime _fechaFiltro = DateTime.now();

  static const LatLng _posicionArequipa = LatLng(-16.409047, -71.537451);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatearHora(dynamic isoString) {
    if (isoString == null) return 'Sin datos';
    try {
      // DateTime.parse() obtiene la hora en UTC de Supabase
      // .toLocal() la convierte automáticamente a la hora de Perú (UTC-5)
      final date = DateTime.parse(isoString.toString()).toLocal();

      // Usamos 'HH:mm' para formato 24h o 'hh:mm a' para 12h con AM/PM
      return DateFormat('hh:mm a', 'es').format(date);
    } catch (e) {
      return '--:--';
    }
  }

  void _abrirModalAsignarCliente(Map<String, dynamic> asesor) {
    final clienteCtrl = TextEditingController();
    final direccionCtrl = TextEditingController();
    final enlaceMapsCtrl = TextEditingController(); // Nuevo campo
    final contactoCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    final obsCtrl = TextEditingController();
    bool guardando = false;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5), // Fondo sutilmente oscuro
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- HEADER DEL MODAL ---
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add_location_alt,
                              color: AppColors.accent,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Asignar Nueva Ruta",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                Text(
                                  "Para: ${asesor['nombre_asesor']}",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // --- FORMULARIO ---
                      _buildCustomTextField(
                        controller: clienteCtrl,
                        label: "Cliente / Obra",
                        hint: "Ej. Constructora Horizonte",
                        icon: Icons.business,
                      ),
                      const SizedBox(height: 12),
                      _buildCustomTextField(
                        controller: direccionCtrl,
                        label: "Dirección",
                        hint: "Ubicación de la visita",
                        icon: Icons.map_outlined,
                      ),
                      const SizedBox(height: 12),
                      _buildCustomTextField(
                        controller: enlaceMapsCtrl,
                        label: "Enlace de Google Maps (Opcional)",
                        hint: "https://maps.app.goo.gl/...",
                        icon: Icons.link,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildCustomTextField(
                              controller: contactoCtrl,
                              label: "Contacto",
                              hint: "Ing. Residente",
                              icon: Icons.person_outline,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildCustomTextField(
                              controller: telefonoCtrl,
                              label: "Teléfono",
                              hint: "9XXXXXXXX",
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildCustomTextField(
                        controller: obsCtrl,
                        label: "Instrucciones",
                        hint: "Motivo de la visita, detalles...",
                        icon: Icons.notes,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 28),

                      // --- BOTONES ---
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              onPressed: guardando
                                  ? null
                                  : () => Navigator.pop(context),
                              child: Text(
                                "Cancelar",
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              onPressed: guardando
                                  ? null
                                  : () async {
                                      if (clienteCtrl.text.trim().isEmpty ||
                                          direccionCtrl.text.trim().isEmpty) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: const Text(
                                              '⚠️ Cliente y Dirección son obligatorios',
                                            ),
                                            backgroundColor:
                                                Colors.orange.shade800,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                        return;
                                      }

                                      setStateDialog(() => guardando = true);
                                      try {
                                        await _erp.asignarCliente(
                                          asesorId: asesor['asesor_id'],
                                          nombreAsesor: asesor['nombre_asesor'],
                                          cliente: clienteCtrl.text.trim(),
                                          direccion: direccionCtrl.text.trim(),
                                          enlaceMaps: enlaceMapsCtrl.text
                                              .trim(), // Se envía el enlace
                                          contacto: contactoCtrl.text.trim(),
                                          telefono: telefonoCtrl.text.trim(),
                                          observaciones: obsCtrl.text.trim(),
                                        );

                                        if (mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                '✅ Ruta asignada correctamente',
                                              ),
                                              backgroundColor: Colors.green,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        setStateDialog(() => guardando = false);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '❌ Error al asignar: $e',
                                            ),
                                            backgroundColor: Colors.red,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    },
                              child: guardando
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      "Enviar Ruta",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- WIDGET HELPER PARA LOS TEXTFIELDS ---
  // Pega esto justo debajo de la función de arriba, dentro de la clase _VistaJefePageState
  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: maxLines > 1,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(bottom: 2.0),
          child: Icon(icon, size: 20, color: AppColors.accent.withOpacity(0.7)),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
    );
  }

  // ... (Funciones de marcadores y GPS se mantienen igual que la versión anterior) ...
  List<Marker> _construirMarcadores(List<Map<String, dynamic>> ubicaciones) {
    final List<Marker> markers = [];
    for (final u in ubicaciones) {
      final double? lat = (u['latitud'] as num?)?.toDouble();
      final double? lng = (u['longitud'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final String estado = u['estado'] ?? 'activo';
      Color color = estado == 'en_obra'
          ? Colors.orange
          : (estado == 'en_camino' ? Colors.blue : Colors.green);

      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 45,
          height: 45,
          child: GestureDetector(
            onTap: () => setState(() => _asesorSeleccionadoMapa = u),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: Icon(Icons.person_pin_circle, color: color, size: 30),
            ),
          ),
        ),
      );
    }
    return markers;
  }

  void _centrarEnAsesor(Map<String, dynamic> u) {
    final lat = (u['latitud'] as num?)?.toDouble();
    final lng = (u['longitud'] as num?)?.toDouble();
    if (lat != null && lng != null) _mapController.move(LatLng(lat, lng), 16.0);
  }

  // ─── MODAL: DETALLE COMPLETO DE LA VISITA ────────────────────
  void _mostrarDetalleEvidencia(Map<String, dynamic> ev) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  const Icon(Icons.assignment_turned_in, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ev['nombre_obra'] ?? 'Sin nombre',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'Visitado por: ${ev['asesor_id']}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _buildInfoTile(
                    Icons.person,
                    "Contacto",
                    ev['contacto'] ?? 'N/A',
                  ),
                  _buildInfoTile(
                    Icons.phone,
                    "Teléfono",
                    ev['telefono'] ?? 'N/A',
                  ),
                  _buildInfoTile(
                    Icons.notes,
                    "Observaciones",
                    ev['observaciones'] ?? 'Sin notas adicionales',
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Evidencias Fotográficas",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (ev['url_foto_exterior'] != null)
                        Expanded(
                          child: _buildThumbnail(
                            ev['url_foto_exterior'],
                            "Exterior",
                          ),
                        ),
                      const SizedBox(width: 12),
                      if (ev['url_foto_interior'] != null)
                        Expanded(
                          child: _buildThumbnail(
                            ev['url_foto_interior'],
                            "Interior",
                          ),
                        ),
                    ],
                  ),
                  if (ev['url_video'] != null) ...[
                    const SizedBox(height: 20),
                    const Text(
                      "Evidencia en Video",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      tileColor: Colors.blue.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: const Icon(
                        Icons.play_circle_fill,
                        color: Colors.blue,
                        size: 30,
                      ),
                      title: const Text(
                        "Reproducir Video de Obra",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => launchUrl(Uri.parse(ev['url_video'])),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(value, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(String url, String label) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            height: 150,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 150,
              color: Colors.grey.shade200,
              child: const Icon(Icons.broken_image),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // ─── TAB ACTIVIDAD (REDISEÑADA) ───────────────────────────────
  // Variable de estado para el filtro de asesor (agrégala al inicio de la clase _VistaJefePageState)
  String? _idAsesorSeleccionado;

  Widget _buildTabActividad() {
    return Column(
      children: [
        // 1. SELECTOR DE ASESORES (Cuadros/Cards dinámicos)
        _buildSelectorAsesores(),

        // 2. SELECTOR DE FECHA (Versión Estilizada)
        _buildFechaFiltroHeader(),

        // 3. LISTADO DE ACTIVIDAD (Timeline Moderna)
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _erp.streamEvidenciasPorDia(_fechaFiltro),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // Filtrar localmente por asesor si hay uno seleccionado
              var evidencias = snap.data ?? [];
              if (_idAsesorSeleccionado != null) {
                evidencias = evidencias
                    .where((ev) => ev['asesor_id'] == _idAsesorSeleccionado)
                    .toList();
              }

              if (evidencias.isEmpty) {
                return _buildEstadoVacio(
                  'Sin actividad registrada',
                  _idAsesorSeleccionado == null
                      ? 'No hay visitas para este día.'
                      : 'Este asesor no registra visitas en la fecha seleccionada.',
                  Icons.history_toggle_off_rounded,
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                itemCount: evidencias.length,
                itemBuilder: (_, i) => _buildTimelineItem(
                  evidencias[i],
                  i == evidencias.length - 1,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- NUEVO: Selector Horizontal de Asesores ---
  Widget _buildSelectorAsesores() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _erp.getAsesoresRegistrados(),
        builder: (context, snap) {
          if (!snap.hasData) return const SizedBox();
          final asesores = snap.data!;

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: asesores.length + 1,
            itemBuilder: (context, i) {
              // Opción "Todos"
              if (i == 0) {
                return _buildAsesorCard(
                  id: null,
                  nombre: "Todos",
                  isSelected: _idAsesorSeleccionado == null,
                );
              }
              final as = asesores[i - 1];
              return _buildAsesorCard(
                id: as['id'],
                nombre: as['nombre'],
                isSelected: _idAsesorSeleccionado == as['id'],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAsesorCard({
    String? id,
    required String nombre,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _idAsesorSeleccionado = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 85,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryDark : Colors.grey.shade200,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryDark.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: isSelected
                  ? Colors.white24
                  : AppColors.accent.withOpacity(0.1),
              child: Text(
                nombre[0].toUpperCase(),
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                nombre.split(' ')[0],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- NUEVO: Header de Fecha Estilizado ---
  Widget _buildFechaFiltroHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            DateFormat('MMMM d, yyyy', 'es').format(_fechaFiltro).toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: AppColors.primaryDark,
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              final pick = await showDatePicker(
                context: context,
                initialDate: _fechaFiltro,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
              );
              if (pick != null) setState(() => _fechaFiltro = pick);
            },
            icon: const Icon(Icons.calendar_month_rounded, size: 18),
            label: const Text("Cambiar Fecha"),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
          ),
        ],
      ),
    );
  }

  // --- NUEVO: Timeline Item (Estética de Visita) ---
  Widget _buildTimelineItem(Map<String, dynamic> ev, bool isLast) {
    final hora = DateFormat(
      'hh:mm a',
    ).format(DateTime.parse(ev['creado_en']).toLocal());

    return IntrinsicHeight(
      child: Row(
        children: [
          // Línea lateral y Hora
          Column(
            children: [
              Text(
                hora.split(' ')[0],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                hora.split(' ')[1],
                style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  width: 2,
                  color: isLast ? Colors.transparent : Colors.grey.shade200,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          // Card de Contenido
          Expanded(
            child: GestureDetector(
              onTap: () => _mostrarDetalleEvidencia(ev),
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ev['nombre_obra'] ?? 'Obra sin nombre',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.person_pin,
                          size: 14,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "Asesor ID: ${ev['asesor_id']}",
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    if (ev['url_foto_exterior'] != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          ev['url_foto_exterior'],
                          height: 80,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ... (El resto del build y widgets helpers se mantienen de la versión anterior) ...
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(flex: 5, child: _buildMapaEnVivo()),
        Expanded(flex: 4, child: _buildPanelInferior()),
      ],
    );
  }

  Widget _buildMapaEnVivo() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _erp.streamUbicacionesAsesores(),
      builder: (context, snap) {
        if (snap.hasData) _marcadores = _construirMarcadores(snap.data!);
        return Stack(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _posicionArequipa,
                  initialZoom: 13.0,
                ),
                children: [
                  TileLayer(
                    // URL directa a los servidores de Google Maps con la capa de tráfico activada
                    urlTemplate:
                        'https://{s}.google.com/vt/lyrs=m,traffic&x={x}&y={y}&z={z}',
                    // Google usa estos 4 subdominios para balancear la carga (mt0, mt1, mt2, mt3)
                    subdomains: const ['mt0', 'mt1', 'mt2', 'mt3'],
                    // Tu paquete para identificar la app
                    userAgentPackageName: 'com.rmmetaltec.erp',
                  ),
                  MarkerLayer(markers: _marcadores),
                ],
              ),
            ),
            if (_asesorSeleccionadoMapa != null)
              Positioned(
                bottom: 14,
                left: 28,
                right: 80,
                child: _buildCardMiniAsesor(_asesorSeleccionadoMapa!),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPanelInferior() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primaryDark,
            indicatorColor: AppColors.accent,
            tabs: const [
              Tab(text: "En Vivo"),
              Tab(text: "Actividad"),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildTabAsesores(), _buildTabActividad()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabAsesores() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _erp.streamUbicacionesAsesores(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final ubicaciones = snap.data ?? [];
        if (ubicaciones.isEmpty) {
          return _buildEstadoVacio(
            'Sin asesores conectados',
            'Ningún asesor ha iniciado sesión aún.',
            Icons.people_outline,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          itemCount: ubicaciones.length,
          itemBuilder: (_, i) => _buildFilaAsesor(ubicaciones[i]),
        );
      },
    );
  }

  Widget _buildFilaAsesor(Map<String, dynamic> u) {
    final String nombre = u['nombre_asesor'] ?? 'Asesor';
    final String estado = u['estado'] ?? 'activo';
    final String hora = _formatearHora(u['ultima_actualizacion']);

    Color estadoColor;
    String estadoLabel;
    IconData estadoIcono;

    switch (estado) {
      case 'en_obra':
        estadoColor = Colors.orange;
        estadoLabel = 'En Obra';
        estadoIcono = Icons.construction;
        break;
      case 'en_camino':
        estadoColor = Colors.blue;
        estadoLabel = 'En Camino';
        estadoIcono = Icons.directions_car;
        break;
      case 'inactivo':
        estadoColor = Colors.red.shade300;
        estadoLabel = 'Inactivo';
        estadoIcono = Icons.pause_circle_outline;
        break;
      default:
        estadoColor = Colors.green;
        estadoLabel = 'Activo';
        estadoIcono = Icons.check_circle_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: estadoColor.withOpacity(0.15),
            child: Text(
              nombre.isNotEmpty ? nombre[0].toUpperCase() : 'A',
              style: TextStyle(color: estadoColor, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Actualizado $hora',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: estadoColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(estadoIcono, size: 12, color: estadoColor),
                const SizedBox(width: 4),
                Text(
                  estadoLabel,
                  style: TextStyle(
                    color: estadoColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (v) {
              if (v == 'centrar') _centrarEnAsesor(u);
              if (v == 'asignar') {
                _abrirModalAsignarCliente(u);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'centrar',
                child: Row(
                  children: [
                    Icon(Icons.my_location, size: 16),
                    SizedBox(width: 8),
                    Text('Ver en mapa'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'asignar',
                child: Row(
                  children: [
                    Icon(Icons.assignment_ind, size: 16),
                    SizedBox(width: 8),
                    Text('Asignar cliente'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardMiniAsesor(Map<String, dynamic> u) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_pin_circle, color: AppColors.primaryDark),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  u['nombre_asesor'] ?? 'Asesor',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Última pos: ${_formatearHora(u['ultima_actualizacion'])}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _asesorSeleccionadoMapa = null),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadoVacio(String t, String s, IconData i) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(i, size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(
            s,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
