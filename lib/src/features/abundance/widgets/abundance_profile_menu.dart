import 'package:flutter/material.dart';

import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';

/// A12's header identity control.  It deliberately owns the menu presentation
/// instead of using the platform popup so the mobile layout is identical on
/// iOS and Android and remains isolated to the Abundance shell.
class AbundanceProfileMenuButton extends StatelessWidget {
  const AbundanceProfileMenuButton({
    super.key,
    required this.displayName,
    this.email = '',
    this.roleLabel = 'Student',
    this.profilePic = '',
    this.onNotifications,
    this.onProfile,
    this.onReplayTutorial,
    this.onSignOut,
  });

  final String displayName;
  final String email;
  final String roleLabel;
  final String profilePic;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfile;
  final VoidCallback? onReplayTutorial;
  final VoidCallback? onSignOut;

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'))
      ..removeWhere((part) => part.isEmpty);
    if (parts.isEmpty) return 'AM';
    return parts.take(2).map((part) => part[0]).join().toUpperCase();
  }

  Future<void> _openMenu(BuildContext context) async {
    await showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Profile menu',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: .72),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final size = MediaQuery.sizeOf(dialogContext);
        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 94, 12, 18),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 430,
                  maxHeight: size.height - 112,
                ),
                child: Material(
                  color: AbundanceColors.surfaceRaised,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                    side: const BorderSide(color: AbundanceColors.borderStrong),
                  ),
                  child: _ProfileMenuContent(
                    displayName: displayName,
                    email: email,
                    roleLabel: roleLabel,
                    onNotifications: () {
                      Navigator.of(dialogContext).pop();
                      onNotifications?.call();
                    },
                    onProfile: () {
                      Navigator.of(dialogContext).pop();
                      onProfile?.call();
                    },
                    onReplayTutorial: () {
                      Navigator.of(dialogContext).pop();
                      onReplayTutorial?.call();
                    },
                    onSignOut: () {
                      Navigator.of(dialogContext).pop();
                      onSignOut?.call();
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOut);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: .97, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Profile menu',
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => _openMenu(context),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(1.5),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AbundanceColors.primaryGold,
              ),
              child: ClipOval(
                child: profilePic.isNotEmpty
                    ? Image.network(profilePic, fit: BoxFit.cover)
                    : ColoredBox(
                        color: AbundanceColors.accentCyan,
                        child: Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: AbundanceColors.surfaceSunken,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 3),
            const Icon(
              Icons.keyboard_arrow_down,
              color: AbundanceColors.mutedStrong,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenuContent extends StatefulWidget {
  const _ProfileMenuContent({
    required this.displayName,
    required this.email,
    required this.roleLabel,
    required this.onNotifications,
    required this.onProfile,
    required this.onReplayTutorial,
    required this.onSignOut,
  });

  final String displayName;
  final String email;
  final String roleLabel;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;
  final VoidCallback onReplayTutorial;
  final VoidCallback onSignOut;

  @override
  State<_ProfileMenuContent> createState() => _ProfileMenuContentState();
}

class _ProfileMenuContentState extends State<_ProfileMenuContent> {
  String _appearance = 'System';

  @override
  Widget build(BuildContext context) {
    final name =
        widget.displayName.isEmpty ? 'Abundance member' : widget.displayName;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close ×', style: TextStyle(fontSize: 17)),
            ),
          ),
          Text(
            name,
            style: const TextStyle(
              color: AbundanceColors.foreground,
              fontFamily: 'Georgia',
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (widget.email.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(widget.email,
                style: const TextStyle(
                    color: AbundanceColors.mutedStrong, fontSize: 16)),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: AbundanceColors.borderStrong),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(widget.roleLabel,
                style: const TextStyle(
                    color: AbundanceColors.mutedStrong, fontSize: 15)),
          ),
          const _MenuDivider(),
          const Text('Navigation',
              style:
                  TextStyle(color: AbundanceColors.mutedStrong, fontSize: 17)),
          _MenuAction(
              icon: Icons.notifications_none,
              label: 'Notifications',
              onTap: widget.onNotifications),
          const _MenuDivider(),
          const Text('Appearance',
              style:
                  TextStyle(color: AbundanceColors.mutedStrong, fontSize: 17)),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final option in const ['Light', 'Dark', 'System'])
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: option == 'System' ? 0 : 8),
                    child: OutlinedButton(
                      onPressed: () => setState(() => _appearance = option),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: _appearance == option
                                ? AbundanceColors.primaryGold
                                : AbundanceColors.border),
                        foregroundColor: _appearance == option
                            ? AbundanceColors.primaryGold
                            : AbundanceColors.mutedStrong,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(option),
                    ),
                  ),
                ),
            ],
          ),
          const _MenuDivider(),
          _MenuAction(
              icon: Icons.menu_book_outlined,
              label: 'Replay tutorial',
              onTap: widget.onReplayTutorial),
          _MenuAction(
              icon: Icons.account_circle_outlined,
              label: 'Profile & settings',
              onTap: widget.onProfile),
          _MenuAction(
              icon: Icons.logout, label: 'Sign out', onTap: widget.onSignOut),
        ],
      ),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Divider(height: 1, color: AbundanceColors.border),
      );
}

class _MenuAction extends StatelessWidget {
  const _MenuAction(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: AbundanceColors.mutedStrong, size: 27),
        title: Text(label,
            style: const TextStyle(
                color: AbundanceColors.mutedStrong, fontSize: 17)),
        onTap: onTap,
      );
}
