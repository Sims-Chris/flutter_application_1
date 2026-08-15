import 'package:flutter/material.dart';
import '../main.dart';
import '../map.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero, // Remove padding from the ListView
        
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
            child: Text(
              'Navigation Drawer', 
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),

          ListTile(
            title: const Text("Main"),
            onTap: () { 
              Navigator.push( 
                context, 
                MaterialPageRoute(
                  builder: (context) => const MyHomePage(),
                ),
              ); 
            },
          ),

          ListTile(
            title: const Text("Map"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MapScreen(),
                ),
              );
            },
          ),

        ],

      ),
    ); 
  }
}