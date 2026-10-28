import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:selfcare_projects/src/features/authentication/screen/step_tracker.dart/walker_avatar.dart';
import 'package:selfcare_projects/src/features/marathon/marathon_list_screen.dart';
import 'package:selfcare_projects/src/features/marathon/marathon_payment_screen.dart';
import 'package:selfcare_projects/src/features/marathon/marathon_theme.dart';
import 'package:selfcare_projects/src/services/api_client.dart';
import 'package:selfcare_projects/src/services/image_storage_service.dart';
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
    setState(() {
      _future = future;
    });
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

  Future<void> _delete(Marathon marathon) async {
    final registered = marathon.registrationCount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete marathon?'),
        content: Text(
          '"${marathon.title}" will be removed for everyone'
          '${registered > 0 ? ', including $registered registration${registered == 1 ? '' : 's'}' : ''}. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm-delete-marathon'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _api.adminDeleteMarathon(marathon.id);
      messenger.showSnackBar(
          SnackBar(content: Text('Deleted "${marathon.title}".')));
      _refresh();
    } catch (error) {
      messenger
          .showSnackBar(SnackBar(content: Text('Could not delete: $error')));
    }
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
                final theme = m.look;
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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (m.pendingReviewCount > 0)
                          Badge(label: Text('${m.pendingReviewCount}')),
                        IconButton(
                          key: ValueKey('delete-marathon-${m.id}'),
                          tooltip: 'Delete marathon',
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () => _delete(m),
                        ),
                      ],
                    ),
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
  const AdminMarathonEditor({
    super.key,
    this.marathon,
    this.api,
    this.pickQr,
    this.uploadQr,
  });

  final Marathon? marathon;
  final MarathonApiService? api;

  /// Overridable for tests.
  final ReceiptPicker? pickQr;
  final ReceiptUploader? uploadQr;

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
  late final _idea = TextEditingController(
      text: widget.marathon?.themeData?['prompt']?.toString());
  late String _theme = widget.marathon?.theme ?? MarathonTheme.all.first.key;
  late Map<String, dynamic>? _themeData = widget.marathon?.themeData;
  late String? _kitImageUrl = widget.marathon?.kitImageUrl;
  late DateTime? _startsAt = widget.marathon?.startsAt;
  late DateTime? _endsAt = widget.marathon?.endsAt;
  late DateTime? _registrationOpensAt = widget.marathon?.registrationOpensAt;
  // The backend reports the race's end when no closing date was set.
  late DateTime? _registrationClosesAt = widget.marathon == null ||
          widget.marathon!.registrationClosesAt == widget.marathon!.endsAt
      ? null
      : widget.marathon!.registrationClosesAt;
  late String? _qrUrl = widget.marathon?.paymentQrUrl;
  late bool _published = widget.marathon?.isPublished ?? false;
  bool _drawKit = false;
  bool _generating = false;
  bool _drawing = false;
  bool _uploadingQr = false;
  bool _saving = false;
  String? _aiError;
  String? _error;

  MarathonApiService get _api => widget.api ?? MarathonApiService.instance;
  bool get _custom => _theme == MarathonTheme.customKey && _themeData != null;

  @override
  void dispose() {
    for (final c in [
      _title,
      _description,
      _distance,
      _price,
      _instructions,
      _idea,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _messageOf(Object error, String fallback) => switch (error) {
        ApiException(:final message) when message.trim().isNotEmpty => message,
        ApiTimeoutException() => 'This is taking too long. Try again.',
        _ => fallback,
      };

  Future<void> _generate() async {
    final idea = _idea.text.trim();
    if (idea.length < 2) {
      setState(() => _aiError = 'Type an idea first, e.g. "under the sea".');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => (_generating = true, _aiError = null));
    try {
      final data = await _api.adminSuggestTheme(idea);
      if (!mounted) return;
      setState(() {
        _themeData = data;
        _theme = MarathonTheme.customKey;
        _kitImageUrl = null;
        final tagline = data['tagline']?.toString().trim() ?? '';
        if (_description.text.trim().isEmpty && tagline.isNotEmpty) {
          _description.text = tagline;
        }
      });
      if (_drawKit) await _drawKitPicture();
    } catch (error) {
      if (mounted) {
        setState(() =>
            _aiError = _messageOf(error, 'Could not reach the AI. Try again.'));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _drawKitPicture() async {
    final data = _themeData;
    if (data == null) return;
    setState(() => (_drawing = true, _aiError = null));
    try {
      final url = await _api.adminDrawKit(
          _idea.text.trim().isEmpty
              ? (data['name']?.toString() ?? 'marathon')
              : _idea.text.trim(),
          data);
      if (mounted) setState(() => _kitImageUrl = url);
    } catch (error) {
      if (mounted) {
        setState(() =>
            _aiError = _messageOf(error, 'Could not draw the kit. Try again.'));
      }
    } finally {
      if (mounted) setState(() => _drawing = false);
    }
  }

  Future<Uint8List?> _defaultPickQr() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1400,
    );
    return image?.readAsBytes();
  }

  Future<void> _uploadQr() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await (widget.pickQr ?? _defaultPickQr)();
      if (bytes == null || !mounted) return;
      setState(() => _uploadingQr = true);
      final url = await (widget.uploadQr ??
          (bytes) => ImageStorageService.uploadMarathonQrBytes(bytes))(bytes);
      if (url == null) throw StateError('upload failed');
      if (mounted) setState(() => _qrUrl = url);
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not upload the QR code.')));
    } finally {
      if (mounted) setState(() => _uploadingQr = false);
    }
  }

  Future<void> _pickDate(
    DateTime? current,
    void Function(DateTime) apply, {
    DateTime? initial,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? initial ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => apply(picked));
  }

  String? _datesProblem() {
    final starts = _startsAt, ends = _endsAt;
    if (starts == null || ends == null) return 'Pick the start and end dates.';
    if (ends.isBefore(starts)) {
      return 'The end date must be on or after the start.';
    }
    final opens = _registrationOpensAt, closes = _registrationClosesAt;
    if (opens != null && opens.isAfter(ends)) {
      return 'Registration must open before the race ends.';
    }
    if (closes != null && closes.isAfter(ends)) {
      return 'Registration must close by the last day of the race.';
    }
    if (opens != null && closes != null && closes.isBefore(opens)) {
      return 'Registration must close on or after it opens.';
    }
    return null;
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    final problem = _theme == MarathonTheme.customKey && _themeData == null
        ? 'Generate an AI theme or pick a ready-made one.'
        : _datesProblem();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    final date = DateFormat('yyyy-MM-dd');
    String? day(DateTime? value) => value == null ? null : date.format(value);
    setState(() => _saving = true);
    try {
      final saved = await _api.adminSaveMarathon(
        {
          'title': _title.text.trim(),
          'description': _description.text.trim(),
          'theme': _theme,
          'theme_data': _custom ? _themeData : null,
          'kit_image_url': _kitImageUrl,
          'distance_km': double.parse(_distance.text.trim()),
          'price': double.parse(_price.text.trim()),
          'starts_at': day(_startsAt),
          'ends_at': day(_endsAt),
          'registration_opens_at': day(_registrationOpensAt),
          'registration_closes_at': day(_registrationClosesAt),
          'payment_instructions': _instructions.text.trim(),
          'payment_qr_url': _qrUrl,
          'is_published': _published,
        },
        id: widget.marathon?.id,
      );
      if (mounted) Navigator.pop(context, saved);
    } catch (error) {
      if (mounted) {
        setState(
            () => _error = _messageOf(error, 'Could not save the marathon.'));
      }
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
    const heading = TextStyle(fontWeight: FontWeight.w800, fontSize: 16);

    Widget dateButton({
      required Key key,
      required IconData icon,
      required String empty,
      required String prefix,
      required DateTime? value,
      required void Function(DateTime) apply,
      VoidCallback? onClear,
      DateTime? initial,
    }) =>
        Expanded(
          child: OutlinedButton.icon(
            key: key,
            onPressed: () => _pickDate(value, apply, initial: initial),
            onLongPress: onClear,
            icon: Icon(icon),
            label: Text(
              value == null ? empty : '$prefix ${date.format(value)}',
              textAlign: TextAlign.center,
            ),
          ),
        );

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
            const SizedBox(height: 20),
            const Text('Theme & kit', style: heading),
            const SizedBox(height: 8),
            _AiThemeCard(
              idea: _idea,
              drawKit: _drawKit,
              busy: _generating || _drawing,
              busyText: _drawing
                  ? 'Drawing the kit… (up to a minute)'
                  : 'Making your theme…',
              error: _aiError,
              onDrawKitChanged: (v) => setState(() => _drawKit = v),
              onGenerate: _generate,
            ),
            if (_custom) ...[
              const SizedBox(height: 12),
              _ThemePreview(
                theme: MarathonTheme.fromData(_themeData!),
                kitImageUrl: _kitImageUrl,
                drawing: _drawing,
                onDrawKit: _generating || _drawing ? null : _drawKitPicture,
                onRemoveKitImage: () => setState(() => _kitImageUrl = null),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              _custom ? 'Or use a ready-made theme' : 'Ready-made themes',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MarathonTheme.all
                  .map((t) => ChoiceChip(
                        key: ValueKey('theme-${t.key}'),
                        avatar: _Swatch(colors: t.gradient),
                        label: Text(t.name),
                        showCheckmark: false,
                        selected: _theme == t.key,
                        selectedColor: t.gradient.first.withValues(alpha: 0.4),
                        onSelected: (_) => setState(() => _theme = t.key),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            const Text('Race', style: heading),
            const SizedBox(height: 8),
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
                dateButton(
                  key: const ValueKey('race-start'),
                  icon: Icons.event,
                  empty: 'Race starts',
                  prefix: 'Starts',
                  value: _startsAt,
                  apply: (d) => _startsAt = d,
                ),
                const SizedBox(width: 12),
                dateButton(
                  key: const ValueKey('race-end'),
                  icon: Icons.flag_outlined,
                  empty: 'Race ends',
                  prefix: 'Ends',
                  value: _endsAt,
                  apply: (d) => _endsAt = d,
                  initial: _startsAt,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Registration', style: heading),
            const SizedBox(height: 4),
            const Text(
              'When people can join. Leave empty to open now and close when '
              'the race ends.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                dateButton(
                  key: const ValueKey('registration-opens'),
                  icon: Icons.how_to_reg_outlined,
                  empty: 'Opens now',
                  prefix: 'Opens',
                  value: _registrationOpensAt,
                  apply: (d) => _registrationOpensAt = d,
                ),
                const SizedBox(width: 12),
                dateButton(
                  key: const ValueKey('registration-closes'),
                  icon: Icons.event_busy_outlined,
                  empty: 'Closes at race end',
                  prefix: 'Closes',
                  value: _registrationClosesAt,
                  apply: (d) => _registrationClosesAt = d,
                  initial: _registrationOpensAt ?? _startsAt,
                ),
              ],
            ),
            if (_registrationOpensAt != null || _registrationClosesAt != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => (
                        _registrationOpensAt = null,
                        _registrationClosesAt = null
                      )),
                  child: const Text('Clear registration dates'),
                ),
              ),
            const SizedBox(height: 20),
            const Text('Payment', style: heading),
            const SizedBox(height: 8),
            _QrUpload(
              url: _qrUrl,
              uploading: _uploadingQr,
              onUpload: _uploadingQr ? null : _uploadQr,
              onRemove: () => setState(() => _qrUrl = null),
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
              onPressed: _saving || _generating || _drawing ? null : _save,
              child: Text(_saving ? 'Saving...' : 'Save marathon'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Type an idea, and AI picks the colours and kit.
class _AiThemeCard extends StatelessWidget {
  const _AiThemeCard({
    required this.idea,
    required this.drawKit,
    required this.busy,
    required this.busyText,
    required this.error,
    required this.onDrawKitChanged,
    required this.onGenerate,
  });

  final TextEditingController idea;
  final bool drawKit;
  final bool busy;
  final String busyText;
  final String? error;
  final ValueChanged<bool> onDrawKitChanged;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('ai-theme-card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0x1A7C4DFF), Color(0x1A00BCD4)],
        ),
        border: Border.all(color: const Color(0x557C4DFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFF7C4DFF)),
              SizedBox(width: 8),
              Expanded(
                child: Text('Create a theme with AI',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "Type an idea and AI picks the colours and the runners' kit.",
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('ai-idea'),
            controller: idea,
            enabled: !busy,
            maxLength: 200,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onGenerate(),
            decoration: const InputDecoration(
              hintText: 'e.g. under the sea, superheroes, Christmas',
              border: OutlineInputBorder(),
              counterText: '',
              isDense: true,
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          SwitchListTile(
            key: const ValueKey('ai-draw-kit'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: drawKit,
            onChanged: busy ? null : onDrawKitChanged,
            title: const Text('Also draw a picture of the kit'),
            subtitle: const Text('Takes up to a minute.'),
          ),
          FilledButton.icon(
            key: const ValueKey('ai-generate'),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C4DFF)),
            onPressed: busy ? null : onGenerate,
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(busy ? busyText : 'Generate theme'),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(error!, style: TextStyle(color: scheme.error)),
            ),
        ],
      ),
    );
  }
}

/// The AI theme: its colours, a walker in the kit and the kit picture.
class _ThemePreview extends StatelessWidget {
  const _ThemePreview({
    required this.theme,
    required this.kitImageUrl,
    required this.drawing,
    required this.onDrawKit,
    required this.onRemoveKitImage,
  });

  final MarathonTheme theme;
  final String? kitImageUrl;
  final bool drawing;
  final VoidCallback? onDrawKit;
  final VoidCallback onRemoveKitImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('ai-theme-preview'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.gradient,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${theme.emoji} ${theme.name}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black38)],
                    ),
                  ),
                ),
                const Chip(
                  label: Text('AI theme'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          SizedBox(
            height: 170,
            child: Row(
              children: [
                Expanded(
                  child: WalkerAvatar(
                    look: theme.dress(const WalkerLook(), 1),
                    phase: 0.25,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 16, 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final (label, color) in [
                          ('Shirt', theme.kitTop),
                          ('Shorts', theme.kitBottom),
                          ('Shoes', theme.kitShoes),
                        ])
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(label,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: kitImageUrl != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Image.network(
                            kitImageUrl!,
                            key: const ValueKey('ai-kit-image'),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                                child: Text('Could not load the picture.')),
                          ),
                        ),
                      ),
                      Wrap(
                        alignment: WrapAlignment.end,
                        children: [
                          TextButton(
                              onPressed: onDrawKit,
                              child: const Text('Draw again')),
                          TextButton(
                              onPressed: onRemoveKitImage,
                              child: const Text('Remove picture')),
                        ],
                      ),
                    ],
                  )
                : OutlinedButton.icon(
                    key: const ValueKey('ai-draw-kit-now'),
                    onPressed: onDrawKit,
                    icon: drawing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.brush_outlined),
                    label: Text(drawing
                        ? 'Drawing the kit…'
                        : 'Draw a picture of this kit'),
                  ),
          ),
        ],
      ),
    );
  }
}

/// The QR code runners scan to pay.
class _QrUpload extends StatelessWidget {
  const _QrUpload({
    required this.url,
    required this.uploading,
    required this.onUpload,
    required this.onRemove,
  });

  final String? url;
  final bool uploading;
  final VoidCallback? onUpload;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (url == null) {
      return InkWell(
        key: const ValueKey('qr-upload'),
        onTap: onUpload,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 110,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.primary, width: 1.5),
            color: scheme.primary.withValues(alpha: 0.05),
          ),
          child: uploading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_2_rounded,
                        size: 36, color: scheme.primary),
                    const SizedBox(height: 6),
                    const Text('Upload payment QR (GCash, Maya or bank)'),
                  ],
                ),
        ),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url!,
                key: const ValueKey('qr-image'),
                width: 96,
                height: 96,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const SizedBox(width: 96, height: 96),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Payment QR',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const Text('Runners scan this to pay.',
                      style: TextStyle(fontSize: 12)),
                  Wrap(
                    children: [
                      TextButton(
                        onPressed: onUpload,
                        child: Text(uploading ? 'Uploading…' : 'Change'),
                      ),
                      TextButton(
                        onPressed: uploading ? null : onRemove,
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A theme's colours as a small round swatch.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: colors),
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

  void _refresh() => setState(() {
        _future = _api.adminFetchRegistrations(widget.marathon.id);
      });

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
          int count(MarathonRegistrationStatus status) =>
              registrations.where((r) => r.status == status).length;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: registrations.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => index == 0
                ? Row(
                    key: const ValueKey('joiner-summary'),
                    children: [
                      for (final (label, value) in [
                        ('Joined', registrations.length),
                        (
                          'To review',
                          count(MarathonRegistrationStatus.paymentSubmitted)
                        ),
                        (
                          'Approved',
                          count(MarathonRegistrationStatus.confirmed)
                        ),
                      ])
                        Expanded(
                          child: Card(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Column(
                                children: [
                                  Text('$value',
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900)),
                                  Text(label,
                                      style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  )
                : _registrationCard(registrations[index - 1]),
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
