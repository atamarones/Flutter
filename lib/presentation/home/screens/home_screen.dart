import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../order/widgets/order_assigned_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/foreground_tracking_service.dart';
import '../../../domain/entities/rider.dart';
import '../../../domain/entities/order.dart';
import '../providers/rider_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../order/providers/order_provider.dart';
import '../../order/screens/order_in_progress_screen.dart';
import '../widgets/rider_map_widget.dart';
import '../../common/widgets/rider_avatar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _lastShownOrderId;

  @override
  void initState() {
    super.initState();
    _initializeSession();
  }

  Future<void> _initializeSession() async {
    final session = SupabaseService.client.auth.currentSession;
    if (session != null) {
      await ForegroundTrackingService.saveToken(session.accessToken);
    }
  }

  @override
  Widget build(BuildContext context) {
    final riderState = ref.watch(riderStateProvider);
    final activeOrderState = ref.watch(activeOrderProvider);

    ref.listen(activeOrderProvider, (previous, next) {
      if (next is AsyncData<Order?>) {
        final order = next.value;
        if (order == null) {
          _lastShownOrderId = null;
          return;
        }
        
        final riderAsync = ref.read(riderStateProvider);
        if (riderAsync is! AsyncData<Rider?>) return;
        final rider = riderAsync.value;
        
        if (rider?.status != RiderStatus.online) return;
        if (order.status != OrderStatus.assigned) return;
        
        // CRÍTICO: Solo mostrar si es un pedido nuevo
        if (_lastShownOrderId == order.id) return;
        _lastShownOrderId = order.id;
        
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
            : _buildNoRiderDataError(context, ref),
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Cargando perfil...'),
            ],
          ),
        ),
        error: (error, stack) => _buildErrorView(context, ref, error),
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

    return RiderMapWidget(rider: rider, activeOrder: activeOrder);
  }

  Widget _buildStatusButton(BuildContext context, WidgetRef ref, Rider rider) {
    final isOnline = rider.status == RiderStatus.online;
    
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: isOnline ? AppColors.online : AppColors.offline,
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
                    isOnline ? 'CONECTADO' : 'DESCONECTADO',
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
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.8),
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo de la app
                    Row(
                      children: [
                        Image.asset(
                          'assets/images/android-icon-48x48.png',
                          width: 32,
                          height: 32,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Urbango',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Avatar y info del repartidor
                    Row(
                      children: [
                        RiderAvatarWithStatus(
                          riderId: rider?.id ?? '',
                          fullName: rider?.fullName ?? 'Rider',
                          avatarUrl: rider?.avatarUrl,
                          radius: 32,
                          isOnline: rider?.status == RiderStatus.online,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rider?.fullName ?? 'Rider',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                rider?.email ?? '',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Stats del repartidor
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _DrawerStatItem(
                            icon: Icons.delivery_dining,
                            value: rider?.dailyDeliveries.toString() ?? '0',
                            label: 'Hoy',
                          ),
                          Container(
                            width: 1,
                            height: 30,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          _DrawerStatItem(
                            icon: Icons.star,
                            value: rider?.rating.toStringAsFixed(1) ?? '0.0',
                            label: 'Rating',
                          ),
                          Container(
                            width: 1,
                            height: 30,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          _DrawerStatItem(
                            icon: Icons.check_circle,
                            value: rider?.totalDeliveries.toString() ?? '0',
                            label: 'Total',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.person, color: AppColors.primary),
            title: const Text('Perfil'),
            onTap: () {
              Navigator.pop(context);
              context.push('/profile');
            },
          ),
          ListTile(
            leading: const Icon(Icons.history, color: AppColors.primary),
            title: const Text('Historial'),
            onTap: () {
              Navigator.pop(context);
              context.push('/history');
            },
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text('Cerrar Sesión', style: TextStyle(color: AppColors.error)),
            onTap: () async {
              await secureLogout(ref);
              if (context.mounted) context.go('/login');
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, WidgetRef ref, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Error al cargar tu perfil',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              error.toString().replaceFirst('Exception: ', ''),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                ref.invalidate(riderStateProvider);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('REINTENTAR'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                await secureLogout(ref);
                if (context.mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout, color: AppColors.error),
              label: const Text(
                'CERRAR SESIÓN',
                style: TextStyle(color: AppColors.error),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoRiderDataError(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.warning_amber,
              size: 64,
              color: AppColors.offline,
            ),
            const SizedBox(height: 24),
            Text(
              'Perfil no encontrado',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'No se encontró información del repartidor.\n\n'
              'Esto puede deberse a un problema de sincronización.\n'
              'Por favor, intenta cerrar sesión y volver a iniciar.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                ref.invalidate(riderStateProvider);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('REINTENTAR'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                await secureLogout(ref);
                if (context.mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout),
              label: const Text('CERRAR SESIÓN'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 32, color: AppColors.primary),
        const SizedBox(height: 8),
        Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

class _DrawerStatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _DrawerStatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: Colors.white),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}