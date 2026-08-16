import 'package:flutter/material.dart';
import 'package:flutter_application_1/widgets/sidebar.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;

class MapSpot {
	final int id;
	final LatLng point;

	final String name;
	final String description;
	final int rating;

	final List<String> tags;


	MapSpot({
		required this.id, 
		required this.point, 
		required this.name,
		required this.description, 
		required this.rating, 
		required this.tags
	});
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
			_confirmNewSpot(point);
		}
  	}

	Future<void> _confirmNewSpot(LatLng point) async {
		final bool? shouldCreate = await showDialog<bool>(
			context: context,

			builder: (BuildContext context){
				return AlertDialog(
					title: const Text("New Spot"),
					content: const Text("Open a new Spot Here?"),
					actions: [
						TextButton(
							onPressed: () => Navigator.pop(context, false),
							child: const Text("No"),
						),
						TextButton(
							onPressed: () => Navigator.pop(context, true),
							child: const Text("Yes")
						),
					],
				);
			},
		);

		if (shouldCreate == true){
			_enterSpotDetails(point);
		}
	}

	Future<void> _enterSpotDetails(LatLng point) async{
		final nameController = TextEditingController();
		final descriptionController = TextEditingController();
		final ratingController = TextEditingController();
		final tagsController = TextEditingController();

		final bool? shouldSave = await showDialog<bool>(
			context: context, 
			builder: (BuildContext context) {
				return AlertDialog(
					title: const Text("New Spot Details"),
					content: SingleChildScrollView(
						child: Column(
							mainAxisSize: MainAxisSize.min,

							children: [
								TextField(
									controller: nameController,
									decoration: const InputDecoration(labelText: "Name"),
								),
								TextField(
									controller: descriptionController,
									decoration: const InputDecoration(labelText: "Description"),
								),
								TextField(
									controller: ratingController,
									decoration: const InputDecoration(labelText: "Rating 1-5"),
								),
								TextField(
									controller: tagsController,
									decoration: const InputDecoration(labelText: "Tags (Comma seperated)"),
								),
							],
						),
					),

					actions: [
						TextButton(
							onPressed: () => Navigator.pop(context, false), 
							child: const Text("Cancel"),
							),
						TextButton(
							onPressed: () => Navigator.pop(context, true),
						 	child: const Text("Save"),
						 ),
					],
				);
			},
		);

		if (shouldSave == true) {
			setState(() {
				final newId = DateTime.now().millisecondsSinceEpoch;

				final int parsedRating = int.tryParse(ratingController.text) ?? 0; // Defaults to 0 if fails to parse

				final List<String> parsedTags = tagsController.text
					.split(',')
					.map((tag) => tag.trim())
					.where((tag) => tag.isNotEmpty)
					.toList();

				_spots.add(
					MapSpot(id: newId,
					 	point: point,
						name: nameController.text,
						description: descriptionController.text,
						rating: parsedRating,
					   	tags: parsedTags
					),
				);
			});
		}
	}


	void _openExistingSpot(MapSpot spot){
		debugPrint("Existing spot tapped, with ID: ${spot.id}");

		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(
				content: Text("Opened spot: ${spot.id} \n ${spot.description}"),

				duration: const Duration(seconds: 5),
			),
		);
	}

	// Legacy add New Spot 
	//void _addNewSpot (LatLng point){
	// 	setState(() {
	// 		final newId = DateTime.now().millisecondsSinceEpoch;
	// 		final String description = "Test Description";
	// 		final int rating = 5;
	// 		final List<String> tags = ["tag1", "tag2"];
	// 		_spots.add(
	// 			MapSpot(id: newId, point: point, description: description, rating: rating, tags: tags)
	// 		);
	// 	});
	// }

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
