import 'package:flutter/material.dart';
import 'package:windoor_core/windoor_core.dart';

import '../models/catalog.dart';
import '../models/project.dart';
import '../services/api_service.dart';
import '../services/design_api.dart';
import '../utils/format.dart';

/// Teknik özellikler: pencerelerin tasarımı + katalog snapshot'tan üretilir.
class ProjectSpecsScreen extends StatefulWidget {
  final int projectId;
  const ProjectSpecsScreen({super.key, required this.projectId});

  @override
  State<ProjectSpecsScreen> createState() => _ProjectSpecsScreenState();
}

class _ProjectSpecsScreenState extends State<ProjectSpecsScreen> {
  final _api = ApiService();
  final _designApi = DesignApi();

  bool _loading = true;
  String? _error;
  String _projectName = '';
  int _windowCount = 0;
  double _totalAreaM2 = 0;
  final Map<String, int> _seriesCounts = {};
  final Map<String, double> _profileMeters = {};
  final Map<String, double> _glassArea = {}; // key: "name · code"
  final Map<String, int> _hardwareCounts = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final project = await _api.getProject(widget.projectId);
      final catalog = await _designApi.catalog();
      if (project == null) {
        setState(() {
          _error = 'Proje bulunamadı.';
          _loading = false;
        });
        return;
      }
      _compute(project, catalog);
      if (!mounted) return;
      setState(() {
        _projectName = project.name;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiError.from(e).toString();
        _loading = false;
      });
    }
  }

  void _compute(Project project, CatalogSnapshot catalog) {
    _windowCount = 0;
    _totalAreaM2 = 0;
    _seriesCounts.clear();
    _profileMeters.clear();
    _glassArea.clear();
    _hardwareCounts.clear();

    for (final u in project.windowUnits) {
      final qty = u.quantity;
      _windowCount += qty;
      _totalAreaM2 += u.width * u.height * qty / 1e6;
      final design = u.previewDesign;
      final series = catalog.seriesFor(u.seriesId ?? design.seriesId);
      _seriesCounts[series.name] = (_seriesCounts[series.name] ?? 0) + qty;

      final layout = LayoutEngine(series.geometry).run(design);
      final bom = BomLine.aggregate(layout.bom);

      for (final l in bom) {
        if (l.group == BomGroup.profile && l.length != null) {
          final role = profileRoleTr(_roleKey(l.role));
          _profileMeters[role] = (_profileMeters[role] ?? 0) + l.length! * l.qty * qty / 1000;
        } else if (l.group == BomGroup.glass || l.group == BomGroup.panel) {
          final info = catalog.glassByCode(l.glassCode ?? '');
          final label = info != null
              ? '${info.name} · ${info.code}'
              : (l.glassCode?.isNotEmpty == true ? l.glassCode! : (l.group == BomGroup.panel ? 'Panel' : 'Cam'));
          final area = (l.w ?? 0) * (l.h ?? 0) * l.qty * qty / 1e6;
          _glassArea[label] = (_glassArea[label] ?? 0) + area;
        } else if (l.group == BomGroup.hardware) {
          final kind = hardwareKindTr(l.kind);
          _hardwareCounts[kind] = (_hardwareCounts[kind] ?? 0) + l.qty * qty;
        }
      }
    }
  }

  String _roleKey(ProfileRole? r) => switch (r) {
        ProfileRole.frame => 'FRAME',
        ProfileRole.sash => 'SASH',
        ProfileRole.mullion => 'MULLION',
        ProfileRole.slideSash => 'SLIDE_SASH',
        ProfileRole.adapter => 'ADAPTER',
        ProfileRole.doorSash => 'DOOR_SASH',
        ProfileRole.threshold => 'THRESHOLD',
        ProfileRole.coupling => 'COUPLING',
        null => '',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teknik Özellikler')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('Tekrar dene')),
                    ]),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(children: [
                          Text(_projectName,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                          const Divider(),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                            _stat(Icons.window, '$_windowCount', 'Pencere'),
                            _stat(Icons.square_foot, formatQty(_totalAreaM2, 'm²'), 'Toplam alan'),
                          ]),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _section('Kullanılan seriler', [
                      for (final e in _seriesCounts.entries) '${e.key} · ${e.value} pencere',
                    ], Icons.view_week),
                    const SizedBox(height: 16),
                    _section('Profiller', [
                      for (final e in _profileMeters.entries) '${e.key}: ${formatQty(e.value, 'm')}',
                    ], Icons.straighten),
                    const SizedBox(height: 16),
                    _section('Camlar / paneller', [
                      for (final e in _glassArea.entries) '${e.key}: ${formatQty(e.value, 'm²')}',
                    ], Icons.grid_view),
                    const SizedBox(height: 16),
                    _section('Donanım', [
                      for (final e in _hardwareCounts.entries) '${e.key}: ${e.value} kanat',
                    ], Icons.build_outlined),
                  ],
                ),
    );
  }

  Widget _stat(IconData icon, String value, String label) => Column(children: [
        Icon(icon, size: 30, color: Colors.blueGrey),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ]);

  Widget _section(String title, List<String> items, IconData icon) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 8),
        child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      Card(
        child: items.isEmpty
            ? const Padding(padding: EdgeInsets.all(16), child: Text('Veri yok.'))
            : Column(
                children: [
                  for (final item in items)
                    ListTile(dense: true, leading: Icon(icon, color: Colors.orangeAccent), title: Text(item)),
                ],
              ),
      ),
    ]);
  }
}
