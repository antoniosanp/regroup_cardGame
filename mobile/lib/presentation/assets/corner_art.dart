import '../../domain/models/corner_attribute.dart';

const String _base = 'assets/attributesImg';

/// Corner artwork paths, keyed by [CornerAttribute]. Mirrors the web client's
/// `CORNER_META` in cards.ts.
const Map<CornerAttribute, String> cornerIcon = {
  CornerAttribute.empty: '$_base/empty.png',
  CornerAttribute.hpPotionCoin: '$_base/hp_potion_coin.png',
  CornerAttribute.coins2: '$_base/coins_2.png',
  CornerAttribute.pa1: '$_base/pa_1.png',
  CornerAttribute.pa2: '$_base/pa_2.png',
  CornerAttribute.pd1: '$_base/pd_1.png',
  CornerAttribute.pd2: '$_base/pd_2.png',
  CornerAttribute.ma1: '$_base/ma_1.png',
  CornerAttribute.ma2: '$_base/ma_2.png',
  CornerAttribute.md1: '$_base/md_1.png',
  CornerAttribute.md2: '$_base/md_2.png',
};

String iconFor(CornerAttribute attribute) =>
    cornerIcon[attribute] ?? cornerIcon[CornerAttribute.empty]!;
