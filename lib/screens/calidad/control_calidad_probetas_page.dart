import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class ControlCalidadProbetasPage extends StatefulWidget {
  const ControlCalidadProbetasPage({super.key});

  @override
  State<ControlCalidadProbetasPage> createState() => _ControlCalidadProbetasPageState();
}

class _ControlCalidadProbetasPageState extends State<ControlCalidadProbetasPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Resistencias', style: TextStyle(color: AppColors.primaryDark)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppColors.primaryDark),
      ),
      body: const Center(
        child: Text('En construcción... Módulo de registro y programación de probetas.'),
      ),
    );
  }
}
