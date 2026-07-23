import 'package:flutter/material.dart';

import '../assets/board_art.dart';

// Exact logical dimensions from the web client's styles.css so the menu keeps
// its painted-art layout (the background art has the logo baked in, and the
// option column sits at a fixed inset over it). The whole 467x548 panel is
// scaled to fit the screen via FittedBox, since 548px tall won't fit a
// landscape phone — the source art is low-res so scaling down is lossless
// enough.
const double _panelWidth = 467;
const double _panelHeight = 548;
const double _optionsLeft = 32;
const double _optionsTop = 196;
const double _optionsWidth = 210;
const double _optionGap = 9;
const double _buttonHeight = 56;
const double _fieldHeight = 34;

/// The 467x548 framed scene from `menuBackground.png` (logo painted in),
/// with its option column at the same fixed inset the web uses. Mirrors
/// MenuShell.tsx's `MenuPanel`.
class MenuPanel extends StatelessWidget {
  final List<Widget> children;

  const MenuPanel({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: _panelWidth,
          height: _panelHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(MenuArt.menuBackground, fit: BoxFit.fill),
              ),
              Positioned(
                left: _optionsLeft,
                top: _optionsTop,
                width: _optionsWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0) const SizedBox(height: _optionGap),
                      children[i],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A plank button whose icon is part of the art (one of the `plank*` images);
/// the label is drawn to the right of the painted icon. Mirrors
/// MenuShell.tsx's `MenuButton` + the `.menu-btn` CSS.
class MenuButton extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback? onPressed;

  const MenuButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: _optionsWidth,
            height: _buttonHeight,
            child: Stack(
              children: [
                Positioned.fill(child: Image.asset(icon, fit: BoxFit.fill)),
                Positioned.fill(
                  // Left padding clears the icon painted into the plank art.
                  child: Padding(
                    padding: const EdgeInsets.only(left: 66, right: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        softWrap: false,
                        style: const TextStyle(
                          color: Color(0xFF17100A),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                          height: 1.1,
                          shadows: [
                            Shadow(
                              color: Color(0x99FFF0D0),
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The name input laid over `fieldBlank.png`, matching the `.menu-field` CSS.
class MenuField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  const MenuField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _optionsWidth,
      height: _fieldHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(MenuArt.fieldBlank, fit: BoxFit.fill),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(left: 34, right: 8),
              child: Center(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  maxLength: 24,
                  textAlignVertical: TextAlignVertical.center,
                  onSubmitted: onSubmitted,
                  style: const TextStyle(
                    color: Color(0xFF2A1A0C),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    counterText: '',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Your name',
                    hintStyle: TextStyle(
                      color: Color(0x802A1A0C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small note line under the options (e.g. queue status), matching
/// `.menu-note` — light text with a dark shadow so it reads over the art.
class MenuNote extends StatelessWidget {
  final String text;

  const MenuNote({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _optionsWidth,
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFF5EAD0),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          shadows: [
            Shadow(
              color: Color(0xE6000000),
              offset: Offset(0, 2),
              blurRadius: 3,
            ),
          ],
        ),
      ),
    );
  }
}

/// Icons available in `MenuArt` (mirrors the web's MENU_ART.plank* usage).
class MenuIcons {
  static const helm = MenuArt.plankHelm;
  static const swords = MenuArt.plankSwords;
  static const banner = MenuArt.plankBanner;
  static const door = MenuArt.plankDoor;
  static const blank = MenuArt.plankBlank;
}
