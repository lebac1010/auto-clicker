const Object _normalQuickConfigNoChange = Object();

class NormalQuickConfig {
  const NormalQuickConfig({
    required this.intervalMs,
    required this.loopCount,
    required this.startDelaySec,
    this.singleTargetX,
    this.singleTargetY,
    this.multiTargetScriptId,
  });

  static const NormalQuickConfig defaults = NormalQuickConfig(
    intervalMs: 300,
    loopCount: 10,
    startDelaySec: 0,
  );

  final int intervalMs;
  final int loopCount;
  final int startDelaySec;
  final double? singleTargetX;
  final double? singleTargetY;
  final String? multiTargetScriptId;

  bool get hasSingleTargetPoint => singleTargetX != null && singleTargetY != null;

  NormalQuickConfig copyWith({
    int? intervalMs,
    int? loopCount,
    int? startDelaySec,
    Object? singleTargetX = _normalQuickConfigNoChange,
    Object? singleTargetY = _normalQuickConfigNoChange,
    Object? multiTargetScriptId = _normalQuickConfigNoChange,
  }) {
    return NormalQuickConfig(
      intervalMs: intervalMs ?? this.intervalMs,
      loopCount: loopCount ?? this.loopCount,
      startDelaySec: startDelaySec ?? this.startDelaySec,
      singleTargetX: identical(singleTargetX, _normalQuickConfigNoChange)
          ? this.singleTargetX
          : singleTargetX as double?,
      singleTargetY: identical(singleTargetY, _normalQuickConfigNoChange)
          ? this.singleTargetY
          : singleTargetY as double?,
      multiTargetScriptId: identical(
        multiTargetScriptId,
        _normalQuickConfigNoChange,
      )
          ? this.multiTargetScriptId
          : multiTargetScriptId as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'intervalMs': intervalMs,
      'loopCount': loopCount,
      'startDelaySec': startDelaySec,
      'singleTargetX': singleTargetX,
      'singleTargetY': singleTargetY,
      'multiTargetScriptId': multiTargetScriptId,
    };
  }

  factory NormalQuickConfig.fromJson(Map<String, dynamic> json) {
    final intervalMs = (json['intervalMs'] as num?)?.toInt() ?? 300;
    final loopCount = (json['loopCount'] as num?)?.toInt() ?? 10;
    final startDelaySec = (json['startDelaySec'] as num?)?.toInt() ?? 0;
    return NormalQuickConfig(
      intervalMs: intervalMs < 1 ? 1 : intervalMs,
      loopCount: loopCount < 0 ? 0 : loopCount,
      startDelaySec: startDelaySec < 0 ? 0 : startDelaySec,
      singleTargetX: (json['singleTargetX'] as num?)?.toDouble(),
      singleTargetY: (json['singleTargetY'] as num?)?.toDouble(),
      multiTargetScriptId: json['multiTargetScriptId']?.toString(),
    );
  }
}
