import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:selfcare_projects/src/features/abundance/services/abundance_notifications_service.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_typography.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_card.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_status_view.dart';

class AbundanceNotificationsScreen extends StatefulWidget {
  const AbundanceNotificationsScreen({super.key, this.gateway});

  final AbundanceNotificationsGateway? gateway;

  @override
  State<AbundanceNotificationsScreen> createState() =>
      _AbundanceNotificationsScreenState();
}

class _AbundanceNotificationsScreenState
    extends State<AbundanceNotificationsScreen> {
  late final AbundanceNotificationsGateway _gateway =
      widget.gateway ?? InnerUAbundanceNotificationsGateway();
  List<AbundanceNotification> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _gateway.load();
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (mounted) setState(() => _error = 'Your updates could not be loaded.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(AbundanceNotification item) async {
    if (item.isRead || item.id.isEmpty) return;
    final index = _items.indexOf(item);
    setState(() => _items[index] = item.copyWith(isRead: true));
    try {
      await _gateway.markRead(item.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _items[index] = item);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('We could not mark that update as read.')),
      );
    }
  }

  Future<void> _markAllRead() async {
    final previous = _items;
    setState(() => _items = _items
        .map((item) => item.copyWith(isRead: true))
        .toList(growable: false));
    try {
      await _gateway.markAllRead();
    } catch (_) {
      if (!mounted) return;
      setState(() => _items = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('We could not mark every update as read.')),
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
        title: const Text('NOTIFICATIONS', style: AbundanceTypography.title),
        actions: [
          TextButton(
            onPressed: _items.isEmpty ? null : _markAllRead,
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_loading) return const AbundanceStatusView.loading();
    if (_error != null) {
      return AbundanceStatusView.error(message: _error!, onRetry: _load);
    }
    if (_items.isEmpty) {
      return const AbundanceStatusView.empty(
        message: 'Your notification hall is quiet.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = _items[index];
          return AbundanceCard(
            child: InkWell(
              onTap: () => _markRead(item),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: item.isRead
                          ? AbundanceColors.border
                          : AbundanceColors.primaryGold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: AbundanceTypography.title),
                        if (item.body.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            item.body,
                            style: AbundanceTypography.body.copyWith(
                              color: AbundanceColors.muted,
                            ),
                          ),
                        ],
                        if (item.createdAt != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            DateFormat('MMM d, h:mm a').format(item.createdAt!),
                            style: AbundanceTypography.eyebrow.copyWith(
                              color: AbundanceColors.muted,
                            ),
                          ),
                        ],
                      ],
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
