// The "How to Play" submenu: read the rules, or play the guided tutorial. Renders in the
// same fixed-size panel as the lobby, so opening it never resizes the background.

import { MenuButton, MenuPanel } from '../components/online/MenuShell';
import { MENU_ART } from '../online/assets';
import { playSfx } from '../sfx/playSfx';

interface HowToPlayMenuProps {
  onRules: () => void;
  onTutorial: () => void;
  onBack: () => void;
}

export function HowToPlayMenu({ onRules, onTutorial, onBack }: HowToPlayMenuProps) {
  const choose = (go: () => void) => () => {
    playSfx('ui-click');
    go();
  };

  return (
    <MenuPanel>
      {/* Icons repeat the lobby's, which is fine — the two are never on screen together. */}
      <MenuButton icon={MENU_ART.plankSwords} label="Tutorial" onClick={choose(onTutorial)} />
      <MenuButton icon={MENU_ART.plankBanner} label="Rules" onClick={choose(onRules)} />
      <MenuButton icon={MENU_ART.plankDoor} label="Back" onClick={choose(onBack)} />
      <p className="menu-note">Learn to play, or read the rulebook</p>
    </MenuPanel>
  );
}
