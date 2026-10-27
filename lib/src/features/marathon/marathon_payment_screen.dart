import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:selfcare_projects/src/features/marathon/marathon_list_screen.dart';
import 'package:selfcare_projects/src/features/marathon/marathon_theme.dart';
import 'package:selfcare_projects/src/services/image_storage_service.dart';
import 'package:selfcare_projects/src/services/marathon_api_service.dart';

typedef ReceiptPicker = Future<Uint8List?> Function();
typedef ReceiptUploader = Future<String?> Function(Uint8List bytes);

/// Shows how to pay and collects the receipt screenshot and reference
/// number for admin review. Pops with the updated [Marathon].
class MarathonPaymentScreen extends StatefulWidget {
  const MarathonPaymentScreen({
    super.key,
    required this.marathon,
    this.api,
    this.pickReceipt,
    this.uploadReceipt,
  });

  final Marathon marathon;
  final MarathonApiService? api;

  /// Overridable for tests.
  final ReceiptPicker? pickReceipt;
  final ReceiptUploader? uploadReceipt;

  @override
  State<MarathonPaymentScreen> createState() => _MarathonPaymentScreenState();
}

class _MarathonPaymentScreenState extends State<MarathonPaymentScreen> {
  final _reference = TextEditingController();
  Uint8List? _receipt;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  Future<Uint8List?> _defaultPick() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
    return image?.readAsBytes();
  }

  Future<void> _pick() async {
    try {
      final bytes = await (widget.pickReceipt ?? _defaultPick)();
      if (bytes != null && mounted) setState(() => _receipt = bytes);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open your photos.');
    }
  }

  Future<void> _submit() async {
    final reference = _reference.text.trim();
    if (_receipt == null) {
      setState(() => _error = 'Attach a screenshot of your payment.');
      return;
    }
    if (reference.isEmpty) {
      setState(() => _error = 'Enter the reference number from your receipt.');
      return;
    }

    setState(() => (_submitting = true, _error = null));
    try {
      final url = await (widget.uploadReceipt ??
          (bytes) => ImageStorageService.uploadMarathonPaymentBytes(bytes))(
        _receipt!,
      );
      if (url == null) throw StateError('upload failed');
      final updated =
          await (widget.api ?? MarathonApiService.instance).submitPayment(
        widget.marathon.id,
        reference: reference,
        proofUrl: url,
      );
      if (mounted) Navigator.pop(context, updated);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not send your payment. Try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final marathon = widget.marathon;
    final theme = MarathonTheme.of(marathon.theme);
    final instructions = (marathon.paymentInstructions ?? '').trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: theme.gradient.first,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: theme.gradient),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(marathon.title,
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 4),
                Text(
                  'Amount to pay: ${formatPrice(marathon)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('1. Send your payment',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              title: SelectableText(instructions.isEmpty
                  ? 'Payment details will be posted by the organizer.'
                  : instructions),
              trailing: instructions.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Copy',
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: instructions));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Payment details copied.')),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('2. Upload your receipt',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pick,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: _receipt == null ? 120 : 260,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.accent, width: 1.5),
                color: theme.accent.withValues(alpha: 0.06),
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: _receipt == null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 36, color: theme.accent),
                        const SizedBox(height: 6),
                        const Text('Tap to attach a screenshot'),
                      ],
                    )
                  : Image.memory(_receipt!, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reference,
            decoration: const InputDecoration(
              labelText: 'Reference number',
              hintText: 'From your GCash, Maya or bank receipt',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: theme.accent,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(_submitting ? 'Sending...' : 'Submit payment'),
          ),
          const SizedBox(height: 8),
          const Text(
            "We'll review your payment and confirm your slot. You'll get your "
            'bib number once it is approved.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
