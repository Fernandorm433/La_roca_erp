import 'package:flutter/material.dart';
import 'package:app_database/screens/guias/guias_page.dart';

class GuiasMainPage extends StatelessWidget {
  const GuiasMainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          toolbarHeight: 70,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('GUÍAS', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -1.0)),
              Text('Control de despachos logísticos y emisión a SUNAT', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          bottom: TabBar(
            labelColor: const Color(0xFF0F172A),
            unselectedLabelColor: Colors.grey.shade400,
            indicatorColor: const Color(0xFF0F172A),
            indicatorWeight: 4,
            labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
            tabs: const [
              Tab(text: 'GUÍAS DE DESPACHO (INTERNAS)'),
              Tab(text: 'GUÍAS DE REMISIÓN (SUNAT)'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            GuiasDespachoPage(), // La página actual
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_done_rounded, size: 80, color: Colors.blueGrey),
                  SizedBox(height: 16),
                  Text("Guías de Remisión Electrónica", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text("Aquí se listarán las GRE validadas por SUNAT.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
