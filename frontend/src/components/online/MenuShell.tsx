// Shared chrome for every pre-match screen (name entry, lobby, queue, how-to-play).
// All of them render inside one fixed-size panel so the background never changes
// dimensions between screens, and every option is drawn at one uniform button size
// regardless of the small height differences in the source plank art.

import type { ReactNode } from 'react';
import { MENU_ART } from '../../online/assets';

/** The 467x548 framed scene. Rendered at its native size — the source art is
 *  low-resolution, so upscaling it would only soften the painting. */
export function MenuPanel({ children }: { children: ReactNode }) {
  return (
    <div className="menu-panel" style={{ backgroundImage: `url(${MENU_ART.menuBackground})` }}>
      {/* The logo is painted into the background, so the column starts below it. */}
      <div className="menu-options">{children}</div>
    </div>
  );
}

interface MenuButtonProps {
  /** One of MENU_ART's plank* images — the icon is part of the art. */
  icon: string;
  label: string;
  onClick?: () => void;
  disabled?: boolean;
  type?: 'button' | 'submit';
}

export function MenuButton({ icon, label, onClick, disabled, type = 'button' }: MenuButtonProps) {
  return (
    <button
      type={type}
      className="menu-btn"
      style={{ backgroundImage: `url(${icon})` }}
      onClick={onClick}
      disabled={disabled}
    >
      <span className="menu-btn-label">{label}</span>
    </button>
  );
}
