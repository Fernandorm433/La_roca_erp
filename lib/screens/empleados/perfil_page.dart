// ═══════════════════════════════════════════════════════════════════════════
//  lib/screens/empleados/perfil_page.dart
//  Perfil de Empleado — Supabase + diseño premium + responsive
// ═══════════════════════════════════════════════════════════════════════════
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../home/home_page.dart';

// ─── Paleta ────────────────────────────────────────────────────────────────
const _kDarkBg   = Color(0xFF0D2137);
const _kDarkCard = Color(0xFF14304F);
const _kAccent   = Color(0xFF2DC8A8);
const _kBg       = Color(0xFFF0F4F8);

// ─── Modelo ────────────────────────────────────────────────────────────────
class EmpleadoPerfil {
  final String id;
  final String nombre;
  final String apellido;
  final String correo;
  final String telefono;
  final String area;
  final String ubicacion;
  final String estado;
  final String fechaIngreso;
  final String jornada;
  final String? fotoUrl;
  final String puesto;
  final int documentos;
  final int solicitudes;
  final String rol;

  const EmpleadoPerfil({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.correo,
    required this.telefono,
    required this.area,
    required this.ubicacion,
    required this.estado,
    required this.fechaIngreso,
    required this.jornada,
    this.fotoUrl,
    required this.puesto,
    required this.documentos,
    required this.solicitudes,
    required this.rol,
  });

  String get nombreCompleto => '$nombre $apellido';

  String get iniciales {
    final n = nombre.isNotEmpty ? nombre[0] : '';
    final a = apellido.isNotEmpty ? apellido[0] : '';
    return '$n$a'.toUpperCase();
  }

  int get antiguedadAnios {
    try {
      final parts = fechaIngreso.split('-');
      if (parts.length >= 1) {
        final year = int.tryParse(parts[0]) ?? DateTime.now().year;
        return DateTime.now().year - year;
      }
    } catch (_) {}
    return 0;
  }

  factory EmpleadoPerfil.fromJson(Map<String, dynamic> json) {
    // Mapea los nombres de columna REALES de tu tabla Supabase:
    //   nombres   → nombre       apellidos → apellido
    //   cargo     → puesto       email     → correo
    //   activo    → estado       turno     → jornada
    final activo = json['activo'];
    return EmpleadoPerfil(
      id:           json['id']?.toString() ?? '',
      nombre:       json['nombres']?.toString() ?? '',
      apellido:     json['apellidos']?.toString() ?? '',
      correo:       json['email']?.toString() ?? '',
      telefono:     json['telefono']?.toString() ?? '',
      area:         json['area']?.toString() ?? '',
      ubicacion:    json['ubicacion']?.toString() ?? '',
      estado:       activo == true ? 'Activo' : 'Inactivo',
      fechaIngreso: json['fecha_ingreso']?.toString() ?? '',
      jornada:      json['turno']?.toString() ?? 'Tiempo Completo',
      fotoUrl:      json['foto_url']?.toString(),
      puesto:       json['cargo']?.toString() ?? '',
      documentos:   (json['documentos'] as num?)?.toInt() ?? 0,
      solicitudes:  (json['solicitudes'] as num?)?.toInt() ?? 0,
      rol:          json['rol']?.toString() ?? 'empleado',
    );
  }

  Map<String, dynamic> toUpdateJson() => {
    'telefono':  telefono,
    'ubicacion': ubicacion,
    'cargo':     puesto,  // nombre real de columna en Supabase
  };

  EmpleadoPerfil copyWith({
    String? telefono,
    String? ubicacion,
    String? puesto,
  }) => EmpleadoPerfil(
    id: id, nombre: nombre, apellido: apellido, correo: correo,
    telefono:    telefono    ?? this.telefono,
    area:        area,
    ubicacion:   ubicacion   ?? this.ubicacion,
    estado:      estado,
    fechaIngreso: fechaIngreso,
    jornada:     jornada,
    fotoUrl:     fotoUrl,
    puesto:      puesto      ?? this.puesto,
    documentos:  documentos,
    solicitudes: solicitudes,
    rol:         rol,
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  WIDGET PRINCIPAL
// ═══════════════════════════════════════════════════════════════════════════
class PerfilPage extends StatefulWidget {
  // Parámetros originales (compatibilidad con home_page.dart)
  final String nombre;
  final RolUsuario rol;
  final String? empleadoId; // null = usa el usuario autenticado

  const PerfilPage({
    super.key,
    required this.nombre,
    required this.rol,
    this.empleadoId,
  });

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage>
    with TickerProviderStateMixin {

  // ── Estado ───────────────────────────────────────────────────────────────
  EmpleadoPerfil? _perfil;
  bool   _cargando   = true;
  String? _error;
  bool   _guardando  = false;

  // ── Controladores ────────────────────────────────────────────────────────
  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;

  final _supabase = Supabase.instance.client;

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _cargarPerfil();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _cargarPerfil() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final authUser = _supabase.auth.currentUser;
      final uid = widget.empleadoId ?? authUser?.id ?? '';
      if (uid.isEmpty) throw Exception('No hay sesión activa.');

      Map<String, dynamic>? empleadoRow;

      // 1. Buscar en empleados por auth_id (sin .single() para evitar error 0 rows)
      final resLista = await _supabase
          .from('empleados')
          .select('''
            id, nombres, apellidos, email, telefono,
            area, ubicacion, activo, fecha_ingreso, turno,
            foto_url, cargo, rol,
            documentos:documentos(count),
            solicitudes:solicitudes(count)
          ''')
          .eq('auth_id', uid)
          .limit(1);

      if (resLista.isNotEmpty) {
        final row = Map<String, dynamic>.from(resLista.first as Map);
        final docsCount = (row['documentos'] as List?)?.firstOrNull?['count'] ?? 0;
        final solsCount = (row['solicitudes'] as List?)?.firstOrNull?['count'] ?? 0;
        empleadoRow = { ...row, 'documentos': docsCount, 'solicitudes': solsCount };
      }

      // 2. Fallback: construir perfil desde tabla usuarios
      if (empleadoRow == null) {
        final usuarioRes = await _supabase
            .from('usuarios')
            .select('id, nombre, rol')
            .eq('id', uid)
            .limit(1);

        if (usuarioRes.isEmpty) {
          throw Exception(
            'No se encontró perfil.\nContacta a tu administrador.');
        }

        final u = Map<String, dynamic>.from(usuarioRes.first as Map);
        final partes = (u['nombre'] as String? ?? '').trim().split(' ');
        empleadoRow = {
          'id':           uid,
          'nombres':      partes.isNotEmpty ? partes.first : authUser?.email?.split('@').first ?? '',
          'apellidos':    partes.length > 1 ? partes.sublist(1).join(' ') : '',
          'email':        authUser?.email ?? '',
          'telefono':     '',
          'area':         '',
          'ubicacion':    '',
          'activo':       true,
          'fecha_ingreso': null,
          'turno':        'Tiempo Completo',
          'foto_url':     null,
          'cargo':        u['rol'] ?? '',
          'rol':          u['rol'] ?? 'empleado',
          'documentos':   0,
          'solicitudes':  0,
        };
      }

      if (!mounted) return;
      setState(() {
        _perfil   = EmpleadoPerfil.fromJson(empleadoRow!);
        _cargando = false;
      });
      _fadeCtrl.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error    = e.toString();
        _cargando = false;
      });
    }
  }

  // ── Actualizar datos editables ───────────────────────────────────────────
  Future<void> _guardarCambios(EmpleadoPerfil actualizado) async {
    setState(() => _guardando = true);
    try {
      await _supabase
          .from('empleados')
          .update(actualizado.toUpdateJson())
          .eq('id', actualizado.id);

      if (!mounted) return;
      setState(() {
        _perfil   = actualizado;
        _guardando = false;
      });
      _mostrarSnack('Perfil actualizado correctamente', ok: true);
    } catch (e) {
      setState(() => _guardando = false);
      _mostrarSnack('Error al guardar: $e', ok: false);
    }
  }

  // ── Cerrar sesión ────────────────────────────────────────────────────────
  Future<void> _cerrarSesion() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        titulo: 'Cerrar sesión',
        mensaje: '¿Estás seguro de que deseas salir?',
        accion:  'Salir',
        peligro: true,
      ),
    );
    if (confirm != true || !mounted) return;
    await _supabase.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  // ── Diálogo editar perfil ────────────────────────────────────────────────
  Future<void> _abrirEdicion() async {
    if (_perfil == null) return;
    final result = await showDialog<EmpleadoPerfil>(
      context: context,
      builder: (ctx) => _EditarPerfilDialog(perfil: _perfil!),
    );
    if (result != null) await _guardarCambios(result);
  }

  void _mostrarSnack(String msg, {required bool ok}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(ok ? Icons.check_circle : Icons.error,
             color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: ok ? const Color(0xFF2DC8A8) : Colors.red.shade600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_cargando) return const _SkeletonPage();
    if (_error != null)  return _ErrorPage(error: _error!, onRetry: _cargarPerfil);

    final isWide = MediaQuery.of(context).size.width >= 720;
    return FadeTransition(
      opacity: _fadeAnim,
      child: isWide
          ? _DesktopLayout(
              perfil:       _perfil!,
              guardando:    _guardando,
              onEditar:     _abrirEdicion,
              onCerrarSesion: _cerrarSesion,
            )
          : _MobileLayout(
              perfil:       _perfil!,
              guardando:    _guardando,
              onEditar:     _abrirEdicion,
              onCerrarSesion: _cerrarSesion,
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  LAYOUT DESKTOP
// ═══════════════════════════════════════════════════════════════════════════
class _DesktopLayout extends StatelessWidget {
  final EmpleadoPerfil perfil;
  final bool guardando;
  final VoidCallback onEditar;
  final VoidCallback onCerrarSesion;

  const _DesktopLayout({
    required this.perfil,
    required this.guardando,
    required this.onEditar,
    required this.onCerrarSesion,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── SIDEBAR ────────────────────────────────────────────────────
          SizedBox(
            width: 290,
            child: _Sidebar(
              perfil:         perfil,
              onEditar:       onEditar,
              onCerrarSesion: onCerrarSesion,
            ),
          ),

          // ── CONTENIDO ──────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 36, 32, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabecera
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mi Perfil',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: _kDarkBg,
                              letterSpacing: -0.5,
                            )),
                          const SizedBox(height: 4),
                          Text('Consulta y gestiona tu información laboral',
                            style: TextStyle(color: Colors.grey.shade500,
                                             fontSize: 14)),
                        ],
                      ),
                      const Spacer(),
                      if (guardando)
                        const _LoadingBadge()
                      else
                        _PrimaryButton(
                          icon: Icons.edit_outlined,
                          label: 'Editar perfil',
                          onPressed: onEditar,
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Stats
                  _StatsRow(perfil: perfil),
                  const SizedBox(height: 24),

                  // Estado laboral
                  _Card(
                    title: 'Estado Laboral',
                    icon: Icons.badge_outlined,
                    iconColor: Colors.blue.shade600,
                    iconBg: Colors.blue.shade50,
                    child: _EstadoLaboralGrid(perfil: perfil),
                  ),
                  const SizedBox(height: 20),

                  // Información de contacto
                  _Card(
                    title: 'Información de Contacto',
                    icon: Icons.contact_page_outlined,
                    iconColor: _kAccent,
                    iconBg: _kAccent.withOpacity(0.08),
                    child: _ContactoGrid(perfil: perfil),
                  ),
                  const SizedBox(height: 20),

                  // Servicios
                  _Card(
                    title: 'Accesos Rápidos',
                    icon: Icons.apps_rounded,
                    iconColor: Colors.purple.shade600,
                    iconBg: Colors.purple.shade50,
                    child: _ServiciosGrid(context: context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sidebar ────────────────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  final EmpleadoPerfil perfil;
  final VoidCallback onEditar;
  final VoidCallback onCerrarSesion;

  const _Sidebar({
    required this.perfil,
    required this.onEditar,
    required this.onCerrarSesion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kDarkBg, Color(0xFF091929)],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 48),

          // Avatar
          _AvatarWidget(iniciales: perfil.iniciales, fotoUrl: perfil.fotoUrl,
                        size: 96),
          const SizedBox(height: 16),

          // Nombre
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              perfil.nombreCompleto.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Puesto badge
          _RolBadge(texto: perfil.puesto.isNotEmpty ? perfil.puesto : perfil.rol),
          const SizedBox(height: 6),

          // Estado badge
          _EstadoBadge(estado: perfil.estado),
          const SizedBox(height: 28),

          const Divider(color: Colors.white12, indent: 24, endIndent: 24),
          const SizedBox(height: 16),

          // Info personal
          _SidebarInfo(Icons.email_outlined,            'Correo',    perfil.correo),
          _SidebarInfo(Icons.phone_outlined,            'Teléfono',  perfil.telefono),
          _SidebarInfo(Icons.business_center_outlined,  'Área',      perfil.area),
          _SidebarInfo(Icons.location_on_outlined,      'Ubicación', perfil.ubicacion),
          _SidebarInfo(Icons.calendar_today_outlined,   'Ingreso',   _formatFecha(perfil.fechaIngreso)),

          const Spacer(),
          const Divider(color: Colors.white12, indent: 24, endIndent: 24),

          // Acciones
          _SidebarAction(Icons.edit_outlined, 'Editar perfil', onEditar),
          _SidebarAction(Icons.lock_outline,  'Cambiar contraseña', () => _cambiarPassword(context)),
          _SidebarAction(Icons.logout,        'Cerrar sesión', onCerrarSesion, danger: true),
          const SizedBox(height: 16),

          Text(
            '© ${DateTime.now().year} Ferrocarril del Istmo\nde Tehuantepec',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _cambiarPassword(BuildContext ctx) {
    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
      content: Text('Se enviará un correo para restablecer tu contraseña.'),
      behavior: SnackBarBehavior.floating,
    ));
    // Supabase: Supabase.instance.client.auth.resetPasswordForEmail(perfil.correo);
  }

  String _formatFecha(String raw) {
    try {
      final dt = DateTime.parse(raw);
      const meses = ['Ene','Feb','Mar','Abr','May','Jun',
                     'Jul','Ago','Sep','Oct','Nov','Dic'];
      return '${meses[dt.month - 1]} ${dt.year}';
    } catch (_) { return raw; }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  LAYOUT MOBILE
// ═══════════════════════════════════════════════════════════════════════════
class _MobileLayout extends StatelessWidget {
  final EmpleadoPerfil perfil;
  final bool guardando;
  final VoidCallback onEditar;
  final VoidCallback onCerrarSesion;

  const _MobileLayout({
    required this.perfil,
    required this.guardando,
    required this.onEditar,
    required this.onCerrarSesion,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App bar con hero gradient
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            stretch: true,
            backgroundColor: _kDarkBg,
            leading: const BackButton(color: Colors.white),
            actions: [
              if (guardando)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)),
                )
              else
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.white),
                  onPressed: onEditar,
                  tooltip: 'Editar perfil',
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.blurBackground],
              background: _MobileHeroHeader(perfil: perfil),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Stats
                _MobileStatsRow(perfil: perfil),
                const SizedBox(height: 16),

                // Contacto
                _Card(
                  title: 'Contacto',
                  icon: Icons.contact_page_outlined,
                  iconColor: _kAccent,
                  iconBg: _kAccent.withOpacity(0.1),
                  child: _ContactoGrid(perfil: perfil),
                ),
                const SizedBox(height: 14),

                // Estado laboral
                _Card(
                  title: 'Estado Laboral',
                  icon: Icons.badge_outlined,
                  iconColor: Colors.blue.shade600,
                  iconBg: Colors.blue.shade50,
                  child: _EstadoLaboralGrid(perfil: perfil),
                ),
                const SizedBox(height: 14),

                // Servicios
                _Card(
                  title: 'Accesos Rápidos',
                  icon: Icons.apps_rounded,
                  iconColor: Colors.purple.shade600,
                  iconBg: Colors.purple.shade50,
                  child: _ServiciosGrid(context: context),
                ),
                const SizedBox(height: 14),

                // Cuenta
                _Card(
                  title: 'Cuenta',
                  icon: Icons.settings_outlined,
                  iconColor: Colors.grey.shade600,
                  iconBg: Colors.grey.shade100,
                  child: _CuentaSection(
                    onCerrarSesion: onCerrarSesion,
                    correo: perfil.correo,
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Mobile hero header ───────────────────────────────────────────────────
class _MobileHeroHeader extends StatelessWidget {
  final EmpleadoPerfil perfil;
  const _MobileHeroHeader({required this.perfil});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kDarkBg, Color(0xFF1B4F72)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 50),
          _AvatarWidget(iniciales: perfil.iniciales, fotoUrl: perfil.fotoUrl,
                        size: 84),
          const SizedBox(height: 14),
          Text(perfil.nombreCompleto.toUpperCase(),
            style: const TextStyle(
              color: Colors.white, fontSize: 18,
              fontWeight: FontWeight.w900, letterSpacing: 0.4,
            )),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RolBadge(texto: perfil.puesto.isNotEmpty ? perfil.puesto : perfil.rol),
              const SizedBox(width: 8),
              _EstadoBadge(estado: perfil.estado),
            ],
          ),
          const SizedBox(height: 10),
          Text(perfil.area,
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  WIDGETS REUTILIZABLES
// ═══════════════════════════════════════════════════════════════════════════

// ── Avatar ────────────────────────────────────────────────────────────────
class _AvatarWidget extends StatelessWidget {
  final String iniciales;
  final String? fotoUrl;
  final double size;

  const _AvatarWidget({
    required this.iniciales,
    this.fotoUrl,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF2DC8A8), Color(0xFF1AA88A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _kAccent.withOpacity(0.45),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: fotoUrl != null && fotoUrl!.isNotEmpty
              ? ClipOval(
                  child: Image.network(fotoUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _Initials(iniciales: iniciales, size: size),
                  ),
                )
              : _Initials(iniciales: iniciales, size: size),
        ),
        // Punto de actividad
        Container(
          width: size * 0.26,
          height: size * 0.26,
          decoration: BoxDecoration(
            color: Colors.green.shade400,
            shape: BoxShape.circle,
            border: Border.all(color: _kDarkBg, width: 2.5),
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 11),
        ),
      ],
    );
  }
}

class _Initials extends StatelessWidget {
  final String iniciales;
  final double size;
  const _Initials({required this.iniciales, required this.size});

  @override
  Widget build(BuildContext context) => Center(
    child: Text(iniciales,
      style: TextStyle(
        fontSize: size * 0.35,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        letterSpacing: 1,
      )),
  );
}

// ── Badges ────────────────────────────────────────────────────────────────
class _RolBadge extends StatelessWidget {
  final String texto;
  const _RolBadge({required this.texto});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: _kAccent.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _kAccent.withOpacity(0.4)),
    ),
    child: Text(texto.toUpperCase(),
      style: const TextStyle(
        color: _kAccent, fontSize: 10,
        fontWeight: FontWeight.bold, letterSpacing: 1.2,
      )),
  );
}

class _EstadoBadge extends StatelessWidget {
  final String estado;
  const _EstadoBadge({required this.estado});

  Color get _color => switch (estado.toLowerCase()) {
    'activo'    => Colors.green,
    'inactivo'  => Colors.red,
    'suspendido'=> Colors.orange,
    _           => Colors.grey,
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: _color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _color.withOpacity(0.4)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 6, height: 6,
        decoration: BoxDecoration(color: _color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(estado,
        style: TextStyle(
          color: _color, fontSize: 10,
          fontWeight: FontWeight.bold,
        )),
    ]),
  );
}

// ── Sidebar helpers ───────────────────────────────────────────────────────
class _SidebarInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _SidebarInfo(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 9),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: _kAccent, size: 17),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
            style: TextStyle(color: Colors.white.withOpacity(0.38),
                             fontSize: 9, letterSpacing: 0.9)),
          const SizedBox(height: 2),
          Text(value,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            overflow: TextOverflow.ellipsis, maxLines: 2),
        ]),
      ),
    ]),
  );
}

class _SidebarAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _SidebarAction(this.icon, this.label, this.onTap, {this.danger = false});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(children: [
        Icon(icon,
          color: danger ? Colors.red.shade300 : Colors.white60,
          size: 18),
        const SizedBox(width: 12),
        Text(label,
          style: TextStyle(
            color: danger ? Colors.red.shade300 : Colors.white70,
            fontSize: 13,
          )),
      ]),
    ),
  );
}

// ── Card genérica ─────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Widget child;

  const _Card({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 12),
          Text(title,
            style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold, color: _kDarkBg)),
        ]),
      ),
      const Divider(height: 22, indent: 20, endIndent: 20),
      child,
    ]),
  );
}

// ── Stats row desktop ─────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final EmpleadoPerfil perfil;
  const _StatsRow({required this.perfil});

  @override
  Widget build(BuildContext context) {
    final stats = [
      _StatItem('Documentos', '${perfil.documentos}',
                Icons.description_outlined, Colors.blue),
      _StatItem('Solicitudes', '${perfil.solicitudes}',
                Icons.send_outlined, Colors.orange),
      _StatItem('Años de servicio', '${perfil.antiguedadAnios}',
                Icons.timer_outlined, Colors.purple),
    ];

    return Row(
      children: stats.map((s) {
        final isLast = s == stats.last;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: isLast ? 0 : 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04),
                          blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: s.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(s.icon, color: s.color, size: 20),
                ),
                const SizedBox(height: 14),
                Text(s.value,
                  style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w900, color: _kDarkBg)),
                const SizedBox(height: 4),
                Text(s.label,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ]),
          ),
        );
      }).toList(),
    );
  }
}

class _StatItem {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatItem(this.label, this.value, this.icon, this.color);
}

// ── Stats row mobile ──────────────────────────────────────────────────────
class _MobileStatsRow extends StatelessWidget {
  final EmpleadoPerfil perfil;
  const _MobileStatsRow({required this.perfil});

  @override
  Widget build(BuildContext context) {
    final stats = [
      _StatItem('Docs',        '${perfil.documentos}',    Icons.description_outlined, Colors.blue),
      _StatItem('Solicitudes', '${perfil.solicitudes}',   Icons.send_outlined,        Colors.orange),
      _StatItem('Años',        '${perfil.antiguedadAnios}',Icons.timer_outlined,      Colors.purple),
    ];

    return Row(
      children: List.generate(stats.length, (i) {
        final s = stats[i];
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < stats.length - 1 ? 10 : 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04),
                          blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: s.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(s.icon, color: s.color, size: 18),
              ),
              const SizedBox(height: 8),
              Text(s.value,
                style: const TextStyle(fontSize: 20,
                                       fontWeight: FontWeight.w900, color: _kDarkBg)),
              Text(s.label,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
            ]),
          ),
        );
      }),
    );
  }
}

// ── Estado laboral grid ───────────────────────────────────────────────────
class _EstadoLaboralGrid extends StatelessWidget {
  final EmpleadoPerfil perfil;
  const _EstadoLaboralGrid({required this.perfil});

  @override
  Widget build(BuildContext context) {
    String fechaFmt = perfil.fechaIngreso;
    try {
      final dt = DateTime.parse(perfil.fechaIngreso);
      const m = ['Ene','Feb','Mar','Abr','May','Jun',
                 'Jul','Ago','Sep','Oct','Nov','Dic'];
      fechaFmt = '${m[dt.month - 1]} ${dt.year}';
    } catch (_) {}

    final chips = [
      ('Estado',        perfil.estado,     Colors.green),
      ('Fecha ingreso', fechaFmt,           Colors.blue),
      ('Jornada',       perfil.jornada,    Colors.orange),
      ('Departamento',  perfil.area,       Colors.purple),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: chips.map((c) => _LaboralChip(
          label: c.$1, value: c.$2, color: c.$3,
        )).toList(),
      ),
    );
  }
}

class _LaboralChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _LaboralChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(),
        style: TextStyle(color: color.withOpacity(0.7),
                         fontSize: 9, letterSpacing: 0.8, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(value,
        style: TextStyle(color: color.withOpacity(0.9),
                         fontSize: 13, fontWeight: FontWeight.w700)),
    ]),
  );
}

// ── Contacto grid ─────────────────────────────────────────────────────────
class _ContactoGrid extends StatelessWidget {
  final EmpleadoPerfil perfil;
  const _ContactoGrid({required this.perfil});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.email_outlined,   'Correo',    perfil.correo),
      (Icons.phone_outlined,   'Teléfono',  perfil.telefono),
      (Icons.location_on_outlined, 'Ubicación', perfil.ubicacion),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: _kAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.$1, color: _kAccent, size: 17),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.$2,
                  style: TextStyle(color: Colors.grey.shade400,
                                   fontSize: 10, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(item.$3,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                         color: _kDarkBg),
                  overflow: TextOverflow.ellipsis),
              ],
            )),
            // Copy button
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: item.$3));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('${item.$2} copiado'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ));
              },
              child: Icon(Icons.copy_outlined,
                color: Colors.grey.shade300, size: 16),
            ),
          ]),
        )).toList(),
      ),
    );
  }
}

// ── Servicios / accesos rápidos ───────────────────────────────────────────
class _ServiciosGrid extends StatelessWidget {
  final BuildContext context;
  const _ServiciosGrid({required this.context});

  static const _servicios = [
    (Icons.receipt_long_outlined, Colors.teal,   'Boletas de Pago',      'Ver historial de nómina'),
    (Icons.event_available_outlined, Colors.indigo,'Solicitudes',         'Permisos y ausencias'),
    (Icons.school_outlined,       Colors.purple,  'Capacitaciones',      'Cursos disponibles'),
    (Icons.calendar_month_outlined, Colors.blue,  'Asistencia',          'Registro de entradas/salidas'),
  ];

  @override
  Widget build(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: _servicios.map((s) => _ServicioTile(
          icon: s.$1, color: s.$2, title: s.$3, subtitle: s.$4,
          onTap: () => ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
            content: Text('Próximamente: ${s.$3}'),
            behavior: SnackBarBehavior.floating,
          )),
        )).toList(),
      ),
    );
  }
}

class _ServicioTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;

  const _ServicioTile({
    required this.icon, required this.color,
    required this.title, required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13, color: _kDarkBg)),
            Text(subtitle, style: TextStyle(
              color: Colors.grey.shade400, fontSize: 11)),
          ])),
        Icon(Icons.chevron_right, color: Colors.grey.shade300, size: 20),
      ]),
    ),
  );
}

// ── Sección cuenta (mobile) ───────────────────────────────────────────────
class _CuentaSection extends StatelessWidget {
  final VoidCallback onCerrarSesion;
  final String correo;
  const _CuentaSection({required this.onCerrarSesion, required this.correo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(children: [
        _CuentaItem(
          icon: Icons.lock_outline,
          label: 'Cambiar contraseña',
          color: Colors.grey.shade700,
          onTap: () {
            // Supabase.instance.client.auth.resetPasswordForEmail(correo)
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Correo de restablecimiento enviado'),
              behavior: SnackBarBehavior.floating,
            ));
          },
        ),
        const SizedBox(height: 6),
        _CuentaItem(
          icon: Icons.logout,
          label: 'Cerrar sesión',
          color: Colors.red.shade400,
          onTap: onCerrarSesion,
        ),
      ]),
    );
  }
}

class _CuentaItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _CuentaItem({required this.icon, required this.label,
                     required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Text(label,
          style: TextStyle(fontSize: 13, color: color,
                           fontWeight: FontWeight.w600)),
        const Spacer(),
        Icon(Icons.chevron_right, color: color.withOpacity(0.4), size: 18),
      ]),
    ),
  );
}

// ── Botón primario ────────────────────────────────────────────────────────
class _PrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _PrimaryButton({required this.icon, required this.label,
                        required this.onPressed});

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 17),
    label: Text(label),
    style: FilledButton.styleFrom(
      backgroundColor: _kAccent,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
    ),
  );
}

class _LoadingBadge extends StatelessWidget {
  const _LoadingBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: _kAccent.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: 14, height: 14,
        child: CircularProgressIndicator(
          color: _kAccent, strokeWidth: 2)),
      SizedBox(width: 8),
      Text('Guardando…',
        style: TextStyle(color: _kAccent, fontSize: 12,
                         fontWeight: FontWeight.w600)),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  DIÁLOGO EDITAR PERFIL
// ═══════════════════════════════════════════════════════════════════════════
class _EditarPerfilDialog extends StatefulWidget {
  final EmpleadoPerfil perfil;
  const _EditarPerfilDialog({required this.perfil});

  @override
  State<_EditarPerfilDialog> createState() => _EditarPerfilDialogState();
}

class _EditarPerfilDialogState extends State<_EditarPerfilDialog> {
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _ubicacionCtrl;
  late final TextEditingController _puestoCtrl;
  final _form = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _telefonoCtrl  = TextEditingController(text: widget.perfil.telefono);
    _ubicacionCtrl = TextEditingController(text: widget.perfil.ubicacion);
    _puestoCtrl    = TextEditingController(text: widget.perfil.puesto);
  }

  @override
  void dispose() {
    _telefonoCtrl.dispose();
    _ubicacionCtrl.dispose();
    _puestoCtrl.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_form.currentState!.validate()) return;
    final actualizado = widget.perfil.copyWith(
      telefono:  _telefonoCtrl.text.trim(),
      ubicacion: _ubicacionCtrl.text.trim(),
      puesto:    _puestoCtrl.text.trim(),
    );
    Navigator.pop(context, actualizado);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Título
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_outlined, color: _kAccent, size: 18),
              ),
              const SizedBox(width: 12),
              const Text('Editar Perfil',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                                 color: _kDarkBg)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
            const SizedBox(height: 6),
            Text('Solo puedes editar tu información de contacto',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
            const SizedBox(height: 24),

            // Campos
            _FormField(
              ctrl: _puestoCtrl,
              label: 'Puesto / Cargo',
              icon: Icons.work_outline,
              validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 16),
            _FormField(
              ctrl: _telefonoCtrl,
              label: 'Teléfono',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 16),
            _FormField(
              ctrl: _ubicacionCtrl,
              label: 'Ubicación',
              icon: Icons.location_on_outlined,
              validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 28),

            // Botones
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _guardar,
                  style: FilledButton.styleFrom(
                    backgroundColor: _kAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Guardar cambios',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _FormField({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl,
    keyboardType: keyboardType,
    validator: validator,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18, color: _kAccent),
      filled: true,
      fillColor: _kBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kAccent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  DIÁLOGO CONFIRMACIÓN
// ═══════════════════════════════════════════════════════════════════════════
class _ConfirmDialog extends StatelessWidget {
  final String titulo, mensaje, accion;
  final bool peligro;

  const _ConfirmDialog({
    required this.titulo,
    required this.mensaje,
    required this.accion,
    this.peligro = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = peligro ? Colors.red.shade600 : _kAccent;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Text(mensaje),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: color),
          child: Text(accion),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SKELETON LOADING
// ═══════════════════════════════════════════════════════════════════════════
class _SkeletonPage extends StatefulWidget {
  const _SkeletonPage();

  @override
  State<_SkeletonPage> createState() => _SkeletonPageState();
}

class _SkeletonPageState extends State<_SkeletonPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 720;
    return Scaffold(
      backgroundColor: _kBg,
      body: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) {
          final base = Color.lerp(
            const Color(0xFFE2E8F0), const Color(0xFFCBD5E1), _anim.value)!;
          return isWide
              ? _buildDesktopSkeleton(base)
              : _buildMobileSkeleton(base);
        },
      ),
    );
  }

  Widget _box(Color c, {double w = double.infinity, double h = 14.0,
               double r = 8}) =>
      Container(
        width: w, height: h,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(r),
        ),
      );

  Widget _buildDesktopSkeleton(Color c) {
    return Row(children: [
      Container(
        width: 290,
        color: _kDarkBg.withOpacity(0.85),
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const SizedBox(height: 48),
          Container(width: 90, height: 90,
            decoration: BoxDecoration(
              color: Colors.white12, shape: BoxShape.circle)),
          const SizedBox(height: 20),
          _box(Colors.white12, w: 160, h: 16, r: 8),
          const SizedBox(height: 12),
          _box(Colors.white12, w: 100, h: 10, r: 16),
          const SizedBox(height: 32),
          for (var i = 0; i < 5; i++) ...[
            _box(Colors.white12, w: double.infinity, h: 12, r: 6),
            const SizedBox(height: 14),
          ],
        ]),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _box(c, w: 180, h: 28, r: 8),
            const SizedBox(height: 10),
            _box(c, w: 260, h: 14, r: 6),
            const SizedBox(height: 28),
            Row(children: List.generate(3, (i) => Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 2 ? 16 : 0),
                height: 100,
                decoration: BoxDecoration(
                  color: c.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16)),
              ),
            ))),
            const SizedBox(height: 24),
            Container(height: 140,
              decoration: BoxDecoration(
                color: c.withOpacity(0.6),
                borderRadius: BorderRadius.circular(18))),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildMobileSkeleton(Color c) {
    return Column(children: [
      Container(
        height: 260, color: _kDarkBg.withOpacity(0.85),
        child: Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 80, height: 80,
              decoration: BoxDecoration(
                color: Colors.white12, shape: BoxShape.circle)),
            const SizedBox(height: 16),
            _box(Colors.white12, w: 160, h: 16, r: 8),
            const SizedBox(height: 10),
            _box(Colors.white12, w: 100, h: 10, r: 16),
          ],
        )),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            const SizedBox(height: 16),
            Row(children: List.generate(3, (i) => Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 2 ? 10 : 0),
                height: 80,
                decoration: BoxDecoration(
                  color: c, borderRadius: BorderRadius.circular(14)),
              ),
            ))),
            const SizedBox(height: 14),
            Container(height: 120,
              decoration: BoxDecoration(
                color: c, borderRadius: BorderRadius.circular(18))),
          ]),
        ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  PÁGINA DE ERROR
// ═══════════════════════════════════════════════════════════════════════════
class _ErrorPage extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorPage({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off_rounded,
                color: Colors.red.shade400, size: 48),
            ),
            const SizedBox(height: 24),
            const Text('No se pudo cargar el perfil',
              style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: _kDarkBg)),
            const SizedBox(height: 10),
            Text(error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: FilledButton.styleFrom(
                backgroundColor: _kAccent,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}