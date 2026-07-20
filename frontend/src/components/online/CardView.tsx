import { cornerMeta, type Card, type CornerAttribute, type Rotation } from '../../online/cards';

// A card's corner fields are always the current arrangement (the store keeps
// them in sync with the server), so rotation here only spins the artwork
// painted on each corner — it never moves attributes between corners.
const ROTATION_DEG: Record<Rotation, number> = {
  DEG_0: 0,
  DEG_90: 90,
  DEG_180: 180,
  DEG_270: 270,
};

function CornerCell({ attr, rotationDeg }: { attr: CornerAttribute; rotationDeg: number }) {
  const meta = cornerMeta(attr);
  return (
    <div
      className="corner"
      style={{ backgroundImage: `url(${meta.icon})`, transform: `rotate(${rotationDeg}deg)` }}
      title={meta.label}
    />
  );
}

/** A card rendered as four corner attribute icons. */
export function CardView({ card }: { card: Card }) {
  const c = card;
  const rotationDeg = ROTATION_DEG[card.rotation] ?? 0;
  return (
    <div className="card">
      <CornerCell attr={c.topLeft} rotationDeg={rotationDeg} />
      <CornerCell attr={c.topRight} rotationDeg={rotationDeg} />
      <CornerCell attr={c.bottomLeft} rotationDeg={rotationDeg} />
      <CornerCell attr={c.bottomRight} rotationDeg={rotationDeg} />
    </div>
  );
}

export function EmptyCard({ label }: { label: string }) {
  return <div className="card card-empty">{label}</div>;
}
