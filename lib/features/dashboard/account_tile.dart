import 'package:flutter/material.dart';
import '../accounts/account_model.dart';

class AccountTile extends StatelessWidget {
  final Account account;
  final VoidCallback? onTap;
  final Future<void> Function()? onEdit;
  final Future<void> Function()? onMarkDone;
  final Future<void> Function()? onDelete;

  const AccountTile({
    super.key,
    required this.account,
    this.onTap,
    this.onEdit,
    this.onMarkDone,
    this.onDelete,
  });

  // updated: use status semantics (overdue -> red, pending -> yellow, else blue)
  Color _priorityColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('over')) return Colors.redAccent;
    if (s.contains('pend')) return Colors.amber.shade700;
    return Colors.blueAccent;
  }

  String _formatDate(DateTime? d) {

    if (d == null) return '-';
    try {
      return d.toLocal().toString().split(' ').first;
    } catch (_) {
      return d.toIso8601String();
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = account.computedStatus;
    final effectiveStatus = (account.status ?? status) ?? '';
    final color = _priorityColor(effectiveStatus);

    final now = DateTime.now();
    final due = account.dueDate;
    final daysDiff = due.isBefore(now)
        ? now.difference(due).inDays
        : due.difference(now).inDays;
    final dueLabel =
        due.isBefore(now) ? '$daysDiff days' : '$daysDiff days';

    final nextFollowUpLabel = _formatDate(account.lastContactDate);

    // new: determine overdue text color based on status
    final statusLower = effectiveStatus.toLowerCase();
    final overdueTextColor = statusLower.contains('over')
        ? Colors.redAccent
        : statusLower.contains('pend')
            ? Colors.amber.shade700
            : Colors.blueAccent;

    return Card(
      // make outer spacing even on all sides
      margin: const EdgeInsets.all(12),
      // add an explicit border side so the stroke appears evenly around the rounded corners
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.28), width: 1),
      ),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        // keep ripple/clipping consistent with the card radius
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Name + Priority badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      account.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      account.status ?? status,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Simple inline amount + due label (replaces enlarged box)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    account.amount.toStringAsFixed(2),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    dueLabel,
                    style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Contact info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Next follow-up: $nextFollowUpLabel',
                      style: const TextStyle(color: Colors.black87)),
                  account.isPaid
                      ? const Icon(Icons.check_circle,
                          color: Colors.green, size: 24)
                      : PopupMenuButton<String>(
                          // styled three-dot icon
                          icon: const Icon(Icons.more_vert, color: Colors.black),
                          color: Colors.white,
                          elevation: 6,
                          onSelected: (value) async {
                            // Do not show confirmation here; the caller (dashboard / detail screen)
                            // is responsible for confirming destructive actions. Simply invoke callbacks.
                            if (value == 'done') {
                              if (onMarkDone != null) await onMarkDone!();
                            } else if (value == 'edit') {
                              if (onEdit != null) await onEdit!();
                            } else if (value == 'delete') {
                              if (onDelete != null) await onDelete!();
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'done',
                              child: Row(
                                children: [
                                  Icon(Icons.check, color: Colors.green.shade700),
                                  const SizedBox(width: 10),
                                  Text('Mark as Done', style: TextStyle(color: Colors.green.shade700)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, color: Colors.blueAccent),
                                  const SizedBox(width: 10),
                                  Text('Edit', style: TextStyle(color: Colors.blueAccent)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, color: Colors.red.shade700),
                                  const SizedBox(width: 10),
                                  Text('Delete', style: TextStyle(color: Colors.red.shade700)),
                                ],
                              ),
                            ),
                          ],
                        ),
                ],
              ),

              const SizedBox(height: 5),
            ],
          ),
        ),
      ),
    );
  }
}
