import 'package:flutter/material.dart';

/// Paleta boja za vrste operacija na karti — kopija
/// `frontend/lib/workOrderMapColors.ts` radi vizualne konzistentnosti s webom.
const List<Color> kOperationPalette = [
  Color(0xFF2563EB),
  Color(0xFFEA580C),
  Color(0xFF9333EA),
  Color(0xFFDB2777),
  Color(0xFF0891B2),
  Color(0xFF65A30D),
  Color(0xFFCA8A04),
  Color(0xFFDC2626),
  Color(0xFF4F46E5),
  Color(0xFF0D9488),
  Color(0xFFC026D3),
  Color(0xFF57534E),
];

const Color kRoadLineColor = Color(0xFF64748B);
const Color kSelectedItemStroke = Color(0xFF111827);
const Color kFallbackColor = Color(0xFF6B7280);

Color colorForOperationType(int? operationTypeId) {
  if (operationTypeId == null) return kFallbackColor;
  return kOperationPalette[operationTypeId.abs() % kOperationPalette.length];
}
