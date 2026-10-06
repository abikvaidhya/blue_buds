class AppSettings {
  final String deviceName;
  final bool backgroundScanEnabled;
  final bool notifyConnectionRequests;
  final bool notifySavedNearby;
  final bool autoAcceptImagesFromSaved;
  final bool requireImagePermission; // default true for strangers

  const AppSettings({
    this.deviceName = 'BlueBud',
    this.backgroundScanEnabled = false,
    this.notifyConnectionRequests = true,
    this.notifySavedNearby = true,
    this.autoAcceptImagesFromSaved = true,
    this.requireImagePermission = true,
  });

  AppSettings copyWith({
    String? deviceName,
    bool? backgroundScanEnabled,
    bool? notifyConnectionRequests,
    bool? notifySavedNearby,
    bool? autoAcceptImagesFromSaved,
    bool? requireImagePermission,
  }) {
    return AppSettings(
      deviceName: deviceName ?? this.deviceName,
      backgroundScanEnabled: backgroundScanEnabled ?? this.backgroundScanEnabled,
      notifyConnectionRequests:
          notifyConnectionRequests ?? this.notifyConnectionRequests,
      notifySavedNearby: notifySavedNearby ?? this.notifySavedNearby,
      autoAcceptImagesFromSaved:
          autoAcceptImagesFromSaved ?? this.autoAcceptImagesFromSaved,
      requireImagePermission:
          requireImagePermission ?? this.requireImagePermission,
    );
  }

  Map<String, dynamic> toMap() => {
        'deviceName': deviceName,
        'backgroundScanEnabled': backgroundScanEnabled,
        'notifyConnectionRequests': notifyConnectionRequests,
        'notifySavedNearby': notifySavedNearby,
        'autoAcceptImagesFromSaved': autoAcceptImagesFromSaved,
        'requireImagePermission': requireImagePermission,
      };

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      deviceName: map['deviceName'] as String? ?? 'BlueBud',
      backgroundScanEnabled: map['backgroundScanEnabled'] as bool? ?? false,
      notifyConnectionRequests:
          map['notifyConnectionRequests'] as bool? ?? true,
      notifySavedNearby: map['notifySavedNearby'] as bool? ?? true,
      autoAcceptImagesFromSaved:
          map['autoAcceptImagesFromSaved'] as bool? ?? true,
      requireImagePermission: map['requireImagePermission'] as bool? ?? true,
    );
  }
}
