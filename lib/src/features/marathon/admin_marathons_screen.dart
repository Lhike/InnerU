import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:selfcare_projects/src/features/marathon/marathon_list_screen.dart';
import 'package:selfcare_projects/src/features/marathon/marathon_theme.dart';
import 'package:selfcare_projects/src/services/marathon_api_service.dart';

/// Admins create marathons and review runners' payments.
class AdminMarathonsScreen extends StatefulWidget {
  const AdminMarathonsScreen({super.key, this.api});

  final MarathonApiService? api;

  @override
  State<AdminMarathonsScreen> createState() => _AdminMarathonsScreenState();
}

class _AdminMarathonsScreenState extends State<AdminMarathonsScreen> {
  MarathonApiService get _api => widget.api ?? MarathonApiService.instance;
  late Future<List<Marathon>> _future = _api.adminFetchMarathons();

  Future<void> _refresh() async {
    final future = _api.adminFetchMarathons();
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {}
  }

  Future<void> _edit([Marathon? marathon]) async {
    final saved = await Navigator.push<Marathon>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AdminMarathonEditor(marathon: marathon, api: widget.api),
      ),
    );
    if (saved != null) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage marathons')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('New marathon'),
      ),
      body: FutureBuilder<List<Marathon>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child:
                  FilledButton(onPressed: _refresh, child: const Text('Retry')),
            );
          }
          final marathons = snapshot.data ?? const <Marathon>[];
          if (marathons.isEmpty) {
            return const Center(child: Text('No marathons yet.'));
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: marathons.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final m = marathons[index];
                final theme = MarathonTheme.of(m.theme);
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading:
                        Text(theme.emoji, style: const TextStyle(fontSize: 28)),
                    title: Text(m.title),
                    subtitle: Text(
                      '${formatKm(m.distanceKm)} km · ${formatPrice(m)} · '
                      '${DateFormat('MMM d').format(m.startsAt)} – '
                      '${DateFormat('MMM d').format(m.endsAt)}\n'
                      '${m.isPublished ? 'Published' : 'Draft'} · '
                      '${m.registrationCount} registered'
                      '${m.pendingReviewCount > 0 ? ' · ${m.pendingReviewCount} to review' : ''}',
                    ),
                    isThreeLine: true,
                    trailing: m.pendingReviewCount > 0
                        ? Badge(label: Text('${m.pendingReviewCount}'))
                        : null,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminMarathonRegistrationsScreen(
                            marathon: m,
                            api: widget.api,
                            onEdit: () => _edit(m),
                          ),
                        ),
                      );
                      _refresh();
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Create or edit a marathon.
class AdminMarathonEditor extends StatefulWidget {
  const AdminMarathonEditor({super.key, this.marathon, this.api});

  final Marathon? marathon;
  final MarathonApiService? api;

  @override
  State<AdminMarathonEditor> createState() => _AdminMarathonEditorState();
}

class _AdminMarathonEditorState extends State<AdminMarathonEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.marathon?.title);
  late final _description =
      TextEditingController(text: widget.marathon?.description);
  late final _distance = TextEditingController(
      text:
          widget.marathon == null ? '' : formatKm(widget.marathon!.distanceKm));
  late final _price = TextEditingController(
      text: widget.marathon == null
          ? ''
          : widget.marathon!.price.toStringAsFixed(0));
  late final _instructions =
      TextEditingController(text: widget.marathon?.paymentInstructions);
  late String _theme = widget.marathon?.theme ?? MarathonTheme.all.first.key;
  late DateTime? _startsAt = widget.marathon?.startsAt;
  late DateTime? _endsAt = widget.marathon?.endsAt;
  late bool _published = widget.marathon?.isPublished ?? false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _description, _distance, _price, _instructions]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(bool start) async {
    final initial =
        (start ? _startsAt : _endsAt) ?? _startsAt ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() => start ? _startsAt = picked : _endsAt = picked);
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    if (_startsAt == null || _endsAt == null) {
      setState(() => _error = 'Pick the start and end dates.');
      return;
    }
    if (_endsAt!.isBefore(_startsAt!)) {
      setState(() => _error = 'The end date must be on or after the start.');
      return;
    }

    final date = DateFormat('yyyy-MM-dd');
    setState(() => _saving = true);
    try {
      final saved =
          await (widget.api ?? MarathonApiService.instance).adminSaveMarathon(
        {
          'title': _title.text.trim(),
          'description': _description.text.trim(),
          'theme': _theme,
          'distance_km': double.parse(_distance.text.trim()),
          'price': double.parse(_price.text.trim()),
          'starts_at': date.format(_startsAt!),
          'ends_at': date.format(_endsAt!),
          'payment_instructions': _instructions.text.trim(),
          'is_published': _published,
        },
        id: widget.marathon?.id,
      );
      if (mounted) Navigator.pop(context, saved);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save the marathon.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _number(String? value, {double min = 0}) {
    final number = double.tryParse((value ?? '').trim());
    if (number == null) return 'Enter a number.';
    return number < min ? 'Must be at least ${formatKm(min)}.' : null;
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMM d, y');
    const border = OutlineInputBorder();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.marathon == null ? 'New marathon' : 'Edit marathon'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                  labelText: 'Title', hintText: 'Sunrise 10K', border: border),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter a title.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                  labelText: 'Description', border: border),
            ),
            const SizedBox(height: 16),
            const Text('Theme', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MarathonTheme.all
                  .map((t) => ChoiceChip(
                        avatar: Text(t.emoji),
                        label: Text(t.name),
                        selected: _theme == t.key,
                        selectedColor: t.gradient.first.withValues(alpha: 0.4),
                        onSelected: (_) => setState(() => _theme = t.key),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _distance,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Distance',
                        suffixText: 'km',
                        border: border),
                    validator: (v) => _number(v, min: 1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Entry fee',
                        prefixText: '₱ ',
                        helperText: '0 for free',
                        border: border),
                    validator: _number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(true),
                    icon: const Icon(Icons.event),
                    label: Text(_startsAt == null
                        ? 'Start date'
                        : 'Starts ${date.format(_startsAt!)}'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(false),
                    icon: const Icon(Icons.flag_outlined),
                    label: Text(_endsAt == null
                        ? 'End date'
                        : 'Ends ${date.format(_endsAt!)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _instructions,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Payment instructions',
                hintText: 'GCash 0917 XXX XXXX · Juan Dela Cruz',
                border: border,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _published,
              onChanged: (v) => setState(() => _published = v),
              title: const Text('Published'),
              subtitle: const Text('Visible to users so they can join.'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving...' : 'Save marathon'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Runners in one marathon, payments to review first.
class AdminMarathonRegistrationsScreen extends StatefulWidget {
  const AdminMarathonRegistrationsScreen({
    super.key,
    required this.marathon,
    this.api,
    this.onEdit,
  });

  final Marathon marathon;
  final MarathonApiService? api;
  final VoidCallback? onEdit;

  @override
  State<AdminMarathonRegistrationsScreen> createState() =>
      _AdminMarathonRegistrationsScreenState();
}

class _AdminMarathonRegistrationsScreenState
    extends State<AdminMarathonRegistrationsScreen> {
  MarathonApiService get _api => widget.api ?? MarathonApiService.instance;
  late Future<List<AdminMarathonRegistration>> _future =
      _api.adminFetchRegistrations(widget.marathon.id);

  void _refresh() => setState(
      () => _future = _api.adminFetchRegistrations(widget.marathon.id));

  Future<void> _review(AdminMarathonRegistration r, String action) async {
    String? reason;
    if (action == 'reject') {
      reason = await _askReason();
      if (reason == null || !mounted) return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _api.adminReview(r.id, action, reason: reason);
      messenger.showSnackBar(SnackBar(
        content: Text(switch (action) {
          'approve' => '${r.fullName} is confirmed.',
          'reject' => 'Payment rejected. ${r.fullName} can resend it.',
          _ => 'Marked as shipped.',
        }),
      ));
      _refresh();
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not update the registration.')));
    }
  }

  Future<String?> _askReason() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject payment'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration:
              const InputDecoration(hintText: 'e.g. Amount does not match'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.pop(context, text);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.marathon.title),
        actions: [
          if (widget.onEdit != null)
            IconButton(
              tooltip: 'Edit marathon',
              icon: const Icon(Icons.edit_outlined),
              onPressed: widget.onEdit,
            ),
        ],
      ),
      body: FutureBuilder<List<AdminMarathonRegistration>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final registrations = snapshot.data ?? const [];
          if (registrations.isEmpty) {
            return const Center(child: Text('No one has registered yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: registrations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                _registrationCard(registrations[index]),
          );
        },
      ),
    );
  }

  Widget _registrationCard(AdminMarathonRegistration r) {
    final statusText = switch (r.status) {
      MarathonRegistrationStatus.pendingPayment => 'Awaiting payment',
      MarathonRegistrationStatus.paymentSubmitted => 'To review',
      MarathonRegistrationStatus.confirmed =>
        r.finishedAt != null ? 'Finisher' : 'Confirmed · Bib ${r.bibNumber}',
      MarathonRegistrationStatus.rejected => 'Rejected',
    };

    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded:
            r.status == MarathonRegistrationStatus.paymentSubmitted,
        title: Text(r.fullName),
        subtitle: Text(statusText),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${r.email} · ${r.phone}'),
          Text('Shirt: ${r.shirtSize}'),
          Text('Ship to: ${r.shippingAddress}'),
          if (r.paymentReference != null)
            Text('Reference: ${r.paymentReference}'),
          if (r.rejectionReason != null) Text('Rejected: ${r.rejectionReason}'),
          if (r.paymentProofUrl != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                r.paymentProofUrl!,
                height: 220,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Text('Could not load the receipt image.'),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              if (r.status == MarathonRegistrationStatus.paymentSubmitted) ...[
                FilledButton(
                  onPressed: () => _review(r, 'approve'),
                  child: const Text('Approve'),
                ),
                OutlinedButton(
                  onPressed: () => _review(r, 'reject'),
                  child: const Text('Reject'),
                ),
              ],
              if (r.finishedAt != null && r.rewardsShippedAt == null)
                FilledButton.icon(
                  onPressed: () => _review(r, 'mark_shipped'),
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('Mark shirt & medal shipped'),
                ),
              if (r.rewardsShippedAt != null)
                const Chip(label: Text('📦 Rewards shipped')),
            ],
          ),
        ],
      ),
    );
  }
}
