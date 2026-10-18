class CourierLocation {
  const CourierLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.capturedAt,
  });
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime capturedAt;

  bool get isFresh {
    final age = DateTime.now().difference(capturedAt);
    return age <= const Duration(minutes: 2) &&
        age >= const Duration(seconds: -10);
  }

  factory CourierLocation.fromJson(Map<String, dynamic> json) =>
      CourierLocation(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        accuracy: (json['accuracy'] as num).toDouble(),
        capturedAt: DateTime.parse(json['captured_at'] as String).toLocal(),
      );
}
