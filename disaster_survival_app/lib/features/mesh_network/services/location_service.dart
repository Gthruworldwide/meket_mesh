import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'sos_draft.dart';

/// الحصول على إحداثيات محلية لإرفاقها بنداء الاستغاثة.
///
/// كل المحاولات تُغلَّف بأمان: أي فشل أو رفض صلاحية يُعيد `null` بدلاً من
/// تعطيل بث النداء، لأن نص الاستغاثة يبقى صالحاً بدون موقع.
class MeshLocationService {
  const MeshLocationService();

  Future<GeoFix?> currentFix({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return null;
      }

      if (!await Geolocator.isLocationServiceEnabled()) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: timeout,
        ),
      );

      return GeoFix(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
      );
    } catch (_) {
      return null;
    }
  }
}

final meshLocationServiceProvider = Provider<MeshLocationService>(
  (ref) => const MeshLocationService(),
);
