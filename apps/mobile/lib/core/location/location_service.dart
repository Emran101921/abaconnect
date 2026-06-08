import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

enum LocationFailure {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
}

class LocationCaptureResult {
  const LocationCaptureResult._({
    this.latitude,
    this.longitude,
    this.failureReason,
  });

  final double? latitude;
  final double? longitude;
  final LocationFailure? failureReason;

  bool get isSuccess => latitude != null && longitude != null;

  static LocationCaptureResult success(double latitude, double longitude) {
    return LocationCaptureResult._(
      latitude: latitude,
      longitude: longitude,
    );
  }

  static LocationCaptureResult failed(LocationFailure reason) {
    return LocationCaptureResult._(failureReason: reason);
  }
}

class LocationService {
  Future<LocationCaptureResult> captureCurrentPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      return LocationCaptureResult.failed(LocationFailure.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationCaptureResult.failed(
        LocationFailure.permissionDeniedForever,
      );
    }
    if (permission == LocationPermission.denied) {
      return LocationCaptureResult.failed(LocationFailure.permissionDenied);
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return LocationCaptureResult.success(pos.latitude, pos.longitude);
  }

  Future<({double lat, double lng})?> getCurrentCoords() async {
    final result = await captureCurrentPosition();
    if (!result.isSuccess) return null;
    return (lat: result.latitude!, lng: result.longitude!);
  }

  static Future<void> showLocationRequiredDialog(
    BuildContext context,
    LocationFailure failure,
  ) {
    final message = switch (failure) {
      LocationFailure.serviceDisabled =>
        'Session note signatures require location services. Turn on Location '
        'Services for this device, then try again.',
      LocationFailure.permissionDenied =>
        'Session note signatures require location permission. Allow location '
        'access for BloomOra, then try again.',
      LocationFailure.permissionDeniedForever =>
        'Location permission is permanently denied. Open Settings → BloomOra '
        'and allow location access to sign session notes.',
    };

    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Location required to sign'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
