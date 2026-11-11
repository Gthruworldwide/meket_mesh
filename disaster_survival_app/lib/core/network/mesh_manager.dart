import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'dtn_packet_handler.dart';
import 'mesh_peer.dart';

export 'mesh_peer.dart';
export 'mesh_router.dart';

/// إدارة شبكة المش اللامركزية عبر BLE.
///
/// الدور المزدوج لكل جهاز:
///  * **مُعلِن (Peripheral):** ينشر خدمة ResiliNet عبر GATT ليتمكن الآخرون من
///    الاتصال به وكتابة حزم DTN في خاصية الاستقبال.
///  * **ماسح (Central):** يبحث عن الخدمة نفسها، يتصل بعقدة مجاورة، يكتب كل
///    حزم صندوق الصادر (Store-and-Forward)، ثم يقطع الاتصال.
///
/// كل حزمة تُقسَّم إلى إطارات ≤ 160 بايت (حدّ آمن لحمولة BLE) وتُعاد تجميعها
/// على الطرف الآخر. عند غياب العتاد أو رفض الصلاحيات ينتقل التطبيق تلقائياً
/// إلى وضع المحاكاة حتى تبقى بقية الواجهات قابلة للتجربة.
class MeshManager extends ChangeNotifier {
  MeshManager(this._dtn);

  final DtnPacketHandler _dtn;

  // ── معرّفات خدمة ResiliNet ────────────────────────────────────────────
  static const String meshServiceUuid = '6c4f2a10-9b3e-4d6a-8f21-7d5e3c1b0a9f';
  static const String rxCharacteristicUuid =
      '6c4f2a10-9b3e-4d6a-8f21-7d5e3c1b0aa0';
  static const String txCharacteristicUuid =
      '6c4f2a10-9b3e-4d6a-8f21-7d5e3c1b0aa1';
  static const int manufacturerId = 0xFFFF;
  static const String localName = 'ResiliNet';

  static const int _frameMagic0 = 0x52; // 'R'
  static const int _frameMagic1 = 0x4E; // 'N'
  static const int _framePayloadSize = 140;
  static const int _maxFrames = 255;

  final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();
  final _FrameReassembler _reassembler = _FrameReassembler();

  MeshStatus _status = MeshStatus.stopped;
  bool _initialized = false;
  bool _advertising = false;
  bool _scanning = false;
  bool _syncing = false;
  bool _disposed = false;
  String? _lastError;
  String? _nodeId;
  DateTime? _lastSyncAt;
  int _packetsRelayed = 0;
  int _packetsReceived = 0;
  int _syncRounds = 0;

  final Map<String, MeshPeer> _peers = {};
  final Map<String, DateTime> _lastAttempt = {};

  Timer? _scanTimer;
  Timer? _syncTimer;
  Timer? _simulationTimer;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<GattWrite>? _gattWriteSub;

  MeshStatus get status => _status;
  String? get lastError => _lastError;
  String? get nodeId => _nodeId;
  bool get isAdvertising => _advertising;
  bool get isScanning => _scanning;
  bool get isSyncing => _syncing;
  bool get isSimulation => _status == MeshStatus.simulation;
  DateTime? get lastSyncAt => _lastSyncAt;
  int get packetsRelayed => _packetsRelayed;
  int get packetsReceived => _packetsReceived;
  int get syncRounds => _syncRounds;

  /// العقد المجاورة الحديثة (آخر دقيقتين)، الأقوى إشارة أولاً.
  List<MeshPeer> get peers {
    final fresh = _peers.values.where((p) => p.isFresh).toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    return fresh;
  }

  int get peerCount => peers.length;

  /// تشغيل المش مرة واحدة عند إقلاع التطبيق.
  Future<void> init() async {
    if (_initialized || _disposed) return;
    _initialized = true;
    await start();
  }

  /// بدء الإعلان + المسح، أو الانتقال لوضع المحاكاة.
  Future<void> start() async {
    if (_disposed) return;
    _setStatus(MeshStatus.starting);
    _lastError = null;

    try {
      final identity = await _dtn.pki.ensureIdentity();
      _nodeId = identity.nodeId;
    } catch (error) {
      _lastError = 'تعذّر توليد هوية العقدة: $error';
    }

    if (_nodeId == null) {
      _startSimulation();
      return;
    }

    final supported = await _bleSupported();
    if (!supported) {
      _lastError =
          'لا يتوفر عتاد BLE للإعلان/المسح على هذه المنصة. تم تفعيل المحاكاة.';
      _startSimulation();
      return;
    }

    await _ensurePermissions();

    var startedSomething = false;
    startedSomething = await _startAdvertising() || startedSomething;
    startedSomething = await _startScanning() || startedSomething;

    if (!startedSomething) {
      _startSimulation();
      return;
    }

    _setStatus(MeshStatus.online);
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(seconds: 18),
      (_) => unawaited(syncNow()),
    );
  }

  /// إيقاف كل نشاط البلوتوث.
  Future<void> stop() async {
    _scanTimer?.cancel();
    _syncTimer?.cancel();
    _simulationTimer?.cancel();
    await _scanSub?.cancel();
    await _gattWriteSub?.cancel();
    _scanSub = null;
    _gattWriteSub = null;
    try {
      if (_scanning) await FlutterBluePlus.stopScan();
    } catch (_) {}
    _scanning = false;
    try {
      if (_advertising) await _peripheral.stop();
    } catch (_) {}
    _advertising = false;
    _setStatus(MeshStatus.stopped);
  }

  /// إعادة تشغيل الطبقة (زر «مزامنة الآن» في الواجهة).
  Future<void> restart() async {
    await stop();
    _initialized = false;
    await init();
  }

  Future<bool> _bleSupported() async {
    var central = false;
    var peripheral = false;
    try {
      central = await FlutterBluePlus.isSupported;
    } catch (_) {
      central = false;
    }
    try {
      peripheral = await _peripheral.isSupported;
    } catch (_) {
      peripheral = false;
    }
    return central || peripheral;
  }

  Future<void> _ensurePermissions() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    try {
      await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();
    } catch (_) {
      // بعض إصدارات النظام لا تعرّف كل الصلاحيات؛ نكمل ويظهر الخطأ من الطبقة الأصلية.
    }
    try {
      await _peripheral.requestPermission();
    } catch (_) {}
  }

  Future<bool> _startAdvertising() async {
    if (_nodeId == null) return false;
    try {
      final advertiseData = AdvertiseDataCore(
        serviceUuid: meshServiceUuid,
        localName: localName,
        manufacturerId: manufacturerId,
        manufacturerData: Uint8List.fromList(utf8.encode('RN:$_nodeId')),
      );
      final state = await _peripheral.start(
        advertiseData: advertiseData,
        gattServer: const GattServerSettings(
          serviceUuid: meshServiceUuid,
          txCharacteristicUuid: txCharacteristicUuid,
          rxCharacteristicUuid: rxCharacteristicUuid,
        ),
      );
      _advertising =
          state == PeripheralBluetoothState.ready ||
          state == PeripheralBluetoothState.granted;

      if (!_advertising) {
        _lastError = 'تعذّر بدء الإعلان (${state.name}).';
      }

      _gattWriteSub ??= _peripheral.onGattWrite.listen(
        _onGattWrite,
        onError: (Object error) {
          _lastError = 'خطأ في استقبال بيانات GATT: $error';
          _notify();
        },
      );
      return _advertising;
    } catch (error) {
      _lastError = 'فشل الإعلان عبر BLE: $error';
      return false;
    }
  }

  Future<bool> _startScanning() async {
    try {
      _scanSub ??= FlutterBluePlus.onScanResults.listen(
        _onScanResults,
        onError: (Object error) {
          _lastError = 'خطأ في مسح BLE: $error';
          _notify();
        },
      );
      await FlutterBluePlus.startScan(
        withServices: [Guid(meshServiceUuid)],
        timeout: const Duration(seconds: 20),
        continuousUpdates: true,
        androidScanMode: AndroidScanMode.lowLatency,
      );
      _scanning = true;

      _scanTimer?.cancel();
      _scanTimer = Timer.periodic(const Duration(seconds: 24), (_) {
        unawaited(_restartScan());
      });
      _notify();
      return true;
    } catch (error) {
      _lastError = 'تعذّر مسح BLE: $error';
      _scanning = false;
      return false;
    }
  }

  Future<void> _restartScan() async {
    if (_disposed || _status != MeshStatus.online) return;
    try {
      if (FlutterBluePlus.isScanningNow) return;
      await FlutterBluePlus.startScan(
        withServices: [Guid(meshServiceUuid)],
        timeout: const Duration(seconds: 20),
        continuousUpdates: true,
        androidScanMode: AndroidScanMode.lowLatency,
      );
    } catch (_) {
      // المحاولة التالية بعد 24 ثانية.
    }
  }

  void _onScanResults(List<ScanResult> results) {
    if (_disposed) return;
    var changed = false;
    for (final result in results) {
      final remoteId = result.device.remoteId.str;
      final advertisedNode = _nodeIdFromAdvertisement(result.advertisementData);
      final peerNodeId = advertisedNode ?? _shortId(remoteId);
      if (peerNodeId == _nodeId) continue; // لا نتصل بأنفسنا.

      final existing = _peers[peerNodeId];
      if (existing == null) {
        _peers[peerNodeId] = MeshPeer(
          nodeId: peerNodeId,
          remoteId: remoteId,
          rssi: result.rssi,
          lastSeen: DateTime.now(),
          name: result.advertisementData.advName.isEmpty
              ? localName
              : result.advertisementData.advName,
        );
        changed = true;
      } else {
        final wasStale = !existing.isFresh;
        existing
          ..rssi = result.rssi
          ..lastSeen = DateTime.now()
          ..remoteId = remoteId;
        changed = changed || wasStale;
      }
    }
    if (changed) _notify();
  }

  String? _nodeIdFromAdvertisement(AdvertisementData data) {
    final raw = data.manufacturerData[manufacturerId];
    if (raw == null) return null;
    try {
      final text = utf8.decode(raw);
      if (!text.startsWith('RN:')) return null;
      final id = text.substring(3).trim();
      return id.isEmpty ? null : id;
    } catch (_) {
      return null;
    }
  }

  String _shortId(String remoteId) {
    final cleaned = remoteId.replaceAll(':', '').replaceAll('-', '');
    if (cleaned.length <= 8) return cleaned;
    return cleaned.substring(cleaned.length - 8);
  }

  /// استقبال إطار مكتوب من عقدة متصلة بنا (نحن في دور Peripheral).
  void _onGattWrite(GattWrite write) {
    if (_disposed) return;
    if (write.characteristicUuid.isNotEmpty &&
        write.characteristicUuid.toLowerCase() !=
            rxCharacteristicUuid.toLowerCase()) {
      return;
    }
    final envelopeBytes = _reassembler.add(write.data);
    if (envelopeBytes == null) return;
    unawaited(_handleIncoming(envelopeBytes));
  }

  Future<void> _handleIncoming(Uint8List bytes) async {
    try {
      final envelope = DtnEnvelope.decode(utf8.decode(bytes));
      final accepted = await _dtn.acceptEnvelope(envelope);
      _packetsReceived++;
      if (accepted && !envelope.isExpired && envelope.ttl > 1) {
        // إعادة التمرير (Flooding) بعد إنقاص TTL وزيادة القفزات.
        await _dtn.queueForRelay(envelope.forwarded());
      }
      _notify();
    } catch (_) {
      // إطار تالف أو حمولة غير معروفة — يُهمل بصمت.
    }
  }

  /// بثّ حزمة جديدة (يُستدعى من معالج DTN عند إنشاء رسالة محلية).
  Future<void> broadcastEnvelope(DtnEnvelope envelope) async {
    await _dtn.queueForRelay(envelope);
    unawaited(syncNow());
  }

  /// دورة مزامنة واحدة: الاتصال بأقرب عقدة، كتابة صندوق الصادر، ثم قطع الاتصال.
  Future<void> syncNow() async {
    if (_disposed || _syncing) return;
    if (isSimulation) {
      _simulationSync();
      return;
    }
    if (_status != MeshStatus.online) return;

    final candidates = peers
        .where((peer) => _canAttempt(peer))
        .toList(growable: false);
    if (candidates.isEmpty) return;

    _syncing = true;
    _notify();
    try {
      final peer = candidates.first;
      _lastAttempt[peer.nodeId] = DateTime.now();

      final device = BluetoothDevice.fromId(peer.remoteId);
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 9),
      );

      final services = await device.discoverServices(timeout: 12);
      BluetoothCharacteristic? rx;
      for (final service in services) {
        if (service.serviceUuid != Guid(meshServiceUuid)) continue;
        for (final characteristic in service.characteristics) {
          if (characteristic.characteristicUuid == Guid(rxCharacteristicUuid)) {
            rx = characteristic;
            break;
          }
        }
        if (rx != null) break;
      }

      if (rx == null) {
        _lastError = 'العقدة ${peer.nodeId} لا توفّر خاصية استقبال ResiliNet.';
        return;
      }

      final outbox = await _dtn.outboxEnvelopes();
      for (final envelope in outbox) {
        final frames = _frameEnvelope(envelope.encode());
        for (final frame in frames) {
          await rx.write(
            frame,
            withoutResponse: false,
            allowLongWrite: false,
            timeout: 8,
          );
          await Future<void>.delayed(const Duration(milliseconds: 18));
        }
        _packetsRelayed++;
      }

      peer.lastSyncedAt = DateTime.now();
      _lastSyncAt = DateTime.now();
      _syncRounds++;
      _lastError = null;
    } catch (error) {
      _lastError = 'تعذّرت مزامنة المش: ${_friendlyBleError(error)}';
    } finally {
      try {
        final device = BluetoothDevice.fromId(candidates.first.remoteId);
        if (device.isConnected) await device.disconnect();
      } catch (_) {}
      _syncing = false;
      _notify();
    }
  }

  bool _canAttempt(MeshPeer peer) {
    final last = _lastAttempt[peer.nodeId];
    if (last == null) return true;
    return DateTime.now().difference(last) > const Duration(seconds: 45);
  }

  String _friendlyBleError(Object error) {
    if (error is FlutterBluePlusException) {
      return '${error.description} (${error.code})';
    }
    return error.toString();
  }

  /// تقسيم حمولة إلى إطارات تحمل ترويسة (R N seq total).
  List<Uint8List> _frameEnvelope(String json) {
    final data = Uint8List.fromList(utf8.encode(json));
    final total = (data.length / _framePayloadSize).ceil().clamp(1, _maxFrames);
    final frames = <Uint8List>[];
    for (var index = 0; index < total; index++) {
      final start = index * _framePayloadSize;
      final end = (start + _framePayloadSize > data.length)
          ? data.length
          : start + _framePayloadSize;
      final chunk = data.sublist(start, end);
      final frame = Uint8List(4 + chunk.length);
      frame[0] = _frameMagic0;
      frame[1] = _frameMagic1;
      frame[2] = index;
      frame[3] = total;
      frame.setRange(4, frame.length, chunk);
      frames.add(frame);
    }
    return frames;
  }

  // ── وضع المحاكاة ──────────────────────────────────────────────────────
  //
  // يُستخدم فقط عندما لا يتوفر عتاد BLE أو تُرفض الصلاحيات. لا يولّد حزماً
  // وهمية في صندوق الرسائل، بل يعرض عقداً افتراضية كي تبقى تجربة الواجهة
  // والمزامنة قابلة للاستعراض.

  void _startSimulation() {
    _simulationTimer?.cancel();
    _peers
      ..clear()
      ..['SIM-RELAY-01'] = MeshPeer(
        nodeId: 'SIM-RELAY-01',
        remoteId: 'sim-relay-01',
        rssi: -58,
        lastSeen: DateTime.now(),
        name: 'عقدة تمرير (محاكاة)',
      )
      ..['SIM-HUB-02'] = MeshPeer(
        nodeId: 'SIM-HUB-02',
        remoteId: 'sim-hub-02',
        rssi: -71,
        lastSeen: DateTime.now(),
        name: 'عقدة ذهبية (محاكاة)',
      );
    _simulationTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_disposed) return;
      for (final peer in _peers.values) {
        peer.lastSeen = DateTime.now();
        peer.rssi = (peer.rssi + 3).clamp(-95, -35);
      }
      _notify();
    });
    _setStatus(MeshStatus.simulation);
  }

  void _simulationSync() {
    _syncRounds++;
    _lastSyncAt = DateTime.now();
    _packetsRelayed += 1;
    for (final peer in _peers.values) {
      peer.lastSyncedAt = DateTime.now();
    }
    _notify();
  }

  void _setStatus(MeshStatus status) {
    if (_status == status) {
      _notify();
      return;
    }
    _status = status;
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _scanTimer?.cancel();
    _syncTimer?.cancel();
    _simulationTimer?.cancel();
    unawaited(stop());
    super.dispose();
  }
}

/// إعادة تجميع إطارات حزمة واحدة. تُعامَل كل كتابة GATT كإطار مستقل.
class _FrameReassembler {
  int _total = 0;
  DateTime? _startedAt;
  final Map<int, Uint8List> _chunks = {};

  Uint8List? add(Uint8List frame) {
    if (frame.length < 5) return null;
    if (frame[0] != 0x52 || frame[1] != 0x4E) return null;

    final seq = frame[2];
    final total = frame[3];
    if (total <= 0 || seq >= total) {
      reset();
      return null;
    }

    final now = DateTime.now();
    final expired =
        _startedAt != null &&
        now.difference(_startedAt!) > const Duration(seconds: 40);

    if (seq == 0 || expired || (_total != 0 && _total != total)) {
      reset();
      _total = total;
      _startedAt = now;
    }

    _chunks[seq] = frame.sublist(4);
    if (_chunks.length < _total) return null;

    final builder = BytesBuilder(copy: false);
    for (var index = 0; index < _total; index++) {
      final chunk = _chunks[index];
      if (chunk == null) {
        reset();
        return null;
      }
      builder.add(chunk);
    }
    final result = builder.takeBytes();
    reset();
    return result;
  }

  void reset() {
    _total = 0;
    _startedAt = null;
    _chunks.clear();
  }
}

// ── مزوّد MeshRouter (في mesh_router.dart) ──────────────────────────────
