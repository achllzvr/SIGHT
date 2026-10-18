import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/server_sync_service.dart';
import '../../theme/lumi_theme.dart';
import '../../widgets/arcade/arcade.dart';
import 'child_dashboard/share_tab.dart';

class PartneredProfessionalsScreen extends StatefulWidget {
  final int? childId;
  const PartneredProfessionalsScreen({super.key, this.childId});

  @override
  State<PartneredProfessionalsScreen> createState() => _PartneredProfessionalsScreenState();
}

class _PartneredProfessionalsScreenState extends State<PartneredProfessionalsScreen> {
  bool _loading = true;
  String _mode = 'list';
  String _query = '';
  List<Map<String, dynamic>> _pros = [];
  Map<String, dynamic>? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await ServerSyncService.instance.fetchPartneredProfessionals(query: _query);
    if (!mounted) return;
    setState(() {
      _pros = result.data ?? [];
      _loading = false;
    });
  }

  Future<void> _openDirections(Map<String, dynamic> pro) async {
    final lat = (pro['latitude'] as num?)?.toDouble();
    final lng = (pro['longitude'] as num?)?.toDouble();
    final address = (pro['clinic_address'] ?? pro['clinic_name'] ?? '').toString();
    Uri uri;
    if (lat != null && lng != null) {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    } else {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openShare() {
    if (widget.childId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Open a child dashboard to generate a share code.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: LumiColors.scaffoldMint,
          appBar: AppBar(
            title: Text('Share with Doctor', style: LumiTheme.clanMedium(16, color: LumiColors.textDark)),
            backgroundColor: LumiColors.scaffoldMint,
            elevation: 0,
          ),
          body: ChildDashboardShareTab(childId: widget.childId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapPros = _pros.where((p) => p['latitude'] != null && p['longitude'] != null).toList();

    return Scaffold(
      backgroundColor: LumiColors.scaffoldMint,
      appBar: AppBar(
        title: Text('Find an Eye Doctor', style: LumiTheme.clanMedium(16, color: LumiColors.textDark)),
        backgroundColor: LumiColors.scaffoldMint,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search city or specialty',
                      filled: true,
                      fillColor: LumiColors.cardWhite,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(LumiRadii.md),
                        borderSide: const BorderSide(color: LumiColors.primaryPurple, width: 3),
                      ),
                    ),
                    onChanged: (v) => _query = v,
                    onSubmitted: (_) => _load(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.search, color: LumiColors.primaryPurple),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('List View'),
                  selected: _mode == 'list',
                  onSelected: (_) => setState(() => _mode = 'list'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Map View'),
                  selected: _mode == 'map',
                  onSelected: (_) => setState(() => _mode = 'map'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: LumiColors.primaryPurple))
                : _mode == 'list'
                    ? _buildList()
                    : _buildMap(mapPros),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_pros.isEmpty) {
      return const Center(child: Text('No partnered professionals found.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _pros.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final pro = _pros[index];
        return ArcadeCard(
          padding: const EdgeInsets.all(LumiSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pro['full_name']?.toString() ?? 'Clinician',
                  style: LumiTheme.clanMedium(16, color: LumiColors.textDark)),
              Text(
                '${pro['specialty'] ?? 'Eye care'} · ✔ LUMI Verified Partner',
                style: LumiTheme.clanRegular(12, color: LumiColors.primaryGreen),
              ),
              const SizedBox(height: 8),
              Text(pro['clinic_name']?.toString() ?? '', style: LumiTheme.clanRegular(13)),
              Text(pro['clinic_address']?.toString() ?? '', style: LumiTheme.clanRegular(13, color: LumiColors.textMuted)),
              Text(pro['operating_hours']?.toString() ?? 'Hours not listed',
                  style: LumiTheme.clanRegular(12, color: LumiColors.textMuted)),
              Text(pro['phone']?.toString() ?? '', style: LumiTheme.clanRegular(12)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => _openDirections(pro),
                    child: const Text('Get Directions'),
                  ),
                  FilledButton(
                    onPressed: _openShare,
                    child: const Text('Share Child\'s LUMI Data'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMap(List<Map<String, dynamic>> mapPros) {
    // Match web clinic picker: Philippines default when no pins yet.
    const phCenter = LatLng(14.5995, 120.9842);
    final center = mapPros.isEmpty
        ? phCenter
        : LatLng(
            (mapPros.first['latitude'] as num).toDouble(),
            (mapPros.first['longitude'] as num).toDouble(),
          );
    final zoom = mapPros.isEmpty ? 6.0 : 11.0;

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: zoom,
            onTap: (_, __) => setState(() => _selected = null),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.lumi.sight',
            ),
            MarkerLayer(
              markers: [
                for (final pro in mapPros)
                  Marker(
                    point: LatLng(
                      (pro['latitude'] as num).toDouble(),
                      (pro['longitude'] as num).toDouble(),
                    ),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => setState(() => _selected = pro),
                      child: const Icon(Icons.location_on, color: LumiColors.primaryPurple, size: 36),
                    ),
                  ),
              ],
            ),
          ],
        ),
        if (mapPros.isEmpty)
          const Align(
            alignment: Alignment.center,
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Material(
                color: Colors.white70,
                borderRadius: BorderRadius.all(Radius.circular(12)),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No professionals have map coordinates yet. Switch to List View or ask your clinician to add a clinic pin.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        if (_selected != null)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: LumiColors.cardWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: LumiColors.primaryPurple, width: 3),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_selected!['full_name']?.toString() ?? '',
                      style: LumiTheme.clanMedium(15)),
                  Text(_selected!['clinic_address']?.toString() ?? '',
                      style: LumiTheme.clanRegular(12, color: LumiColors.textMuted)),
                  Text(_selected!['operating_hours']?.toString() ?? '',
                      style: LumiTheme.clanRegular(12, color: LumiColors.textMuted)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(onPressed: () => _openDirections(_selected!), child: const Text('Directions')),
                      TextButton(onPressed: _openShare, child: const Text('Share with Doctor')),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
