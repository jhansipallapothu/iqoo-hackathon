import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';

class GPSService {
  static const LocationAccuracy _accuracy = LocationAccuracy.best;
  static const int _timeoutSeconds = 30;
  static const int _distanceFilter = 0;

  Stream<Position>? _positionStream;
  StreamSubscription<Position>? _positionSubscription;
  Position? _lastKnownPosition;
  String? _lastKnownAddress;

  Future<bool> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    
    return permission == LocationPermission.whileInUse || 
           permission == LocationPermission.always;
  }

  Future<Position?> getCurrentPosition({bool forceRefresh = false}) async {
    if (!forceRefresh && _lastKnownPosition != null) {
      final age = DateTime.now().difference(_lastKnownPosition!.timestamp);
      if (age.inSeconds < 30) {
        return _lastKnownPosition;
      }
    }

    final hasPermission = await requestPermission();
    if (!hasPermission) {
      throw Exception('Location permission denied');
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: _accuracy,
      ).timeout(Duration(seconds: _timeoutSeconds));

      _lastKnownPosition = position;
      _lastKnownAddress = await _getAddressFromPosition(position);
      return position;
    } catch (e) {
      if (_lastKnownPosition != null) {
        return _lastKnownPosition;
      }
      rethrow;
    }
  }

  Stream<Position> getPositionStream() {
    _positionSubscription?.cancel();

    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: _accuracy,
        distanceFilter: _distanceFilter,
      ),
    ).handleError((error) {
      print('GPS Stream error: $error');
    });

    _positionSubscription = _positionStream!.listen((position) {
      _lastKnownPosition = position;
      _getAddressFromPosition(position).then((address) {
        _lastKnownAddress = address;
      });
    });

    return _positionStream!;
  }

  Future<String> _getAddressFromPosition(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.postalCode,
          place.country,
        ].where((e) => e != null && e!.isNotEmpty).join(', ');
      }
    } catch (e) {
      print('Geocoding error: $e');
    }
    return 'Unknown address';
  }

  String? getLastKnownAddress() => _lastKnownAddress;
  Position? getLastKnownPosition() => _lastKnownPosition;

  Future<Map<String, dynamic>> getLocationData() async {
    final position = await getCurrentPosition();
    if (position == null) return {};
    
    final address = await _getAddressFromPosition(position);
    
    return {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'altitude': position.altitude,
      'accuracy': position.accuracy,
      'speed': position.speed,
      'heading': position.heading,
      'timestamp': position.timestamp.toIso8601String(),
      'address': address,
    };
  }

  double? calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  void dispose() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _positionStream = null;
  }

  Future<bool> get isLocationServiceEnabled => Geolocator.isLocationServiceEnabled();
  
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }
  
  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }
}