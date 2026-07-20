// Central import point for the wood/parchment board art under
// img/attributesImg/boardElements and img/attributesImg/players. Nothing here
// computes game rules — it's presentation-only asset wiring, same spirit as
// cards.ts's CORNER_META.

import boardBackground from '../img/attributesImg/boardBackground.png';
import borderPole1 from '../img/attributesImg/boardElements/borderPole1.png';
import borderPole2 from '../img/attributesImg/boardElements/borderPole2.png';
import cardBack from '../img/attributesImg/boardElements/cardBack.png';
import coin from '../img/attributesImg/boardElements/coin.png';
import cornerGoldBl from '../img/attributesImg/boardElements/cornerGold_bl.png';
import cornerGoldTl from '../img/attributesImg/boardElements/cornerGold_tl.png';
import cornerMetalBl from '../img/attributesImg/boardElements/cornerMetal_bl.png';
import cornerMetalTl from '../img/attributesImg/boardElements/cornerMetal_tl.png';
import cornerMetalTr from '../img/attributesImg/boardElements/cornerMetal_tr.png';
import frameThin from '../img/attributesImg/boardElements/frameThin.png';
import hp from '../img/attributesImg/boardElements/hp.png';
import mainBoard from '../img/attributesImg/boardElements/mainBoard.png';
import ma from '../img/attributesImg/boardElements/ma.png';
import marketFrame from '../img/attributesImg/boardElements/marketFrame.png';
import md from '../img/attributesImg/boardElements/md.png';
import opponentBoardButton from '../img/attributesImg/boardElements/opponentBoardButton.png';
import pa from '../img/attributesImg/boardElements/pa.png';
import panelSquare from '../img/attributesImg/boardElements/panelSquare.png';
import panelWide from '../img/attributesImg/boardElements/panelWide.png';
import pd from '../img/attributesImg/boardElements/pd.png';
import playerPanel from '../img/attributesImg/boardElements/playerPanel.png';
import pot from '../img/attributesImg/boardElements/pot.png';

import fieldBlank from '../img/attributesImg/MenuAssets/fieldBlank.png';
import menuBackground from '../img/attributesImg/MenuAssets/menuBackground.png';
import plankBanner from '../img/attributesImg/MenuAssets/plankBanner.png';
import plankBlank from '../img/attributesImg/MenuAssets/plankBlank.png';
import plankCart from '../img/attributesImg/MenuAssets/plankCart.png';
import plankDoor from '../img/attributesImg/MenuAssets/plankDoor.png';
import plankGear from '../img/attributesImg/MenuAssets/plankGear.png';
import plankHelm from '../img/attributesImg/MenuAssets/plankHelm.png';
import plankSwords from '../img/attributesImg/MenuAssets/plankSwords.png';

import player1 from '../img/attributesImg/players/player1.png';
import player2 from '../img/attributesImg/players/player2.png';
import player3 from '../img/attributesImg/players/player3.png';
import player4 from '../img/attributesImg/players/player4.png';

export const BOARD_ART = {
  boardBackground,
  borderPole1,
  borderPole2,
  cardBack,
  coin,
  cornerGoldBl,
  cornerGoldTl,
  cornerMetalBl,
  cornerMetalTl,
  cornerMetalTr,
  frameThin,
  hp,
  mainBoard,
  ma,
  marketFrame,
  md,
  opponentBoardButton,
  pa,
  panelSquare,
  panelWide,
  pd,
  playerPanel,
  pot,
};

// Menu chrome, cut from menuAndElements.png. The plank* variants are the shipped
// button art with its baked-in label patched out (the painted words were PLAY / ARMY /
// OPTIONS etc., which do not match this game's actual options) — the icon, wood grain
// and metal brackets are the original pixels, and labels are drawn as text on top.
export const MENU_ART = {
  menuBackground,
  plankHelm,
  plankSwords,
  plankBanner,
  plankCart,
  plankGear,
  plankDoor,
  plankBlank,
  fieldBlank,
};

const AVATARS = [player1, player2, player3, player4];

/** Seat number (any integer) -> one of the 4 player portraits, wrapping. */
export function avatarFor(seat: number): string {
  const i = ((seat % AVATARS.length) + AVATARS.length) % AVATARS.length;
  return AVATARS[i];
}

export type StatKey = 'hp' | 'pa' | 'pd' | 'ma' | 'md' | 'cn' | 'hpp';

export const STAT_ICON: Record<StatKey, string> = {
  hp,
  pa,
  pd,
  ma,
  md,
  cn: coin,
  hpp: pot,
};
