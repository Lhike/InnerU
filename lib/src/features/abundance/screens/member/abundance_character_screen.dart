import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:selfcare_projects/src/features/abundance/theme/abundance_assets.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_typography.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_button.dart';

typedef CharacterLoader = Future<String?> Function(String uid);
typedef CharacterSaver = Future<void> Function(String uid, String character);

class AbundanceCharacterScreen extends StatefulWidget {
  const AbundanceCharacterScreen({
    super.key,
    required this.uid,
    required this.onOpenAccountSettings,
    this.loadCharacter,
    this.saveCharacter,
  });

  final String uid;
  final VoidCallback onOpenAccountSettings;
  final CharacterLoader? loadCharacter;
  final CharacterSaver? saveCharacter;

  @override
  State<AbundanceCharacterScreen> createState() =>
      _AbundanceCharacterScreenState();
}

class _AbundanceCharacterScreenState extends State<AbundanceCharacterScreen> {
  String _selected = abundanceCharacterKeys.first;

  String get _storageKey => 'abundance_character_${widget.uid}';

  @override
  void initState() {
    super.initState();
    _load();
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
    return Scaffold(
      backgroundColor: AbundanceColors.background,
      appBar: AppBar(
        backgroundColor: AbundanceColors.surfaceRaised,
        foregroundColor: AbundanceColors.foreground,
        title: const Text('CHARACTER', style: AbundanceTypography.eyebrow),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: .72,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: abundanceCharacterKeys.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return const _CharacterIntro();
          }
          if (index == abundanceCharacterKeys.length + 1) {
            return Center(
              child: AbundanceButton(
                label: 'Account settings',
                icon: Icons.manage_accounts_outlined,
                outlined: true,
                onPressed: widget.onOpenAccountSettings,
              ),
            );
          }
          final character = abundanceCharacterKeys[index - 1];
          final selected = character == _selected;
          return InkWell(
            key: ValueKey('character-$character'),
            borderRadius: BorderRadius.circular(18),
            onTap: () => _select(character),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: AbundanceColors.surfaceRaised,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? AbundanceColors.primaryGold
                      : AbundanceColors.border,
                  width: selected ? 2 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AbundanceColors.primaryGold
                              .withValues(alpha: .18),
                          blurRadius: 18,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(
                        abundanceCharacterAsset(character)!,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                    child: Text(
                      character.toUpperCase(),
                      style: AbundanceTypography.eyebrow.copyWith(
                        color: selected
                            ? AbundanceColors.primaryGold
                            : AbundanceColors.foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
