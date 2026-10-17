import 'package:flutter/material.dart';
import 'package:app_database/screens/guias/guias_page.dart';
import 'package:app_database/screens/guias/guias_sunat_page.dart';

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
          surfaceTintColor: Colors.white,
          elevation: 0,
          toolbarHeight: 80,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.lightBlue.shade600, Colors.blue.shade600],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.description_outlined, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'GUÍAS',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                      letterSpacing: -1.0,
                    ),
                  ),
                  Text(
                    'Control de despachos logísticos y emisión a SUNAT',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade100),
                ),
              ),
              child: TabBar(
                labelColor: const Color(0xFF0F172A),
                unselectedLabelColor: Colors.grey.shade400,
                indicatorColor: Colors.lightBlue.shade600,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_shipping_outlined, size: 18, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        const Text('GUÍAS DE DESPACHO'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 18, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        const Text('GUÍAS DE REMISIÓN (SUNAT)'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            GuiasDespachoPage(),
            GuiasSunatPage(),
          ],
        ),
      ),
    );
  }
}
