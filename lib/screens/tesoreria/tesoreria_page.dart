import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'caja_page.dart';
import 'caja_chica_page.dart';
import 'legal_page.dart';
import 'ganancias_page.dart';
import 'facturacion_sunat_page.dart';

class TesoreriaPage extends StatefulWidget {
  const TesoreriaPage({super.key});

  @override
  State<TesoreriaPage> createState() => _TesoreriaPageState();
}

class _TesoreriaPageState extends State<TesoreriaPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Fondo moderno slate
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 70,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('TESORERÍA', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -1.0)),
            Text('Control financiero, compras de agregados y legal', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0F172A),
          unselectedLabelColor: Colors.grey.shade400,
          indicatorColor: const Color(0xFF0F172A),
          indicatorWeight: 4,
          isScrollable: true,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
          tabs: const [
            Tab(text: 'FACTURACIÓN'),
            Tab(text: 'GANANCIAS'),
            Tab(text: 'CAJA GENERAL'),
            Tab(text: 'CAJA CHICA'),
            Tab(text: 'AREA LEGAL'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const FacturacionSunatPage().animate().fade(),
          const GananciasPage().animate().fade(),
          const CajaPage().animate().fade(),
          const CajaChicaPage().animate().fade(),
          const LegalPage().animate().fade(),
        ],
      ),
    );
  }
}
