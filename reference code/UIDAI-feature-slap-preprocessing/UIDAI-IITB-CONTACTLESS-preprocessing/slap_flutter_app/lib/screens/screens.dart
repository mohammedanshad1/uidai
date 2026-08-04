import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

// Shared UI helpers used by the slap visualizer.

Widget ysShimmer({double height = 80, double? width, double radius = 14}) =>
    Shimmer.fromColors(
      baseColor: YS.stroke,
      highlightColor: YS.cardAlt,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: YS.card,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );

Widget ysOfflineCard(VoidCallback onRetry) => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: YS.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: YS.stroke),
      ),
      child: Column(children: [
        const Icon(Icons.wifi_off_rounded, size: 40, color: YS.inkLight),
        const SizedBox(height: 12),
        Text('Cannot reach server',
            style: YS.label(14, color: YS.inkMid, w: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Tap the server icon (top-right) to set the URL',
            style: YS.label(12, color: YS.inkLight), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ),
      ]),
    );

// ══════════════════════════════════════════════════════════════════════════════
// SETTINGS — only the server URL (multi-finger pipeline host)
// ══════════════════════════════════════════════════════════════════════════════

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _urlCtrl =
      TextEditingController(text: ApiService.baseUrl);
  bool _checking = false;
  Map<String, dynamic>? _health;

  Future<void> _save() async {
    await ApiService.setBaseUrl(_urlCtrl.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Saved', style: YS.label(13)),
          backgroundColor: YS.green));
    }
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _health = null;
    });
    try {
      final h = await ApiService.healthCheck();
      setState(() {
        _health = h;
        _checking = false;
      });
    } catch (e) {
      setState(() {
        _health = {'error': e.toString()};
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: YS.bg,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go('/')),
        title: Text('Server', style: YS.label(17, w: FontWeight.w700)),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: YS.stroke)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('PIPELINE SERVER',
              style: YS.label(11, color: YS.inkLight, w: FontWeight.w700)
                  .copyWith(letterSpacing: 1.8)),
          const SizedBox(height: 12),
          TextField(
              controller: _urlCtrl,
              style: YS.label(14),
              decoration: InputDecoration(
                  labelText: 'Slap Server URL',
                  hintText: 'http://192.168.x.x:5010',
                  prefixIcon:
                      Icon(Icons.dns_outlined, color: YS.inkLight, size: 18))),
          const SizedBox(height: 8),
          Text('Physical device: http://<PC-IP>:5010\nEmulator: http://10.0.2.2:5010',
              style: YS.label(11, color: YS.inkLight)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: ElevatedButton(
                    onPressed: _save, child: const Text('Save URL'))),
            const SizedBox(width: 12),
            Expanded(
                child: OutlinedButton(
              onPressed: _checking ? null : _check,
              child: _checking
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: YS.amber, strokeWidth: 2))
                  : const Text('Check Health'),
            )),
          ]),
          if (_health != null) ...[const SizedBox(height: 16), _healthCard(_health!)],
        ]),
      ),
    );
  }

  Widget _healthCard(Map<String, dynamic> h) {
    final ok = h['status'] == 'ok';
    final color = ok ? YS.green : YS.red;
    final bg = ok ? YS.greenBg : YS.redBg;
    final models = (h['models_loaded'] as List?)?.join(', ') ?? '—';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded,
              color: color, size: 18),
          const SizedBox(width: 8),
          Text(ok ? 'Server Online' : 'Unreachable',
              style: YS.label(14, color: color, w: FontWeight.w700)),
        ]),
        if (h['error'] != null) ...[
          const SizedBox(height: 8),
          Text(h['error'], style: YS.label(11, color: YS.inkMid))
        ],
        if (ok) ...[
          const SizedBox(height: 10),
          Text('Device: ${h['device'] ?? '—'}',
              style: YS.label(12, w: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Models: $models', style: YS.label(11, color: YS.inkMid)),
        ],
      ]),
    );
  }
}
