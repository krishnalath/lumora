import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng? _selectedLocation;
  String _address = 'Move the map to select a location';
  bool _isLoading = false;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(20.5937, 78.9629), // Default to India roughly
    zoom: 4.0,
  );

  Future<void> _updateAddress(LatLng position) async {
    setState(() => _isLoading = true);
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final parts = [place.street, place.subLocality, place.locality, place.administrativeArea]
            .where((p) => p != null && p.isNotEmpty)
            .toList();
        setState(() {
          _address = parts.join(', ');
        });
      } else {
        setState(() => _address = 'Unknown location');
      }
    } catch (e) {
      setState(() => _address = 'Could not fetch address');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E212B),
        title: Text(
          'Select Location',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialPosition,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            onCameraMove: (position) {
              _selectedLocation = position.target;
            },
            onCameraIdle: () {
              if (_selectedLocation != null) {
                _updateAddress(_selectedLocation!);
              }
            },
            onMapCreated: (controller) {
              // Optionally handle controller
            },
          ),
          // Center Pin marker
          const Center(
            child: Icon(Icons.location_pin, color: AppTheme.accentLavender, size: 40),
          ),
          // Bottom panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF1E212B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Address',
                    style: GoogleFonts.dmSans(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: AppTheme.accentLavender),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _isLoading
                            ? const Text('Loading address...', style: TextStyle(color: Colors.white))
                            : Text(
                                _address,
                                style: GoogleFonts.dmSans(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_selectedLocation != null) {
                          Navigator.pop(context, _address);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentLavender,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        'Confirm Location',
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
