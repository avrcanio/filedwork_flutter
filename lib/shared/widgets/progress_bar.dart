import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Progress bar napretka izvršenja stavke s postotkom.
class ExecutionProgressBar extends StatelessWidget {
  const ExecutionProgressBar({
    super.key,
    required this.percent,
    this.height = 8,
    this.showLabel = true,
  });

  final double percent;
  final double height;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final clamped = (percent / 100).clamp(0.0, 1.0);
    final color = clamped >= 1.0 ? AppColors.emerald : AppColors.emeraldLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: LinearProgressIndicator(
            value: clamped,
            minHeight: height,
            backgroundColor: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 4),
          Text(
            '${percent.toStringAsFixed(0)}%',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ],
    );
  }
}
