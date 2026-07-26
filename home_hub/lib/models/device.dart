enum DeviceType {
  light,
  plug,
  airConditioner,
  curtain,
  airPurifier,
  fan,
  switchPanel,
  sensor,
  camera,
  speaker,
  unknown,
}

enum DeviceProtocol {
  demo,
  homeAssistant,
  http,
  tuya,
}

extension DeviceTypeX on DeviceType {
  String get label => switch (this) {
        DeviceType.light => '灯具',
        DeviceType.plug => '插座',
        DeviceType.airConditioner => '空调',
        DeviceType.curtain => '窗帘',
        DeviceType.airPurifier => '空气净化器',
        DeviceType.fan => '风扇',
        DeviceType.switchPanel => '开关',
        DeviceType.sensor => '传感器',
        DeviceType.camera => '摄像头',
        DeviceType.speaker => '音箱',
        DeviceType.unknown => '未知设备',
      };

}

class SmartDevice {
  SmartDevice({
    required this.id,
    required this.name,
    required this.room,
    required this.type,
    required this.protocol,
    this.online = true,
    this.powerOn = false,
    this.brightness = 80,
    this.colorTemp = 4000,
    this.temperature = 26,
    this.targetTemp = 26,
    this.humidity = 50,
    this.position = 50,
    this.fanSpeed = 2,
    this.mode = 'auto',
    this.entityId,
    this.endpoint,
    this.brand = '通用',
    this.lastSeen,
  });

  final String id;
  String name;
  String room;
  final DeviceType type;
  final DeviceProtocol protocol;
  bool online;
  bool powerOn;
  double brightness;
  double colorTemp;
  double temperature;
  double targetTemp;
  double humidity;
  double position;
  int fanSpeed;
  String mode;
  String? entityId;
  String? endpoint;
  String brand;
  DateTime? lastSeen;

  bool get isControllable =>
      type != DeviceType.sensor && type != DeviceType.camera;

  String get statusText {
    if (!online) return '离线';
    return switch (type) {
      DeviceType.light => powerOn ? '亮度 ${brightness.round()}%' : '已关闭',
      DeviceType.plug || DeviceType.switchPanel => powerOn ? '已开启' : '已关闭',
      DeviceType.airConditioner =>
        powerOn ? '$mode · ${targetTemp.round()}°C' : '已关闭',
      DeviceType.curtain => '开合 ${position.round()}%',
      DeviceType.airPurifier => powerOn ? '风速 $fanSpeed' : '已关闭',
      DeviceType.fan => powerOn ? '档位 $fanSpeed' : '已关闭',
      DeviceType.sensor => '${temperature.toStringAsFixed(1)}°C · ${humidity.round()}%',
      DeviceType.camera => '在线',
      DeviceType.speaker => powerOn ? '播放中' : '待机',
      DeviceType.unknown => powerOn ? '开启' : '关闭',
    };
  }

  SmartDevice copyWith({
    String? name,
    String? room,
    bool? online,
    bool? powerOn,
    double? brightness,
    double? colorTemp,
    double? temperature,
    double? targetTemp,
    double? humidity,
    double? position,
    int? fanSpeed,
    String? mode,
    String? entityId,
    String? endpoint,
    String? brand,
    DateTime? lastSeen,
  }) {
    return SmartDevice(
      id: id,
      name: name ?? this.name,
      room: room ?? this.room,
      type: type,
      protocol: protocol,
      online: online ?? this.online,
      powerOn: powerOn ?? this.powerOn,
      brightness: brightness ?? this.brightness,
      colorTemp: colorTemp ?? this.colorTemp,
      temperature: temperature ?? this.temperature,
      targetTemp: targetTemp ?? this.targetTemp,
      humidity: humidity ?? this.humidity,
      position: position ?? this.position,
      fanSpeed: fanSpeed ?? this.fanSpeed,
      mode: mode ?? this.mode,
      entityId: entityId ?? this.entityId,
      endpoint: endpoint ?? this.endpoint,
      brand: brand ?? this.brand,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'room': room,
        'type': type.name,
        'protocol': protocol.name,
        'online': online,
        'powerOn': powerOn,
        'brightness': brightness,
        'colorTemp': colorTemp,
        'temperature': temperature,
        'targetTemp': targetTemp,
        'humidity': humidity,
        'position': position,
        'fanSpeed': fanSpeed,
        'mode': mode,
        'entityId': entityId,
        'endpoint': endpoint,
        'brand': brand,
        'lastSeen': lastSeen?.toIso8601String(),
      };

  factory SmartDevice.fromJson(Map<String, dynamic> json) {
    return SmartDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      room: json['room'] as String? ?? '未分配',
      type: DeviceType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => DeviceType.unknown,
      ),
      protocol: DeviceProtocol.values.firstWhere(
        (e) => e.name == json['protocol'],
        orElse: () => DeviceProtocol.demo,
      ),
      online: json['online'] as bool? ?? true,
      powerOn: json['powerOn'] as bool? ?? false,
      brightness: (json['brightness'] as num?)?.toDouble() ?? 80,
      colorTemp: (json['colorTemp'] as num?)?.toDouble() ?? 4000,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 26,
      targetTemp: (json['targetTemp'] as num?)?.toDouble() ?? 26,
      humidity: (json['humidity'] as num?)?.toDouble() ?? 50,
      position: (json['position'] as num?)?.toDouble() ?? 50,
      fanSpeed: json['fanSpeed'] as int? ?? 2,
      mode: json['mode'] as String? ?? 'auto',
      entityId: json['entityId'] as String?,
      endpoint: json['endpoint'] as String?,
      brand: json['brand'] as String? ?? '通用',
      lastSeen: json['lastSeen'] != null
          ? DateTime.tryParse(json['lastSeen'] as String)
          : null,
    );
  }
}
