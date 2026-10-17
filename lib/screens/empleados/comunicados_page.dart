// Archivo: lib/screens/empleados/comunicados_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';

class ComunicadosPage extends StatefulWidget {
  const ComunicadosPage({super.key});

  @override
  State<ComunicadosPage> createState() => _ComunicadosPageState();
}

class _ComunicadosPageState extends State<ComunicadosPage> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List noticias = [];
  String _filtro = 'todos';
  final TextEditingController _searchController = TextEditingController();
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _cargarComunicados();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarComunicados() async {
    try {
      final data = await supabase
          .from('comunicados')
          .select()
          .order('fecha', ascending: false);
      setState(() {
        noticias = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        noticias = [
          {
            "titulo": "Uso obligatorio de EPPs",
            "mensaje":
                "Se recuerda a todo el personal de planta el uso estricto de casco y botas en las zonas operativas.",
            "fecha": "2026-04-13",
            "importancia": "alta",
          },
          {
            "titulo": "Feriado Largo",
            "mensaje":
                "Las operaciones se reducirán al 50% este fin de semana largo. Coordinar con sus jefaturas.",
            "fecha": "2026-04-10",
            "importancia": "media",
          },
          {
            "titulo": "Capacitación - Sistema de Gestión",
            "mensaje":
                "Se realizará una capacitación obligatoria para todos los colaboradores sobre el nuevo sistema de gestión.",
            "fecha": "2026-04-08",
            "importancia": "capacitacion",
          },
        ];
        isLoading = false;
      });
    }
  }

  List get _noticiasFiltradas {
    return noticias.where((n) {
      final matchFiltro =
          _filtro == 'todos' || n['importancia'] == _filtro;
      final matchBusqueda = _busqueda.isEmpty ||
          (n['titulo'] ?? '')
              .toLowerCase()
              .contains(_busqueda.toLowerCase()) ||
          (n['mensaje'] ?? '')
              .toLowerCase()
              .contains(_busqueda.toLowerCase());
      return matchFiltro && matchBusqueda;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : CustomScrollView(
              slivers: [
                _buildSliverHeader(),
                SliverToBoxAdapter(child: _buildBarraBusqueda()),
                SliverToBoxAdapter(child: _buildFiltros()),
                SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final lista = _noticiasFiltradas;
                        if (lista.isEmpty) {
                          return _buildEmptyState();
                        }
                        return _buildComunicadoCard(lista[index]);
                      },
                      childCount:
                          _noticiasFiltradas.isEmpty ? 1 : _noticiasFiltradas.length,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // --- Sliver Header con degradado ---
  Widget _buildSliverHeader() {
    return SliverAppBar(
      expandedHeight: 130,
      collapsedHeight: 60,
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: const Color(0xFF0D2137),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.campaign_outlined,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'Comunicados',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D2137), Color(0xFF1A4A6E)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 56),
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                '${_noticiasFiltradas.length} comunicado${_noticiasFiltradas.length != 1 ? 's' : ''} disponibles',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Barra de Búsqueda ---
  Widget _buildBarraBusqueda() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _busqueda = val),
          decoration: InputDecoration(
            prefixIcon:
                const Icon(Icons.search, color: Colors.grey, size: 22),
            suffixIcon: _busqueda.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _busqueda = '');
                    },
                  )
                : null,
            hintText: 'Buscar comunicados...',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  // --- Chips de filtro ---
  Widget _buildFiltros() {
    final filtros = [
      {'key': 'todos', 'label': 'Todos', 'icon': Icons.apps},
      {'key': 'alta', 'label': 'Importante', 'icon': Icons.warning_amber_rounded},
      {'key': 'media', 'label': 'Aviso', 'icon': Icons.info_outline},
      {'key': 'capacitacion', 'label': 'Capacitación', 'icon': Icons.school_outlined},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filtros.map((f) {
            final isSelected = _filtro == f['key'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: isSelected,
                onSelected: (_) =>
                    setState(() => _filtro = f['key'] as String),
                avatar: Icon(
                  f['icon'] as IconData,
                  size: 16,
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                ),
                label: Text(
                  f['label'] as String,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                  ),
                ),
                backgroundColor: Colors.white,
                selectedColor: const Color(0xFF0D2137),
                checkmarkColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF0D2137)
                        : Colors.grey.shade300,
                  ),
                ),
                elevation: isSelected ? 2 : 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Sin resultados',
              style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Intenta con otro filtro o búsqueda',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // --- Tarjeta de Comunicado ---
  Widget _buildComunicadoCard(Map noticia) {
    final importancia = noticia['importancia'] ?? 'media';

    final config = {
      'alta': {
        'tagColor': Colors.red.shade50,
        'tagText': Colors.red.shade700,
        'icon': Icons.campaign_rounded,
        'label': 'Importante',
        'borderColor': Colors.red.shade100,
        'accentBar': Colors.red.shade400,
      },
      'media': {
        'tagColor': Colors.blue.shade50,
        'tagText': Colors.blue.shade700,
        'icon': Icons.article_outlined,
        'label': 'Aviso',
        'borderColor': Colors.blue.shade100,
        'accentBar': Colors.blue.shade400,
      },
      'capacitacion': {
        'tagColor': Colors.lightBlue.shade50,
        'tagText': Colors.lightBlue.shade700,
        'icon': Icons.school_outlined,
        'label': 'Capacitación',
        'borderColor': Colors.lightBlue.shade100,
        'accentBar': Colors.lightBlue.shade400,
      },
    };

    final c = config[importancia] ?? config['media']!;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c['borderColor'] as Color, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra lateral de color
              Container(
                width: 5,
                color: c['accentBar'] as Color,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Tag
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: c['tagColor'] as Color,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(c['icon'] as IconData,
                                    color: c['tagText'] as Color, size: 13),
                                const SizedBox(width: 5),
                                Text(
                                  c['label'] as String,
                                  style: TextStyle(
                                    color: c['tagText'] as Color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Fecha
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined,
                                  size: 12, color: Colors.grey.shade400),
                              const SizedBox(width: 4),
                              Text(
                                noticia['fecha'] ?? '',
                                style: TextStyle(
                                    color: Colors.grey.shade400, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        noticia['titulo'] ?? 'Sin título',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0D2137),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        noticia['mensaje'] ?? '',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          height: 1.5,
                          fontSize: 13,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () {},
                            icon: Icon(Icons.visibility_outlined,
                                size: 16,
                                color: (c['tagText'] as Color)),
                            label: Text(
                              'Ver más',
                              style: TextStyle(
                                fontSize: 12,
                                color: (c['tagText'] as Color),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              backgroundColor:
                                  (c['tagColor'] as Color),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}