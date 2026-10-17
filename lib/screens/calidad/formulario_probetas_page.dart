import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class FormularioProbetasPage extends StatefulWidget {
  const FormularioProbetasPage({super.key});

  @override
  State<FormularioProbetasPage> createState() => _FormularioProbetasPageState();
}

class _FormularioProbetasPageState extends State<FormularioProbetasPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Formulario de Probetas', style: TextStyle(color: AppColors.primaryDark)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppColors.primaryDark),
      ),
      body: const Center(
        child: Text('En construcción... Aquí se ingresarán las medidas de las probetas.'),
      ),
    );
  }
}
