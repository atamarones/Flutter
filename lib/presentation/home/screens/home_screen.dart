import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_urbango_logistics/presentation/order/widgets/order_assigned_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/background_service.dart';
import '../../../domain/entities/rider.dart';
import '../../../domain/entities/order.dart';
import '../providers/rider_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../order/providers/order_provider.dart';
import '../../order/screens/order_in_progress_screen.dart';
import '../widgets/rider_map_widget.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _initializeSession();
  }

  Future<void> _initializeSession() async {
    final session = SupabaseService.client.auth.currentSession;
    if (session != null) {
      await BackgroundService.saveToken(session.accessToken);
      debugPrint('[HOME] Token saved on init');
    }
  }

  @override
  Widget build(BuildContext context) {
    final riderState = ref.watch(riderStateProvider);
    final activeOrderState = ref.watch(activeOrderProvider);

    ref.listen(riderStateProvider, (previous, next) {
      if (next is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error.toString()),
            backgroundColor: AppColors.error,
            action: SnackBarAction(
              label: 'CONFIGURAR',
              textColor: Colors.white,
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
    });

    ref.listen(activeOrderProvider, (previous, next) {
      if (next is AsyncData<Order?>) {
        final order = next.value;
        if (order == null) return;
        
        final riderAsync = ref.read(riderStateProvider);
        if (riderAsync is! AsyncData<Rider?>) return;
        final rider = riderAsync.value;
        
        if (rider?.status != RiderStatus.online) return;
        if (order.status != OrderStatus.assigned) return;
        
        final prevOrder = previous is AsyncData<Order?> ? previous.value : null;
        if (prevOrder?.id == order.id) return;
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => OrderAssignedDialog(order: order),
            );
          }
        });
      }
    });

    if (activeOrderState.value != null && 
        (activeOrderState.value!.status == OrderStatus.accepted || 
         activeOrderState.value!.status == OrderStatus.inProgress)) {
      return const OrderInProgressScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Urbango Rider'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: _buildDrawer(context, ref, riderState.value),
      body: riderState.when(
        data: (rider) => rider != null 
            ? _buildContent(context, ref, rider)
            : const Center(child: Text('No rider data')),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, Rider rider) {
    final activeOrderState = ref.watch(activeOrderProvider);
    final activeOrder = activeOrderState.value;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(riderStateProvider);
        ref.invalidate(activeOrderProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height - 250,
              child: rider.status == RiderStatus.offline
                  ? _buildOfflineState(context, rider)
                  : _buildOnlineState(context, ref, rider, activeOrder),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: _buildStatusButton(context, ref, rider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineState(BuildContext context, Rider rider) {
    return Container(
      color: AppColors.offline.withValues(alpha: 0.1),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.warning, size: 64, color: AppColors.offline),
          const SizedBox(height: 16),
          Text(
            'Desconectado',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.offline,
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatCard(
                  icon: Icons.check_circle,
                  label: 'Hoy',
                  value: rider.dailyDeliveries.toString(),
                ),
                _StatCard(
                  icon: Icons.star,
                  label: 'Rating',
                  value: rider.rating.toStringAsFixed(1),
                ),
                _StatCard(
                  icon: Icons.delivery_dining,
                  label: 'Total',
                  value: rider.totalDeliveries.toString(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineState(BuildContext context, WidgetRef ref, Rider rider, Order? activeOrder) {
    if (rider.currentLat == null || rider.currentLng == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Obteniendo ubicación...'),
          ],
        ),
      );
    }

    // El mapa ya incluye su propio overlay con la info
    return RiderMapWidget(rider: rider, activeOrder: activeOrder);
  }

  Widget _buildStatusButton(BuildContext context, WidgetRef ref, Rider rider) {
    final isOnline = rider.status == RiderStatus.online;
    
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: isOnline ?  AppColors.online : AppColors.offline,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => ref.read(riderStateProvider.notifier).toggleStatus(),
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isOnline ? 'DESCONECTARME' : 'CONECTARME',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 60,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    alignment: isOnline ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isOnline ? AppColors.online : AppColors.offline,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, WidgetRef ref, Rider? rider) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Text(
                    rider?.fullName.substring(0, 1).toUpperCase() ?? 'R',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  rider?.fullName ?? 'Rider',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  rider?.email ?? '',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Perfil'),
            onTap: () {
              Navigator.pop(context);
              context.push('/profile');
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Historial'),
            onTap: () {
              Navigator.pop(context);
              context.push('/history');
            },
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text('Cerrar Sesión', 
                style: TextStyle(color: AppColors.error)),
            onTap: () async {
              await ref.read(authRepositoryProvider).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 32, color: AppColors.primary),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}