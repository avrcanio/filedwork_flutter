import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Jedna GeoJSON feature stavke rada (transformirana u WGS84 na backendu).
class WorkItemGeoFeature {
  const WorkItemGeoFeature({
    required this.id,
    required this.geomType,
    required this.polygons,
    required this.lines,
    this.operationTypeId,
    this.operationTypeName = '',
    this.roadSection = '',
    this.quantity = 0,
  });

  final int id;
  final String geomType;

  /// Lista prstenova za poligone (svaki prsten = lista točaka).
  final List<List<LatLng>> polygons;

  /// Lista linija (svaka linija = lista točaka).
  final List<List<LatLng>> lines;

  final int? operationTypeId;
  final String operationTypeName;
  final String roadSection;
  final double quantity;

  Iterable<LatLng> get allPoints sync* {
    for (final ring in polygons) {
      yield* ring;
    }
    for (final line in lines) {
      yield* line;
    }
  }

  static List<WorkItemGeoFeature> listFromFeatureCollection(
    Map<String, dynamic> json,
  ) {
    final features = (json['features'] as List?) ?? const [];
    final result = <WorkItemGeoFeature>[];
    for (final raw in features) {
      final feature = raw as Map<String, dynamic>;
      final geometry = feature['geometry'] as Map<String, dynamic>?;
      if (geometry == null) continue;
      final props = (feature['properties'] as Map<String, dynamic>?) ?? const {};
      final type = geometry['type'] as String? ?? '';
      final coords = geometry['coordinates'];

      final polygons = <List<LatLng>>[];
      final lines = <List<LatLng>>[];
      _parseGeometry(type, coords, polygons, lines);

      result.add(
        WorkItemGeoFeature(
          id: (feature['id'] as num?)?.toInt() ??
              (props['id'] as num?)?.toInt() ??
              0,
          geomType: type,
          polygons: polygons,
          lines: lines,
          operationTypeId: (props['operation_type_id'] as num?)?.toInt(),
          operationTypeName: props['operation_type'] as String? ?? '',
          roadSection: props['road_section'] as String? ?? '',
          quantity: (props['quantity'] as num?)?.toDouble() ?? 0,
        ),
      );
    }
    return result;
  }

  static void _parseGeometry(
    String type,
    dynamic coords,
    List<List<LatLng>> polygons,
    List<List<LatLng>> lines,
  ) {
    switch (type) {
      case 'Polygon':
        polygons.addAll(_rings(coords));
        break;
      case 'MultiPolygon':
        for (final poly in (coords as List)) {
          polygons.addAll(_rings(poly));
        }
        break;
      case 'LineString':
        lines.add(_points(coords));
        break;
      case 'MultiLineString':
        for (final line in (coords as List)) {
          lines.add(_points(line));
        }
        break;
      case 'Point':
        lines.add([_point(coords)]);
        break;
    }
  }

  static List<List<LatLng>> _rings(dynamic coords) {
    return (coords as List).map((ring) => _points(ring)).toList();
  }

  static List<LatLng> _points(dynamic coords) {
    return (coords as List).map((c) => _point(c)).toList();
  }

  /// GeoJSON je [lng, lat].
  static LatLng _point(dynamic c) {
    final list = c as List;
    return LatLng((list[1] as num).toDouble(), (list[0] as num).toDouble());
  }
}
