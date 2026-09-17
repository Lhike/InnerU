import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:selfcare_projects/src/features/abundance/theme/abundance_assets.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_typography.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_button.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_header_profile_button.dart';
import 'package:selfcare_projects/src/services/auth_service.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_council_service.dart';

typedef CharacterLoader = Future<String?> Function(String uid);
typedef CharacterSaver = Future<void> Function(String uid, String character);

class AbundanceCharacterScreen extends StatefulWidget {
  const AbundanceCharacterScreen({
    super.key,
    required this.uid,
    required this.onOpenAccountSettings,
    this.onOpenAchievements,
    this.onAppearanceChanged,
    this.onSignOut,
    this.onReplayTutorial,
    this.appearance = 'dark',
    this.loadCharacter,
    this.saveCharacter,
  });

  final String uid;
  final VoidCallback onOpenAccountSettings;
  final VoidCallback? onOpenAchievements;
  final ValueChanged<String>? onAppearanceChanged;
  final VoidCallback? onSignOut;
  final VoidCallback? onReplayTutorial;
  final String appearance;
  final CharacterLoader? loadCharacter;
  final CharacterSaver? saveCharacter;

  @override
  State<AbundanceCharacterScreen> createState() =>
      _AbundanceCharacterScreenState();
}

class _AbundanceCharacterScreenState extends State<AbundanceCharacterScreen> {
  String _selected = abundanceCharacterKeys.first;
  String? _councilName;
  String? _councilCoach;

  String get _storageKey => 'abundance_character_${widget.uid}';

  @override
  void initState() {
    super.initState();
    _load();
    _loadCouncil();
  }

  Future<void> _loadCouncil() async {
    if (AuthService.instance.currentSession == null) return;
    try {
      final council = await AbundanceCouncilService().fetchCurrent();
      if (!mounted || council == null) return;
      setState(() {
        _councilName = council.name;
        _councilCoach = council.coachName;
      });
    } catch (_) {
      // Council data is supplemental; keep the source empty state usable when
      // the relationship endpoint is unavailable.
    }
  }

  Future<void> _load() async {
    final value = widget.loadCharacter != null
        ? await widget.loadCharacter!(widget.uid)
        : (await SharedPreferences.getInstance()).getString(_storageKey);
    if (!mounted) return;
    setState(() {
      if (value != null && abundanceCharacterKeys.contains(value)) {
        _selected = value;
      }
    });
  }

  Future<void> _select(String character) async {
    final previous = _selected;
    setState(() => _selected = character);
    try {
      if (widget.saveCharacter != null) {
        await widget.saveCharacter!(widget.uid, character);
      } else {
        final saved = await (await SharedPreferences.getInstance())
            .setString(_storageKey, character);
        if (!saved) throw StateError('Character preference was not saved.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _selected = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('We could not save your character.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthService.instance.currentSession;
    final displayName = session?.name.trim().isNotEmpty == true
        ? session!.name.trim()
        : 'Your champion';
    final email = session?.email.trim() ?? '';
    final sourceProfileLayout =
        widget.loadCharacter == null && widget.saveCharacter == null;
    return Scaffold(
      backgroundColor: AbundanceColors.background,
      appBar: AuthService.instance.currentSession == null
          ? AppBar(
              backgroundColor: AbundanceColors.surfaceRaised,
              foregroundColor: AbundanceColors.foreground,
              title: const Text('CHARACTER SHEET',
                  style: AbundanceTypography.eyebrow),
            )
          : const AbundanceHeaderBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          const Text('Character Sheet', style: AbundanceTypography.display),
          const SizedBox(height: 6),
          const Text(
            'Who you are here, and the settings that keep the account yours.',
            style: AbundanceTypography.body,
          ),
          const SizedBox(height: 18),
          _IdentityCard(
            name: displayName,
            email: email,
            sourceLayout: sourceProfileLayout,
          ),
          const SizedBox(height: 18),
          if (sourceProfileLayout)
            _SelectedCharacterSection(
              selected: _selected,
              onChoose: () => _showCharacterPicker(context),
            )
          else ...[
            const Text('Your character', style: AbundanceTypography.title),
            const SizedBox(height: 6),
            const _CharacterIntro(),
            const SizedBox(height: 12),
            _CharacterGrid(selected: _selected, onSelect: _select),
          ],
          const SizedBox(height: 18),
          _CouncilCard(
            councilName: _councilName,
            coachName: _councilCoach,
            onChange: () => _showCouncilPicker(context),
          ),
          const SizedBox(height: 18),
          const _ProgressionCard(),
          const SizedBox(height: 18),
          _EarnedBadgesCard(onOpenAchievements: widget.onOpenAchievements),
          const SizedBox(height: 18),
          if (sourceProfileLayout) ...[
            _EditProfileCard(name: displayName),
            const SizedBox(height: 18),
            const _ChangePasswordCard(),
            const SizedBox(height: 18),
            _AppearanceCard(
              appearance: widget.appearance,
              onChanged: widget.onAppearanceChanged,
              onSignOut: widget.onSignOut,
              onReplayTutorial: widget.onReplayTutorial,
            ),
            const SizedBox(height: 18),
            const _DeleteAccountCard(),
          ],
        ],
      ),
    );
  }

  Future<void> _showCharacterPicker(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AbundanceColors.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Choose your character',
                      style: AbundanceTypography.title),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close,
                        color: AbundanceColors.foreground),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Select the champion you chose when you began your journey.',
                style: AbundanceTypography.body,
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 300,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: abundanceCharacterKeys.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final character = abundanceCharacterKeys[index];
                    final selected = character == _selected;
                    return InkWell(
                      key: ValueKey('character-$character'),
                      onTap: () async {
                        await _select(character);
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 220,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AbundanceColors.surfaceSunken,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: selected
                                ? AbundanceColors.primaryGold
                                : AbundanceColors.border,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: Image.asset(
                                abundanceCharacterAsset(character)!,
                                fit: BoxFit.contain,
                              ),
                            ),
                            Text(
                              character[0].toUpperCase() +
                                  character.substring(1),
                              style: AbundanceTypography.body,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCouncilPicker(BuildContext context) async {
    List<AbundanceCouncil> available = const [];
    Object? loadError;
    try {
      available = await AbundanceCouncilService().fetchAvailable();
    } catch (error) {
      loadError = error;
    }
    if (!context.mounted) return;
    String? selectedId;
    for (final council in available) {
      if (council.isCurrent || council.name == _councilName) {
        selectedId = council.id;
        break;
      }
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AbundanceColors.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 64,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AbundanceColors.muted,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Choose your council',
                        style: AbundanceTypography.title),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close,
                          color: AbundanceColors.foreground),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose the council you want to climb with.',
                  style: AbundanceTypography.body,
                ),
                const SizedBox(height: 18),
                if (loadError != null)
                  const Text('Councils could not be loaded. Try again later.',
                      style: AbundanceTypography.body)
                else if (available.isEmpty)
                  Text(
                      'No councils are available right now. Ask your coach for an invitation.',
                      style: AbundanceTypography.body)
                else
                  ...available.map((council) {
                    final selected = council.id == selectedId;
                    return InkWell(
                      onTap: () => setSheetState(() => selectedId = council.id),
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AbundanceColors.surfaceSunken,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: selected
                                ? AbundanceColors.primaryGold
                                : AbundanceColors.border,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(council.name,
                                    style: AbundanceTypography.title),
                                Icon(
                                  selected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: selected
                                      ? AbundanceColors.primaryGold
                                      : AbundanceColors.muted,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Coach ${council.coachName} · ${council.memberCount} members · ${council.averageScore}% Life Power',
                              style: AbundanceTypography.body,
                            ),
                            if (council.description?.isNotEmpty == true)
                              Text(council.description!,
                                  style: AbundanceTypography.body),
                            if (council.isCurrent)
                              const Text('CURRENT COUNCIL',
                                  style: AbundanceTypography.eyebrow),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: selectedId == null
                          ? null
                          : () async {
                              try {
                                await AbundanceCouncilService()
                                    .join(selectedId!);
                                final current = await AbundanceCouncilService()
                                    .fetchCurrent();
                                if (mounted && current != null) {
                                  setState(() {
                                    _councilName = current.name;
                                    _councilCoach = current.coachName;
                                  });
                                }
                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                }
                              } catch (_) {
                                if (sheetContext.mounted) {
                                  ScaffoldMessenger.of(sheetContext)
                                      .showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Unable to join this council.')),
                                  );
                                }
                              }
                            },
                      child: const Text('Join council'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.name,
    required this.email,
    this.sourceLayout = true,
  });

  final String name;
  final String email;
  final bool sourceLayout;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    if (!sourceLayout) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AbundanceColors.surfaceRaised,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AbundanceColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AbundanceColors.accentCyan,
              child: Text(
                initials.isEmpty ? '?' : initials,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AbundanceTypography.title),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      style: AbundanceTypography.body.copyWith(fontSize: 12),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'Your chosen champion and the progress you are building.',
                    style: AbundanceTypography.body.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: AbundanceColors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AbundanceColors.border),
        image: const DecorationImage(
          image: AssetImage(abundanceHomeSceneAsset),
          fit: BoxFit.cover,
          opacity: .22,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AbundanceColors.accentCyan,
                      border: Border.all(
                          color: AbundanceColors.primaryGold, width: 3),
                    ),
                    child: Center(
                      child: Text(
                        initials.isEmpty ? '?' : initials,
                        style: const TextStyle(
                            color: Colors.black,
                            fontSize: 30,
                            fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -12,
                    bottom: -10,
                    child: Transform.rotate(
                      angle: math.pi / 4,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AbundanceColors.surfaceSunken,
                          border: Border.all(
                              color: AbundanceColors.primaryGold, width: 2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Transform.rotate(
                          angle: -math.pi / 4,
                          child: const Center(
                            child: Text('2', style: AbundanceTypography.title),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style:
                            AbundanceTypography.display.copyWith(fontSize: 26)),
                    const SizedBox(height: 2),
                    const Text('LEGEND', style: AbundanceTypography.title),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: const LinearProgressIndicator(
                        value: .35,
                        minHeight: 9,
                        backgroundColor: AbundanceColors.border,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AbundanceColors.accentCyan),
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text('Level 2', style: AbundanceTypography.body),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: AbundanceColors.primaryGold,
              side: const BorderSide(color: AbundanceColors.primaryGold),
            ),
            child: const Text('Add profile photo'),
          ),
          const SizedBox(height: 18),
          if (email.isNotEmpty) Text(email, style: AbundanceTypography.body),
          const SizedBox(height: 14),
          const Text('Joined Sep 14, 2026', style: AbundanceTypography.body),
          const SizedBox(height: 14),
          const Text('I MATTER', style: AbundanceTypography.body),
        ],
      ),
    );
  }
}

class _CharacterIntro extends StatelessWidget {
  const _CharacterIntro();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('YOUR CHARACTER', style: AbundanceTypography.eyebrow),
        SizedBox(height: 8),
        Text('Choose your path', style: AbundanceTypography.display),
        SizedBox(height: 8),
        Text(
          'Pick the identity that represents how you want to show up.',
          style: AbundanceTypography.body,
        ),
      ],
    );
  }
}

class _EditProfileCard extends StatelessWidget {
  const _EditProfileCard({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return _ProfileSectionCard(
      title: 'Edit profile',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Timezone: Asia/Manila', style: AbundanceTypography.body),
          const SizedBox(height: 14),
          _GoldOutlineButton(
            label: 'Edit details',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: AbundanceColors.surfaceRaised,
              builder: (_) => _EditProfileSheet(name: name),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.name});

  final String name;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final _firstName = TextEditingController(text: _namePart(0));
  late final _lastName = TextEditingController(text: _namePart(1));
  final _headline = TextEditingController(text: 'I MATTER');
  final _bio = TextEditingController();
  final _timezone = TextEditingController(text: 'Asia/Manila');
  final _avatarUrl = TextEditingController();

  String _namePart(int index) {
    final parts = widget.name.trim().split(RegExp(r'\s+'));
    if (index == 0) return parts.isEmpty ? '' : parts.first;
    return parts.length > 1 ? parts.skip(1).join(' ') : '';
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _headline.dispose();
    _bio.dispose();
    _timezone.dispose();
    _avatarUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fields = <(String, TextEditingController)>[
      ('FIRST NAME', _firstName),
      ('LAST NAME', _lastName),
      ('HEADLINE', _headline),
      ('BIO', _bio),
      ('TIMEZONE', _timezone),
      ('AVATAR IMAGE URL (OPTIONAL)', _avatarUrl),
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit profile', style: AbundanceTypography.title),
            const SizedBox(height: 18),
            for (final field in fields) ...[
              Text(field.$1, style: AbundanceTypography.eyebrow),
              const SizedBox(height: 6),
              TextField(
                controller: field.$2,
                style: AbundanceTypography.body,
                decoration: const InputDecoration(),
              ),
              const SizedBox(height: 14),
            ],
            const Text(
              'Timezone example: Asia/Manila. Use an HTTPS image URL for your avatar; leave it blank to remove it.',
              style: AbundanceTypography.body,
            ),
            const SizedBox(height: 18),
            _GoldFilledButton(
              label: 'Save profile',
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(height: 10),
            _GoldOutlineButton(
              label: 'Cancel',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangePasswordCard extends StatefulWidget {
  const _ChangePasswordCard();

  @override
  State<_ChangePasswordCard> createState() => _ChangePasswordCardState();
}

class _ChangePasswordCardState extends State<_ChangePasswordCard> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ProfileSectionCard(
      title: 'Change password',
      subtitle: 'Enter your current password to choose a new one.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PasswordField(label: 'CURRENT PASSWORD', controller: _current),
          _PasswordField(label: 'NEW PASSWORD', controller: _next),
          _PasswordField(label: 'CONFIRM NEW PASSWORD', controller: _confirm),
          _GoldFilledButton(
            label: 'Change password',
            onPressed: () {
              if (_next.text.isEmpty || _next.text != _confirm.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match.')),
                );
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password change requested.')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AbundanceTypography.eyebrow),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            obscureText: true,
            style: AbundanceTypography.body,
            decoration: const InputDecoration(),
          ),
        ],
      ),
    );
  }
}

class _AppearanceCard extends StatefulWidget {
  const _AppearanceCard({
    required this.appearance,
    required this.onChanged,
    required this.onSignOut,
    required this.onReplayTutorial,
  });

  final String appearance;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSignOut;
  final VoidCallback? onReplayTutorial;

  @override
  State<_AppearanceCard> createState() => _AppearanceCardState();
}

class _AppearanceCardState extends State<_AppearanceCard> {
  late String _selected = widget.appearance;

  void _setAppearance(String value) {
    setState(() => _selected = value);
    widget.onChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return _ProfileSectionCard(
      title: 'Appearance',
      subtitle: 'Choose how Abundance 12 looks on this device.',
      child: Column(
        children: [
          Row(
            children: [
              for (final option in const ['light', 'dark', 'system']) ...[
                if (option != 'light') const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _setAppearance(option),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      side: BorderSide(
                        color: _selected == option
                            ? AbundanceColors.primaryGold
                            : AbundanceColors.border,
                      ),
                    ),
                    child: Text(
                      option[0].toUpperCase() + option.substring(1),
                      style: AbundanceTypography.body,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _GoldOutlineButton(
            label: 'Replay tutorial',
            onPressed: widget.onReplayTutorial,
          ),
          const SizedBox(height: 12),
          _GoldOutlineButton(label: 'Log out', onPressed: widget.onSignOut),
        ],
      ),
    );
  }
}

class _DeleteAccountCard extends StatelessWidget {
  const _DeleteAccountCard();

  @override
  Widget build(BuildContext context) {
    return _ProfileSectionCard(
      title: 'Delete account',
      subtitle:
          'Permanently delete your account and associated data. This cannot be undone.',
      child: _GoldOutlineButton(
        label: 'Delete my account',
        onPressed: () => showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AbundanceColors.surfaceRaised,
            title:
                const Text('Delete account', style: AbundanceTypography.title),
            content: const Text('This action cannot be undone.',
                style: AbundanceTypography.body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Delete'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSectionCard extends StatelessWidget {
  const _ProfileSectionCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AbundanceColors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AbundanceColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AbundanceTypography.title),
          if (subtitle != null) ...[
            const SizedBox(height: 10),
            Text(subtitle!, style: AbundanceTypography.body),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _GoldFilledButton extends StatelessWidget {
  const _GoldFilledButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AbundanceColors.primaryGold,
            foregroundColor: Colors.black,
            minimumSize: const Size.fromHeight(52),
          ),
          child: Text(label),
        ),
      );
}

class _GoldOutlineButton extends StatelessWidget {
  const _GoldOutlineButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AbundanceColors.primaryGold,
            side: const BorderSide(color: AbundanceColors.primaryGold),
            minimumSize: const Size.fromHeight(52),
          ),
          child: Text(label),
        ),
      );
}

class _CharacterGrid extends StatelessWidget {
  const _CharacterGrid({required this.selected, required this.onSelect});

  final String selected;
  final Future<void> Function(String character) onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: .72,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: abundanceCharacterKeys.length,
      itemBuilder: (context, index) {
        final character = abundanceCharacterKeys[index];
        final isSelected = character == selected;
        return InkWell(
          key: ValueKey('character-$character'),
          borderRadius: BorderRadius.circular(18),
          onTap: () => onSelect(character),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: AbundanceColors.surfaceRaised,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected
                    ? AbundanceColors.primaryGold
                    : AbundanceColors.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(abundanceCharacterAsset(character)!,
                        fit: BoxFit.contain),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  child: Text(character.toUpperCase(),
                      style: AbundanceTypography.eyebrow.copyWith(
                          color: isSelected
                              ? AbundanceColors.primaryGold
                              : AbundanceColors.foreground)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SelectedCharacterSection extends StatelessWidget {
  const _SelectedCharacterSection(
      {required this.selected, required this.onChoose});

  final String selected;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final label = selected[0].toUpperCase() + selected.substring(1);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AbundanceColors.surfaceRaised,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AbundanceColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your character', style: AbundanceTypography.title),
          const SizedBox(height: 12),
          const Text('CHARACTER', style: AbundanceTypography.eyebrow),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 118,
                height: 180,
                child: Image.asset(abundanceCharacterAsset(selected)!,
                    fit: BoxFit.contain),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AbundanceTypography.title),
                    const SizedBox(height: 6),
                    const Text('Your chosen champion',
                        style: AbundanceTypography.body),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onChoose,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              foregroundColor: AbundanceColors.primaryGold,
              side: const BorderSide(color: AbundanceColors.primaryGold),
            ),
            child: const Text('Choose your character'),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            children: [
              _RoleChip(label: 'STUDENT'),
              _RoleChip(label: 'COACH'),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          foregroundColor: AbundanceColors.primaryGold,
          side: const BorderSide(color: AbundanceColors.primaryGold),
        ),
        child: Text(label),
      );
}

class _CouncilCard extends StatelessWidget {
  const _CouncilCard(
      {required this.onChange, this.councilName, this.coachName});

  final VoidCallback onChange;
  final String? councilName;
  final String? coachName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AbundanceColors.surfaceRaised,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AbundanceColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Your council', style: AbundanceTypography.title),
              TextButton(
                onPressed: onChange,
                child: Text(councilName == null ? 'Join council' : 'Change'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'The council you climb with, and the coach who leads it.',
            style: AbundanceTypography.body,
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AbundanceColors.surfaceSunken,
              borderRadius: BorderRadius.circular(16),
            ),
            child: councilName == null
                ? const Text(
                    'No council assigned. Choose a council to climb with.',
                    style: AbundanceTypography.body,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(councilName!, style: AbundanceTypography.title),
                      const SizedBox(height: 6),
                      Text(
                        'Coached by ${coachName?.isNotEmpty == true ? coachName : 'your coach'}',
                        style: AbundanceTypography.body,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProgressionCard extends StatelessWidget {
  const _ProgressionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AbundanceColors.surfaceRaised,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AbundanceColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Progression', style: AbundanceTypography.title),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('LEVEL 1', style: AbundanceTypography.eyebrow),
                    const SizedBox(height: 4),
                    const Text('NOVICE', style: AbundanceTypography.display),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: const LinearProgressIndicator(
                        value: 0,
                        minHeight: 8,
                        backgroundColor: AbundanceColors.border,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AbundanceColors.accentCyan,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AbundanceColors.border,
                    width: 8,
                  ),
                ),
                child: const Center(
                  child: Text('0%', style: AbundanceTypography.title),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(child: _ProfileStat(value: '0', label: 'Quests')),
              SizedBox(width: 8),
              Expanded(child: _ProfileStat(value: '0', label: 'Completed')),
              SizedBox(width: 8),
              Expanded(child: _ProfileStat(value: '0', label: 'Day streak')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AbundanceColors.surfaceSunken,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AbundanceColors.border),
      ),
      child: Column(
        children: [
          Text(value, style: AbundanceTypography.title),
          const SizedBox(height: 3),
          Text(label,
              style: AbundanceTypography.body, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _EarnedBadgesCard extends StatelessWidget {
  const _EarnedBadgesCard({required this.onOpenAchievements});

  final VoidCallback? onOpenAchievements;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AbundanceColors.surfaceRaised,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AbundanceColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Earned badges', style: AbundanceTypography.title),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AbundanceColors.surfaceSunken,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Complete your first quest to earn a badge.',
              style: AbundanceTypography.body,
            ),
          ),
          const SizedBox(height: 12),
          AbundanceButton(
            label: 'View all achievements',
            outlined: true,
            onPressed: onOpenAchievements,
          ),
        ],
      ),
    );
  }
}
