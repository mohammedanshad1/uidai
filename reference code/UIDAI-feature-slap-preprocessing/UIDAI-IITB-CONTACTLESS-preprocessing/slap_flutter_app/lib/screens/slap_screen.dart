import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/fingerprint_camera_widget.dart';
import '../services/api_service.dart';
import 'screens.dart';

/// Slap visualizer: capture all fingers, then for EACH finger show the three
/// pipeline stages — cropped capture → preprocessed → minutiae overlay.
/// No enrol / authenticate / verify / matching.
class SlapScreen extends StatefulWidget {
  const SlapScreen({super.key});
  @override
  State<SlapScreen> createState() => _SlapScreenState();
}

class _SlapScreenState extends State<SlapScreen> {
  String _handSide = 'right';
  bool _loading = false;
  Map<String, dynamic>? _result;

  Future<void> _onCapture(File image) async {
    setState(() {
      _loading = true;
      _result = null;
    });
    try {
      final r = await ApiService.processSlap(image: image, handSide: _handSide);
      setState(() {
        _result = r;
        _loading = false;
      });
      HapticFeedback.mediumImpact();
    } catch (e) {
      setState(() {
        _result = {'error': e.toString(), 'offline': true};
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fingers = (_result?['fingers'] as List?)?.cast<Map>() ?? [];
    final count = _result?['finger_count'] ?? 0;
    final totalMinutiae =
        fingers.fold<int>(0, (s, f) => s + ((f['minutiae_count'] ?? 0) as int));

    return Scaffold(
      backgroundColor: YS.bg,
      appBar: AppBar(
        title: Text('Slap Visualizer', style: YS.label(17, w: FontWeight.w700)),
        actions: [
          IconButton(
              icon: const Icon(Icons.dns_outlined),
              tooltip: 'Server URL',
              onPressed: () => context.go('/settings')),
        ],
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: YS.stroke)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: YS.blueBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: YS.blue.withValues(alpha: 0.3))),
            child: Row(children: [
              const Icon(Icons.back_hand_outlined, color: YS.blue, size: 16),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                      'Present all four fingers. Each detected finger is shown '
                      'through capture → preprocess → minutiae extraction.',
                      style: YS.label(12, color: YS.blue))),
            ]),
          ),
          const SizedBox(height: 18),

          Text('HAND',
              style: YS.label(11, color: YS.inkLight, w: FontWeight.w700)
                  .copyWith(letterSpacing: 1.8)),
          const SizedBox(height: 8),
          Row(children: [
            _handChip('right', 'Right hand'),
            const SizedBox(width: 10),
            _handChip('left', 'Left hand'),
          ]),
          const SizedBox(height: 18),

          Text('CAPTURE',
              style: YS.label(11, color: YS.inkLight, w: FontWeight.w700)
                  .copyWith(letterSpacing: 1.8)),
          const SizedBox(height: 10),
          FingerprintCameraWidget(
              onImageCaptured: _onCapture,
              disabled: _loading,
              overlayStyle: 'none',
              handSide: _handSide),

          const SizedBox(height: 20),
          if (_loading) ...[
            ysShimmer(height: 60),
            const SizedBox(height: 8),
            ysShimmer(height: 200),
          ],

          if (!_loading && _result != null) ...[
            if (_result!['offline'] == true || _result!['error'] != null)
              ysOfflineCard(() => setState(() => _result = null))
            else if (count == 0)
              _banner('No fingers detected', YS.red,
                  'Move closer and present your fingers to the camera.')
            else ...[
              _summary(count, totalMinutiae),
              const SizedBox(height: 14),
              if (_result!['composite_b64'] is String) ...[
                _compositeCard(_result!['composite_b64'] as String),
                const SizedBox(height: 14),
              ],
              ...fingers.map(_fingerCard),
            ],
          ],
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _summary(int count, int totalMinutiae) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: YS.amberSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: YS.amber.withValues(alpha: 0.4))),
        child: Row(children: [
          const Icon(Icons.fingerprint_rounded, color: YS.amberDeep, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$count fingers detected',
                  style: YS.display(16, color: YS.amberDeep, w: FontWeight.w800)),
              Text('$totalMinutiae minutiae extracted total',
                  style: YS.label(12, color: YS.amberDeep)),
            ]),
          ),
        ]),
      );

  Widget _compositeCard(String b64) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: YS.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: YS.stroke),
            boxShadow: YS.cardShadow),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.grid_view_rounded, color: YS.amberDeep, size: 18),
            const SizedBox(width: 8),
            Text('PREPROCESSED SLAP (ALL FINGERS)',
                style: YS.label(11, w: FontWeight.w800)
                    .copyWith(letterSpacing: 0.6)),
          ]),
          const SizedBox(height: 4),
          Text('Each finger preprocessed and placed at its captured position',
              style: YS.label(11, color: YS.inkLight)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              color: Colors.white,
              child: Image.memory(base64Decode(b64),
                  fit: BoxFit.contain, gaplessPlayback: true),
            ),
          ),
        ]),
      );

  Widget _fingerCard(Map f) {
    final pos = (f['finger_position'] ?? '—').toString().replaceAll('_', ' ');
    final conf = ((f['detection_conf'] ?? 0) as num) * 100;
    final minutiae = f['minutiae_count'] ?? 0;
    final live = (f['liveness'] as Map?)?['is_live'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: YS.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: YS.stroke),
          boxShadow: YS.cardShadow),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(pos.toUpperCase(),
                  style: YS.label(14, w: FontWeight.w800))),
          _pill('${conf.toStringAsFixed(0)}%', YS.inkMid),
          const SizedBox(width: 6),
          _pill('$minutiae min', YS.amberDeep, bg: YS.amberSoft),
          const SizedBox(width: 6),
          _pill(live ? 'LIVE' : 'SPOOF', live ? YS.green : YS.red,
              bg: live ? YS.greenBg : YS.redBg),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _stage('Capture', f['cropped_b64']),
          const SizedBox(width: 8),
          _stage('Preprocess', f['preprocessed_b64']),
          const SizedBox(width: 8),
          _stage('Minutiae', f['visualization_b64']),
        ]),
      ]),
    );
  }

  Widget _stage(String label, dynamic b64) {
    Widget img;
    if (b64 is String && b64.isNotEmpty) {
      img = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio: 1,
          child: Image.memory(base64Decode(b64), fit: BoxFit.cover,
              gaplessPlayback: true),
        ),
      );
    } else {
      img = AspectRatio(
          aspectRatio: 1,
          child: Container(
              decoration: BoxDecoration(
                  color: YS.cardAlt, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.image_not_supported_outlined,
                  color: YS.inkFaint)));
    }
    return Expanded(
      child: Column(children: [
        img,
        const SizedBox(height: 6),
        Text(label, style: YS.label(10, color: YS.inkLight, w: FontWeight.w600)),
      ]),
    );
  }

  Widget _pill(String text, Color color, {Color? bg}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: bg ?? YS.cardAlt, borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: YS.label(10, color: color, w: FontWeight.w700)),
      );

  Widget _banner(String title, Color color, String sub) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: YS.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.error_outline_rounded, color: color, size: 20),
            const SizedBox(width: 8),
            Text(title, style: YS.display(15, color: color, w: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          Text(sub, style: YS.label(12, color: YS.inkMid)),
        ]),
      );

  Widget _handChip(String value, String label) {
    final sel = _handSide == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _handSide = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: sel ? YS.amberSoft : YS.cardAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? YS.amber : YS.stroke),
          ),
          child: Center(
              child: Text(label,
                  style: YS.label(13,
                      color: sel ? YS.amberDeep : YS.inkMid,
                      w: FontWeight.w700))),
        ),
      ),
    );
  }
}
