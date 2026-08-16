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
	final double rating;

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

	Future<void> _enterSpotDetails(LatLng point) async {
        final formKey = GlobalKey<FormState>();
        
        final nameController = TextEditingController();
        final descriptionController = TextEditingController();
        final tagsController = TextEditingController();
        
        // Changed to a double to support .5 values
        double selectedRating = 0.0; 

        final bool? shouldSave = await showDialog<bool>(
            context: context, 
            builder: (BuildContext context) {
                return StatefulBuilder(
                    builder: (context, setDialogState) {
                        return AlertDialog(
                            title: const Text("New Spot Details"),
                            content: SingleChildScrollView(
                                child: Form(
                                    key: formKey,
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                            TextFormField(
                                                controller: nameController,
                                                decoration: const InputDecoration(labelText: "Name*"),
                                                validator: (value) {
                                                    if (value == null || value.trim().isEmpty) {
                                                        return 'Please enter a name';
                                                    }
                                                    return null;
                                                },
                                            ),
                                            TextFormField(
                                                controller: descriptionController,
                                                decoration: const InputDecoration(labelText: "Description"),
												validator: (value){
													if (value == null || value.trim().isEmpty){
														return 'Please enter a description';
													}
													return null;
												}
                                            ),
                                            const SizedBox(height: 16),
                                            
                                            const Text("Rating", style: TextStyle(fontSize: 12, color: Colors.black54)),
                                            Row(
                                                mainAxisAlignment: MainAxisAlignment.start,
                                                children: List.generate(5, (index) {
                                                    // Determine which icon to show for this position
                                                    IconData iconData;
                                                    if (selectedRating >= index + 1.0) {
                                                        iconData = Icons.star;
                                                    } else if (selectedRating >= index + 0.5) {
                                                        iconData = Icons.star_half;
                                                    } else {
                                                        iconData = Icons.star_border;
                                                    }

                                                    return GestureDetector(
                                                        // Use onTapDown to get exactly where the user touched
                                                        onTapDown: (TapDownDetails details) {
                                                            setDialogState(() {
                                                                // The icon is 36 pixels wide. If they tap the left half (< 18), 
                                                                // it's a half star. Otherwise, it's a full star.
                                                                if (details.localPosition.dx < 18) {
                                                                    selectedRating = index + 0.5;
                                                                } else {
                                                                    selectedRating = index + 1.0;
                                                                }
                                                            });
                                                        },
                                                        child: Padding(
                                                            // Add slight padding between stars for a better touch target
                                                            padding: const EdgeInsets.only(right: 4.0),
                                                            child: Icon(
                                                                iconData,
                                                                color: Colors.amber,
                                                                size: 36,
                                                            ),
                                                        ),
                                                    );
                                                }),
                                            ),
                                           
										    const SizedBox(height: 8),

                                            TextFormField(
                                                controller: tagsController,
                                                decoration: const InputDecoration(labelText: "Tags (Comma separated)"),
                                                validator: (value) {
													if (value == null || value.trim().isEmpty){
														return 'Please enter at least one tag';
													}
                                                    if (value.contains(RegExp(r'[!@#\$%^&*()]'))) {
                                                        return 'Please do not use special characters in tags';
                                                    }
                                                    return null;
                                                },
                                            ),
                                        ],
                                    ),
                                ),
                            ),

                            actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(context, false), 
                                    child: const Text("Cancel"),
                                ),
                                TextButton(
                                    onPressed: () {
                                        if (formKey.currentState!.validate()) {
                                            Navigator.pop(context, true);
                                        }
                                    },
                                    child: const Text("Save"),
                                 ),
                            ],
                        );
                    }
                );
            },
        );

        if (shouldSave == true) {
            setState(() {
                final newId = DateTime.now().millisecondsSinceEpoch;

                final List<String> parsedTags = tagsController.text
                    .split(',')
                    .map((tag) => tag.trim())
                    .where((tag) => tag.isNotEmpty)
                    .toList();

                _spots.add(
                    MapSpot(
                        id: newId,
                        point: point,
                        name: nameController.text.trim(),
                        description: descriptionController.text.trim(),
                        rating: selectedRating, // Now passes the double value
                        tags: parsedTags
                    ),
                );
            });
        }
    }

	Future<void> _openExistingSpot(MapSpot spot) async{

		final bool? visitedSpot = await showDialog<bool>(
			context: context, 
			builder: (BuildContext context){
				return AlertDialog(
					title: Text(spot.name.isNotEmpty ? spot.name : "Unnamed Spot"),

					content: SingleChildScrollView(
						child: Column(
							mainAxisSize: MainAxisSize.min,
							crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Text("Description: ${spot.description}"),
									const SizedBox(height: 10),
									Text("Rating: ${spot.rating} / 5"),
									const SizedBox(height: 10),
									Text("Tags: ${spot.tags.join(', ')}"),
									const SizedBox(height: 20),
									const Text("Have you visited this spot?"),
								],
						),
					),

					actions: [
						TextButton(
							onPressed: () => Navigator.pop(context, false),
						 	child: const Text("Not yet"),
						),
						TextButton(
							onPressed: () => Navigator.pop(context, true),
							child: const Text("I have!")
						),
					],
				);
			}
		);

		if (visitedSpot == true) {
			debugPrint("Visted Spot ${spot.name}");
		}

		else if (visitedSpot == false) {
			debugPrint("Not visited spot ${spot.name}");
		}

		// debugPrint("Existing spot tapped, with ID: ${spot.id}");
		// ScaffoldMessenger.of(context).showSnackBar(
		// 	SnackBar(
		// 		content: Text("Opened spot: ${spot.id} \n ${spot.description}"),
		// 		duration: const Duration(seconds: 5),
		// 	),
		// );
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
