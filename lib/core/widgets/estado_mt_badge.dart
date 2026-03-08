import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Badge que destaca o estado do candidato (MT - Mato Grosso) em toda a aplicação.
class EstadoMTBadge extends StatelessWidget {
  const EstadoMTBadge({
    super.key,
    this.compact = false,
  });

  /// Se true, usa menos padding (ex.: em barras de título).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 10,
      ),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primary.withValues(alpha: 0.6), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on,
            size: compact ? 18 : 20,
            color: primary,
          ),
          SizedBox(width: compact ? 6 : 8),
          Text(
            AppConstants.ufLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: primary,
            ),
          ),
        ],
      ),
    );
  }
}
