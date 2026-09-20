import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:selfcare_projects/src/features/abundance/theme/abundance_assets.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_typography.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_button.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_header_profile_button.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_tutorial_target.dart';
import 'package:selfcare_projects/src/features/abundance/tutorial/abundance_tutorial_controller.dart';
import 'package:selfcare_projects/src/services/auth_service.dart';
import 'package:selfcare_projects/src/services/app_session_service.dart';
import 'package:selfcare_projects/src/features/authentication/screen/UsersData/user_service.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_council_service.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_achievements_service.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_profile_service.dart';
import 'package:selfcare_projects/src/features/abundance/services/goals_service.dart';
import 'package:selfcare_projects/src/services/image_storage_service.dart';
import 'package:selfcare_projects/src/services/profile_picture_bus.dart';

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
    this.isCoach = false,
    this.loadCharacter,
    this.saveCharacter,
    this.profileService,
    this.councilService,
    this.goalsService,
    this.tutorialController,
  });

  final String uid;
  final VoidCallback onOpenAccountSettings;
  final VoidCallback? onOpenAchievements;
  final ValueChanged<String>? onAppearanceChanged;
  final VoidCallback? onSignOut;
  final VoidCallback? onReplayTutorial;
  final String appearance;
  final bool isCoach;
  final CharacterLoader? loadCharacter;
  final CharacterSaver? saveCharacter;
  final AbundanceProfileService? profileService;
  final AbundanceCouncilService? councilService;
  final GoalsService? goalsService;
  final AbundanceTutorialController? tutorialController;

  @override
  State<AbundanceCharacterScreen> createState() =>
      _AbundanceCharacterScreenState();
}

class _AbundanceCharacterScreenState extends State<AbundanceCharacterScreen> {
  String _selected = abundanceCharacterKeys.first;
  String? _coachName;
  AbundanceProfileSnapshot? _snapshot;
  bool _profileLoading = false;
  bool _profilePhotoUploading = false;
  String? _profilePhotoOverride;
  Object? _profileError;

  AbundanceProfileService get _profileGateway =>
      widget.profileService ?? AbundanceProfileService();

  AbundanceCouncilService get _councilGateway =>
      widget.councilService ?? AbundanceCouncilService();

  String get _storageKey => 'abundance_character_${widget.uid}';

  @override
  void initState() {
    super.initState();
    _profilePhotoOverride = ProfilePictureBus.latestUrl.value;
    ProfilePictureBus.latestUrl.addListener(_onProfilePictureBusUpdate);
    _load();
    _loadCoachAssignment();
    _loadProfile();
  }

  @override
  void dispose() {
    ProfilePictureBus.latestUrl.removeListener(_onProfilePictureBusUpdate);
    super.dispose();
  }

  void _onProfilePictureBusUpdate() {
    if (!mounted) return;
    setState(() => _profilePhotoOverride = ProfilePictureBus.latestUrl.value);
  }

  Future<void> _loadProfile() async {
    if (AuthService.instance.currentSession == null &&
        widget.profileService == null) {
      return;
    }
    setState(() {
      _profileLoading = true;
      _profileError = null;
    });
    try {
      final snapshot = await _profileGateway.fetchSnapshot();
      if (!mounted) return;
      var achievements = snapshot.achievements;
      if (achievements.isEmpty &&
          widget.loadCharacter == null &&
          widget.saveCharacter == null) {
        try {
          final records = await InnerUAbundanceAchievementsGateway(
            uid: widget.uid,
            goals: widget.goalsService ?? GoalsService(),
          ).load();
          achievements = records
              .where((record) => record.unlocked)
              .map(
                (record) => AbundanceProfileAchievement(
                  key: record.definition.key,
                  name: record.definition.name,
                  description: record.definition.description,
                  art: record.definition.assetKey,
                  tier: record.definition.tier,
                  // The InnerU calculator returns earned state but not an
                  // unlock timestamp. Keep the card honest instead of
                  // inventing a date; the A12 profile API still supplies the
                  // real timestamp whenever it is available.
                  unlockedAt: null,
                ),
              )
              .toList(growable: false);
        } catch (_) {
          // Keep the A12 profile response and its empty state if the
          // compatibility achievement sources are unavailable.
        }
      }
      if (!mounted) return;
      setState(() {
        // The profile endpoint does not always embed the coach relationship.
        // Do not let that partial response erase the coach loaded from /guild
        // while the screen is reloading after an appearance change.
        final council = snapshot.council ?? _snapshot?.council;
        _snapshot = AbundanceProfileSnapshot(
          profile: snapshot.profile,
          achievements: achievements,
          council: council,
        );
        _profileLoading = false;
        if (snapshot.profile.character != null &&
            abundanceCharacterKeys.contains(snapshot.profile.character)) {
          _selected = snapshot.profile.character!;
        }
        if (snapshot.council != null) {
          _coachName = snapshot.council!.coachName;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _profileLoading = false;
        _profileError = error;
      });
    }
  }

  Future<void> _loadCoachAssignment() async {
    if (AuthService.instance.currentSession == null &&
        widget.councilService == null) {
      return;
    }
    try {
      final coachName = await _councilGateway.fetchAssignedCoachName();
      if (!mounted || coachName == null || coachName.trim().isEmpty) return;
      setState(() {
        _coachName = coachName;
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
      } else if (AuthService.instance.currentSession != null) {
        await _profileGateway.updateCharacter(character);
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

  Future<void> _pickProfilePhoto() async {
    if (_profilePhotoUploading) return;

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (picked == null || !mounted) return;

    final profile = _snapshot?.profile;
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile data is still loading.')),
      );
      return;
    }

    setState(() => _profilePhotoUploading = true);
    try {
      final url = await ImageStorageService.uploadImageFile(File(picked.path));
      if (url == null || url.trim().isEmpty) {
        throw StateError(
          ImageStorageService.lastError ?? 'Photo upload failed.',
        );
      }

      await _profileGateway.updateProfile(
        firstName: profile.firstName,
        lastName: profile.lastName,
        headline: profile.headline ?? '',
        bio: profile.bio ?? '',
        timezone: profile.timezone,
        avatarUrl: url,
      );
      // The shell header reads InnerU's session while the profile card reads
      // the A12 snapshot. Keep the canonical InnerU profile and both live
      // surfaces in sync after the upload succeeds.
      await UserService.updateUserFields({'profile_pic': url});
      final currentSession = AuthService.instance.currentSession;
      if (currentSession != null) {
        await AppSessionService.instance.setSession(
          currentSession.copyWith(profilePic: url),
        );
      }
      if (!mounted) return;
      setState(() => _profilePhotoOverride = url);
      ProfilePictureBus.publish(url);
      await _loadProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update profile photo.')),
      );
    } finally {
      if (mounted) setState(() => _profilePhotoUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthService.instance.currentSession;
    final profile = _snapshot?.profile;
    final displayName = profile?.displayName.trim().isNotEmpty == true
        ? profile!.displayName.trim()
        : session?.name.trim().isNotEmpty == true
            ? session!.name.trim()
            : 'Your champion';
    final email = profile?.email.trim().isNotEmpty == true
        ? profile!.email.trim()
        : session?.email.trim() ?? '';
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
          : AbundanceHeaderBar(
              appearance: widget.appearance,
              onAppearanceChanged: widget.onAppearanceChanged,
              onSelected: (value) {
                switch (value) {
                  case 'sign_out':
                    widget.onSignOut?.call();
                  case 'tutorial':
                    widget.onReplayTutorial?.call();
                }
              },
            ),
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AbundanceColors.background,
                  image: const DecorationImage(
                    image: AssetImage(abundanceHomeSceneAsset),
                    fit: BoxFit.cover,
                    opacity: .22,
                  ),
                ),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x33080C1C),
                        Color(0xCC080C1C),
                        Color(0xF2080C1C),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: [
              const Text('Character Sheet', style: AbundanceTypography.display),
              const SizedBox(height: 6),
              const Text(
                'Who you are here, and the settings that keep the account yours.',
                style: AbundanceTypography.body,
              ),
              const SizedBox(height: 18),
              AbundanceTutorialTarget(
                name: 'profile-character',
                controller: widget.tutorialController,
                child: _IdentityCard(
                  name: displayName,
                  email: email,
                  profile: profile,
                  profilePhotoOverride: _profilePhotoOverride,
                  onEdit: () => _showEditProfile(context, displayName, profile),
                  onAddProfilePhoto: _pickProfilePhoto,
                  profilePhotoUploading: _profilePhotoUploading,
                  sourceLayout: sourceProfileLayout,
                ),
              ),
              const SizedBox(height: 18),
              if (sourceProfileLayout)
                _SelectedCharacterSection(
                  selected: _selected,
                  isCoach: widget.isCoach || session?.isCoach == true,
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
              AbundanceTutorialTarget(
                name: 'profile-coach',
                controller: widget.tutorialController,
                child: _CoachCard(
                  coachName: _coachName ?? _snapshot?.council?.coachName,
                ),
              ),
              const SizedBox(height: 18),
              AbundanceTutorialTarget(
                name: 'profile-stats',
                controller: widget.tutorialController,
                child: _ProgressionCard(progression: profile?.progression),
              ),
              const SizedBox(height: 18),
              _EarnedBadgesCard(
                achievements: _snapshot?.achievements ?? const [],
                loading: _profileLoading,
                hasError: _profileError != null,
                onRetry: _loadProfile,
                onOpenAchievements: widget.onOpenAchievements,
              ),
              const SizedBox(height: 18),
              if (sourceProfileLayout) ...[
                _EditProfileCard(
                  profile: profile,
                  name: displayName,
                  onSaved: _loadProfile,
                  service: _profileGateway,
                ),
                const SizedBox(height: 18),
                _ChangePasswordCard(service: _profileGateway),
                const SizedBox(height: 18),
                AbundanceTutorialTarget(
                  name: 'profile-settings',
                  controller: widget.tutorialController,
                  child: _AppearanceCard(
                    appearance: widget.appearance,
                    onChanged: widget.onAppearanceChanged,
                    onSignOut: widget.onSignOut,
                    onReplayTutorial: widget.onReplayTutorial,
                  ),
                ),
                const SizedBox(height: 18),
                _DeleteAccountCard(service: _profileGateway),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showEditProfile(
    BuildContext context,
    String displayName,
    AbundanceProfile? profile,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AbundanceColors.surfaceRaised,
      builder: (_) => _EditProfileSheet(
        name: displayName,
        profile: profile,
        service: _profileGateway,
        onSaved: _loadProfile,
      ),
    );
  }

  Future<void> _showCharacterPicker(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AbundanceColors.lightAppearanceActive
          ? const Color(0xFFF2ECCE)
          : AbundanceColors.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        final content = SafeArea(
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
                                child: AbundanceArtwork(
                                  child: Image.asset(
                                    abundanceCharacterAsset(character)!,
                                    fit: BoxFit.contain,
                                  ),
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
        );
        return AbundanceColors.lightAppearanceActive
            ? ColorFiltered(
                colorFilter: AbundanceColors.restoreArtworkColorFilter,
                child: content,
              )
            : content;
      },
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.name,
    required this.email,
    this.profile,
    this.profilePhotoOverride,
    this.onEdit,
    this.onAddProfilePhoto,
    this.profilePhotoUploading = false,
    this.sourceLayout = true,
  });

  final String name;
  final String email;
  final AbundanceProfile? profile;
  final String? profilePhotoOverride;
  final VoidCallback? onEdit;
  final VoidCallback? onAddProfilePhoto;
  final bool profilePhotoUploading;
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
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AbundanceColors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AbundanceColors.border),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AbundanceArtwork(
              child: Opacity(
                opacity: .36,
                child: Image.asset(
                  abundanceHomeSceneAsset,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
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
                          child: (profilePhotoOverride ?? profile?.avatarUrl)
                                      ?.startsWith('https://') ==
                                  true
                              ? AbundanceArtwork(
                                  child: ClipOval(
                                    child: Image.network(
                                      profilePhotoOverride ??
                                          profile!.avatarUrl!,
                                      width: 84,
                                      height: 84,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _initials(initials),
                                    ),
                                  ),
                                )
                              : _initials(initials),
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
                                    color: AbundanceColors.primaryGold,
                                    width: 2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Transform.rotate(
                                angle: -math.pi / 4,
                                child: Center(
                                  child: Text(
                                    '${profile?.progression?.level ?? 0}',
                                    style: AbundanceTypography.title,
                                  ),
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
                              style: AbundanceTypography.display
                                  .copyWith(fontSize: 26)),
                          const SizedBox(height: 2),
                          Text(
                            profile?.progression?.rank.toUpperCase() ?? '—',
                            style: AbundanceTypography.title,
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value:
                                  ((profile?.progression?.lifePower ?? 0) / 100)
                                      .clamp(0, 1)
                                      .toDouble(),
                              minHeight: 9,
                              backgroundColor: AbundanceColors.border,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  AbundanceColors.accentCyan),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Level ${profile?.progression?.level ?? 0}',
                            style: AbundanceTypography.body,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: profilePhotoUploading ? null : onAddProfilePhoto,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: AbundanceColors.primaryGold,
                    backgroundColor: AbundanceColors.surfaceRaised,
                    side: const BorderSide(color: AbundanceColors.primaryGold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: profilePhotoUploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add profile photo'),
                ),
                const SizedBox(height: 18),
                if (email.isNotEmpty)
                  Text(email, style: AbundanceTypography.body),
                const SizedBox(height: 14),
                Text(
                  profile?.joinedAt == null
                      ? 'Joined date unavailable'
                      : 'Joined ${_formatDate(profile!.joinedAt!)}',
                  style: AbundanceTypography.body,
                ),
                const SizedBox(height: 14),
                Text(profile?.headline ?? 'No headline yet',
                    style: AbundanceTypography.body),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) =>
      '${value.month}/${value.day}/${value.year}';

  Widget _initials(String initials) => Center(
        child: Text(
          initials.isEmpty ? '?' : initials,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
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
  const _EditProfileCard({
    required this.name,
    required this.profile,
    required this.service,
    required this.onSaved,
  });

  final String name;
  final AbundanceProfile? profile;
  final AbundanceProfileService service;
  final Future<void> Function() onSaved;

  @override
  Widget build(BuildContext context) {
    return _ProfileSectionCard(
      title: 'Edit profile',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Timezone: ${profile?.timezone.isNotEmpty == true ? profile!.timezone : 'Not set'}',
            style: AbundanceTypography.body,
          ),
          const SizedBox(height: 14),
          _GoldOutlineButton(
            label: 'Edit details',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: AbundanceColors.surfaceRaised,
              builder: (_) => _EditProfileSheet(
                name: name,
                profile: profile,
                service: service,
                onSaved: onSaved,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({
    required this.name,
    required this.profile,
    required this.service,
    required this.onSaved,
  });

  final String name;
  final AbundanceProfile? profile;
  final AbundanceProfileService service;
  final Future<void> Function() onSaved;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final _firstName = TextEditingController(text: _namePart(0));
  late final _lastName = TextEditingController(text: _namePart(1));
  late final _headline =
      TextEditingController(text: widget.profile?.headline ?? '');
  late final _bio = TextEditingController(text: widget.profile?.bio ?? '');
  late final _timezone =
      TextEditingController(text: widget.profile?.timezone ?? '');
  late final _avatarUrl =
      TextEditingController(text: widget.profile?.avatarUrl ?? '');
  bool _saving = false;

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
                decoration: _abundanceInputDecoration(),
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
              onPressed: _saving ? null : _save,
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

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.service.updateProfile(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        headline: _headline.text.trim(),
        bio: _bio.text.trim(),
        timezone: _timezone.text.trim(),
        avatarUrl:
            _avatarUrl.text.trim().isEmpty ? null : _avatarUrl.text.trim(),
      );
      await widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save profile.')),
      );
    }
  }
}

class _ChangePasswordCard extends StatefulWidget {
  const _ChangePasswordCard({required this.service});

  final AbundanceProfileService service;

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
            onPressed: () async {
              if (_next.text.isEmpty || _next.text != _confirm.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match.')),
                );
                return;
              }
              try {
                await widget.service.changePassword(
                  currentPassword: _current.text,
                  newPassword: _next.text,
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password changed.')),
                );
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Unable to change password.')),
                );
              }
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
            decoration: _abundanceInputDecoration(),
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

  @override
  void didUpdateWidget(covariant _AppearanceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appearance != widget.appearance &&
        const ['light', 'dark', 'system'].contains(widget.appearance)) {
      _selected = widget.appearance;
    }
  }

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
                      backgroundColor: AbundanceColors.surfaceRaised,
                      foregroundColor: AbundanceColors.foreground,
                      side: BorderSide(
                        color: _selected == option
                            ? AbundanceColors.primaryGold
                            : AbundanceColors.border,
                      ),
                    ),
                    child: Text(
                      option[0].toUpperCase() + option.substring(1),
                      style: AbundanceTypography.body.copyWith(
                        color: AbundanceColors.foreground,
                      ),
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
  const _DeleteAccountCard({required this.service});

  final AbundanceProfileService service;

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
                onPressed: () async {
                  try {
                    await service.deleteAccount();
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  } catch (_) {
                    if (!dialogContext.mounted) return;
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                          content: Text('Unable to delete account.')),
                    );
                  }
                },
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
            disabledBackgroundColor:
                AbundanceColors.primaryGold.withValues(alpha: .55),
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
            backgroundColor: AbundanceColors.surfaceRaised,
            side: const BorderSide(color: AbundanceColors.primaryGold),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
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
                    child: AbundanceArtwork(
                      child: Image.asset(abundanceCharacterAsset(character)!,
                          fit: BoxFit.contain),
                    ),
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

InputDecoration _abundanceInputDecoration() => InputDecoration(
      filled: true,
      fillColor: AbundanceColors.surfaceSunken,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AbundanceColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AbundanceColors.primaryGold),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AbundanceColors.border),
      ),
    );

class _SelectedCharacterSection extends StatelessWidget {
  const _SelectedCharacterSection(
      {required this.selected, required this.isCoach, required this.onChoose});

  final String selected;
  final bool isCoach;
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
                child: AbundanceArtwork(
                  child: Image.asset(abundanceCharacterAsset(selected)!,
                      fit: BoxFit.contain),
                ),
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
              backgroundColor: AbundanceColors.surfaceRaised,
              side: const BorderSide(color: AbundanceColors.primaryGold),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Choose your character'),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            children: [
              _RoleChip(label: 'STUDENT'),
              if (isCoach) _RoleChip(label: 'COACH'),
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
          backgroundColor: AbundanceColors.surfaceRaised,
          side: const BorderSide(color: AbundanceColors.primaryGold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(label),
      );
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({this.coachName});

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
              const Text('Your coach', style: AbundanceTypography.title),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'The coach assigned to guide your Abundance journey.',
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
            child: coachName == null || coachName!.trim().isEmpty
                ? const Text(
                    'No coach assigned yet. Your admin will assign one to you.',
                    style: AbundanceTypography.body,
                  )
                : Text(coachName!, style: AbundanceTypography.title),
          ),
        ],
      ),
    );
  }
}

class _ProgressionCard extends StatelessWidget {
  const _ProgressionCard({required this.progression});

  final AbundanceProgression? progression;

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
                    Text('LEVEL ${progression?.level ?? 0}',
                        style: AbundanceTypography.eyebrow),
                    const SizedBox(height: 4),
                    Text(progression?.rank.toUpperCase() ?? '—',
                        style: AbundanceTypography.display),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: ((progression?.lifePower ?? 0) / 100)
                            .clamp(0, 1)
                            .toDouble(),
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
              _LifePowerRing(value: progression?.lifePower ?? 0),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child: _ProfileStat(
                      value: '${progression?.stats['goalsTotal'] ?? 0}',
                      label: 'Quests')),
              SizedBox(width: 8),
              Expanded(
                  child: _ProfileStat(
                      value: '${progression?.stats['goalsCompleted'] ?? 0}',
                      label: 'Completed')),
              SizedBox(width: 8),
              Expanded(
                  child: _ProfileStat(
                      value: '${progression?.stats['currentStreak'] ?? 0}',
                      label: 'Day streak')),
            ],
          ),
        ],
      ),
    );
  }
}

class _LifePowerRing extends StatelessWidget {
  const _LifePowerRing({required this.value});

  final num value;

  @override
  Widget build(BuildContext context) {
    final progress = (value / 100).clamp(0, 1).toDouble();
    return SizedBox(
      width: 96,
      height: 96,
      child: CustomPaint(
        painter: _LifePowerRingPainter(progress),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$value%', style: AbundanceTypography.title),
              Text('of 100',
                  style: AbundanceTypography.body.copyWith(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LifePowerRingPainter extends CustomPainter {
  const _LifePowerRingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 7;
    final track = Paint()
      ..color = AbundanceColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7;
    final fill = Paint()
      ..color = AbundanceColors.primaryGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _LifePowerRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
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
  const _EarnedBadgesCard({
    required this.achievements,
    required this.loading,
    required this.hasError,
    required this.onRetry,
    required this.onOpenAchievements,
  });

  final List<AbundanceProfileAchievement> achievements;
  final bool loading;
  final bool hasError;
  final Future<void> Function() onRetry;
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
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(
                    color: AbundanceColors.primaryGold),
              ),
            )
          else if (hasError)
            AbundanceButton(
                label: 'Retry', icon: Icons.refresh, onPressed: onRetry)
          else if (achievements.isEmpty)
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
            )
          else
            SizedBox(
              height: 170,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: achievements.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final achievement = achievements[index];
                  final definition = abundanceAchievementDefinitions
                      .where((item) => item.key == achievement.key)
                      .firstOrNull;
                  final assetKey = achievement.art ??
                      definition?.assetKey ??
                      achievement.name.toLowerCase().replaceAll(' ', '-');
                  final asset = abundanceAchievementAssets[assetKey] ??
                      abundanceAchievementAssets[achievement.key] ??
                      abundanceAchievementAssets[
                          achievement.name.toLowerCase().replaceAll(' ', '-')];
                  return SizedBox(
                    width: 150,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          Expanded(
                            child: asset == null
                                ? const Icon(Icons.workspace_premium,
                                    color: AbundanceColors.primaryGold,
                                    size: 48)
                                : AbundanceArtwork(
                                    child:
                                        Image.asset(asset, fit: BoxFit.contain),
                                  ),
                          ),
                          Text(achievement.name,
                              style: AbundanceTypography.body,
                              textAlign: TextAlign.center),
                          Text(
                              achievement.unlockedAt == null
                                  ? 'UNLOCKED'
                                  : 'Earned ${achievement.unlockedAt!.month}/${achievement.unlockedAt!.day}/${achievement.unlockedAt!.year}',
                              style: AbundanceTypography.body
                                  .copyWith(fontSize: 11),
                              textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  );
                },
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
