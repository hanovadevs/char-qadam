import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tour_provider.dart';

final tourTargetsProvider = Provider((ref) => TourTargets());
GlobalKey tourKey(WidgetRef ref, String id) =>
    ref.read(tourTargetsProvider).key(id);
double tourBottomPadding(WidgetRef ref, BuildContext context) =>
    ref.watch(guidedTourProvider.select((s) => s.active))
    ? MediaQuery.sizeOf(context).height * .53 + 28
    : 28;

class TourTargets {
  final _keys = <String, GlobalKey>{};
  GlobalKey key(String id) =>
      _keys.putIfAbsent(id, () => GlobalKey(debugLabel: 'tour:$id'));
  BuildContext? context(String id) => _keys[id]?.currentContext;
  ScrollableState? scrollable(int tab) {
    ScrollableState? result;
    void visit(Element element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        result ??= element.state as ScrollableState;
      }
      if (result == null) element.visitChildElements(visit);
    }

    context('page.$tab')?.visitChildElements(visit);
    return result;
  }
}
