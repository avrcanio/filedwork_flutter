import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/theme/map_styles.dart';
import '../../core/theme/theme_controller.dart';
import '../../shared/utils/map_colors.dart';
import '../../shared/widgets/async_value_view.dart';
import 'work_item_geo.dart';
import 'work_item_repository.dart';

class WorkItemMapScreen extends ConsumerStatefulWidget {
  const WorkItemMapScreen({
    super.key,
    required this.workOrderId,
    required this.title,
  });

  final int workOrderId;
  final String title;

  @override
  ConsumerState<WorkItemMapScreen> createState() => _WorkItemMapScreenState();
}

class _WorkItemMapScreenState extends ConsumerState<WorkItemMapScreen> {
  GoogleMapController? _controller;
  MapType _mapType = MapType.normal;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _goToMyLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _snack('Lokacijske usluge su isključene.');
      return;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      _snack('Nema dozvole za lokaciju.');
      return;
    }
    final pos = await Geolocator.getCurrentPosition();
    await _controller?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 16),
    );
  }

  ({Set<Polygon> polygons, Set<Polyline> polylines, LatLngBounds? bounds})
      _buildOverlays(List<WorkItemGeoFeature> features) {
    final polygons = <Polygon>{};
    final polylines = <Polyline>{};
    final allPoints = <LatLng>[];

    for (final f in features) {
      final color = colorForOperationType(f.operationTypeId);
      allPoints.addAll(f.allPoints);

      if (f.polygons.isNotEmpty) {
        polygons.add(
          Polygon(
            polygonId: PolygonId('item_${f.id}'),
            points: f.polygons.first,
            holes: f.polygons.length > 1 ? f.polygons.sublist(1) : const [],
            strokeColor: color,
            strokeWidth: 2,
            fillColor: color.withValues(alpha: 0.3),
          ),
        );
      }
      for (var i = 0; i < f.lines.length; i++) {
        polylines.add(
          Polyline(
            polylineId: PolylineId('line_${f.id}_$i'),
            points: f.lines[i],
            color: color,
            width: 4,
          ),
        );
      }
    }

    return (
      polygons: polygons,
      polylines: polylines,
      bounds: _boundsOf(allPoints),
    );
  }

  LatLngBounds? _boundsOf(List<LatLng> points) {
    if (points.isEmpty) return null;
    var minLat = points.first.latitude, maxLat = points.first.latitude;
    var minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      minLat = p.latitude < minLat ? p.latitude : minLat;
      maxLat = p.latitude > maxLat ? p.latitude : maxLat;
      minLng = p.longitude < minLng ? p.longitude : minLng;
      maxLng = p.longitude > maxLng ? p.longitude : maxLng;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  Future<void> _fit(LatLngBounds? bounds) async {
    if (bounds == null || _controller == null) return;
    await Future.delayed(const Duration(milliseconds: 300));
    await _controller!
        .animateCamera(CameraUpdate.newLatLngBounds(bounds, 48));
  }

  @override
  Widget build(BuildContext context) {
    final geojson = ref.watch(workOrderGeojsonProvider(widget.workOrderId));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Drži referencu na temu radi stila karte.
    ref.watch(themeControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Karta — ${widget.title}'),
        actions: [
          PopupMenuButton<MapType>(
            icon: const Icon(Icons.layers_outlined),
            tooltip: 'Tip karte',
            initialValue: _mapType,
            onSelected: (value) => setState(() => _mapType = value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: MapType.normal, child: Text('Normalna')),
              PopupMenuItem(value: MapType.satellite, child: Text('Satelit')),
              PopupMenuItem(value: MapType.hybrid, child: Text('Hibrid')),
            ],
          ),
        ],
      ),
      body: AsyncValueView<List<WorkItemGeoFeature>>(
        value: geojson,
        onRetry: () =>
            ref.invalidate(workOrderGeojsonProvider(widget.workOrderId)),
        data: (features) {
          if (features.isEmpty) {
            return const Center(
              child: Text('Nema geometrije za stavke ovog naloga.'),
            );
          }
          final overlays = _buildOverlays(features);
          final initial = overlays.bounds != null
              ? overlays.bounds!.southwest
              : const LatLng(43.73, 15.9);

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition:
                    CameraPosition(target: initial, zoom: 11),
                polygons: overlays.polygons,
                polylines: overlays.polylines,
                mapType: _mapType,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                style: (_mapType == MapType.normal && isDark)
                    ? kDarkMapStyle
                    : null,
                onMapCreated: (controller) {
                  _controller = controller;
                  _fit(overlays.bounds);
                },
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton(
                  heroTag: 'mapMyLocation',
                  tooltip: 'Moja lokacija',
                  onPressed: _goToMyLocation,
                  child: const Icon(Icons.my_location),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
