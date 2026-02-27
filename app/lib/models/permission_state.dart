class PermissionState {
  const PermissionState({
    required this.accessibilityEnabled,
    required this.overlayEnabled,
    required this.notificationsEnabled,
    required this.batteryOptimizationIgnored,
    required this.exactAlarmAllowed,
  });

  final bool accessibilityEnabled;
  final bool overlayEnabled;
  final bool notificationsEnabled;
  final bool batteryOptimizationIgnored;
  final bool exactAlarmAllowed;

  bool get hasCorePermissions => accessibilityEnabled && overlayEnabled;

  factory PermissionState.fromMap(Map<dynamic, dynamic> map) {
    return PermissionState(
      accessibilityEnabled: map['accessibilityEnabled'] == true,
      overlayEnabled: map['overlayEnabled'] == true,
      notificationsEnabled: map['notificationsEnabled'] == true,
      batteryOptimizationIgnored: map['batteryOptimizationIgnored'] == true,
      exactAlarmAllowed: map['exactAlarmAllowed'] != false,
    );
  }

  static const PermissionState fallback = PermissionState(
    accessibilityEnabled: false,
    overlayEnabled: false,
    notificationsEnabled: false,
    batteryOptimizationIgnored: false,
    exactAlarmAllowed: true,
  );
}
