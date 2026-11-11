import 'package:disaster_survival_app/core/constants/disaster_types.dart';
import 'package:disaster_survival_app/core/network/dtn_packet_handler.dart';
import 'package:disaster_survival_app/features/medical_triage/services/offline_triage_engine.dart';
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
}
