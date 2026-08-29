# Habilidade 1 / Habilidade 2 / Suprema per element — Design

## Goal

Implement the 15 remaining moves from the original design doc (Habilidade 1,
Habilidade 2, Habilidade Suprema × 5 elements), replacing the placeholder
data currently used for those slots. Ataque Básico stays as-is.

## Control mapping (confirmed with user)

- Ataque Básico → unchanged (left-click, no-direction combo family, slots 9/10)
- **Habilidade 1** → left-click while holding **W** (combo slots 1 and 2 both
  fire Habilidade 1; slot 2 = the empowered second hit, same
  odd/even damage scaling already used elsewhere)
- **Habilidade 2** → left-click while holding **A** (slots 3 and 4)
- **Habilidade Suprema** → middle-click (`_try_special`, already gated on a
  full meter) — replaces the generic "2x basic damage" placeholder
  `AbilityLibrary.get_special()` currently returns
- S, D, and the no-direction pair keep today's placeholder (scaled basic
  attack) — the source doc doesn't define more than 4 named moves per
  element, so those stay as-is until/unless the user asks for more.

## Visuals are out of scope here

A separate session is handling textures/VFX for these powers. Every new
delivery path below reuses the existing generic `VFX.spawn_cast_burst` /
`VFX.spawn_impact` / `VFX.spawn_beam` calls with `ElementType.get_color()`
— the same placeholder pattern already used for the basic attacks. Don't
hardcode new textures or particle setups; leave the color-driven calls as
the extension point.

## New `AbilityData` fields (extend `scripts/ability_data.gd`)

```gdscript
## CONE/LINE only: hit shape.
@export var aoe_range: float = 5.0
@export var cone_angle_degrees: float = 70.0

## Burn DoT (Fogo H1) — applied to the target on hit.
@export var burn_damage_per_tick: int = 0
@export var burn_ticks: int = 0
@export var burn_tick_interval: float = 1.0

## Fogo H2 — forces the target out of block on hit.
@export var breaks_guard: bool = false

## SELF_BUFF only.
@export var self_buff_type: String = ""  # "shield" | "extra_dash" | "repulse_aura" | "damage_mitigation"
@export var self_buff_duration: float = 0.0
@export var self_buff_value: float = 0.0  # mitigation % (0-1), or repulse force

## CONE/LINE knockback direction toward the caster instead of away (Água/Ar Suprema).
@export var pull_instead_of_push: bool = false

## MULTI_HITSCAN only (Raios Suprema).
@export var multi_hit_count: int = 1
@export var multi_hit_interval: float = 0.3
```

Extend `Delivery` enum: `MELEE, PROJECTILE, HITSCAN, CONE, LINE, SELF_BUFF, WALL, TELEPORT_STRIKE, MULTI_HITSCAN`.

## `AbilityLibrary` (extend `scripts/ability_library.gd`)

Add `get_habilidade_1(element)`, `get_habilidade_2(element)`, and replace
the body of `get_special(element)` — all three return hand-authored
`AbilityData` per element (a `Dictionary[ElementType.Type][String]` table
of factory lambdas, or a `match` — either is fine, prefer whichever reads
more linearly). Exact values:

| Elemento | Habilidade 1 | Habilidade 2 | Suprema |
|---|---|---|---|
| Fogo | **Onda de Calor** — CONE, dmg 10, cone 70°, range 4.0, burn 3×4 (1s tick), knockback 4, cooldown 1.6 | **Investida Flamejante** — dash (speed 20, 0.25s) + MELEE dmg 14, `breaks_guard=true`, knockback 8, cooldown 1.8 | **Impacto de Meteoro** — CONE dmg 30, cone 360°, range 5.0, knockback 10 |
| Água | **Escudo de Névoa** — SELF_BUFF `shield`, duration 3.0, cooldown 4.0, dmg 0 | **Prisão de Gelo** — PROJECTILE dmg 10, stagger 2.2, speed 16, cooldown 1.8 | **Tsunami** — LINE dmg 28, range 8.0, `pull_instead_of_push=true`, knockback 6 |
| Terra | **Parede de Pedra** — WALL, no dmg, spawns 3m ahead, blocks 6.0s, cooldown 5.0 | **Terremoto** — LINE dmg 18, range 6.0, stagger 1.5, knockback 5, cooldown 2.0 | **Armadura de Rocha** — SELF_BUFF `damage_mitigation`, value 0.8, duration 4.0 (also grants `cc_immune`) |
| Ar | **Impulso de Ar** — SELF_BUFF `extra_dash` (boosted dash: speed 26, 0.3s, iframe 0.25s), cooldown 1.5, no dmg | **Tornado Repulsor** — SELF_BUFF `repulse_aura`, value(force) 8.0, duration 3.0, cooldown 4.0, no dmg | **Furacão Aprisionador** — CONE dmg 20, cone 360°, range 6.0, `pull_instead_of_push=true`, stagger 2.0, knockback 3 |
| Raios | **Teletransporte Elétrico** — TELEPORT_STRIKE, reposition behind opponent, dmg 8, stagger 0.3, knockback 3, cooldown 2.5 | **Corrente de Choque** — HITSCAN dmg 8, stagger 0.6, range 25, cooldown 1.4 | **Tempestade de Raios** — MULTI_HITSCAN, 3 hits × dmg 12, interval 0.3 |

All unlisted fields (`anim_name`, etc.) reuse the element's existing basic
ability's values, same as the current placeholder generator does.

## Player state (extend `scenes/player/player.gd`)

New timer-boolean pairs, following the exact pattern `is_invincible` /
`_invincible_timer` already established:

```gdscript
var is_shielded: bool = false
var _shield_timer: float = 0.0

var damage_mitigation: float = 0.0
var _mitigation_timer: float = 0.0

var cc_immune: bool = false
var _cc_immune_timer: float = 0.0

var is_repulsing: bool = false
var _repulse_timer: float = 0.0
var _repulse_force: float = 0.0
var _repulse_cooldown_timer: float = 0.0
const REPULSE_RADIUS := 3.5
const REPULSE_INTERVAL := 0.5
```

Decrement all four timers alongside the existing `_combo_window_timer` /
`_invincible_timer` block at the top of `_physics_process`, clearing the
matching bool at zero. While `is_repulsing` and `_repulse_cooldown_timer
<= 0.0`, check distance to `opponent`; if within `REPULSE_RADIUS`, call
`opponent.take_damage(0, equipped_element, away_dir, _repulse_force, 0.0)`
and reset `_repulse_cooldown_timer = REPULSE_INTERVAL` — reuses the
existing networked knockback pipeline instead of inventing a new one
(0 damage still routes through the real `take_damage` → RPC →
`_apply_damage` chain, so knockback lands correctly for both peers).

### `_apply_damage` ordering (top of the function, before `stats.apply_damage`)

```gdscript
if is_invincible:
	return
if is_shielded:
	return
if is_blocking:
	amount = int(amount * (1.0 - block_ability.block_damage_reduction))
if damage_mitigation > 0.0:
	amount = int(amount * (1.0 - damage_mitigation))
```

And guard the existing knockback/stagger application further down:

```gdscript
if not cc_immune:
	if knockback_force > 0.0 and knockback_dir.length() > 0.01:
		... # unchanged
	if stagger_duration > 0.0:
		stagger_timer = max(stagger_timer, stagger_duration)
```

### `_try_attack` — route W/A families to the named abilities

```gdscript
else:
	slot = ATTACK_SLOT_MAP[family]["first"]
	...
var ability: AbilityData
if family == "W":
	ability = AbilityLibrary.get_habilidade_1(equipped_element)
elif family == "A":
	ability = AbilityLibrary.get_habilidade_2(equipped_element)
else:
	ability = AbilityLibrary.get_attack(equipped_element, slot)
_fire_attack(ability)
```

(The odd/even slot number still selects power level for S/D/no-direction
via `get_attack`; W/A ignore the slot number and always return the same
named ability — Habilidade 1/2 aren't "two different moves", they're one
move triggerable via either hit of that combo pair, matching how the
original doc only defines one Habilidade 1 and one Habilidade 2 per
element, not four.)

### New `_execute_*` dispatch cases in `_fire_attack`'s `match ability.delivery`

- `CONE`: check `opponent` (1v1, so no need to iterate all bodies) —
  within `aoe_range` and within `cone_angle_degrees/2` of `-global_transform.basis.z`;
  if so, `opponent.take_damage(...)`, then if `ability.burn_ticks > 0`,
  kick off the burn coroutine on `opponent`.
- `LINE`: same as CONE but a capsule/box-shaped check along forward
  instead of an angle check (`(opponent.global_position - global_position).dot(forward) 
  in [0, aoe_range]` and perpendicular distance under a fixed half-width,
  e.g. 1.5m).
- `SELF_BUFF`: `match ability.self_buff_type`: `"shield"` sets
  `is_shielded/_shield_timer`; `"damage_mitigation"` sets
  `damage_mitigation/_mitigation_timer` + `cc_immune/_cc_immune_timer`;
  `"repulse_aura"` sets `is_repulsing/_repulse_timer/_repulse_force`;
  `"extra_dash"` directly calls the existing `_perform_dodge()` using the
  currently-held movement direction (fallback to facing-forward if none
  held) with a synthesized `DodgeData` using the ability's own
  speed/duration/iframe (reuses the dash system already built for
  right-click dodges — no new movement code).
- `WALL`: see networking note below — spawns `StoneWall.tscn` via RPC.
- `TELEPORT_STRIKE`: reposition `global_position` to
  `opponent.global_position + (opponent.global_position - global_position).normalized() * -1.2`
  (i.e. 1.2m behind the opponent, on the far side from the caster's
  current position), `look_at(opponent)`, then deal damage/stagger like
  a melee hit.
- `MULTI_HITSCAN`: loop `multi_hit_count` times, `await
  get_tree().create_timer(multi_hit_interval).timeout` between hits,
  each iteration re-running the existing `_execute_hitscan(ability)` logic
  (call it directly `multi_hit_count` times — it already re-aims from the
  caster's current facing each call, which is fine since the opponent is
  locked via the combat camera).

### Burn coroutine

```gdscript
func _apply_burn(ability: AbilityData, target: Player) -> void:
	for i in range(ability.burn_ticks):
		await get_tree().create_timer(ability.burn_tick_interval).timeout
		if not is_instance_valid(target):
			return
		target.take_damage(ability.burn_damage_per_tick, ElementType.Type.FIRE)
```

Called as `_apply_burn(ability, opponent)` (fire-and-forget, not awaited)
from the CONE handler when `ability.burn_ticks > 0`.

## Terrain wall (new files)

`scenes/arena/StoneWall.tscn` + `scenes/arena/stone_wall.gd`: a
`StaticBody3D` with a `BoxShape3D` (e.g. `Vector3(2.5, 2.0, 0.4)`) and a
plain `MeshInstance3D` box (placeholder gray material — the other
session can texture it), `collision_layer = 1` (same layer as the arena
floor, so it blocks `CharacterBody3D` movement automatically via players'
existing `collision_mask = 3`). Auto-frees after `wall_duration` seconds
(`get_tree().create_timer(wall_duration).timeout.connect(queue_free)` in
its own `_ready()`).

**Networking**: unlike projectiles (fire-and-forget, cosmetic-only sync
gap already accepted elsewhere in this codebase), a wall that only
exists in the caster's own scene tree would let the *opponent's* peer
walk straight through it — a real gameplay bug, not just a visual one.
So `Arena` gets a small RPC to keep both peers' physics worlds
consistent:

```gdscript
# arena.gd
const STONE_WALL_SCENE: PackedScene = preload("res://scenes/arena/StoneWall.tscn")

@rpc("any_peer", "call_local", "reliable")
func _spawn_wall(position: Vector3, rotation_y: float, duration: float) -> void:
	var wall: Node3D = STONE_WALL_SCENE.instantiate()
	add_child(wall)
	wall.global_position = position
	wall.rotation.y = rotation_y
	wall.get_node("Timer") # or however duration is wired — see stone_wall.gd
```

`Player._execute_wall(ability)` computes the spawn transform (3m ahead of
the caster, caster's current `rotation.y`) and calls
`get_parent()._spawn_wall.rpc(spawn_pos, rotation.y, wall_duration)` when
online, or calls the same logic directly when offline
(`multiplayer.has_multiplayer_peer() == false`, same pattern used
throughout this codebase for the online/offline split).

**Explicitly out of scope**: the wall does not block projectiles or
hitscan rays in this pass (the current `hitscan` raycast mask and
`Projectile` collision detection only check the Player layer, not world
geometry — extending that is a separate, riskier change to the existing
collision-layer setup). Stated here so it isn't mistaken for an
oversight.

## Testing

- GUT unit tests for `AbilityLibrary.get_habilidade_1/2` and the rewritten
  `get_special`: assert damage/cooldown/delivery/self_buff fields match
  the table above for at least 2 elements each (not all 15 — enough to
  catch a copy-paste mistake in the data table).
- Manual real-process playtest: verify Habilidade 1 (W+click) burns/cones
  correctly, Habilidade 2 (A+click) lands its named effect, Suprema fires
  the new named move instead of the old generic 2x-damage placeholder,
  the stone wall blocks movement for both a host and a client process,
  and shield/mitigation/repulse-aura self-buffs visibly change behavior
  (no damage taken while shielded, reduced damage while mitigated,
  opponent pushed back by the aura).
