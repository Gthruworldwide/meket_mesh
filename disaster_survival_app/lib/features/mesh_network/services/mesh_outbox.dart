import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dtn_packet_handler.dart';

/// الحزم المنتظرة في صندوق الصادر للتمرير عبر المش (Store-and-Forward).
final meshOutboxProvider = FutureProvider<List<DtnEnvelope>>((ref) {
  return ref.watch(dtnPacketHandlerProvider).outboxEnvelopes();
});
