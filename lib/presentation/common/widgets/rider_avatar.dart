import 'package:flutter/material.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_colors.dart';

/// Widget que muestra el avatar de un repartidor
///
/// Prioridad de carga:
/// 1. avatarUrl si se proporciona directamente
/// 2. Supabase Storage usando riderId
/// 3. Inicial del nombre como fallback
class RiderAvatar extends StatelessWidget {
  final String riderId;
  final String fullName;
  final String? avatarUrl;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;
  final String avatarFileName;

  const RiderAvatar({
    super.key,
    required this.riderId,
    required this.fullName,
    this.avatarUrl,
    this.radius = 30,
    this.backgroundColor,
    this.textColor,
    this.avatarFileName = 'avatar.jpg',
  });

  @override
  Widget build(BuildContext context) {
    // Prioridad 1: URL directa (de la BD)
    String? finalAvatarUrl = avatarUrl;

    // Prioridad 2: Generar desde Storage si no hay URL directa
    if (finalAvatarUrl == null || finalAvatarUrl.isEmpty) {
      finalAvatarUrl = StorageService.getRiderAvatarUrl(
        riderId,
        fileName: avatarFileName,
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? AppColors.primary,
      backgroundImage: finalAvatarUrl != null && finalAvatarUrl.isNotEmpty
          ? NetworkImage(finalAvatarUrl)
          : null,
      onBackgroundImageError: finalAvatarUrl != null
          ? (exception, stackTrace) {
              // Si falla la carga, el child con la inicial se mostrará
            }
          : null,
      child: finalAvatarUrl == null || finalAvatarUrl.isEmpty
          ? Text(
              _getInitial(fullName),
              style: TextStyle(
                fontSize: radius * 0.8,
                fontWeight: FontWeight.bold,
                color: textColor ?? Colors.white,
              ),
            )
          : null,
    );
  }

  String _getInitial(String name) {
    if (name.isEmpty) return 'R';
    return name.substring(0, 1).toUpperCase();
  }
}

/// Widget mejorado para el avatar con indicador de estado
class RiderAvatarWithStatus extends StatelessWidget {
  final String riderId;
  final String fullName;
  final String? avatarUrl;
  final double radius;
  final bool isOnline;
  final String avatarFileName;

  const RiderAvatarWithStatus({
    super.key,
    required this.riderId,
    required this.fullName,
    this.avatarUrl,
    this.radius = 30,
    this.isOnline = false,
    this.avatarFileName = 'avatar.jpg',
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RiderAvatar(
          riderId: riderId,
          fullName: fullName,
          avatarUrl: avatarUrl,
          radius: radius,
          avatarFileName: avatarFileName,
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: radius * 0.4,
            height: radius * 0.4,
            decoration: BoxDecoration(
              color: isOnline ? AppColors.online : AppColors.offline,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
