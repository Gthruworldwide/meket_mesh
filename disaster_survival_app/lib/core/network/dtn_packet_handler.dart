import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/offgrid_news/models/news_bulletin.dart';
import '../utils/local_store.dart';
import '../utils/pki_verifier.dart';

/// أنواع حزم DTN المدعومة.
class DtnType {
  DtnType._();
  static const String sos = 'sos';
  static const String news = 'news';
}

/// مغلّف حزمة DTN (Store-and-Forward).
///
/// التوقيع يغطي المحتوى فقط (المعرّف، النوع، المصدر، الوقت، والحمولة) ولا يغطي
/// عدد القفزات أو مدة الصلاحية، لأن كل عقدة تمرير تعدّل هذين الحقلين.
class DtnEnvelope {
  final String msgId;
  final String type;
  final String originNodeId;

  /// عدد القفزات التي قطعتها الحزمة.
  final int hops;

  /// ما تبقى من عمر الحزمة بالقفزات (Time-To-Live).
  final int ttl;

  final DateTime createdAt;
  final Map<String, dynamic> payload;
  final String? signature;
  final String? signerKey;

  /// نتيجة التحقق المحلية (لا تُنقل عبر الشبكة).
  final bool verified;

  const DtnEnvelope({
    required this.msgId,
    required this.type,
    required this.originNodeId,
    required this.hops,
    required this.ttl,
    required this.createdAt,
    required this.payload,
    this.signature,
    this.signerKey,
    this.verified = false,
  });

  bool get isSos => type == DtnType.sos;
  bool get isExpired =>
      ttl <= 0 ||
      DateTime.now().toUtc().difference(createdAt) > const Duration(hours: 72);

  Map<String, dynamic> toJson() => {
    'msgId': msgId,
    'type': type,
    'originNodeId': originNodeId,
    'hops': hops,
    'ttl': ttl,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'payload': payload,
    'signature': signature,
    'signerKey': signerKey,
  };

  factory DtnEnvelope.fromJson(Map<String, dynamic> json) {
    return DtnEnvelope(
      msgId: json['msgId'] as String? ?? '',
      type: json['type'] as String? ?? DtnType.news,
      originNodeId: json['originNodeId'] as String? ?? '',
      hops: json['hops'] as int? ?? 0,
      ttl: json['ttl'] as int? ?? 0,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
      signature: json['signature'] as String?,
      signerKey: json['signerKey'] as String?,
    );
  }

  String encode() => jsonEncode(toJson());

  static DtnEnvelope decode(String raw) =>
      DtnEnvelope.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  DtnEnvelope forwarded() => DtnEnvelope(
    msgId: msgId,
    type: type,
    originNodeId: originNodeId,
    hops: hops + 1,
    ttl: ttl - 1,
    createdAt: createdAt,
    payload: payload,
    signature: signature,
    signerKey: signerKey,
    verified: verified,
  );

  DtnEnvelope copyWith({bool? verified, int? hops, int? ttl}) => DtnEnvelope(
    msgId: msgId,
    type: type,
    originNodeId: originNodeId,
    hops: hops ?? this.hops,
    ttl: ttl ?? this.ttl,
    createdAt: createdAt,
    payload: payload,
    signature: signature,
    signerKey: signerKey,
    verified: verified ?? this.verified,
  );

  /// المحتوى الموقّع (ترتيب مفاتيح قانوني لضمان تطابق التوقيع).
  String buildSignable() => jsonEncode(
    _canonical({
      'id': msgId,
      'type': type,
      'origin': originNodeId,
      'ts': createdAt.toUtc().toIso8601String(),
      'payload': payload,
    }),
  );

  static Object? _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((k) => k.toString()).toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }
}

/// رسالة استغاثة مهيّأة للعرض.
class SosMessage {
  final String callsign;
  final String message;
  final String originNodeId;
  final DateTime timestamp;
  final int hops;
  final bool verified;
  final double? lat;
  final double? lng;

  const SosMessage({
    required this.callsign,
    required this.message,
    required this.originNodeId,
    required this.timestamp,
    required this.hops,
    required this.verified,
    this.lat,
    this.lng,
  });

  factory SosMessage.fromEnvelope(DtnEnvelope envelope) {
    return SosMessage(
      callsign: envelope.payload['callsign'] as String? ?? 'غير معروف',
      message: envelope.payload['message'] as String? ?? '',
      originNodeId: envelope.originNodeId,
      timestamp: envelope.createdAt.toLocal(),
      hops: envelope.hops,
      verified: envelope.verified,
      lat: (envelope.payload['lat'] as num?)?.toDouble(),
      lng: (envelope.payload['lng'] as num?)?.toDouble(),
    );
  }

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
  }
}

/// معالج حزم DTN: إنشاء، توقيع، التحقق، منع التكرار، والتمرير (Store-and-Forward).
class DtnPacketHandler {
  DtnPacketHandler({required this.pki});

  final PkiVerifier pki;

  static const int maxTtl = 7;
  static const int _maxOutboxEntries = 80;
  static const Duration maxAge = Duration(hours: 72);

  final StreamController<DtnEnvelope> _incomingCtrl =
      StreamController<DtnEnvelope>.broadcast();
  final StreamController<NewsBulletin> _newsCtrl =
      StreamController<NewsBulletin>.broadcast();
  final StreamController<SosMessage> _sosCtrl =
      StreamController<SosMessage>.broadcast();

  Future<void> Function(DtnEnvelope envelope)? _broadcastHook;

  Stream<DtnEnvelope> get incomingEnvelopes => _incomingCtrl.stream;
  Stream<NewsBulletin> get newsStream => _newsCtrl.stream;
  Stream<SosMessage> get sosStream => _sosCtrl.stream;

  /// ربط المعالج بطبقة النقل (شبكة المش) لبث الحزم الجديدة.
  void attachBroadcast(Future<void> Function(DtnEnvelope) hook) {
    _broadcastHook = hook;
  }

  /// إنشاء حزمة موقّعة جاهزة للنقل.
  Future<DtnEnvelope> createEnvelope({
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    final identity = await pki.ensureIdentity();
    final createdAt = DateTime.now().toUtc();
    final draft = DtnEnvelope(
      msgId:
          '${identity.nodeId}-${createdAt.microsecondsSinceEpoch.toRadixString(36)}',
      type: type,
      originNodeId: identity.nodeId,
      hops: 0,
      ttl: maxTtl,
      createdAt: createdAt,
      payload: payload,
    );
    final signature = await pki.signBytes(
      Uint8List.fromList(utf8.encode(draft.buildSignable())),
    );
    return DtnEnvelope(
      msgId: draft.msgId,
      type: draft.type,
      originNodeId: draft.originNodeId,
      hops: draft.hops,
      ttl: draft.ttl,
      createdAt: draft.createdAt,
      payload: draft.payload,
      signature: signature,
      signerKey: identity.publicKeyB64,
    );
  }

  /// إنشاء وبث نداء استغاثة.
  Future<DtnEnvelope> sendSos({
    required String callsign,
    required String message,
    double? lat,
    double? lng,
  }) async {
    final envelope = await createEnvelope(
      type: DtnType.sos,
      payload: {
        'callsign': callsign,
        'message': message,
        'lat': ?lat,
        'lng': ?lng,
      },
    );
    await _publish(envelope);
    return envelope;
  }

  /// توقيع وبث خبر جديد (نشرة محلية).
  Future<NewsBulletin> publishBulletin({
    required String title,
    required String body,
    required NewsSeverity severity,
  }) async {
    final envelope = await createEnvelope(
      type: DtnType.news,
      payload: {'title': title, 'body': body, 'severity': severity.name},
    );
    await _publish(envelope);
    return _bulletinFromEnvelope(
      envelope.copyWith(verified: true),
      source: 'محلي / مش',
    );
  }

  Future<void> _publish(DtnEnvelope envelope) async {
    await _storeOutbox(envelope);
    await acceptEnvelope(envelope);
    await _broadcastHook?.call(envelope);
  }

  /// استقبال حزمة: منع التكرار، فحص الصلاحية، التحقق من التوقيع، ثم التسليم.
  ///
  /// تعيد `true` إذا قُبلت الحزمة وأصبحت مؤهلة للتمرير.
  Future<bool> acceptEnvelope(DtnEnvelope envelope) async {
    if (envelope.msgId.isEmpty) return false;
    if (envelope.isExpired) return false;
    if (LocalStore.exists(LocalStore.dtnSeen, envelope.msgId)) return false;

    var verified = false;
    final signature = envelope.signature;
    final signerKey = envelope.signerKey;
    if (signature != null && signerKey != null) {
      verified = await pki.verifyBytes(
        data: utf8.encode(envelope.buildSignable()),
        signatureB64: signature,
        publicKeyB64: signerKey,
      );
    }

    final verifiedEnvelope = envelope.copyWith(verified: verified);

    await LocalStore.write(
      LocalStore.dtnSeen,
      envelope.msgId,
      DateTime.now().toIso8601String(),
    );
    await LocalStore.write(
      LocalStore.dtnInbox,
      envelope.msgId,
      envelope.encode(),
    );

    _incomingCtrl.add(verifiedEnvelope);

    if (verifiedEnvelope.isSos) {
      _sosCtrl.add(SosMessage.fromEnvelope(verifiedEnvelope));
    } else if (verifiedEnvelope.type == DtnType.news) {
      _newsCtrl.add(
        _bulletinFromEnvelope(
          verifiedEnvelope,
          source: 'شبكة مش / DTN',
          trusted: signerKey != null && pki.isTrusted(signerKey),
        ),
      );
    }

    return true;
  }

  /// إضافة حزمة إلى صندوق الصادر لتمريرها لاحقاً (Relay).
  Future<void> queueForRelay(DtnEnvelope envelope) => _storeOutbox(envelope);

  /// الحزم الجاهزة للتمرير (الأحدث أولاً).
  Future<List<DtnEnvelope>> outboxEnvelopes() async {
    final envelopes = <DtnEnvelope>[];
    for (final raw in LocalStore.values(LocalStore.dtnOutbox)) {
      if (raw is! String) continue;
      try {
        envelopes.add(DtnEnvelope.decode(raw));
      } catch (_) {
        // حزمة تالفة — تُهمل بصمت.
      }
    }
    envelopes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return envelopes.take(40).toList(growable: false);
  }

  Future<void> _storeOutbox(DtnEnvelope envelope) async {
    if (envelope.isExpired) return;
    await LocalStore.write(
      LocalStore.dtnOutbox,
      envelope.msgId,
      envelope.encode(),
    );
    await _pruneOutbox();
  }

  Future<void> _pruneOutbox() async {
    final entries = LocalStore.entries(LocalStore.dtnOutbox);
    if (entries.length <= _maxOutboxEntries) return;

    final decoded = <String, DtnEnvelope>{};
    for (final entry in entries.entries) {
      try {
        final envelope = DtnEnvelope.decode(entry.value as String);
        decoded[entry.key as String] = envelope;
      } catch (_) {
        await LocalStore.remove(LocalStore.dtnOutbox, entry.key);
      }
    }

    final sorted = decoded.entries.toList()
      ..sort((a, b) => b.value.createdAt.compareTo(a.value.createdAt));

    final now = DateTime.now().toUtc();
    for (var i = 0; i < sorted.length; i++) {
      final envelope = sorted[i].value;
      final tooOld = now.difference(envelope.createdAt) > maxAge;
      final overflow = i >= _maxOutboxEntries;
      if (tooOld || overflow || envelope.ttl <= 0) {
        await LocalStore.remove(LocalStore.dtnOutbox, sorted[i].key);
      }
    }
  }

  NewsBulletin _bulletinFromEnvelope(
    DtnEnvelope envelope, {
    required String source,
    bool trusted = false,
  }) {
    return NewsBulletin(
      id: envelope.msgId,
      title: envelope.payload['title'] as String? ?? '(بدون عنوان)',
      body: envelope.payload['body'] as String? ?? '',
      severity: newsSeverityFromId(envelope.payload['severity'] as String?),
      source: source,
      originNodeId: envelope.originNodeId,
      timestamp: envelope.createdAt.toLocal(),
      hops: envelope.hops,
      signature: envelope.signature,
      signerKey: envelope.signerKey,
      verified: envelope.verified,
      trusted: trusted,
    );
  }

  void dispose() {
    _incomingCtrl.close();
    _newsCtrl.close();
    _sosCtrl.close();
  }
}

final dtnPacketHandlerProvider = Provider<DtnPacketHandler>((ref) {
  final handler = DtnPacketHandler(pki: ref.watch(pkiVerifierProvider));
  ref.onDispose(handler.dispose);
  return handler;
});

/// تدفق أنباء شبكة المش.
final meshNewsProvider = StreamProvider<NewsBulletin>((ref) {
  return ref.watch(dtnPacketHandlerProvider).newsStream;
});

/// تدفق نداءات الاستغاثة الواردة عبر المش.
final incomingSosProvider = StreamProvider<SosMessage>((ref) {
  return ref.watch(dtnPacketHandlerProvider).sosStream;
});
