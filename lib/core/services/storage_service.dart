import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Servicio para gestionar archivos en Supabase Storage
class StorageService {
  static const String riderAvatarsBucket = 'rider-avatars';

  static SupabaseStorageClient get _storage => SupabaseService.client.storage;

  /// Obtiene la URL pública del avatar de un repartidor
  ///
  /// [riderId] - ID del repartidor
  /// [fileName] - Nombre del archivo del avatar (ej: 'avatar.jpg', 'profile.png')
  ///
  /// Retorna la URL pública del avatar o null si no se puede generar
  static String? getRiderAvatarUrl(String riderId, {String fileName = 'avatar.jpg'}) {
    try {
      final path = '$riderId/$fileName';
      return _storage.from(riderAvatarsBucket).getPublicUrl(path);
    } catch (e) {
      return null;
    }
  }

  /// Verifica si existe un avatar para el repartidor
  ///
  /// [riderId] - ID del repartidor
  /// [fileName] - Nombre del archivo del avatar
  ///
  /// Retorna true si el archivo existe, false en caso contrario
  static Future<bool> riderAvatarExists(String riderId, {String fileName = 'avatar.jpg'}) async {
    try {
      final files = await _storage.from(riderAvatarsBucket).list(path: riderId);
      return files.any((file) => file.name == fileName);
    } catch (e) {
      return false;
    }
  }

  /// Sube un avatar para un repartidor
  ///
  /// [riderId] - ID del repartidor
  /// [file] - Archivo a subir
  /// [fileName] - Nombre con el que se guardará el archivo
  ///
  /// Retorna la URL pública del archivo subido
  static Future<String?> uploadRiderAvatar(
    String riderId,
    File file, {
    String fileName = 'avatar.jpg',
  }) async {
    try {
      final path = '$riderId/$fileName';
      await _storage.from(riderAvatarsBucket).upload(
        path,
        file,
        fileOptions: const FileOptions(upsert: true),
      );
      return getRiderAvatarUrl(riderId, fileName: fileName);
    } catch (e) {
      return null;
    }
  }

  /// Elimina el avatar de un repartidor
  ///
  /// [riderId] - ID del repartidor
  /// [fileName] - Nombre del archivo a eliminar
  ///
  /// Retorna true si se eliminó correctamente, false en caso contrario
  static Future<bool> deleteRiderAvatar(String riderId, {String fileName = 'avatar.jpg'}) async {
    try {
      final path = '$riderId/$fileName';
      await _storage.from(riderAvatarsBucket).remove([path]);
      return true;
    } catch (e) {
      return false;
    }
  }
}
