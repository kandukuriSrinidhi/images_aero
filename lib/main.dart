import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SignInPage(),
    );
  }
}

class SignInPage extends StatefulWidget {
  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  TextEditingController _emailController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();

  void _signIn() {
    // Perform sign-in logic here
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sign In'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
              ),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
              ),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _signIn,
              child: Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  LatLng? _pickupPoint;
  LatLng? _destinationPoint;
  List<LatLng> _routePoints = [];
  MapController _mapController = MapController();
  double _currentZoom = 13.0;
  Timer? _navigationTimer;
  int _navigationIndex = 0;
  TextEditingController _locationController = TextEditingController();
  List<String> _directions = [];
  String _searchType = 'Pickup';

  // Average speeds in km/h
  final double _walkingSpeed = 5.0;
  final double _cyclingSpeed = 15.0;
  final double _drivingSpeed = 50.0;

  // Method to calculate distance
  double _calculateDistance() {
    if (_pickupPoint != null && _destinationPoint != null) {
      final distanceInMeters = Distance().as(
        LengthUnit.Meter,
        _pickupPoint!,
        _destinationPoint!,
      );
      return distanceInMeters / 1000; // Convert to kilometers
    }
    return 0.0;
  }

  // Method to calculate travel time based on distance and mode of transport
  String _calculateTravelTime(double distance, double speed) {
    final timeInHours = distance / speed;
    final hours = timeInHours.floor();
    final minutes = ((timeInHours - hours) * 60).round();

    return '${hours > 0 ? '$hours hrs ' : ''}${minutes > 0 ? '$minutes mins' : ''}';
  }

  Future<void> _getRoute() async {
    if (_pickupPoint != null && _destinationPoint != null) {
      final String url =
          'http://router.project-osrm.org/route/v1/driving/${_pickupPoint!.longitude},${_pickupPoint!.latitude};${_destinationPoint!.longitude},${_destinationPoint!.latitude}?geometries=geojson&overview=full&steps=true';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List<dynamic> coordinates =
        json['routes'][0]['geometry']['coordinates'];
        final List<dynamic> steps = json['routes'][0]['legs'][0]['steps'];
        setState(() {
          _routePoints = coordinates
              .map((point) => LatLng(point[1], point[0]))
              .toList();
          _directions = steps
              .map((step) => step['maneuver']['instruction'].toString())
              .toList();
        });
      }
    }
  }

  Future<void> _searchLocation(String address, {bool isPickup = true}) async {
    final String url =
        'https://nominatim.openstreetmap.org/search?q=$address&format=json&limit=1';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      if (data.isNotEmpty) {
        final point = data[0];
        setState(() {
          final latLng = LatLng(
            double.parse(point['lat']),
            double.parse(point['lon']),
          );
          if (isPickup) {
            _pickupPoint = latLng;
            _mapController.move(_pickupPoint!, _currentZoom);
          } else {
            _destinationPoint = latLng;
            _getRoute();
          }
        });
      }
    }
  }

  void _clearPoints() {
    setState(() {
      _pickupPoint = null;
      _destinationPoint = null;
      _routePoints = [];
      _navigationIndex = 0;
      _navigationTimer?.cancel();
      _locationController.clear();
      _directions = [];
    });
  }

  void _removeLastPoint() {
    setState(() {
      if (_destinationPoint != null) {
        _destinationPoint = null;
        _locationController.clear();
      } else if (_pickupPoint != null) {
        _pickupPoint = null;
        _locationController.clear();
      }
      _routePoints = [];
      _navigationIndex = 0;
      _navigationTimer?.cancel();
    });
  }

  void _zoomIn() {
    setState(() {
      _currentZoom++;
      _mapController.move(_mapController.center, _currentZoom);
    });
  }

  void _zoomOut() {
    setState(() {
      _currentZoom--;
      _mapController.move(_mapController.center, _currentZoom);
    });
  }

  void _startNavigation() {
    if (_routePoints.isNotEmpty) {
      _navigationIndex = 0;
      _navigationTimer?.cancel();
      _navigationTimer = Timer.periodic(Duration(seconds: 1), (timer) {
        if (_navigationIndex < _routePoints.length) {
          _mapController.move(_routePoints[_navigationIndex], _currentZoom);
          setState(() {
            _navigationIndex++;
          });
        } else {
          _navigationTimer?.cancel();
        }
      });
    }
  }

  void _nextDirection() {
    if (_directions.isNotEmpty && _navigationIndex < _directions.length - 1) {
      setState(() {
        _navigationIndex++;
        _mapController.move(_routePoints[_navigationIndex], _currentZoom);
      });
    }
  }

  void _previousDirection() {
    if (_directions.isNotEmpty && _navigationIndex > 0) {
      setState(() {
        _navigationIndex--;
        _mapController.move(_routePoints[_navigationIndex], _currentZoom);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double distance = _calculateDistance();
    String walkingTime = _calculateTravelTime(distance, _walkingSpeed);
    String cyclingTime = _calculateTravelTime(distance, _cyclingSpeed);
    String drivingTime = _calculateTravelTime(distance, _drivingSpeed);

    return Scaffold(
      appBar: AppBar(
        title: Text('           Way To Destination         '),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _locationController,
                    decoration: InputDecoration(
                      labelText: 'Enter Location',
                      suffixIcon: IconButton(
                        icon: Icon(Icons.search),
                        onPressed: () {
                          if (_searchType == 'Pickup') {
                            _searchLocation(_locationController.text,
                                isPickup: true);
                          } else {
                            _searchLocation(_locationController.text,
                                isPickup: false);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                DropdownButton<String>(
                  value: _searchType,
                  items: <String>['Pickup', 'Destination']
                      .map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _searchType = newValue!;
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                center: LatLng(17.3850, 78.4867),
                zoom: _currentZoom,
                onTap: (tapPosition, point) {
                  setState(() {
                    if (_pickupPoint == null) {
                      _pickupPoint = point;
                    }
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                  "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: ['a', 'b', 'c'],
                ),
                MarkerLayer(
                  markers: [
                    if (_pickupPoint != null)
                      Marker(
                        point: _pickupPoint!,
                        builder: (ctx) => Icon(
                          Icons.location_on,
                          color: Colors.green,
                          size: 40,
                        ),
                      ),
                    if (_destinationPoint != null)
                      Marker(
                        point: _destinationPoint!,
                        builder: (ctx) => Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                  ],
                ),
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        strokeWidth: 4.0,
                        color: Colors.blue,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.grey[200],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Icon(Icons.directions_walk, color: Colors.black),
                    SizedBox(height: 4),
                    Text(
                      _pickupPoint != null && _destinationPoint != null
                          ? walkingTime
                          : 'N/A',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Icon(Icons.directions_bike, color: Colors.black),
                    SizedBox(height: 4),
                    Text(
                      _pickupPoint != null && _destinationPoint != null
                          ? cyclingTime
                          : 'N/A',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Icon(Icons.directions_car, color: Colors.black),
                    SizedBox(height: 4),
                    Text(
                      _pickupPoint != null && _destinationPoint != null
                          ? drivingTime
                          : 'N/A',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.grey[200],
            child: Text(
              _directions.isNotEmpty
                  ? 'Direction: ${_directions.isNotEmpty ? _directions[_navigationIndex] : "N/A"}'
                  : 'Direction: N/A',
              style: TextStyle(fontSize: 16),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                if (_pickupPoint != null && _destinationPoint != null)
                  ElevatedButton(
                    onPressed: _startNavigation,
                    child: Text('Get Started'),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _clearPoints,
                      child: Text('Clear Points'),
                    ),
                    SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _removeLastPoint,
                      child: Text('Remove Last Point'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _zoomIn,
            child: Icon(Icons.zoom_in),
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            onPressed: _zoomOut,
            child: Icon(Icons.zoom_out),
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            onPressed: _previousDirection,
            child: Icon(Icons.arrow_back),
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            onPressed: _nextDirection,
            child: Icon(Icons.arrow_forward),
          ),
        ],
      ),
    );
  }
}