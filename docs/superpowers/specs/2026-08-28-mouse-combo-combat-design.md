# Mouse Combo Combat System — Design

## Goal

Replace the current single-keyboard-attack combat (Q = one basic attack per
element) with a mouse-driven system: left click attacks (10 per element,
arranged as 4 directional 2-hit combos + 1 non-directional 2-hit combo),
right click dodges/blocks (4 directional dashes with i-frames + 1
non-directional block), and middle click fires a special once its meter is
full. This reverses an earlier decision to keep combat entirely on the
keyboard — confirmed intentional with the user on 2026-08-28.

Move data (damage, effects, animations) for the 10 attacks + 5
dodges + special per element is **not** part of this pass — the user will
supply that later, the same way the original 5 basic attacks were designed
in a separate doc. This system ships with placeholder data generated from
each element's existing basic-attack resource, so the mechanics are fully
playable and testable now, and swapping in real per-move data later is a
data change, not a code change.

CPU AI is explicitly out of scope: it keeps its current behavior (fires
`basic_ability` on a distance check with `AI_MISS_CHANCE`), unaffected by
combos/dodge/block/special.

## Global Constraints

- Damage resolution stays server-authoritative through the existing
  `take_damage()` → `_request_damage` (client→server) → `_apply_damage.rpc()`
  (server→all, `call_local`) pipeline. Do not change that flow's shape —
  only what happens inside `_apply_damage` before applying the number.
- No new `.tres` resource files. All 10 attacks + 5 dodges + special per
  element are generated in code from the element's existing
  `assets/abilities/<element>_basic.tres`.
- Existing single-player/offline path (`multiplayer.has_multiplayer_peer()
  == false`, used by vs-computer mode) must keep working exactly as it
  does today — the new input/combo logic runs identically online and
  offline; only the block/i-frame network sync is peer-only.
- Godot 4.3 GDScript typing conventions already in the codebase apply:
  use explicit `var x: float = ...` (not `:=`) wherever the RHS is a call
  Godot can't infer a static type from (this has bitten this project
  before — see `clamp()` calls).

## Data Model

### `scripts/ability_data.gd` (existing file, extend)

Add one field, keep everything else as-is:

```gdscript
## 1-10 for a combo attack slot, 0 for the basic/special (non-combo) abilities.
@export var combo_slot: int = 0
```

### `scripts/dodge_data.gd` (new file)

```gdscript
class_name DodgeData
extends Resource

@export var dodge_name: String = "Dodge"
@export var element: ElementType.Type = ElementType.Type.NONE
@export var dodge_index: int = 1

## Directional dodges (index 1-4) only:
@export var dash_speed: float = 18.0
@export var dash_duration: float = 0.18
@export var iframe_duration: float = 0.2

## Block (index 5) only:
@export var is_block: bool = false
@export var block_damage_reduction: float = 0.7
```

### `scripts/ability_library.gd` (existing file, extend)

Add three functions alongside the existing `get_basic_ability`. All three
derive placeholder data from `get_basic_ability(element)` — no new files.

```gdscript
const ATTACK_SLOT_POWER_MULTIPLIER := {1: 1.0, 2: 1.4}  # odd/even within a pair

static func get_attack(element: ElementType.Type, slot: int) -> AbilityData:
	var base := get_basic_ability(element)
	var power_level := 2 if slot % 2 == 0 else 1
	var data := AbilityData.new()
	data.ability_name = "%s — Golpe %d" % [ElementType.display_name(element), slot]
	data.element = element
	data.damage = int(round(base.damage * ATTACK_SLOT_POWER_MULTIPLIER[power_level]))
	data.cooldown = base.cooldown
	data.delivery = base.delivery
	data.anim_name = base.anim_name
	data.melee_range = base.melee_range
	data.projectile_speed = base.projectile_speed
	data.projectile_lifetime = base.projectile_lifetime
	data.hitscan_range = base.hitscan_range
	data.hitscan_delay = base.hitscan_delay
	data.knockback_force = base.knockback_force
	data.stagger_duration = base.stagger_duration
	data.combo_slot = slot
	return data

static func get_dodge(element: ElementType.Type, index: int) -> DodgeData:
	var data := DodgeData.new()
	data.element = element
	data.dodge_index = index
	if index == 5:
		data.dodge_name = "%s — Bloqueio" % ElementType.display_name(element)
		data.is_block = true
		data.block_damage_reduction = 0.7
	else:
		data.dodge_name = "%s — Esquiva %d" % [ElementType.display_name(element), index]
		data.dash_speed = 18.0
		data.dash_duration = 0.18
		data.iframe_duration = 0.2
	return data

static func get_special(element: ElementType.Type) -> AbilityData:
	var base := get_basic_ability(element)
	var data := AbilityData.new()
	data.ability_name = "%s — Especial" % ElementType.display_name(element)
	data.element = element
	data.damage = base.damage * 2
	data.cooldown = base.cooldown
	data.delivery = base.delivery
	data.anim_name = base.anim_name
	data.melee_range = base.melee_range
	data.projectile_speed = base.projectile_speed
	data.projectile_lifetime = base.projectile_lifetime
	data.hitscan_range = base.hitscan_range
	data.hitscan_delay = base.hitscan_delay
	data.knockback_force = base.knockback_force * 1.5
	data.stagger_duration = base.stagger_duration
	data.combo_slot = 0
	return data
```

Both `get_attack` and `get_special` return a freshly constructed
`AbilityData`, not a cached/loaded resource — that's fine since these are
plain in-memory `Resource` objects (no disk I/O), and the caller
(`Player`) is expected to cache what it needs per-attack at fire time
rather than re-fetch every frame.

## Input Map (`project.godot`)

Remove the now-unused keyboard ability actions (`ability_basic`,
`ability_1`, `ability_2`, `ability_supreme` — nothing else references
them). Add:

```
attack_button   -> Mouse Button Left  (BUTTON_LEFT / MOUSE_BUTTON_LEFT)
dodge_button    -> Mouse Button Right (BUTTON_RIGHT / MOUSE_BUTTON_RIGHT)
special_button  -> Mouse Button Middle (BUTTON_MIDDLE / MOUSE_BUTTON_MIDDLE)
```

Each as an `InputEventMouseButton` entry in `[input]`, same shape as the
existing key entries but with `button_index` instead of
`physical_keycode`.

## Combo Resolution (`scenes/player/player.gd`)

### New state

```gdscript
const ATTACK_COMBO_WINDOW := 0.8
const ATTACK_SLOT_MAP := {
	"W": {"first": 1, "second": 2},
	"A": {"first": 3, "second": 4},
	"S": {"first": 5, "second": 6},
	"D": {"first": 7, "second": 8},
	"": {"first": 9, "second": 10},
}
const DODGE_INDEX_MAP := {"W": 1, "A": 2, "S": 3, "D": 4}
const DODGE_DASH_MOVE_MULTIPLIER := 2.0  # how much dash_speed dominates normal movement while dashing
const BLOCK_DAMAGE_REDUCTION_FALLBACK := 0.7

var _last_attack_family: String = ""
var _attack_awaiting_second: bool = false
var _combo_window_timer: float = 0.0

var is_blocking: bool = false
var is_invincible: bool = false
var _invincible_timer: float = 0.0
var _dodge_dir: Vector3 = Vector3.ZERO
var _dodge_timer: float = 0.0
var _dodge_speed: float = 0.0

var special_meter: float = 0.0
const SPECIAL_METER_MAX := 100.0
const SPECIAL_METER_PER_HIT := 12.5

var block_ability: DodgeData = AbilityLibrary.get_dodge(ElementType.Type.FIRE, 5)
```

`block_ability` is re-derived in `set_element()` alongside `basic_ability`
(add one line: `block_ability = AbilityLibrary.get_dodge(element, 5)`) so
`block_damage_reduction` reflects the player's own element.

### Direction resolution

```gdscript
func _get_held_direction_family() -> String:
	if Input.is_action_pressed("move_forward"):
		return "W"
	if Input.is_action_pressed("move_left"):
		return "A"
	if Input.is_action_pressed("move_back"):
		return "S"
	if Input.is_action_pressed("move_right"):
		return "D"
	return ""
```

Priority order W > A > S > D when multiple are held — arbitrary but
deterministic, matches the order the user listed them in.

### `_unhandled_input` (replaces the current Q-only body)

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if not is_local_player or not match_active or stagger_timer > 0.0:
		return
	if event.is_action_pressed("attack_button"):
		_try_attack()
	elif event.is_action_pressed("dodge_button"):
		_try_dodge()
	elif event.is_action_released("dodge_button"):
		is_blocking = false
	elif event.is_action_pressed("special_button"):
		_try_special()
```

### Attack resolution

```gdscript
func _try_attack() -> void:
	if not attack_ready:
		return
	var family := _get_held_direction_family()
	var slot: int
	if family == _last_attack_family and _attack_awaiting_second and _combo_window_timer > 0.0:
		slot = ATTACK_SLOT_MAP[family]["second"]
		_last_attack_family = ""
		_attack_awaiting_second = false
		_combo_window_timer = 0.0
	else:
		slot = ATTACK_SLOT_MAP[family]["first"]
		_last_attack_family = family
		_attack_awaiting_second = true
		_combo_window_timer = ATTACK_COMBO_WINDOW
	_fire_attack(AbilityLibrary.get_attack(equipped_element, slot))
```

### `_fire_attack` (rename/generalize the current `_do_basic_attack`)

Same body as today's `_do_basic_attack`, but taking the ability as a
parameter instead of reading `basic_ability`:

```gdscript
func _fire_attack(ability: AbilityData) -> void:
	attack_ready = false
	var anim := ability.anim_name if not ability.anim_name.is_empty() else ANIM_PUNCH
	anim_player.play(anim)
	VFX.spawn_cast_burst(get_parent(), muzzle_point.global_position, -global_transform.basis.z, ElementType.get_color(ability.element))
	if multiplayer.has_multiplayer_peer():
		_show_attack_anim.rpc(anim)

	if not (is_ai_controlled and randf() < AI_MISS_CHANCE):
		match ability.delivery:
			AbilityData.Delivery.MELEE:
				_execute_melee(ability)
			AbilityData.Delivery.PROJECTILE:
				_execute_projectile(ability)
			AbilityData.Delivery.HITSCAN:
				_execute_hitscan(ability)

	get_tree().create_timer(ability.cooldown).timeout.connect(func(): attack_ready = true)
```

`_execute_melee`, `_execute_projectile`, `_execute_hitscan` each gain an
`ability: AbilityData` parameter (replacing their internal reads of
`basic_ability`) — mechanical rename, same bodies otherwise. Each call
site that currently does `target.take_damage(basic_ability.damage, ...)`
now uses `ability.damage`, etc.

`_ai_maybe_attack()` (unchanged AI path) now calls `_fire_attack(basic_ability)`
instead of `_do_basic_attack()`.

### Special-meter gain on confirmed hit

Add a small helper:

```gdscript
func _gain_special_meter() -> void:
	special_meter = min(SPECIAL_METER_MAX, special_meter + SPECIAL_METER_PER_HIT)
```

Call `shooter._gain_special_meter()` (or `_gain_special_meter()` on
`self` for the attacker in melee/hitscan) at every point in
`player.gd` and `projectile.gd` that currently calls
`target.take_damage(...)` on a successful hit — i.e. inside
`_execute_melee`'s loop, at the end of `_execute_hitscan`'s hit branch,
and in `Projectile._on_body_entered`. The meter belongs to the *attacker*,
not the target — it only grows for the player whose hit connected.

### Special

```gdscript
func _try_special() -> void:
	if special_meter < SPECIAL_METER_MAX or not attack_ready:
		return
	special_meter = 0.0
	_fire_attack(AbilityLibrary.get_special(equipped_element))
```

### Dodge / block

```gdscript
func _try_dodge() -> void:
	var family := _get_held_direction_family()
	if family == "":
		is_blocking = true
		return
	var dodge := AbilityLibrary.get_dodge(equipped_element, DODGE_INDEX_MAP[family])
	_perform_dodge(dodge, family)

func _perform_dodge(dodge: DodgeData, family: String) -> void:
	var local_dir := {"W": Vector3(0, 0, -1), "A": Vector3(-1, 0, 0), "S": Vector3(0, 0, 1), "D": Vector3(1, 0, 0)}[family]
	_dodge_dir = (transform.basis * local_dir).normalized()
	_dodge_speed = dodge.dash_speed
	_dodge_timer = dodge.dash_duration
	is_invincible = true
	_invincible_timer = dodge.iframe_duration
```

### Per-frame timer upkeep (add near the top of `_physics_process`, before
the existing stagger-timer early-return block)

```gdscript
if _combo_window_timer > 0.0:
	_combo_window_timer -= delta
	if _combo_window_timer <= 0.0:
		_attack_awaiting_second = false
if _invincible_timer > 0.0:
	_invincible_timer -= delta
	if _invincible_timer <= 0.0:
		is_invincible = false
```

### Dash displacement

In the normal-movement branch of `_physics_process` (after `direction` is
computed from `input_dir`, before `velocity.x = ...` is assigned), blend
in the dash when active:

```gdscript
if _dodge_timer > 0.0:
	_dodge_timer -= delta
	velocity.x = _dodge_dir.x * _dodge_speed
	velocity.z = _dodge_dir.z * _dodge_speed
else:
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED
```

(replaces the current unconditional `velocity.x = direction.x * SPEED`
/ `velocity.z = direction.z * SPEED` pair)

### Damage reduction / negation (`_apply_damage`)

At the very top of `_apply_damage`, before `stats.apply_damage(amount)`:

```gdscript
if is_invincible:
	return
if is_blocking:
	amount = int(amount * (1.0 - block_ability.block_damage_reduction))
```

## Networking

`_remote_update_transform` gains two parameters so the target's
block/invincibility state is known on the server and the other peer at
roughly the same cadence as position (`unreliable_ordered`, matching the
existing tolerance for this kind of state in this project):

```gdscript
@rpc("unreliable_ordered", "call_remote")
func _remote_update_transform(pos: Vector3, rot_y: float, blocking: bool, invincible: bool) -> void:
	...  # existing body unchanged
	is_blocking = blocking
	is_invincible = invincible
```

Both call sites (`_remote_update_transform.rpc(global_position,
rotation.y)`) become `_remote_update_transform.rpc(global_position,
rotation.y, is_blocking, is_invincible)`.

This is best-effort like the rest of the project's netcode — a defender's
block/dodge state can lag an attacker's hit by a frame or two under
latency. That's an accepted tradeoff, not a bug to chase in this pass.

## HUD (`scenes/arena/Arena.tscn`, `arena.gd`)

Reuse `ChevronBar` as-is (it already exposes `fill_color`, `max_value`,
`value` — no script changes needed). Add one `ChevronBar` node per player
under the existing `HpGroupP1`/`HpGroupP2` (or directly under `HUDRoot`
just below each HP bar), sized smaller (e.g. `Vector2(160, 12)`), with
`fill_color = Color(0.85, 0.63, 0.30, 1)` (the existing gold accent).

`arena.gd` gets two new `@onready` refs (`special_bar_p1`,
`special_bar_p2`) and, in `_wire_player`, connects a new `Player` signal:

```gdscript
signal special_meter_changed(current: float, max: float)
```

emitted from `_gain_special_meter()` and from `_try_special()` (on
reset to 0), wired the same way `damaged` already is:

```gdscript
player.special_meter_changed.connect(func(current, max_value):
	special_bar.max_value = max_value
	special_bar.value = current
)
```

## Testing Plan

- GUT unit test for the combo-slot arithmetic: given a sequence of
  `_get_held_direction_family()` results, assert `_try_attack()` (or a
  small pure-function extraction of the slot-selection logic) yields the
  expected slot sequence (1,2 then resets to 1 if interrupted, 3,4 for A,
  9,10 for no direction, etc.) and that the window timing out resets to
  the "first" slot.
- GUT unit test for `AbilityLibrary.get_attack/get_dodge/get_special`
  placeholder generation: odd slots use the base damage, even slots use
  1.4x, `get_special` uses 2x, `get_dodge(el, 5).is_block == true` and
  1-4 are dashes.
- Manual real-process playtest (the project's established pattern):
  verify left-click combos land, right-click dash dodges move the
  character and grant a brief window where a simultaneous incoming hit
  is negated, holding right-click with no direction reduces incoming
  damage, and the special fires only once the bar fills and resets it
  after firing.
- Verify vs-computer mode still works end-to-end (CPU still uses
  `basic_ability` via `_fire_attack(basic_ability)`, player uses the new
  input scheme against it).

## Out of Scope (this pass)

- Real per-move damage/effects/animations for all 80 attacks, 25 dodges,
  and 5 specials — placeholder-generated until the user supplies a design
  doc for them.
- CPU AI using combos, dodges, blocking, or the special.
- Any visual/UI difference between the 10 attack animations (they all
  reuse the element's existing single `anim_name` for now, same as
  today).
- Rebalancing `AI_MISS_CHANCE`/cooldowns now that the player has more
  options — left for a follow-up once real move data exists.
