import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'liquidaciones_mixers_tab.dart';
import 'liquidaciones_bombas_tab.dart';

class LiquidacionesPage extends StatelessWidget {
  const LiquidacionesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Módulo de Liquidaciones',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          iconTheme: const IconThemeData(color: Colors.black87),
          backgroundColor: Colors.white,
          elevation: 0,
          bottom: const TabBar(
            labelColor: AppColors.primaryDark,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primaryDark,
            indicatorWeight: 3,
            tabs: [
              Tab(text: "MIXERS"),
              Tab(text: "BOMBAS"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            LiquidacionesMixersTab(),
            LiquidacionesBombasTab(),
          ],
        ),
      ),
    );
  }
}
