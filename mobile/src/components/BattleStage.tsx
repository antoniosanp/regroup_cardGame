// Full-screen battle-phase overlay. Plays BATTLE_RESULT.attacks[] as a
// sequential animation — the attacker's badge lunges toward the defender, a
// projectile flies across, the defender shakes and a damage number floats up —
// then applies outcomes[] (heals, eliminations, authoritative hpAfter). Purely
// presentational: every number shown comes from the server's BATTLE_RESULT.

import { useEffect, useRef, useState } from 'react';
import { Animated, Easing, ScrollView, StyleSheet, Text, View } from 'react-native';
import type { PlayerState } from '../online/messages';
import type { BattleVM } from '../online/onlineStore';
import { colors, spacing } from '../theme';
import { Button } from './ui';

interface BattleStageProps {
  battle: BattleVM;
  players: PlayerState[];
  selfId: string;
  nameOf: (playerId: string) => string;
}

interface FighterAnim {
  offset: Animated.ValueXY;
  scale: Animated.Value;
  shake: Animated.Value;
  flash: Animated.Value;
  dead: Animated.Value;
}

interface Floater {
  id: number;
  x: number;
  y: number;
  text: string;
  color: string;
  anim: Animated.Value;
}

const BADGE_W = 104;
const BADGE_H = 84;
// Seat-indexed badge centers as fractions of the arena's width/height.
const SPOTS: Array<{ fx: number; fy: number }> = [
  { fx: 0.27, fy: 0.24 },
  { fx: 0.73, fy: 0.24 },
  { fx: 0.27, fy: 0.76 },
  { fx: 0.73, fy: 0.76 },
];

function timing(v: Animated.Value | Animated.ValueXY, toValue: number | { x: number; y: number }, ms: number) {
  return Animated.timing(v as Animated.Value, {
    toValue: toValue as number,
    duration: ms,
    easing: Easing.inOut(Easing.quad),
    useNativeDriver: true,
  });
}

function play(anim: Animated.CompositeAnimation): Promise<void> {
  return new Promise((resolve) => anim.start(() => resolve()));
}

export function BattleStage({ battle, players, selfId, nameOf }: BattleStageProps) {
  const ordered = [...players].sort((a, b) => a.seat - b.seat);
  const [arena, setArena] = useState<{ w: number; h: number } | null>(null);
  // hp shown on each badge while the sequence plays: starts at hpBefore and is
  // decremented as hits land; outcomes[].hpAfter overwrites it at the end.
  const [shownHp, setShownHp] = useState<Record<string, number>>({});
  const [deadIds, setDeadIds] = useState<Set<string>>(new Set());
  const [floaters, setFloaters] = useState<Floater[]>([]);
  const [finished, setFinished] = useState(false);
  const skippedRef = useRef(false);
  const floaterId = useRef(0);

  const fighters = useRef(new Map<string, FighterAnim>());
  const fighterAnim = (playerId: string): FighterAnim => {
    let f = fighters.current.get(playerId);
    if (!f) {
      f = {
        offset: new Animated.ValueXY({ x: 0, y: 0 }),
        scale: new Animated.Value(1),
        shake: new Animated.Value(0),
        flash: new Animated.Value(0),
        dead: new Animated.Value(0),
      };
      fighters.current.set(playerId, f);
    }
    return f;
  };

  const projectile = useRef({
    pos: new Animated.ValueXY({ x: 0, y: 0 }),
    opacity: new Animated.Value(0),
    scale: new Animated.Value(1),
  }).current;
  const [projectileLook, setProjectileLook] = useState<{ text: string; color: string } | null>(null);

  const centerOf = (playerId: string): { x: number; y: number } => {
    if (!arena) return { x: 0, y: 0 };
    const seat = ordered.findIndex((p) => p.playerId === playerId);
    const spot = SPOTS[Math.max(0, seat)] ?? SPOTS[0];
    return { x: spot.fx * arena.w, y: spot.fy * arena.h };
  };

  const addFloater = (playerId: string, text: string, color: string) => {
    const c = centerOf(playerId);
    const id = ++floaterId.current;
    const anim = new Animated.Value(0);
    setFloaters((fs) => [...fs, { id, x: c.x, y: c.y - BADGE_H / 2, text, color, anim }]);
    Animated.timing(anim, {
      toValue: 1,
      duration: 900,
      easing: Easing.out(Easing.quad),
      useNativeDriver: true,
    }).start(() => setFloaters((fs) => fs.filter((f) => f.id !== id)));
  };

  const finishInstantly = () => {
    for (const o of battle.outcomes) {
      fighterAnim(o.playerId).offset.setValue({ x: 0, y: 0 });
      fighterAnim(o.playerId).scale.setValue(1);
      if (o.eliminated) fighterAnim(o.playerId).dead.setValue(1);
    }
    projectile.opacity.setValue(0);
    setShownHp(Object.fromEntries(battle.outcomes.map((o) => [o.playerId, o.hpAfter])));
    setDeadIds(new Set(battle.outcomes.filter((o) => o.eliminated).map((o) => o.playerId)));
    setFinished(true);
  };

  useEffect(() => {
    if (!arena) return;
    skippedRef.current = false;
    setFinished(false);
    setDeadIds(new Set());
    setShownHp(Object.fromEntries(battle.outcomes.map((o) => [o.playerId, o.hpBefore])));

    let cancelled = false;
    const active = () => !cancelled && !skippedRef.current;

    (async () => {
      // Every attacks[] row gets its own mini animation, in the server's
      // resolution order (round movement order) — 12 of them when all four
      // players are alive. Zero-damage pairs play too, as blocked hits.
      for (const attack of battle.attacks) {
        if (!active()) break;
        const atk = fighterAnim(attack.attackerId);
        const from = centerOf(attack.attackerId);
        const to = centerOf(attack.defenderId);

        // Lunge: the attacker leans 25% of the way toward the defender.
        const lunge = { x: (to.x - from.x) * 0.25, y: (to.y - from.y) * 0.25 };
        await play(
          Animated.parallel([
            timing(atk.offset, lunge, 150),
            timing(atk.scale, 1.14, 150),
          ]),
        );
        if (!active()) break;

        // Projectile: physical hits fly an orange blade, magic a blue bolt,
        // mixed damage shows both in white, and a fully blocked (zero-damage)
        // attack flies a grey shield.
        const isBlocked = attack.totalDamage <= 0;
        const isPhys = attack.physicalDamage > 0 && attack.magicDamage === 0;
        const isMagic = attack.magicDamage > 0 && attack.physicalDamage === 0;
        setProjectileLook({
          text: isBlocked ? '🛡' : isPhys ? '⚔️' : isMagic ? '✦' : '⚔✦',
          color: isBlocked ? colors.textDim : isPhys ? colors.physical : isMagic ? colors.magic : colors.text,
        });
        projectile.pos.setValue({ x: from.x + lunge.x, y: from.y + lunge.y });
        projectile.opacity.setValue(1);
        projectile.scale.setValue(0.7);
        await play(
          Animated.parallel([
            Animated.timing(projectile.pos, {
              toValue: to,
              duration: 250,
              easing: Easing.in(Easing.quad),
              useNativeDriver: true,
            }),
            timing(projectile.scale, 1.25, 250),
          ]),
        );
        projectile.opacity.setValue(0);
        if (!active()) break;

        // Impact: defender shakes + flashes (softly when blocked), the damage
        // number (or a blocked "0") floats up, shown hp drops.
        const def = fighterAnim(attack.defenderId);
        addFloater(
          attack.defenderId,
          isBlocked ? '0' : `-${attack.totalDamage}`,
          isBlocked ? colors.textDim : colors.danger,
        );
        if (!isBlocked) {
          setShownHp((hp) => ({
            ...hp,
            [attack.defenderId]: (hp[attack.defenderId] ?? 0) - attack.totalDamage,
          }));
        }
        const wobble = isBlocked ? 3 : 8;
        const shakeSeq = Animated.sequence([
          timing(def.shake, wobble, 40),
          timing(def.shake, -wobble, 50),
          timing(def.shake, wobble * 0.75, 50),
          timing(def.shake, -wobble * 0.5, 40),
          timing(def.shake, 0, 40),
        ]);
        const flashSeq = isBlocked
          ? Animated.delay(0)
          : Animated.sequence([timing(def.flash, 1, 70), timing(def.flash, 0, 210)]);
        const retreat = Animated.parallel([
          timing(atk.offset, { x: 0, y: 0 }, 180),
          timing(atk.scale, 1, 180),
        ]);
        await play(Animated.parallel([shakeSeq, flashSeq, retreat]));
        if (!active()) break;
        await new Promise((r) => setTimeout(r, 80));
      }

      if (cancelled) return;

      // Outcomes: heals float up green, eliminations dim + skull, and the
      // badge hp snaps to the server's authoritative hpAfter.
      if (!skippedRef.current) {
        const deathAnims: Animated.CompositeAnimation[] = [];
        for (const o of battle.outcomes) {
          if (o.healedHp > 0 && !o.eliminated) addFloater(o.playerId, `+${o.healedHp}`, colors.ok);
          if (o.eliminated) deathAnims.push(timing(fighterAnim(o.playerId).dead, 1, 500));
        }
        setShownHp(Object.fromEntries(battle.outcomes.map((o) => [o.playerId, o.hpAfter])));
        setDeadIds(new Set(battle.outcomes.filter((o) => o.eliminated).map((o) => o.playerId)));
        if (deathAnims.length > 0) await play(Animated.parallel(deathAnims));
        setFinished(true);
      } else {
        finishInstantly();
      }
    })();

    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [battle, arena]);

  return (
    <View style={styles.overlay}>
      <Text style={styles.title}>Battle — round {battle.round}</Text>

      <View style={styles.arena} onLayout={(e) => {
        const { width, height } = e.nativeEvent.layout;
        setArena((a) => (a && a.w === width && a.h === height ? a : { w: width, h: height }));
      }}>
        {arena &&
          ordered.map((p) => {
            const f = fighterAnim(p.playerId);
            const c = centerOf(p.playerId);
            const isDead = deadIds.has(p.playerId);
            return (
              <Animated.View
                key={p.playerId}
                style={[
                  styles.badge,
                  {
                    left: c.x - BADGE_W / 2,
                    top: c.y - BADGE_H / 2,
                    transform: [
                      { translateX: Animated.add(f.offset.x, f.shake) },
                      { translateY: f.offset.y },
                      { scale: f.scale },
                    ],
                    opacity: f.dead.interpolate({ inputRange: [0, 1], outputRange: [1, 0.45] }),
                  },
                  p.playerId === selfId && styles.badgeSelf,
                ]}
              >
                <View style={styles.avatar}>
                  <Text style={styles.avatarText}>{isDead ? '💀' : p.name.charAt(0).toUpperCase()}</Text>
                </View>
                <Text style={styles.badgeName} numberOfLines={1}>
                  {p.name}
                  {p.playerId === selfId ? ' (you)' : ''}
                </Text>
                <Text style={[styles.badgeHp, (shownHp[p.playerId] ?? 0) <= 0 && styles.badgeHpDead]}>
                  {shownHp[p.playerId] ?? p.stats.hp} hp
                </Text>
                <Animated.View pointerEvents="none" style={[styles.flash, { opacity: f.flash }]} />
              </Animated.View>
            );
          })}

        {projectileLook && (
          <Animated.View
            pointerEvents="none"
            style={[
              styles.projectile,
              {
                left: -16,
                top: -16,
                opacity: projectile.opacity,
                transform: [
                  { translateX: projectile.pos.x },
                  { translateY: projectile.pos.y },
                  { scale: projectile.scale },
                ],
              },
            ]}
          >
            <Text style={[styles.projectileText, { color: projectileLook.color }]}>{projectileLook.text}</Text>
          </Animated.View>
        )}

        {floaters.map((f) => (
          <Animated.Text
            key={f.id}
            pointerEvents="none"
            style={[
              styles.floater,
              {
                left: f.x - 40,
                top: f.y - 20,
                color: f.color,
                opacity: f.anim.interpolate({ inputRange: [0, 0.7, 1], outputRange: [1, 1, 0] }),
                transform: [
                  { translateY: f.anim.interpolate({ inputRange: [0, 1], outputRange: [0, -46] }) },
                ],
              },
            ]}
          >
            {f.text}
          </Animated.Text>
        ))}
      </View>

      {!finished && battle.attacks.length > 0 && (
        <Button
          label="Skip animation"
          kind="ghost"
          onPress={() => {
            skippedRef.current = true;
            finishInstantly();
          }}
        />
      )}

      {finished && (
        <ScrollView style={styles.log} contentContainerStyle={{ gap: spacing.xs }}>
          {battle.attacks.length === 0 && <Text style={styles.logLine}>No damage this round.</Text>}
          {battle.attacks.map((a, i) => (
            <Text key={i} style={styles.logLine}>
              {nameOf(a.attackerId)} → {nameOf(a.defenderId)}: {a.totalDamage} dmg
              {'  '}
              <Text style={{ color: colors.physical }}>{a.physicalDamage} phys</Text>
              {' · '}
              <Text style={{ color: colors.magic }}>{a.magicDamage} magic</Text>
            </Text>
          ))}
          {battle.outcomes.map((o) => (
            <Text key={o.playerId} style={[styles.logLine, o.eliminated && { color: colors.danger }]}>
              {nameOf(o.playerId)}: {o.hpBefore} hp − {o.damageTaken} + {o.healedHp} healed → {o.hpAfter} hp
              {o.eliminated ? ' — eliminated' : ''}
            </Text>
          ))}
          <Text style={styles.hint}>Next round starts automatically…</Text>
        </ScrollView>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  overlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(8, 11, 18, 0.96)',
    padding: spacing.lg,
    gap: spacing.md,
  },
  title: {
    color: colors.text,
    fontSize: 20,
    fontWeight: '800',
    textAlign: 'center',
  },
  arena: {
    flex: 1,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: colors.border,
    backgroundColor: colors.panel,
    overflow: 'hidden',
  },
  badge: {
    position: 'absolute',
    width: BADGE_W,
    height: BADGE_H,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: colors.border,
    backgroundColor: colors.panelSoft,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 2,
  },
  badgeSelf: {
    borderColor: colors.primary,
  },
  avatar: {
    width: 30,
    height: 30,
    borderRadius: 15,
    backgroundColor: colors.primaryDark,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: {
    color: '#fff',
    fontWeight: '800',
  },
  badgeName: {
    color: colors.text,
    fontSize: 12,
    fontWeight: '600',
    maxWidth: BADGE_W - 10,
  },
  badgeHp: {
    color: colors.ok,
    fontSize: 12,
    fontWeight: '800',
  },
  badgeHpDead: {
    color: colors.danger,
  },
  flash: {
    ...StyleSheet.absoluteFillObject,
    borderRadius: 12,
    backgroundColor: colors.danger,
  },
  projectile: {
    position: 'absolute',
    width: 32,
    height: 32,
    alignItems: 'center',
    justifyContent: 'center',
  },
  projectileText: {
    fontSize: 22,
    fontWeight: '800',
  },
  floater: {
    position: 'absolute',
    width: 80,
    textAlign: 'center',
    fontSize: 20,
    fontWeight: '900',
  },
  log: {
    maxHeight: 180,
    backgroundColor: colors.panel,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: colors.border,
    padding: spacing.md,
  },
  logLine: {
    color: colors.text,
    fontSize: 13,
  },
  hint: {
    color: colors.textDim,
    fontSize: 12,
    marginTop: spacing.sm,
  },
});
