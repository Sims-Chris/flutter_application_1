import 'package:flutter/material.dart';
import 'package:flutter_application_1/widgets/sidebar.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;

class MapSpot {
	final int id;
	final LatLng point;

	MapSpot({required this.id, required this.point});
}

class MapScreen extends StatefulWidget{
	const MapScreen({super.key});

	@override
	State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
	final List<MapSpot> _spots = [];

	final MapController _mapController = MapController();
	

	void _handleMapTap(TapPosition tapPosition, LatLng point){
		debugPrint('Tapped Latitude: ${point.latitude}');
    	debugPrint('Tapped Longitude: ${point.longitude}');

		MapSpot? tappedSpot;

		const distanceCalculator = Distance();

		final currentZoom = _mapController.camera.zoom;

		// Calculate the hitbox, by scaling the meters (size) of the hitbox
		const double baseThresholdMeters = 2000; // May need fine tuning
		const double baseZoomLevel = 9.2;

		final double hitThresholdMeters = baseThresholdMeters * math.pow(2, baseZoomLevel - currentZoom);


		for (final spot in _spots){
			final double distanceMeters = distanceCalculator.distance(point, spot.point);

			if (distanceMeters < hitThresholdMeters){
				tappedSpot = spot;
				break; // clicked on a marker
			}
		}
		
		if (tappedSpot != null) {
			_openExistingSpot(tappedSpot);
		} 
		else {
			_addNewSpot(point);
		}
  	}

	void _openExistingSpot(MapSpot spot){
		debugPrint("Existing spot tapped, with ID: ${spot.id}");

		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(
				content: Text("Opened spot: ${spot.id}"),
				duration: const Duration(seconds: 5),
			),
		);
	}

	void _addNewSpot (LatLng point){
		setState(() {

			final newId = DateTime.now().millisecondsSinceEpoch;

			_spots.add(
				MapSpot(id: newId, point: point)
			);
		});
	}

	@override
	Widget build(BuildContext context){
		return Scaffold(

			appBar: AppBar(title: const Text("Map")),

			drawer: const Sidebar(),

			body: FlutterMap(
				mapController: _mapController,
				options: MapOptions(
					initialCenter: const LatLng(51.509364, -0.128928), // Change to location around where user is
					initialZoom: 9.2,

					onTap: _handleMapTap,
				),

				children: [
					TileLayer(
						urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
						userAgentPackageName: 'com.yourcompany.yourapp', // temp
					),

					RichAttributionWidget(
						attributions: [
							TextSourceAttribution(
								"OpenStreetMap Contriputors",
								onTap: () => launchUrl(Uri.parse("https://openstreetmap.org/copyright")),
							),
						],
					),

					MarkerLayer(
						markers: _spots.map((spot) {
							return Marker(
								point: spot.point,
								width: 80,
								height: 40,

								child: const Icon(
									Icons.location_on,
									color: Colors.red,
									size: 40,
								),
							);
						}).toList(),
					),
				],
			),
		);
	}
}
