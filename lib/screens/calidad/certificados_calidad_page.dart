import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class CertificadosCalidadPage extends StatefulWidget {
  const CertificadosCalidadPage({super.key});

  @override
  State<CertificadosCalidadPage> createState() => _CertificadosCalidadPageState();
}

class _CertificadosCalidadPageState extends State<CertificadosCalidadPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Certificados de Calidad', style: TextStyle(color: AppColors.primaryDark)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppColors.primaryDark),
      ),
      body: const Center(
        child: Text('En construcción... Módulo de emisión de certificados de calidad.'),
      ),
    );
  }
}
