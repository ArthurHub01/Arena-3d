# Combat pacing fix: telegraph + miss punishment

## Problem

Combat currently rewards raw click speed over reading the opponent. The
character auto-faces the locked opponent (`look_at`), hits resolve
instantly (only Raio's hitscan has a pre-hit delay), and missing/being
blocked costs nothing beyond the ability's normal cooldown — so there's
no reason not to spam attacks nonstop. Confirmed against reference
footage (True Masters gameplay clips): heavy attacks there have a visible
windup before they land, landed hits launch/knock down the target for a
real recovery beat, and specials are big, committed events.

## Fix

1. **Generalize the pre-hit delay.** Every attack that threatens the
   opponent (MELEE, PROJECTILE, HITSCAN, CONE, LINE, TELEPORT_STRIKE,
   MULTI_HITSCAN) now waits `ability.cast_time` seconds — animation and
   VFX play immediately, but the actual hit resolves after the delay,
   giving the opponent a real window to dodge or block. This replaces
   and centralizes the old `hitscan_delay` (was hitscan-only, unused
   value in practice since nothing overrode the 0.25 default) —
   `_execute_hitscan` no longer awaits internally, `_fire_attack` does
   it once for every delivery type instead.
2. **Punish whiffed attacks.** Each `_execute_*` that can miss now
   reports back whether it actually connected. A miss (nothing in
   range/angle, hitscan/multi-hitscan found no target) sets the next
   `attack_ready` timer to `cooldown * MISS_RECOVERY_MULTIPLIER` (2.5x)
   instead of the normal cooldown — attacking into empty space is now a
   real commitment, not a free action.
   - **Scope cut**: PROJECTILE, SELF_BUFF, and WALL are treated as
     "connected" regardless of outcome — a projectile's hit/miss isn't
     known synchronously without extra plumbing (it resolves later via
     its own `body_entered`), and self-buffs/the wall don't threaten
     the opponent directly. Punishing whiffed melee/cone/line/hitscan
     already addresses the "clicking into empty air costs nothing"
     complaint; extending it to projectiles is a follow-up if it's
     still a problem after this change.
   - Being blocked/dodged (vs. simply missing) is **not** separately
     detected/punished in this pass — the attacker's client doesn't
     synchronously know the defender's block/invincibility state. A
     miss (nobody in range at all) is what's punished here.

## Values

`cast_time` (seconds, new `AbilityData` field, replaces reliance on
`hitscan_delay`):
- Ataque Básico (5 `.tres` files) and combo slots 9/10 (simple pair):
  0.15 — matches "fastest, simplest hit" from the original combo design
- Combo slots 1-8 (placeholder directional pairs): 0.2 (odd/first hit),
  0.3 (even/second hit) — mirrors the existing power-level split
- Habilidade 1 (W): 0.3 for the ones that threaten the opponent (Fogo
  cone, Raios teleport strike); 0.0 for pure self/utility ones (Água
  shield, Terra wall, Ar dash) — nothing to dodge, no reason to
  telegraph
- Habilidade 2 (A): 0.35 for attacking ones (Fogo dash-melee, Água
  freeze projectile, Terra line, Raios hitscan); 0.0 for Ar's repulse
  aura (self buff)
- Suprema (special): 0.5 for attacking ones (Fogo/Água/Ar); 0.0 for
  Terra's armor buff; 0.35 for Raios' multi-hit (on top of its existing
  0.3s between-hit interval)

`MISS_RECOVERY_MULTIPLIER := 2.5` (new `Player` constant).

## Files touched

- `scripts/ability_data.gd`: add `cast_time` field, keep `hitscan_delay`
  field for now (unused at runtime, harmless — not worth a data
  migration for a value nothing ever overrode).
- `assets/abilities/*.tres` (5 files): add `cast_time = 0.15`.
- `scripts/ability_library.gd`: set `cast_time` on every generated
  `AbilityData` per the table above (`get_attack`, `get_habilidade_1`,
  `get_habilidade_2`, `get_special`).
- `scenes/player/player.gd`: centralize the delay in `_fire_attack`;
  change `_execute_melee/_execute_cone/_execute_line/_execute_hitscan/
  _execute_teleport_strike` to return `bool` (hit or not);
  `_execute_multi_hitscan` returns `bool` (at least one hit landed);
  apply `MISS_RECOVERY_MULTIPLIER` when nothing connected.

## Why not also touch AI or base cooldowns

The CPU already goes through `_fire_attack`, so it automatically gets
the same telegraph and miss-punishment — no AI-specific change needed,
and its attacks become dodgeable the same way Raio's hitscan already
was for players. Base per-ability cooldowns (0.5-1.8s) are left as-is;
the added cast_time plus the miss penalty should be enough pacing
correction without also making combat feel sluggish. Revisit only if
spamming is still viable after this ships.
