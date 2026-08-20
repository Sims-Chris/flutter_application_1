import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/widgets/sidebar.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;

// ===========================
// Data Models
// ===========================

class MapSpot {
  final String id;
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
    required this.tags,
  });

  // The factory method parses the data safely so the app won't crash on bad data
  factory MapSpot.fromFirestore(DocumentSnapshot doc) {
    try {
      Map data = doc.data() as Map<String, dynamic>? ?? {};
      
      // Safely extract coordinates
      double lat = 0.0;
      double lng = 0.0;
      if (data['location'] != null && data['location']['coordinates'] != null) {
        List coords = data['location']['coordinates'];
        if (coords.length >= 2) {
          // Force conversion to double safely
          lng = (coords[0] is num) ? (coords[0] as num).toDouble() : 0.0;
          lat = (coords[1] is num) ? (coords[1] as num).toDouble() : 0.0;
        }
      }
      
      return MapSpot(
        id: doc.id,
        point: LatLng(lat, lng),
        name: data['title']?.toString() ?? 'Unnamed Spot',
        description: data['description']?.toString() ?? '',
        rating: (data['rating'] is num) ? (data['rating'] as num).toDouble() : 0.0,
        tags: (data['filters'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      );
    } 
    catch (e) {
      // If a document is corrupted, print the error but don't crash
      debugPrint("Error parsing spot ${doc.id}: $e");
      return MapSpot(
        id: doc.id, 
        point: const LatLng(0,0), 
        name: 'Broken Data', 
        description: '', 
        rating: 0, 
        tags: []
      );
    }
  }
}

class _SpotFormData {
  final String name;
  final String description;
  final double rating;
  final List<String> tags;

  _SpotFormData({
    required this.name,
    required this.description,
    required this.rating,
    required this.tags,
  });
}

// ===========================
// Map Screen
// ===========================

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<MapSpot> _spots = [];
  final MapController _mapController = MapController();

  // Search Variables
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose(){
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }
  
  void _handleMapTap(TapPosition tapPosition, LatLng point) {
    debugPrint('Tapped Latitude: ${point.latitude}');
    debugPrint('Tapped Longitude: ${point.longitude}');

    MapSpot? tappedSpot;
    const distanceCalculator = Distance();
    final currentZoom = _mapController.camera.zoom;

    // Calculate the hit box, by scaling the meters (size) of the hit box
    const double baseThresholdMeters = 2000; 
    const double baseZoomLevel = 9.2;
    final double hitThresholdMeters = baseThresholdMeters * math.pow(2, baseZoomLevel - currentZoom);

    for (final spot in _spots) {
      final double distanceMeters = distanceCalculator.distance(
        point,
        spot.point,
      );

      if (distanceMeters < hitThresholdMeters) {
        tappedSpot = spot;
        break; // clicked on a marker
      }
    }

    if (tappedSpot != null) {
      _openExistingSpot(tappedSpot);
    } else {
      _confirmNewSpot(point);
    }
  }

  Future<void> _confirmNewSpot(LatLng point) async {
    final bool? shouldCreate = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => const ConfirmNewSpotDialog(),
    );

    if (shouldCreate == true) {
      _enterSpotDetails(point);
    }
  }

  Future<void> _enterSpotDetails(LatLng point) async {
    // Shows extracted dialog. Returns the cleaned _SpotFormData object
    final _SpotFormData? formData = await showDialog<_SpotFormData>(
      context: context,
      builder: (BuildContext context) => const NewSpotFormDialog(),
    );

    // If user has saved the form, not canceled then wont be null
    if (formData != null){
      await FirebaseFirestore.instance.collection("spots").add({
        "title": formData.name,
        'description': formData.description,
        "location": {
          "type": "Point",
          "coordinates": [point.longitude, point.latitude] // in GeoJSON format
        },
        "rating": formData.rating,
        "filters": formData.tags,
        "createdAt": FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _openExistingSpot(MapSpot spot) async {
    final bool? visitedSpot = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => ExistingSpotDialog(spot: spot),
    );

    if (visitedSpot == true) {
      debugPrint("Visited Spot ${spot.name}");
    } else if (visitedSpot == false) {
      debugPrint("Not visited spot ${spot.name}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Make the title the search bar
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: "Search for names or tags...",
            border: InputBorder.none, // Removes underline
            suffixIcon:  _searchQuery.isNotEmpty
              ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = "";
                  });
                },
              )
            : const Icon(Icons.search),
          ),
          onChanged: (value){
            setState(() {
              _searchQuery = value.toLowerCase();
            });
          },
        ),
      ),
      drawer: const Sidebar(),
      
      // Wrapping the map in a StreamBuilder fixes the Windows UI Freezing
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("spots").snapshots(),
        builder: (context, snapshot) {
          // Show a loader while fetching to prevent locking the screen
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final List<MapSpot> allSpots = snapshot.hasData
            ? snapshot.data!.docs.map<MapSpot>((doc) => MapSpot.fromFirestore(doc)).toList()
            : <MapSpot>[];

          // Filter spots based on search query
          final List<MapSpot> filteredSpots = allSpots.where((spot) {
            if (_searchQuery.isEmpty) return true;

            final nameMatches = spot.name.toLowerCase().contains(_searchQuery);
            final tagMatches = spot.tags.any((tag) => tag.toLowerCase().contains(_searchQuery));

            return nameMatches || tagMatches;
          }).toList();

          // Assign just filtered spots to global var for map taps
          _spots = filteredSpots;

          return FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(51.509364, -0.128928), 
              initialZoom: 9.2,
              onTap: _handleMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.yourcompany.yourapp', 
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    "OpenStreetMap Contributors",
                    onTap: () => launchUrl(Uri.parse("https://openstreetmap.org/copyright")),
                  ),
                ],
              ),
              MarkerLayer(
                markers: filteredSpots.map((spot) {
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
          );
        }
      ),
    );
  }
}

  // ===========================
  // Extracted Dialog Widgets
  // This means we can move display info out of the _enterSpotDetails and such
  // ===========================

class ConfirmNewSpotDialog extends StatelessWidget{
  const ConfirmNewSpotDialog({super.key});

  @override
  Widget build (BuildContext context){
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
          child: const Text("Yes"),
        ),
      ],
    );
  }
}

class ExistingSpotDialog extends StatelessWidget{
  final MapSpot spot;

  const ExistingSpotDialog({super.key, required this.spot});

  @override
  Widget build(BuildContext context) {
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
          child: const Text("I have!"),
        ),
      ],
    );
  }
}

class NewSpotFormDialog extends StatefulWidget {
  const NewSpotFormDialog({super.key});

  @override
  State<NewSpotFormDialog> createState() => _NewSpotFormDialogState();
}

class _NewSpotFormDialogState extends State<NewSpotFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  double _selectedRating = 0.0;

  final List<String> _availableTags = [
    'Walking', 'Nature', 'Picnic', 'Hiking', 'Sunsets', 'Sunrises', 
    'Star gazing', 'Bird watching', 'Wildlife areas', 'Wild swimming', 
    'Trail running', 'Climbing', 'Cycling', 'Scrambling', 'Camping', 
    'Van living', 'Wild camping', 'Beaches', 'Lakes', 'Woods', 
    'Rivers', 'Waterfalls', 'Amenities'
  ];
  
  final List<String> _selectedTags = [];

  @override
  void dispose() {
    // Always dispose controllers to prevent memory leaks!
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      // Parse the tags cleanly here
      if (_selectedTags.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select at least one tag")),
        );
        return;
      }

      // Return the completed data object back to the main screen
      final formData = _SpotFormData(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        rating: _selectedRating,
        tags: _selectedTags,
      );
      
      Navigator.pop(context, formData);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("New Spot Details"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Name*"),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Please enter a name';
                  return null;
                },
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: "Description"),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Please enter a description';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              const Text("Rating", style: TextStyle(fontSize: 12, color: Colors.black54)),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: List.generate(5, (index) {
                  IconData iconData;
                  if (_selectedRating >= index + 1.0) {
                    iconData = Icons.star;
                  } else if (_selectedRating >= index + 0.5) {
                    iconData = Icons.star_half;
                  } else {
                    iconData = Icons.star_border;
                  }

                  return GestureDetector(
                    onTapDown: (TapDownDetails details) {
                      // Standard setState is much cleaner here than StatefulBuilder
                      setState(() {
                        if (details.localPosition.dx < 18) {
                          _selectedRating = index + 0.5;
                        } else {
                          _selectedRating = index + 1.0;
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4.0),
                      child: Icon(iconData, color: Colors.amber, size: 36),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              
              const Text("Tags*", style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 8),

              // Tag Selection
              Wrap(
                spacing: 8, // Horizontal spacing
                runSpacing: 4.0, // Vertical spacing

                children: _availableTags.map((tag) {
                  final isSelected = _selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: isSelected,
                    selectedColor: Colors.deepPurple.withOpacity(0.2),
                    checkmarkColor: Colors.deepPurple,
                    onSelected: (bool selected){
                      setState(() {
                        if (selected){
                          _selectedTags.add(tag);
                        }
                        else{
                          _selectedTags.remove(tag);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null), // Return null on cancel
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: _submitForm,
          child: const Text("Save"),
        ),
      ],
    );
  }
}