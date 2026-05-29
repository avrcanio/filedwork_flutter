import 'package:flutter/material.dart';

/// Boja i prikaz badge-a za status radnog naloga.
class WorkOrderStatusChip extends StatelessWidget {
  const WorkOrderStatusChip({
    super.key,
    required this.status,
    required this.label,
  });

  final String status;
  final String label;

  Color _color() {
    switch (status) {
      case 'approved':
        return const Color(0xFF2563EB);
      case 'in_progress':
        return const Color(0xFFCA8A04);
      case 'completed':
        return const Color(0xFF059669);
      case 'cancelled':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label.isEmpty ? status : label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
