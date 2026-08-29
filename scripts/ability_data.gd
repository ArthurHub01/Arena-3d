class_name AbilityData
extends Resource

enum Delivery {
	MELEE,
	PROJECTILE,
	HITSCAN,
	CONE,
	LINE,
	SELF_BUFF,
	WALL,
	TELEPORT_STRIKE,
	MULTI_HITSCAN,
}

@export var ability_name: String = "Ability"
@export var element: ElementType.Type = ElementType.Type.NONE
@export var damage: int = 10
@export var cooldown: float = 1.0
@export var delivery: Delivery = Delivery.MELEE
@export var anim_name: String = ""

## MELEE only: radius of the hit check around MeleeHitPoint.
@export var melee_range: float = 1.0

## PROJECTILE only: travel speed and lifetime before despawning.
@export var projectile_speed: float = 15.0
@export var projectile_lifetime: float = 3.0

## HITSCAN only: max distance the instant hit can reach.
@export var hitscan_range: float = 25.0

## HITSCAN only: delay between aiming and the hit resolving, so the target has time to dodge.
@export var hitscan_delay: float = 0.25

## On-hit effects, shared by any delivery type. 0 = no effect.
@export var knockback_force: float = 0.0
@export var stagger_duration: float = 0.0

## 1-10 for a combo attack slot, 0 for the basic/special (non-combo) abilities.
@export var combo_slot: int = 0

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
@export var self_buff_value: float = 0.0

## CONE/LINE: pull the target toward the caster instead of pushing away.
@export var pull_instead_of_push: bool = false

## WALL only: how long the spawned wall blocks movement.
@export var wall_duration: float = 6.0

## MULTI_HITSCAN only.
@export var multi_hit_count: int = 1
@export var multi_hit_interval: float = 0.3

## Selects a bespoke VFX preset in AbilityVFX (see scripts/ability_vfx.gd).
## Empty = fall back to the generic element-colored VFX (Ataque Básico/Golpes).
@export var vfx_key: String = ""
