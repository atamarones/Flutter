import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Sección de Navegación
          const _SectionHeader(
            icon: Icons.navigation,
            title: 'Navegación',
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _SettingsTile(
                  title: 'Método de Navegación',
                  subtitle: settings.navigationMethod.displayName,
                  icon: Icons.map,
                  onTap: () => _showNavigationMethodDialog(context, ref, settings.navigationMethod),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Sección de Geolocalización
          const _SectionHeader(
            icon: Icons.location_on,
            title: 'Geolocalización',
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _SettingsTile(
                  title: 'Precisión de Ubicación',
                  subtitle: settings.locationAccuracy.displayName,
                  icon: Icons.gps_fixed,
                  onTap: () => _showLocationAccuracyDialog(context, ref, settings.locationAccuracy),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Información adicional
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Estas configuraciones afectan el consumo de batería y la precisión del seguimiento de entregas.',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNavigationMethodDialog(BuildContext context, WidgetRef ref, NavigationMethod current) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Método de Navegación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: NavigationMethod.values.map((method) {
            return RadioListTile<NavigationMethod>(
              value: method,
              groupValue: current,
              onChanged: (value) {
                if (value != null) {
                  ref.read(settingsProvider.notifier).setNavigationMethod(value);
                  Navigator.pop(context);
                }
              },
              title: Text(method.displayName),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
        ],
      ),
    );
  }

  void _showLocationAccuracyDialog(BuildContext context, WidgetRef ref, LocationAccuracy current) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Precisión de Ubicación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: LocationAccuracy.values.map((accuracy) {
            return RadioListTile<LocationAccuracy>(
              value: accuracy,
              groupValue: current,
              onChanged: (value) {
                if (value != null) {
                  ref.read(settingsProvider.notifier).setLocationAccuracy(value);
                  Navigator.pop(context);
                }
              },
              title: Text(
                accuracy.name.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                accuracy.displayName,
                style: const TextStyle(fontSize: 12),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
        ],
      ),
    );
  }

}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
