import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class BoletasPage extends StatelessWidget {
  const BoletasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Boletas de Pago', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: 6,
        itemBuilder: (context, index) {
          final meses = ['Mayo', 'Abril', 'Marzo', 'Febrero', 'Enero', 'Diciembre'];
          final isActual = index == 0;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isActual ? Colors.teal.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.receipt_long, color: isActual ? Colors.teal : Colors.grey.shade600),
              ),
              title: Text('${meses[index]} 2026', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              subtitle: Text(isActual ? 'Disponible' : 'Pagado', style: TextStyle(color: isActual ? Colors.teal : Colors.grey.shade500)),
              trailing: IconButton(
                icon: const Icon(Icons.download_rounded, color: AppColors.accent),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Descargando boleta en PDF...'), behavior: SnackBarBehavior.floating),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
