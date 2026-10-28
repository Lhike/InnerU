import 'package:flutter/material.dart';
import 'package:selfcare_projects/src/features/marathon/marathon_list_screen.dart';
import 'package:selfcare_projects/src/features/marathon/marathon_theme.dart';
import 'package:selfcare_projects/src/services/auth_service.dart';
import 'package:selfcare_projects/src/services/marathon_api_service.dart';

/// Registration form for a marathon. Pops with the updated [Marathon].
class MarathonRegistrationScreen extends StatefulWidget {
  const MarathonRegistrationScreen({
    super.key,
    required this.marathon,
    this.api,
  });

  final Marathon marathon;
  final MarathonApiService? api;

  @override
  State<MarathonRegistrationScreen> createState() =>
      _MarathonRegistrationScreenState();
}

class _MarathonRegistrationScreenState
    extends State<MarathonRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  final _address = TextEditingController();
  String? _shirtSize;
  bool _agreed = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final session = AuthService.instance.currentSession;
    _name = TextEditingController(text: session?.name ?? '');
    _email = TextEditingController(text: session?.email ?? '');
    _phone = TextEditingController(text: session?.number ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    if (_shirtSize == null) {
      setState(() => _error = 'Pick your shirt size.');
      return;
    }
    if (!_agreed) {
      setState(() => _error = 'Please confirm your details are correct.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final updated =
          await (widget.api ?? MarathonApiService.instance).register(
        widget.marathon.id,
        MarathonRegistrationForm(
          fullName: _name.text.trim(),
          email: _email.text.trim(),
          phone: _phone.text.trim(),
          shirtSize: _shirtSize!,
          shippingAddress: _address.text.trim(),
        ),
      );
      if (mounted) Navigator.pop(context, updated);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not register. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _required(String? value, String label) =>
      (value ?? '').trim().isEmpty ? 'Enter your $label.' : null;

  @override
  Widget build(BuildContext context) {
    final marathon = widget.marathon;
    final theme = marathon.look;
    InputDecoration decoration(String label, {String? hint}) => InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registration'),
        backgroundColor: theme.gradient.first,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('${theme.emoji}  ${marathon.title}',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
                '${formatKm(marathon.distanceKm)} km · ${formatPrice(marathon)}'),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: decoration('Full name',
                  hint: 'As it should appear on your certificate'),
              validator: (v) => _required(v, 'full name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: decoration('Email'),
              validator: (v) {
                final value = (v ?? '').trim();
                if (value.isEmpty) return 'Enter your email.';
                return value.contains('@') && value.contains('.')
                    ? null
                    : 'Enter a valid email.';
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: decoration('Mobile number', hint: '09XX XXX XXXX'),
              validator: (v) => _required(v, 'mobile number'),
            ),
            const SizedBox(height: 16),
            const Text('Shirt size',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MarathonRegistrationForm.shirtSizes
                  .map((size) => ChoiceChip(
                        label: Text(size),
                        selected: _shirtSize == size,
                        onSelected: (_) => setState(() => _shirtSize = size),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _address,
              minLines: 2,
              maxLines: 4,
              decoration: decoration('Shipping address',
                  hint: 'Where we send your shirt, medal and certificate'),
              validator: (v) => _required(v, 'shipping address'),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _agreed,
              onChanged: (v) => setState(() => _agreed = v ?? false),
              title: const Text(
                  'My details are correct and I agree to the event rules.'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: theme.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(_submitting
                  ? 'Registering...'
                  : marathon.isFree
                      ? 'Register'
                      : 'Register and continue to payment'),
            ),
          ],
        ),
      ),
    );
  }
}
