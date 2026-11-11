import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_store.dart';

/// هوية تشفيرية للجهاز (مفتاح Ed25519).
///
/// تُولَّد مرة واحدة عند أول تشغيل وتُخزَّن محلياً؛ يُشتق منها معرّف العقدة
/// (Node ID) الذي يُستخدم في ترويسة كل حزمة DTN.
class NodeIdentity {
  NodeIdentity({
    required this.keyPair,
    required this.publicKey,
    required this.nodeId,
  });

  final SimpleKeyPair keyPair;
  final SimplePublicKey publicKey;

  /// بصمة قصيرة (16 حرف hex) من SHA-256 للمفتاح العام.
  final String nodeId;

  Uint8List get publicKeyBytes => Uint8List.fromList(publicKey.bytes);

  /// المفتاح العام بصيغة Base64 لتضمينه في الحزم.
  String get publicKeyB64 => base64Encode(publicKeyBytes);
}

/// التوقيع والتحقق الرقمي أوفلاين (Ed25519).
///
/// لا يعتمد على أي سيرفر: كل جهاز يوقّع منشوراته بمفتاحه الخاص، ويتحقق
/// المستقبل من التوقيع باستخدام المفتاح العام المرفق. قائمة الثقة المحلية
/// (Trust Store) تسمح بترقية مصدر إلى «موثوق» بعد التحقق اليدوي منه
/// (مثلاً عبر رمز QR أو مقارنة بصمة المفتاح وجهًا لوجه).
class PkiVerifier {
  final Ed25519 _ed25519 = Ed25519();

  NodeIdentity? _identity;

  /// تحميل الهوية المخزنة أو إنشاء هوية جديدة.
  Future<NodeIdentity> ensureIdentity() async {
    final cached = _identity;
    if (cached != null) return cached;

    final storedSeed = LocalStore.get<String>(
      LocalStore.identityBox,
      'seed_b64',
    );

    SimpleKeyPair keyPair;
    if (storedSeed != null) {
      keyPair = await _ed25519.newKeyPairFromSeed(base64Decode(storedSeed));
    } else {
      keyPair = await _ed25519.newKeyPair();
      final extracted = await keyPair.extract();
      final seedBytes = extracted.bytes;
      await LocalStore.write(
        LocalStore.identityBox,
        'seed_b64',
        base64Encode(seedBytes),
      );
    }

    final publicKey = await keyPair.extractPublicKey();
    final digest = await Sha256().hash(publicKey.bytes);
    final hex = digest.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final identity = NodeIdentity(
      keyPair: keyPair,
      publicKey: publicKey,
      nodeId: hex.substring(0, 16),
    );
    _identity = identity;
    return identity;
  }

  /// توقيع بيانات وإرجاع التوقيع بصيغة Base64.
  Future<String> signBytes(List<int> data) async {
    final identity = await ensureIdentity();
    final signature = await _ed25519.sign(data, keyPair: identity.keyPair);
    return base64Encode(signature.bytes);
  }

  /// التحقق من توقيع بصيغة Base64 باستخدام مفتاح عام بصيغة Base64.
  Future<bool> verifyBytes({
    required List<int> data,
    required String signatureB64,
    required String publicKeyB64,
  }) async {
    try {
      final publicKey = SimplePublicKey(
        base64Decode(publicKeyB64),
        type: KeyPairType.ed25519,
      );
      final signature = Signature(
        base64Decode(signatureB64),
        publicKey: publicKey,
      );
      return await _ed25519.verify(data, signature: signature);
    } catch (_) {
      return false;
    }
  }

  /// هل المفتاح العام موجود في قائمة الثقة المحلية؟
  bool isTrusted(String publicKeyB64) =>
      LocalStore.exists(LocalStore.trustBox, publicKeyB64);

  /// إضافة مفتاح عام إلى قائمة الثقة (بعد تحقق يدوي من بصمته).
  Future<void> trustKey(String publicKeyB64) => LocalStore.write(
    LocalStore.trustBox,
    publicKeyB64,
    DateTime.now().toUtc().toIso8601String(),
  );

  /// إزالة مفتاح من قائمة الثقة.
  Future<void> untrustKey(String publicKeyB64) =>
      LocalStore.remove(LocalStore.trustBox, publicKeyB64);
}

final pkiVerifierProvider = Provider<PkiVerifier>((ref) => PkiVerifier());

/// هوية الجهاز كوسيط غير متزامن للواجهة.
final identityProvider = FutureProvider<NodeIdentity>((ref) {
  return ref.watch(pkiVerifierProvider).ensureIdentity();
});
