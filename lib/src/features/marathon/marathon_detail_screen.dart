import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:selfcare_projects/src/features/authentication/screen/step_tracker.dart/walker_avatar.dart';
import 'package:selfcare_projects/src/features/marathon/marathon_certificate_screen.dart';
import 'package:selfcare_projects/src/features/marathon/marathon_kit.dart';
import 'package:selfcare_projects/src/features/marathon/marathon_list_screen.dart';
import 'package:selfcare_projects/src/features/marathon/marathon_payment_screen.dart';
import 'package:selfcare_projects/src/features/marathon/marathon_registration_screen.dart';
import 'package:selfcare_projects/src/features/marathon/marathon_theme.dart';
import 'package:selfcare_projects/src/services/marathon_api_service.dart';

/// A marathon's themed page: details, joining, payment status, progress,
/// the finisher rewards guide and the virtual certificate.
class MarathonDetailScreen extends StatefulWidget {
  const MarathonDetailScreen({
    super.key,
    required this.marathonId,
    this.initial,
    this.api,
    this.today,
    this.kitSaver,
  });

  final String marathonId;
  final Marathon? initial;
  final MarathonApiService? api;
  final DateTime? today;

  /// Overridable for tests; defaults to saving the walker through the API.
  final Future<void> Function(Map<String, dynamic> look)? kitSaver;

  @override
  State<MarathonDetailScreen> createState() => _MarathonDetailScreenState();
}

class _MarathonDetailScreenState extends State<MarathonDetailScreen>
    with SingleTickerProviderStateMixin {
  Marathon? _marathon;
  Object? _error;
  WalkerLook _look = const WalkerLook();
  bool _wearingKit = false;
  bool _savingKit = false;

  late final AnimationController _stride = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  MarathonApiService get _api => widget.api ?? MarathonApiService.instance;
  DateTime get _today => widget.today ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _marathon = widget.initial;
    _refresh();
    _loadLook();
  }

  @override
  void dispose() {
    _stride.dispose();
    super.dispose();
  }

  Future<void> _loadLook() async {
    final look = await MarathonKit.loadLook();
    if (mounted) setState(() => _look = look);
  }

  Future<void> _refresh() async {
    try {
      final marathon = await _api.fetchMarathon(widget.marathonId);
      if (mounted) setState(() => (_marathon = marathon, _error = null));
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _join() async {
    final marathon = _marathon!;
    final updated = await Navigator.push<Marathon>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MarathonRegistrationScreen(marathon: marathon, api: widget.api),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() => _marathon = updated);
    if (updated.myRegistration?.status ==
        MarathonRegistrationStatus.pendingPayment) {
      await _pay();
    }
  }

  Future<void> _pay() async {
    final updated = await Navigator.push<Marathon>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MarathonPaymentScreen(marathon: _marathon!, api: widget.api),
      ),
    );
    if (updated != null && mounted) setState(() => _marathon = updated);
  }

  Future<void> _wearKit(MarathonTheme theme, int bib) async {
    setState(() => _savingKit = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final look = await MarathonKit.wear(theme, bib, saver: widget.kitSaver);
      if (!mounted) return;
      setState(() => (_look = look, _wearingKit = true));
      messenger.showSnackBar(SnackBar(
        content: Text(
            'Your walker is wearing the ${theme.name} kit with bib #$bib.'),
      ));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not put on the kit. Try again.'),
      ));
    } finally {
      if (mounted) setState(() => _savingKit = false);
    }
  }

  void _openCertificate() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MarathonCertificateScreen(
          marathonId: widget.marathonId,
          api: widget.api,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final marathon = _marathon;
    if (marathon == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : FilledButton(onPressed: _refresh, child: const Text('Retry')),
        ),
      );
    }

    final theme = marathon.look;
    final registration = marathon.myRegistration;
    final bib =
        registration?.isConfirmed == true ? registration!.bibNumber : null;
    final preview = bib != null
        ? (_wearingKit || _look.kit == theme.key
            ? _look
            : theme.dress(_look, bib))
        : theme.dress(_look, 0).copyWith(takeOffKit: true);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 280,
              foregroundColor: Colors.white,
              backgroundColor: theme.gradient.last,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(marathon.title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                background: _Hero(
                  theme: theme,
                  look: preview,
                  stride: _stride,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              sliver: SliverList.list(
                children: [
                  _FactsRow(marathon: marathon, today: _today),
                  if ((marathon.description ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(marathon.description!.trim()),
                  ],
                  if (marathon.kitImageUrl != null) ...[
                    const SizedBox(height: 16),
                    _KitPicture(theme: theme, url: marathon.kitImageUrl!),
                  ],
                  const SizedBox(height: 16),
                  _buildStatusCard(marathon, theme),
                  const SizedBox(height: 16),
                  _HowItWorks(theme: theme),
                  const SizedBox(height: 16),
                  _FinisherGuide(theme: theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(Marathon marathon, MarathonTheme theme) {
    final registration = marathon.myRegistration;
    final dateFormat = DateFormat('EEE, MMM d, y');

    if (registration == null) {
      if (marathon.phase == MarathonPhase.ended) {
        return const _Card(child: Text('This marathon has ended.'));
      }
      if (marathon.registrationWindow != MarathonRegistrationWindow.open) {
        final opens = marathon.registrationOpensAt;
        return _Card(
          child: Row(
            children: [
              const Icon(Icons.event_busy_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  marathon.registrationWindow ==
                              MarathonRegistrationWindow.notYet &&
                          opens != null
                      ? 'Registration opens on ${dateFormat.format(opens)}. '
                          'Come back then to join!'
                      : 'Registration for this marathon is closed.',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );
      }
      final closes = marathon.registrationClosesAt;
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              marathon.isFree
                  ? 'Free to join'
                  : 'Entry fee: ${formatPrice(marathon)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text('Includes your finisher shirt, medal and certificate.'),
            if (closes != null) ...[
              const SizedBox(height: 4),
              Text('Register by ${dateFormat.format(closes)}.',
                  style: const TextStyle(fontSize: 12)),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: theme.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _join,
              icon: const Icon(Icons.directions_run_rounded),
              label: const Text('Join this marathon'),
            ),
          ],
        ),
      );
    }

    switch (registration.status) {
      case MarathonRegistrationStatus.pendingPayment:
      case MarathonRegistrationStatus.rejected:
        return _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                registration.status == MarathonRegistrationStatus.rejected
                    ? 'Your payment was not approved'
                    : "You're registered! Complete your payment",
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              if (registration.rejectionReason != null) ...[
                const SizedBox(height: 6),
                Text('Reason: ${registration.rejectionReason}',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 6),
              Text('Pay ${formatPrice(marathon)} and send us the receipt. '
                  "We'll confirm your slot and give you a bib number."),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: theme.accent),
                onPressed: _pay,
                icon: const Icon(Icons.payments_rounded),
                label: Text(
                    registration.status == MarathonRegistrationStatus.rejected
                        ? 'Send payment again'
                        : 'Pay now'),
              ),
            ],
          ),
        );
      case MarathonRegistrationStatus.paymentSubmitted:
        return const _Card(
          child: Row(
            children: [
              Icon(Icons.hourglass_top_rounded),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Payment under review. We'll confirm your slot and bib "
                  'number soon.',
                ),
              ),
            ],
          ),
        );
      case MarathonRegistrationStatus.confirmed:
        return _buildConfirmedCard(marathon, registration, theme, dateFormat);
    }
  }

  Widget _buildConfirmedCard(
    Marathon marathon,
    MyMarathonRegistration registration,
    MarathonTheme theme,
    DateFormat dateFormat,
  ) {
    final progress = registration.progress;
    final bib = registration.bibNumber;
    final wearing = _wearingKit || (_look.kit == theme.key && _look.bib == bib);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  registration.isFinisher ? '🏅 You finished!' : "✓ You're in!",
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ),
              if (bib != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black26),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('BIB #$bib',
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (marathon.phase == MarathonPhase.upcoming)
            Text(
              'The race opens on ${dateFormat.format(marathon.startsAt)} '
              '(${marathonStatusLabel(marathon, _today).toLowerCase()}). '
              'Every step from that day counts automatically.',
            )
          else ...[
            Text(
              '${progress.km.toStringAsFixed(2)} of '
              '${formatKm(marathon.distanceKm)} km',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (progress.percent / 100).clamp(0.0, 1.0),
                minHeight: 12,
                color: theme.accent,
                backgroundColor: theme.accent.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${NumberFormat.decimalPattern().format(progress.steps)} steps'
              '${marathon.phase == MarathonPhase.ongoing && !registration.isFinisher ? ' · ends ${dateFormat.format(marathon.endsAt)}' : ''}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
          if (bib != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed:
                  wearing || _savingKit ? null : () => _wearKit(theme, bib),
              icon: Text(theme.emoji),
              label: Text(wearing
                  ? 'Your walker is wearing the ${theme.name} kit'
                  : 'Wear the ${theme.name} kit in the steps race'),
            ),
          ],
          if (registration.isFinisher) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: theme.accent),
              onPressed: _openCertificate,
              icon: const Icon(Icons.workspace_premium_rounded),
              label: const Text('View virtual certificate'),
            ),
            const SizedBox(height: 8),
            Text(
              registration.rewardsShippedAt == null
                  ? 'Your finisher shirt, medal and printed certificate will be '
                      'shipped to your address.'
                  : '📦 Your finisher shirt, medal and certificate have been shipped!',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.theme, required this.look, required this.stride});

  final MarathonTheme theme;
  final WalkerLook look;
  final Animation<double> stride;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.gradient,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 20,
            top: 84,
            child: Text(theme.emoji, style: const TextStyle(fontSize: 56)),
          ),
          // On the right so the title (bottom-left) never covers it.
          Positioned(
            right: 20,
            bottom: 40,
            width: 150,
            height: 190,
            child: AnimatedBuilder(
              animation: stride,
              builder: (context, _) => WalkerAvatar(
                key: const ValueKey('marathon-walker'),
                look: look,
                phase: stride.value,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FactsRow extends StatelessWidget {
  const _FactsRow({required this.marathon, required this.today});

  final Marathon marathon;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final dates = DateFormat('MMM d');
    Widget fact(IconData icon, String value, String label) => Expanded(
          child: Column(
            children: [
              Icon(icon),
              const SizedBox(height: 4),
              Text(value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        fact(Icons.straighten_rounded, '${formatKm(marathon.distanceKm)} km',
            'Distance'),
        fact(
            Icons.event_rounded,
            '${dates.format(marathon.startsAt)} – ${dates.format(marathon.endsAt)}',
            marathonStatusLabel(marathon, today)),
        fact(Icons.confirmation_number_outlined, formatPrice(marathon),
            'Entry fee'),
      ],
    );
  }
}

/// The AI-drawn picture of this marathon's kit.
class _KitPicture extends StatelessWidget {
  const _KitPicture({required this.theme, required this.url});

  final MarathonTheme theme;
  final String url;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${theme.emoji} The ${theme.name} kit',
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('Your walker wears it in the race once you are in.',
              style: TextStyle(fontSize: 12)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 1,
              child: Image.network(
                url,
                key: const ValueKey('marathon-kit-image'),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: theme.accent.withValues(alpha: 0.1),
                  child: const Center(child: Icon(Icons.image_not_supported)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.theme});

  final MarathonTheme theme;

  @override
  Widget build(BuildContext context) {
    const steps = [
      ('📝', 'Join', 'Fill in the registration form.'),
      ('💳', 'Pay', 'Send your payment receipt for review.'),
      ('🎽', 'Get your bib', 'Once confirmed you get a bib number and kit.'),
      ('🚶', 'Walk', 'From the start date, every step you track counts.'),
      ('🏁', 'Finish', 'Reach the distance before the end date.'),
    ];
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How it works',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          for (final (emoji, title, text) in steps)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(TextSpan(children: [
                      TextSpan(
                          text: '$title  ',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(text: text),
                    ])),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// What every finisher receives.
class _FinisherGuide extends StatelessWidget {
  const _FinisherGuide({required this.theme});

  final MarathonTheme theme;

  @override
  Widget build(BuildContext context) {
    const rewards = [
      ('👕', 'Finisher shirt'),
      ('🏅', 'Medal'),
      ('📜', 'Printed certificate'),
      ('💻', 'Virtual certificate'),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: theme.gradient.map((c) => c.withValues(alpha: 0.14)).toList(),
        ),
        border: Border.all(color: theme.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('When you finish your marathon',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          const Text(
            'you will receive your finisher shirt, medal and certificate, '
            'shipped to the address in your registration. You also get a '
            'virtual certificate right away that you can save and share.',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final (emoji, label) in rewards)
                Expanded(
                  child: Column(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 4),
                      Text(label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}
