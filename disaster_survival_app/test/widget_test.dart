import 'package:disaster_survival_app/core/constants/disaster_types.dart';
import 'package:disaster_survival_app/core/network/dtn_packet_handler.dart';
import 'package:disaster_survival_app/core/network/mesh_manager.dart';
import 'package:disaster_survival_app/core/utils/pki_verifier.dart';
import 'package:disaster_survival_app/features/medical_triage/services/offline_triage_engine.dart';
import 'package:disaster_survival_app/features/mesh_network/models/mesh_link.dart';
import 'package:disaster_survival_app/features/mesh_network/services/sos_draft.dart';
import 'package:disaster_survival_app/features/offgrid_news/models/news_bulletin.dart';
import 'package:disaster_survival_app/features/offgrid_news/services/rds_sdr_listener.dart';
import 'package:disaster_survival_app/features/survival_checklists/models/equipment_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('محرك الفرز الطبي (START)', () {
    test('النزيف الحاد غير المسيطر عليه = فوري', () {
      final result = OfflineTriageEngine.evaluate(
        TriageInput(severeBleeding: true),
      );
      expect(result, isNotNull);
      expect(result!.category, TriageCategory.immediate);
      expect(result.instructions, isNotEmpty);
    });

    test('القادر على المشي = بسيط', () {
      final result = OfflineTriageEngine.evaluate(
        TriageInput(severeBleeding: false, canWalk: true),
      );
      expect(result?.category, TriageCategory.minor);
    });

    test('توقف التنفس = رعاية تلطيفية', () {
      final result = OfflineTriageEngine.evaluate(
        TriageInput(severeBleeding: false, canWalk: false, isBreathing: false),
      );
      expect(result?.category, TriageCategory.expectant);
    });

    test('مستقر تنفسياً ودورانياً = مؤجل', () {
      final result = OfflineTriageEngine.evaluate(
        TriageInput(
          severeBleeding: false,
          canWalk: false,
          isBreathing: true,
          normalRespiration: true,
          normalPerfusion: true,
          obeysCommands: true,
        ),
      );
      expect(result?.category, TriageCategory.delayed);
    });

    test('البيانات الناقصة تُعيد null لمواصلة الأسئلة', () {
      expect(OfflineTriageEngine.evaluate(TriageInput()), isNull);
    });
  });

  group('حاسبة احتياجات البقاء', () {
    test('تحسب المياه والسعرات والعبوات والأقراص', () {
      final needs = OfflineTriageEngine.computeSurvivalNeeds(
        persons: 4,
        children: 1,
        days: 3,
      );

      // 3 بالغين × 3 لتر + طفل × 1.5 = 10.5 لتر/يوم × 3 أيام.
      expect(needs.drinkingWaterLiters, closeTo(31.5, 0.001));
      // نظافة: 4 أشخاص × 2 لتر × 3 أيام.
      expect(needs.hygieneWaterLiters, closeTo(24.0, 0.001));
      expect(needs.totalWaterLiters, closeTo(55.5, 0.001));
      expect(needs.waterContainers5L, 12);
      expect(needs.purificationTablets, 16);
      expect(needs.caloriesKcal, 22200);
      expect(needs.dryFoodKg, closeTo(6.3428, 0.001));
    });
  });

  group('بروتوكول RDS', () {
    test('تجميع وتفكيك RadioText', () {
      const text = 'تحذير سيول في وادي النمل';
      final frames = RdsSdrListener.encodeRadioText(text);
      expect(frames.length, greaterThan(1));
      expect(RdsSdrListener.decodeRadioText(frames), text);
    });

    test('تغليف نشرة وفكها', () {
      final bulletin = NewsBulletin(
        id: 'test-1',
        title: 'عنوان تجريبي',
        body: 'نص النشرة التجريبية',
        severity: NewsSeverity.critical,
        source: 'اختبار',
        originNodeId: 'node-1',
        timestamp: DateTime.utc(2026, 1, 1),
      );
      final encoded = RdsSdrListener.encodeBulletin(bulletin);
      final decoded = RdsSdrListener.decodeBulletin(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.id, 'test-1');
      expect(decoded.severity, NewsSeverity.critical);
      expect(RdsSdrListener.decodeBulletin('غير صالح'), isNull);
    });
  });

  group('حزم DTN', () {
    test('التوقيع لا يتأثر بتعديل القفزات و TTL', () {
      final envelope = DtnEnvelope(
        msgId: 'msg-1',
        type: DtnType.news,
        originNodeId: 'node-a',
        hops: 0,
        ttl: 7,
        createdAt: DateTime.utc(2026, 1, 1, 12),
        payload: const {'title': 'خبر', 'body': 'محتوى'},
      );
      final forwarded = envelope.forwarded();
      expect(forwarded.hops, 1);
      expect(forwarded.ttl, 6);
      expect(forwarded.buildSignable(), envelope.buildSignable());
    });

    test('ترميز وفك الترميز يحفظ الحمولة', () {
      final envelope = DtnEnvelope(
        msgId: 'msg-2',
        type: DtnType.sos,
        originNodeId: 'node-b',
        hops: 2,
        ttl: 4,
        createdAt: DateTime.utc(2026, 2, 2),
        payload: const {'callsign': 'فريق 7', 'message': 'نحتاج ماءً'},
        signature: 'sig',
        signerKey: 'key',
      );
      final decoded = DtnEnvelope.decode(envelope.encode());
      expect(decoded.msgId, 'msg-2');
      expect(decoded.isSos, isTrue);
      expect(decoded.payload['callsign'], 'فريق 7');
      expect(decoded.signature, 'sig');
    });
  });

  group('نموذج التجهيزات', () {
    test('التحويل إلى JSON والعودة', () {
      final item = EquipmentItem(
        id: 'eq_test',
        name: 'جهاز اختبار',
        category: 'الاتصالات',
        description: 'وصف',
        priorityLevel: 1,
        applicableDisasters: const [
          DisasterCategory.commsOutage,
          DisasterCategory.flood,
        ],
        isAcquired: true,
      );
      final clone = EquipmentItem.fromJson(item.toJson());
      expect(clone.id, 'eq_test');
      expect(clone.isAcquired, isTrue);
      expect(clone.applicableDisasters, contains(DisasterCategory.flood));
      expect(clone.priorityLabel, 'حرج 72 ساعة');
    });
  });

  group('شبكة المش', () {
    test('تصنيف جودة الوصلة وأعمدة الإشارة', () {
      expect(LinkQuality.fromRssi(-50), LinkQuality.excellent);
      expect(LinkQuality.fromRssi(-65), LinkQuality.good);
      expect(LinkQuality.fromRssi(-80), LinkQuality.fair);
      expect(LinkQuality.fromRssi(-92), LinkQuality.weak);

      final peer = MeshPeer(
        nodeId: 'node-1',
        remoteId: 'AA:BB:CC',
        rssi: -65,
        lastSeen: DateTime.now(),
      );
      final link = MeshNodeLink.fromPeer(peer);
      expect(link.quality, LinkQuality.good);
      expect(link.signalBars, 3);
      expect(link.isSimulated, isFalse);
      expect(link.lastSeenLabel, 'الآن');
      expect(link.lastSyncLabel, 'لم تُزامَن بعد');
    });

    test('درجة صحة الشبكة تبلغ السقف وتصنّف الحالات', () {
      final robust = MeshReadiness.evaluate(
        peerCount: 6,
        online: true,
        simulation: false,
        syncRounds: 9,
        relayed: 5,
        received: 5,
      );
      expect(robust.score, 100);
      expect(robust.grade, MeshGrade.robust);
      expect(robust.normalized, 1.0);

      final idle = MeshReadiness.evaluate(
        peerCount: 0,
        online: false,
        simulation: false,
        syncRounds: 0,
        relayed: 0,
        received: 0,
      );
      expect(idle.score, 0);
      expect(idle.grade, MeshGrade.critical);

      final sim = MeshReadiness.evaluate(
        peerCount: 2,
        online: false,
        simulation: true,
        syncRounds: 1,
        relayed: 1,
        received: 0,
      );
      expect(sim.score, 38);
      expect(sim.grade, MeshGrade.limited);
    });
  });

  group('مسودة نداء الاستغاثة', () {
    test('التحقق يرفض الاسم الفارغ والوصف القصير', () {
      expect(SosDraft.validateCallsign('  '), isNotNull);
      expect(SosDraft.validateMessage('ماء'), isNotNull);
      expect(SosDraft.validateCallsign('فريق 7'), isNull);
      expect(SosDraft.validateMessage('نحتاج ماءً وإسعافاً'), isNull);
    });

    test('الحمولة تُنظّف النص وتستبعد الموقع غير الصالح', () {
      const draft = SosDraft(
        callsign: '  فريق 7  ',
        message: '  نحتاج ماءً  ',
        fix: GeoFix(latitude: 200, longitude: 46),
      );
      expect(draft.isValid, isTrue);
      expect(draft.hasLocation, isFalse);
      expect(draft.toPayload(), {
        'callsign': 'فريق 7',
        'message': 'نحتاج ماءً',
      });
    });

    test('الحمولة تتضمن الموقع الصالح ودقته', () {
      const draft = SosDraft(
        callsign: 'فريق 7',
        message: 'نحتاج ماءً',
        fix: GeoFix(
          latitude: 24.7136,
          longitude: 46.6753,
          accuracyMeters: 12,
        ),
      );
      expect(draft.hasLocation, isTrue);
      expect(draft.toPayload()['lat'], 24.7136);
      expect(draft.toPayload()['lng'], 46.6753);
      expect(draft.fix!.accuracyLabel, 'دقة ±12 م');
    });

    test('بث SOS يوقّع الحزمة ويضعها في صندوق الصادر', () async {
      final handler = DtnPacketHandler(pki: PkiVerifier());
      final envelope = await handler.sendSos(
        callsign: 'فريق 7',
        message: 'نحتاج ماءً وإسعافاً',
        lat: 24.7136,
        lng: 46.6753,
      );

      expect(envelope.isSos, isTrue);
      expect(envelope.signature, isNotNull);
      expect(envelope.signerKey, isNotNull);
      expect(envelope.payload['lat'], 24.7136);

      final outbox = await handler.outboxEnvelopes();
      expect(outbox.map((item) => item.msgId), contains(envelope.msgId));
      handler.dispose();
    });
  });
}
