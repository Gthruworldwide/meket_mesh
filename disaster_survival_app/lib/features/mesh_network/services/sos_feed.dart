import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dtn_packet_handler.dart';
import '../../../core/utils/local_store.dart';

/// دمج نداءات SOS الواردة مع سجل صندوق الوارد المحفوظ.
class SosFeedNotifier extends Notifier<List<SosMessage>> {
  static const int _maxItems = 25;

  @override
  List<SosMessage> build() {
    ref.listen(incomingSosProvider, (previous, next) {
      final message = next.value;
      if (message != null) _merge(message);
    });
    return _seedFromInbox();
  }

  void _merge(SosMessage message) {
    if (state.any(
      (existing) =>
          existing.originNodeId == message.originNodeId &&
          existing.timestamp == message.timestamp &&
          existing.message == message.message,
    )) {
      return;
    }
    final next = [message, ...state]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    state = next.take(_maxItems).toList(growable: false);
  }

  List<SosMessage> _seedFromInbox() {
    final messages = <SosMessage>[];
    for (final raw in LocalStore.values(LocalStore.dtnInbox)) {
      if (raw is! String) continue;
      try {
        final envelope = DtnEnvelope.decode(raw);
        if (envelope.isSos) {
          messages.add(SosMessage.fromEnvelope(envelope));
        }
      } catch (_) {
        // حزمة تالفة — تُهمل بصمت كما في بقية الطبقات.
      }
    }
    messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return messages.take(_maxItems).toList(growable: false);
  }
}

final sosFeedProvider = NotifierProvider<SosFeedNotifier, List<SosMessage>>(
  SosFeedNotifier.new,
);
