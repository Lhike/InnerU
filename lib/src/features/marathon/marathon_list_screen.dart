import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:selfcare_projects/src/features/marathon/marathon_detail_screen.dart';
import 'package:selfcare_projects/src/features/marathon/marathon_theme.dart';
import 'package:selfcare_projects/src/services/marathon_api_service.dart';

/// Every open, upcoming and past virtual marathon the user can join.
class MarathonListScreen extends StatefulWidget {
  const MarathonListScreen({super.key, this.api, this.today});

  final MarathonApiService? api;

  /// Overridable for tests; used for "opens in N days".
  final DateTime? today;

  @override
  State<MarathonListScreen> createState() => _MarathonListScreenState();
}

class _MarathonListScreenState extends State<MarathonListScreen> {
  late Future<List<Marathon>> _future = _load();

  MarathonApiService get _api => widget.api ?? MarathonApiService.instance;

  Future<List<Marathon>> _load() => _api.fetchMarathons();

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _future = future;
    });
    try {
      await future;
    } catch (_) {
      // Shown by the FutureBuilder.
    }
  }

  Future<void> _open(Marathon marathon) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MarathonDetailScreen(
          marathonId: marathon.id,
          initial: marathon,
          api: widget.api,
          today: widget.today,
        ),
      ),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Virtual Marathons')),
      body: FutureBuilder<List<Marathon>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _Message(
              icon: Icons.cloud_off_rounded,
              text: 'Could not load marathons.',
              action: FilledButton(
                onPressed: _refresh,
                child: const Text('Retry'),
              ),
            );
          }
          final marathons = snapshot.data ?? const <Marathon>[];
          return RefreshIndicator(
            onRefresh: _refresh,
            child: marathons.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      _Message(
                        icon: Icons.directions_run_rounded,
                        text: 'No marathons yet. Check back soon!',
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: marathons.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) => MarathonCard(
                      marathon: marathons[index],
                      today: widget.today ?? DateTime.now(),
                      onTap: () => _open(marathons[index]),
                    ),
                  ),
          );
        },
      ),
    );
  }
}

class MarathonCard extends StatelessWidget {
  const MarathonCard({
    super.key,
    required this.marathon,
    required this.today,
    required this.onTap,
  });

  final Marathon marathon;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = marathon.look;
    final dates = DateFormat('MMM d');
    final status = marathonStatusLabel(marathon, today);
    final mine = myStatusLabel(marathon.myRegistration);

    return Material(
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: theme.gradient,
            ),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(theme.emoji, style: const TextStyle(fontSize: 30)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      marathon.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Tag('${formatKm(marathon.distanceKm)} km'),
                  _Tag(
                      '${dates.format(marathon.startsAt)} – ${dates.format(marathon.endsAt)}'),
                  _Tag(formatPrice(marathon)),
                  _Tag(status),
                  if (mine != null) _Tag(mine, strong: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String formatKm(double km) =>
    km == km.roundToDouble() ? km.toInt().toString() : km.toStringAsFixed(1);

String formatPrice(Marathon marathon) => marathon.isFree
    ? 'Free'
    : NumberFormat.currency(
        symbol: marathon.currency == 'PHP' ? '₱' : '${marathon.currency} ',
        decimalDigits: marathon.price == marathon.price.roundToDouble() ? 0 : 2,
      ).format(marathon.price);

/// "Opens in 5 days", "Ongoing · 3 days left" or "Ended".
String marathonStatusLabel(Marathon marathon, DateTime today) {
  final day = DateTime(today.year, today.month, today.day);
  switch (marathon.phase) {
    case MarathonPhase.upcoming:
      final days = marathon.startsAt.difference(day).inDays;
      return days <= 1 ? 'Opens tomorrow' : 'Opens in $days days';
    case MarathonPhase.ongoing:
      final left = marathon.endsAt.difference(day).inDays;
      return left <= 0 ? 'Last day!' : 'Ongoing · $left days left';
    case MarathonPhase.ended:
      return 'Ended';
  }
}

String? myStatusLabel(MyMarathonRegistration? registration) {
  if (registration == null) return null;
  if (registration.isFinisher) return '🏅 Finisher';
  return switch (registration.status) {
    MarathonRegistrationStatus.pendingPayment => 'Awaiting payment',
    MarathonRegistrationStatus.paymentSubmitted => 'Payment under review',
    MarathonRegistrationStatus.confirmed =>
      '✓ Joined · Bib ${registration.bibNumber ?? ''}',
    MarathonRegistrationStatus.rejected => 'Payment needs attention',
  };
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {this.strong = false});

  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: strong ? Colors.white : Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: strong ? Colors.black87 : Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}
