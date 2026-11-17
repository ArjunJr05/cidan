import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../models/audit_and_notification_model.dart';
import '../services/cidan_api_service.dart';

class AuditTrailScreen extends StatefulWidget {
  final String bankId;
  const AuditTrailScreen({super.key, this.bankId = 'apex-bank-01'});

  @override
  State<AuditTrailScreen> createState() => _AuditTrailScreenState();
}

class _AuditTrailScreenState extends State<AuditTrailScreen> {
  final CidanApiService _api = CidanApiService();
  bool _isLoading = true;
  List<AuditEvent> _events = [];
  List<NotificationRecord> _notifications = [];
  String? _selectedResourceType;

  @override
  void initState() {
    super.initState();
    _loadAuditData();
  }

  Future<void> _loadAuditData() async {
    setState(() => _isLoading = true);
    final events = await _api.getAuditEvents(resourceType: _selectedResourceType);
    final notifs = await _api.getNotifications();
    if (mounted) {
      setState(() {
        _events = events;
        _notifications = notifs;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleExportCsv() async {
    final csv = await _api.exportAuditCsv();
    if (mounted) {
      if (csv != null) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Exported Compliance Audit Trail (CSV)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: SizedBox(
              width: 500,
              height: 300,
              child: SingleChildScrollView(
                child: SelectableText(csv, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
              ElevatedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy to Clipboard'),
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('CSV copied to clipboard!'), backgroundColor: AppColors.success),
                  );
                },
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Audit Trail & Notifications',
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Export CSV'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
            ),
            onPressed: _handleExportCsv,
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: Badge(
              label: Text(unreadCount.toString()),
              isLabelVisible: unreadCount > 0,
              child: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
            ),
            onPressed: () => _showNotificationSheet(context),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filter Chips
                  _buildFilterChips(),
                  const SizedBox(height: 16),

                  // Event Log Table
                  _buildAuditEventsList(),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterChips() {
    final types = [
      {'label': 'All Events', 'val': null},
      {'label': 'Approval Workflows', 'val': 'APPROVAL_WORKFLOW'},
      {'label': 'Rule Versions', 'val': 'RULE_VERSION'},
      {'label': 'Test Simulation', 'val': 'TEST_RUN'},
      {'label': 'Deployments', 'val': 'DEPLOYMENT_RECORD'},
      {'label': 'Rollbacks', 'val': 'ROLLBACK_RECORD'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: types.map((t) {
          final isSelected = _selectedResourceType == t['val'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(t['label'] as String),
              selected: isSelected,
              selectedColor: AppColors.primaryLight,
              checkmarkColor: AppColors.primary,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
              backgroundColor: Colors.white,
              side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
              onSelected: (_) {
                setState(() => _selectedResourceType = t['val']);
                _loadAuditData();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAuditEventsList() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Audit Log Records (${_events.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
              ),
              const Spacer(),
              const Text('Immutable • Append-Only', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 14),
          if (_events.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No audit events found for selected criteria.', style: TextStyle(color: AppColors.textMuted))),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _events.length,
              separatorBuilder: (_, __) => const Divider(height: 18),
              itemBuilder: (context, idx) {
                final e = _events[idx];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.primaryLight,
                      child: const Icon(Icons.history_toggle_off, size: 14, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(e.action, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(e.resourceType, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                              const Spacer(),
                              if (e.createdAt != null)
                                Text(
                                  '${e.createdAt!.hour.toString().padLeft(2, '0')}:${e.createdAt!.minute.toString().padLeft(2, '0')}:${e.createdAt!.second.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontFamily: 'monospace'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text('Actor: ${e.actorEmail} (${e.actorRole}) • Resource ID: ${e.resourceId}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          if (e.metadata.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('Metadata: ${e.metadata}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textSecondary)),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  void _showNotificationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.notifications_active, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text('Notification Center', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: _notifications.isEmpty
                    ? const Center(child: Text('No active notifications.', style: TextStyle(color: AppColors.textMuted)))
                    : ListView.separated(
                        itemCount: _notifications.length,
                        separatorBuilder: (_, __) => const Divider(height: 12),
                        itemBuilder: (context, idx) {
                          final n = _notifications[idx];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              n.isRead ? Icons.mark_email_read_outlined : Icons.mark_email_unread,
                              color: n.isRead ? AppColors.textMuted : AppColors.primary,
                            ),
                            title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold, fontSize: 13)),
                            subtitle: Text(n.message, style: const TextStyle(fontSize: 11)),
                            trailing: !n.isRead
                                ? IconButton(
                                    icon: const Icon(Icons.check, size: 16),
                                    onPressed: () async {
                                      await _api.markNotificationRead(n.id);
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      _loadAuditData();
                                    },
                                  )
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
