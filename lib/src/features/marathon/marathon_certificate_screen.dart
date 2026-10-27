import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:selfcare_projects/src/features/marathon/marathon_list_screen.dart';
import 'package:selfcare_projects/src/features/marathon/marathon_theme.dart';
import 'package:selfcare_projects/src/services/marathon_api_service.dart';
import 'package:share_plus/share_plus.dart';

/// The finisher's virtual certificate, which they can save or share as an
/// image.
class MarathonCertificateScreen extends StatefulWidget {
  const MarathonCertificateScreen({
    super.key,
    required this.marathonId,
    this.api,
  });

  final String marathonId;
  final MarathonApiService? api;

  @override
  State<MarathonCertificateScreen> createState() =>
      _MarathonCertificateScreenState();
}

class _MarathonCertificateScreenState extends State<MarathonCertificateScreen> {
  final _boundary = GlobalKey();
  late final Future<MarathonCertificate> _future =
      (widget.api ?? MarathonApiService.instance)
          .fetchCertificate(widget.marathonId);
  bool _sharing = false;

  Future<void> _share(MarathonCertificate certificate) async {
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final boundary = _boundary.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/certificate-${certificate.number}.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        text: 'I finished the ${certificate.marathonTitle}! 🏅',
      ));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not share the certificate.')));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Virtual Certificate')),
      body: FutureBuilder<MarathonCertificate>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final certificate = snapshot.data;
          if (certificate == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Finish the marathon to unlock your certificate.',
                    textAlign: TextAlign.center),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              RepaintBoundary(
                key: _boundary,
                child: MarathonCertificateCard(certificate: certificate),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _sharing ? null : () => _share(certificate),
                icon: const Icon(Icons.ios_share_rounded),
                label: Text(_sharing ? 'Preparing...' : 'Save or share'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class MarathonCertificateCard extends StatelessWidget {
  const MarathonCertificateCard({super.key, required this.certificate});

  final MarathonCertificate certificate;

  @override
  Widget build(BuildContext context) {
    final theme = MarathonTheme.of(certificate.theme);
    final finished = certificate.finishedAt;

    return AspectRatio(
      aspectRatio: 1.414,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: theme.gradient),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          color: const Color(0xFFFFFBF2),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${theme.emoji}  🏅  ${theme.emoji}',
                      style: const TextStyle(fontSize: 26)),
                  const SizedBox(height: 6),
                  Text(
                    'CERTIFICATE OF COMPLETION',
                    style: TextStyle(
                      letterSpacing: 3,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: theme.accent,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('This certifies that',
                      style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(
                    certificate.runnerName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  Container(
                      height: 1.5,
                      width: 360,
                      color: theme.accent.withValues(alpha: 0.6)),
                  const SizedBox(height: 10),
                  Text(
                    'completed the ${formatKm(certificate.distanceKm)} km\n'
                    '${certificate.marathonTitle}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _detail(
                          'Finished',
                          finished == null
                              ? '—'
                              : DateFormat('MMMM d, y').format(finished)),
                      if (certificate.bibNumber != null)
                        _detail('Bib', '#${certificate.bibNumber}'),
                      _detail('Certificate no.', certificate.number),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _detail(String label, String value) => Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      );
}
