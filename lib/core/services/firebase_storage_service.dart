// Archivo: lib/core/services/firebase_storage_service.dart
// Sube fotos y videos a Firebase Storage (no consume cuota de Supabase)

import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class FirebaseStorageService {
  static final FirebaseStorageService _instance = FirebaseStorageService._internal();
  factory FirebaseStorageService() => _instance;
  FirebaseStorageService._internal();

  final _storage = FirebaseStorage.instance;

  /// Sube un archivo y retorna la URL pública de descarga.
  /// [tipo] puede ser: 'exterior', 'interior', 'video'
  Future<String?> subirArchivo({
    required File archivo,
    required String asesorId,
    required String tipo,
    required String extension,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'evidencias/$asesorId/${tipo}_$timestamp.$extension';

      final ref = _storage.ref().child(path);

      final metadata = SettableMetadata(
        contentType: extension == 'mp4' ? 'video/mp4' : 'image/jpeg',
        customMetadata: {'asesor_id': asesorId, 'tipo': tipo},
      );

      final uploadTask = ref.putFile(archivo, metadata);

      // Progreso en consola para debug
      uploadTask.snapshotEvents.listen((TaskSnapshot snap) {
        final progress = (snap.bytesTransferred / snap.totalBytes * 100).toStringAsFixed(0);
        debugPrint('Upload $tipo: $progress%');
      });

      await uploadTask;
      final url = await ref.getDownloadURL();
      debugPrint('✅ Firebase Storage [$tipo]: $url');
      return url;
    } catch (e) {
      debugPrint('❌ Error subiendo $tipo a Firebase: $e');
      return null;
    }
  }
}