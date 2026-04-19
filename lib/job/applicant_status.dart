
// lib/job/application_status.dart
import 'package:flutter/material.dart';

class ApplicationStatusTimeline extends StatelessWidget {
  final String currentStatus;
  final DateTime? appliedAt;
  final DateTime? updatedAt;

  const ApplicationStatusTimeline({
    super.key,
    required this.currentStatus,
    this.appliedAt,
    this.updatedAt,
  });

  @override
  Widget build(BuildContext context) {
    final statuses = ['pending', 'accepted', 'rejected'];
    final currentIndex = statuses.indexOf(currentStatus.toLowerCase());
    final isRejected = currentStatus.toLowerCase() == 'rejected';
    final isAccepted = currentStatus.toLowerCase() == 'accepted';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Application Status',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildTimelineStep(
                step: 1,
                label: 'Applied',
                isCompleted: true,
                isActive: true,
                date: appliedAt,
              ),
              Expanded(
                child: Container(
                  height: 2,
                  color: isRejected
                      ? Colors.red.shade300
                      : (isAccepted ? Colors.green.shade300 : Colors.grey.shade300),
                ),
              ),
              _buildTimelineStep(
                step: 2,
                label: isRejected ? 'Rejected' : 'Reviewed',
                isCompleted: currentIndex >= 0 && !isRejected,
                isActive: currentIndex >= 0,
                date: currentIndex >= 0 ? updatedAt : null,
                isRejected: isRejected,
              ),
              if (!isRejected) ...[
                Expanded(
                  child: Container(
                    height: 2,
                    color: currentIndex >= 1 ? Colors.green.shade300 : Colors.grey.shade300,
                  ),
                ),
                _buildTimelineStep(
                  step: 3,
                  label: 'Hired',
                  isCompleted: currentIndex >= 1,
                  isActive: currentIndex >= 1,
                  date: currentIndex >= 1 ? updatedAt : null,
                ),
              ],
            ],
          ),
          if (isRejected)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your application was not selected for this position. Keep applying for other opportunities!',
                        style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (isAccepted)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Congratulations! Your application has been accepted. The employer will contact you soon.',
                        style: TextStyle(color: Colors.green.shade700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required int step,
    required String label,
    required bool isCompleted,
    required bool isActive,
    DateTime? date,
    bool isRejected = false,
  }) {
    final circleColor = isCompleted
        ? (isRejected ? Colors.red : Colors.green)
        : Colors.grey.shade300;
    final textColor = isCompleted ? (isRejected ? Colors.red : Colors.green) : Colors.grey;

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? Icon(isRejected ? Icons.close : Icons.check, size: 18, color: Colors.white)
                : Text('$step', style: const TextStyle(color: Colors.white)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        if (date != null)
          Text(
            '${date.day}/${date.month}',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          ),
      ],
    );
  }
}

class ApplicationStatusChip extends StatelessWidget {
  final String status;

  const ApplicationStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _getStatusConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 14, color: config.textColor),
          const SizedBox(width: 4),
          Text(
            config.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: config.textColor,
            ),
          ),
        ],
      ),
    );
  }

  _StatusConfig _getStatusConfig(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return _StatusConfig(
          label: 'Pending',
          icon: Icons.access_time,
          backgroundColor: Colors.amber.shade100,
          textColor: Colors.amber.shade800,
        );
      case 'accepted':
        return _StatusConfig(
          label: 'Accepted',
          icon: Icons.check_circle,
          backgroundColor: Colors.green.shade100,
          textColor: Colors.green.shade800,
        );
      case 'rejected':
        return _StatusConfig(
          label: 'Rejected',
          icon: Icons.cancel,
          backgroundColor: Colors.red.shade100,
          textColor: Colors.red.shade800,
        );
      default:
        return _StatusConfig(
          label: status,
          icon: Icons.help_outline,
          backgroundColor: Colors.grey.shade200,
          textColor: Colors.grey.shade700,
        );
    }
  }
}

class _StatusConfig {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color textColor;

  _StatusConfig({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
  });
}
