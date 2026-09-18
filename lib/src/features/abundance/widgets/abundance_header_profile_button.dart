import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_assets.dart';
import 'package:selfcare_projects/src/services/auth_service.dart';
import 'package:selfcare_projects/src/services/profile_picture_bus.dart';

/// The persistent A12 brand bar shown above member pages in the source app.
/// It is kept as a reusable widget so nested A12 routes do not fall back to
/// InnerU's generic page AppBar.
class AbundanceHeaderBar extends StatelessWidget
    implements PreferredSizeWidget {
  const AbundanceHeaderBar({
    super.key,
    this.onNotifications,
    this.onMenu,
    this.onSelected,
    this.appearance = 'dark',
    this.onAppearanceChanged,
  });

  final VoidCallback? onNotifications;
  final VoidCallback? onMenu;
  final ValueChanged<String>? onSelected;
  final String appearance;
  final ValueChanged<String>? onAppearanceChanged;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final session = AuthService.instance.currentSession;
    final name = session?.name.trim() ?? '';
    final initials = name.isEmpty
        ? 'A'
        : name
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .take(2)
            .map((part) => part[0].toUpperCase())
            .join();
    return AppBar(
      backgroundColor: AbundanceColors.surfaceRaised,
      foregroundColor: AbundanceColors.foreground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: 72,
      titleSpacing: 18,
      title: Row(children: [
        AbundanceArtwork(
          child: Image.asset(abundanceLogoAsset, width: 42, height: 38),
        ),
        const SizedBox(width: 9),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ABUNDANCE 12',
                  style: TextStyle(
                      color: AbundanceColors.foreground,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6)),
              Text('THE GAME OF MY LIFE',
                  style: TextStyle(
                      color: AbundanceColors.primaryGold,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2)),
            ],
          ),
        ),
      ]),
      actions: [
        InkWell(
          onTap: onNotifications,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AbundanceColors.border)),
            child: const Icon(Icons.notifications_none,
                color: AbundanceColors.muted, size: 21),
          ),
        ),
        const SizedBox(width: 10),
        ValueListenableBuilder<String?>(
          valueListenable: ProfilePictureBus.latestUrl,
          builder: (context, latestUrl, _) => AbundanceHeaderProfileButton(
            initials: initials,
            profilePic: latestUrl ?? session?.profilePic ?? '',
            displayName: session?.name ?? '',
            email: session?.email ?? '',
            appearance: appearance,
            onAppearanceChanged: onAppearanceChanged,
            onSelected: (value) {
              if (onSelected != null) {
                onSelected!(value);
                return;
              }
              if (value == 'notifications') onNotifications?.call();
              if (value == 'more') onMenu?.call();
            },
          ),
        ),
        const SizedBox(width: 10),
      ],
    );
  }
}

/// Compact A12 header profile control used only by the Abundance shell.
///
/// The reference app uses a 32px avatar with a chevron and opens an anchored
/// profile menu. Keeping the menu here avoids relying on route-level pop calls
/// (which can accidentally close the whole shell instead of the menu).
class AbundanceHeaderProfileButton extends StatelessWidget {
  const AbundanceHeaderProfileButton({
    super.key,
    required this.initials,
    required this.profilePic,
    this.displayName = '',
    this.email = '',
    this.roleLabel = 'Student',
    this.appearance = 'dark',
    this.onAppearanceChanged,
    required this.onSelected,
  });

  final String initials;
  final String profilePic;
  final String displayName;
  final String email;
  final String roleLabel;
  final String appearance;
  final ValueChanged<String>? onAppearanceChanged;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      key: const ValueKey('abundance-header-profile-menu'),
      tooltip: 'Open profile menu',
      padding: EdgeInsets.zero,
      offset: const Offset(0, 8),
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      // Keep the PopupMenuButton in the tree for existing accessibility and
      // widget-test semantics, but replace its tiny native menu with the
      // anchored A12 profile overlay used by the reference app.
      onOpened: () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          Navigator.of(context).pop();
          _showProfileOverlay(context);
        });
      },
      itemBuilder: (_) => const [
        PopupMenuItem<String>(
          value: 'profile_overlay_placeholder',
          enabled: false,
          height: 1,
          child: SizedBox.shrink(),
        ),
      ],
      child: Semantics(
        button: true,
        label: 'Open profile menu',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AbundanceColors.primaryGold,
              ),
              child: profilePic.isNotEmpty
                  ? AbundanceArtwork(
                      child: CircleAvatar(
                        radius: 15,
                        backgroundColor: AbundanceColors.accentCyan,
                        backgroundImage: NetworkImage(profilePic),
                      ),
                    )
                  : CircleAvatar(
                      radius: 15,
                      backgroundColor: AbundanceColors.accentCyan,
                      child: _Initials(initials),
                    ),
            ),
            const SizedBox(width: 5),
            const Icon(
              Icons.keyboard_arrow_down,
              color: AbundanceColors.muted,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileOverlay(BuildContext context) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss profile menu',
      barrierColor: Colors.black.withValues(alpha: .70),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, _, __) {
        final media = MediaQuery.of(dialogContext);
        final cardWidth = (media.size.width - 24).clamp(0.0, 360.0);
        // Keep the full action list reachable on compact test/simulator
        // viewports while still capping the menu on larger devices.
        final maxHeight = (media.size.height - 24).clamp(220.0, 760.0);
        return SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 12, right: 12, left: 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: cardWidth,
                  minWidth: cardWidth,
                  maxHeight: maxHeight,
                ),
                child: Material(
                  color: AbundanceColors.surfaceRaised,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AbundanceColors.border),
                  ),
                  child: _ProfileOverlayContent(
                    displayName: displayName.isEmpty ? initials : displayName,
                    email: email,
                    roleLabel: roleLabel,
                    initialAppearance: appearance,
                    onAppearanceChanged: onAppearanceChanged,
                    onSelected: (value) {
                      Navigator.of(dialogContext).pop();
                      // Let the overlay finish its exit transition before
                      // pushing another route or opening the More sheet.
                      // Starting either action synchronously races the dialog
                      // pop and makes Notifications/More appear unresponsive.
                      Future<void>.delayed(const Duration(milliseconds: 200),
                          () {
                        if (context.mounted) onSelected(value);
                      });
                    },
                    onClose: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProfileOverlayContent extends StatefulWidget {
  const _ProfileOverlayContent({
    required this.displayName,
    required this.email,
    required this.roleLabel,
    required this.initialAppearance,
    required this.onAppearanceChanged,
    required this.onSelected,
    required this.onClose,
  });

  final String displayName;
  final String email;
  final String roleLabel;
  final String initialAppearance;
  final ValueChanged<String>? onAppearanceChanged;
  final ValueChanged<String> onSelected;
  final VoidCallback onClose;

  @override
  State<_ProfileOverlayContent> createState() => _ProfileOverlayContentState();
}

class _ProfileOverlayContentState extends State<_ProfileOverlayContent> {
  static const _appearanceKey = 'abundance-appearance';
  late String _appearance = widget.initialAppearance;

  @override
  void initState() {
    super.initState();
    _loadAppearance();
  }

  Future<void> _loadAppearance() async {
    final saved =
        (await SharedPreferences.getInstance()).getString(_appearanceKey);
    if (!mounted ||
        saved == null ||
        !const ['light', 'dark', 'system'].contains(saved)) {
      return;
    }
    setState(() => _appearance = saved);
  }

  void _setAppearance(String option) {
    setState(() => _appearance = option);
    widget.onAppearanceChanged?.call(option);
    unawaited(_persistAppearance(option));
  }

  Future<void> _persistAppearance(String option) async {
    await (await SharedPreferences.getInstance())
        .setString(_appearanceKey, option);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: widget.onClose,
              child: const Text(
                'Close ×',
                style: TextStyle(
                  color: AbundanceColors.foreground,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          Text(
            widget.displayName,
            style: const TextStyle(
              color: AbundanceColors.foreground,
              fontFamily: 'serif',
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (widget.email.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.email,
              style: const TextStyle(
                color: AbundanceColors.muted,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: AbundanceColors.border),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              widget.roleLabel,
              style: const TextStyle(
                color: AbundanceColors.muted,
                fontSize: 12,
              ),
            ),
          ),
          const _OverlayDivider(),
          const Text('Navigation', style: _OverlayLabelStyle()),
          _OverlayAction(
            icon: Icons.notifications_none,
            label: 'Notifications',
            onTap: () => widget.onSelected('notifications'),
          ),
          const _OverlayDivider(),
          const Text('Appearance', style: _OverlayLabelStyle()),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final option in const ['light', 'dark', 'system']) ...[
                if (option != 'light') const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _setAppearance(option),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 42),
                      side: BorderSide(
                        color: _appearance == option
                            ? AbundanceColors.primaryGold
                            : AbundanceColors.border,
                      ),
                      backgroundColor: _appearance == option
                          ? AbundanceColors.primaryGold.withValues(alpha: .12)
                          : Colors.transparent,
                    ),
                    child: Text(
                      option[0].toUpperCase() + option.substring(1),
                      style: TextStyle(
                        color: _appearance == option
                            ? AbundanceColors.primaryGold
                            : AbundanceColors.muted,
                        fontSize: 12,
                        fontWeight: _appearance == option
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const _OverlayDivider(),
          _OverlayAction(
            icon: Icons.menu_book_outlined,
            label: 'Replay tutorial',
            onTap: () => widget.onSelected('tutorial'),
          ),
          _OverlayAction(
            icon: Icons.account_circle_outlined,
            label: 'Profile & settings',
            onTap: () => widget.onSelected('profile'),
          ),
          _OverlayAction(
            icon: Icons.logout_outlined,
            label: 'Sign out',
            onTap: () => widget.onSelected('sign_out'),
          ),
        ],
      ),
    );
  }
}

class _OverlayDivider extends StatelessWidget {
  const _OverlayDivider();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Divider(color: AbundanceColors.border, height: 1),
      );
}

class _OverlayLabelStyle extends TextStyle {
  const _OverlayLabelStyle()
      : super(color: AbundanceColors.muted, fontSize: 14);
}

class _OverlayAction extends StatelessWidget {
  const _OverlayAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: AbundanceColors.muted, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AbundanceColors.muted,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _Initials extends StatelessWidget {
  const _Initials(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        value,
        maxLines: 1,
        style: const TextStyle(
          color: AbundanceColors.surfaceSunken,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
