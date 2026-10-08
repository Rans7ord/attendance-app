import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/responsive.dart';
import '../../core/theme/app_theme.dart';
import 'branch_schedule_screen.dart';

class BranchesScreen extends StatefulWidget {
  const BranchesScreen({super.key});

  @override
  State<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends State<BranchesScreen> {
  final _api = ApiService();
  List<dynamic> _branches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _api.getBranches();
      setState(() {
        _branches = data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load branches')),
        );
      }
    }
  }

  void _openCreateDialog() async {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final radiusController = TextEditingController(text: '150');
    double? lat, lng;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.add_business_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Text('New Branch'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Branch name',
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address (optional)',
                    prefixIcon: Icon(Icons.place_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: radiusController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Geofence radius (meters)',
                    prefixIcon: Icon(Icons.radar_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.my_location_rounded),
                    label: const Text('Use current location'),
                    onPressed: () async {
                      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
                      if (!serviceEnabled) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Turn on Location services, then try again'),
                            ),
                          );
                        }
                        return;
                      }

                      var permission = await Geolocator.checkPermission();
                      if (permission == LocationPermission.denied) {
                        permission = await Geolocator.requestPermission();
                      }
                      if (permission == LocationPermission.denied ||
                          permission == LocationPermission.deniedForever) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(permission == LocationPermission.deniedForever
                                  ? 'Enable location permission in the app settings'
                                  : 'Location permission denied'),
                            ),
                          );
                        }
                        return;
                      }

                      final pos = await Geolocator.getCurrentPosition();
                      setDialogState(() {
                        lat = pos.latitude;
                        lng = pos.longitude;
                      });
                    },
                  ),
                ),
                if (lat != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.successSoft,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Captured: ${lat!.toStringAsFixed(6)}, ${lng!.toStringAsFixed(6)}',
                              style: const TextStyle(color: AppColors.success, fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (nameController.text.isEmpty || lat == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name and location are required')),
                  );
                  return;
                }
                try {
                  await _api.createBranch(
                    name: nameController.text,
                    address: addressController.text.isEmpty ? null : addressController.text,
                    lat: lat!,
                    lng: lng!,
                    radius: int.tryParse(radiusController.text) ?? 150,
                  );
                  if (context.mounted) Navigator.pop(context);
                  _load();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to create branch')),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Branches')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Branch'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: Responsive.isDesktop(context) ? 700 : double.infinity),
                child: _branches.isEmpty
                    ? _EmptyBranches(onAdd: _openCreateDialog)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
                        itemCount: _branches.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final b = _branches[index];
                          return _BranchCard(
                            name: b['name'] ?? '',
                            address: b['address'],
                            radius: b['geofence_radius_m'],
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => BranchScheduleScreen(
                                  branchId: b['id'] as int,
                                  branchName: b['name'] ?? 'Branch',
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
    );
  }
}

class _BranchCard extends StatelessWidget {
  final String name;
  final String? address;
  final dynamic radius;
  final VoidCallback onTap;

  const _BranchCard({
    required this.name,
    required this.address,
    required this.radius,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.location_on_rounded, color: AppColors.warning, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(address ?? 'No address', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.radar_rounded, size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('${radius}m', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyBranches extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyBranches({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(color: AppColors.warningSoft, shape: BoxShape.circle),
              child: const Icon(Icons.business_rounded, size: 38, color: AppColors.warning),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('No branches yet', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Add a branch to start geofencing attendance',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Branch'),
            ),
          ],
        ),
      ),
    );
  }
}