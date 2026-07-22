import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/responsive.dart';

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
    bool useCurrentLocation = true;
    double? lat, lng;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Branch'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Branch name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Address (optional)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: radiusController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Geofence radius (meters)'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.my_location),
                        label: const Text('Use current location'),
                        onPressed: () async {
                          final permission = await Geolocator.requestPermission();
                          if (permission == LocationPermission.denied) return;
                          final pos = await Geolocator.getCurrentPosition();
                          setDialogState(() {
                            lat = pos.latitude;
                            lng = pos.longitude;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                if (lat != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Captured: ${lat!.toStringAsFixed(6)}, ${lng!.toStringAsFixed(6)}'),
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
      appBar: AppBar(
        title: const Text('Branches'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _openCreateDialog),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: Responsive.isDesktop(context) ? 700 : double.infinity),
                child: _branches.isEmpty
                    ? const Center(child: Text('No branches yet — tap + to add one'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _branches.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final b = _branches[index];
                          return ListTile(
                            leading: const Icon(Icons.location_on_outlined),
                            title: Text(b['name'] ?? ''),
                            subtitle: Text(
                                '${b['address'] ?? 'No address'} • ${b['geofence_radius_m']}m radius'),
                          );
                        },
                      ),
              ),
            ),
    );
  }
}