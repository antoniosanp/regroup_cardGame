// Central asset path constants for the wood/parchment board art under
// assets/attributesImg. Presentation-only asset wiring — mirrors the web
// client's assets.ts. Nothing here computes game rules.

const String _base = 'assets/attributesImg';

class BoardArt {
  static const boardBackground = '$_base/boardBackground.png';
  static const borderPole1 = '$_base/boardElements/borderPole1.png';
  static const borderPole2 = '$_base/boardElements/borderPole2.png';
  static const cardBack = '$_base/boardElements/cardBack.png';
  static const coin = '$_base/boardElements/coin.png';
  static const cornerGoldBl = '$_base/boardElements/cornerGold_bl.png';
  static const cornerGoldTl = '$_base/boardElements/cornerGold_tl.png';
  static const cornerMetalBl = '$_base/boardElements/cornerMetal_bl.png';
  static const cornerMetalTl = '$_base/boardElements/cornerMetal_tl.png';
  static const cornerMetalTr = '$_base/boardElements/cornerMetal_tr.png';
  static const frameThin = '$_base/boardElements/frameThin.png';
  static const hp = '$_base/boardElements/hp.png';
  static const mainBoard = '$_base/boardElements/mainBoard.png';
  static const ma = '$_base/boardElements/ma.png';
  static const marketFrame = '$_base/boardElements/marketFrame.png';
  static const md = '$_base/boardElements/md.png';
  static const opponentBoardButton =
      '$_base/boardElements/opponentBoardButton.png';
  static const pa = '$_base/boardElements/pa.png';
  static const panelSquare = '$_base/boardElements/panelSquare.png';
  static const panelWide = '$_base/boardElements/panelWide.png';
  static const pd = '$_base/boardElements/pd.png';
  static const playerPanel = '$_base/boardElements/playerPanel.png';
  static const pot = '$_base/boardElements/pot.png';
}

/// Menu chrome. The plank* variants are the shipped button art with its
/// baked-in label patched out — icon, wood grain and metal brackets are the
/// original pixels; labels are drawn as text on top.
class MenuArt {
  static const menuBackground = '$_base/MenuAssets/menuBackground.png';
  static const plankHelm = '$_base/MenuAssets/plankHelm.png';
  static const plankSwords = '$_base/MenuAssets/plankSwords.png';
  static const plankBanner = '$_base/MenuAssets/plankBanner.png';
  static const plankCart = '$_base/MenuAssets/plankCart.png';
  static const plankGear = '$_base/MenuAssets/plankGear.png';
  static const plankDoor = '$_base/MenuAssets/plankDoor.png';
  static const plankBlank = '$_base/MenuAssets/plankBlank.png';
  static const fieldBlank = '$_base/MenuAssets/fieldBlank.png';
}

const List<String> _avatars = [
  '$_base/players/player1.png',
  '$_base/players/player2.png',
  '$_base/players/player3.png',
  '$_base/players/player4.png',
];

/// Seat number (any integer) -> one of the 4 player portraits, wrapping.
String avatarFor(int seat) {
  final i = ((seat % _avatars.length) + _avatars.length) % _avatars.length;
  return _avatars[i];
}

enum StatKey { hp, pa, pd, ma, md, cn, hpp }

const Map<StatKey, String> statIcon = {
  StatKey.hp: BoardArt.hp,
  StatKey.pa: BoardArt.pa,
  StatKey.pd: BoardArt.pd,
  StatKey.ma: BoardArt.ma,
  StatKey.md: BoardArt.md,
  StatKey.cn: BoardArt.coin,
  StatKey.hpp: BoardArt.pot,
};
