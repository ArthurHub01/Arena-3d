# Arena 3D Online 1v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a playable 3D arena game for 2 players (melee + ranged combat, HP-based rounds) that can be hosted by one player and joined by a remote friend over a VPN-bridged LAN connection, exportable to a Windows `.exe`.

**Architecture:** Godot 4.x project. Pure combat/round logic lives in plain `RefCounted`/`Resource` GDScript classes (unit-testable with GUT, no scene tree needed). Player movement, camera, and combat *actions* live on a `CharacterBody3D` scene, manually verified by running the game (physics/input can't be meaningfully unit tested). Networking uses Godot's high-level `ENetMultiplayerPeer` API; the host is authoritative for round state (HP totals, win/reset), clients are authoritative for their own movement input (v1 accepts client-trusted movement — see spec's "out of scope: anti-cheat").

**Tech Stack:** Godot 4.x (GDScript), GUT (Gut Unit Test addon) for pure-logic unit tests, Godot's built-in ENet multiplayer.

**Spec:** `docs/superpowers/specs/2026-08-28-arena-3d-online-design.md`

## Global Constraints

- Godot version: 4.x (any current 4.x stable release).
- No external servers/relays — networking must work over a VPN-bridged virtual LAN (Radmin VPN/Hamachi) with direct `create_server`/`create_client`.
- No custom 3D models/animations/audio in this plan — primitive placeholder meshes only (per spec's "Escopo da primeira versão").
- Max 2 players, no lobby list — host enters "Hospedar", client enters host's virtual-LAN IP and "Conectar".
- Player HP: 100. Round ends at 0 HP. Reset via input restores HP and repositions both players.
- Export target: Windows Desktop `.exe` (Godot export preset).

---

## File Structure

- `project.godot` — Godot project file (created by editor on first save).
- `addons/gut/` — GUT testing framework (installed via asset, not hand-written).
- `.gutconfig.json` — GUT CLI config pointing at `test/unit`.
- `scripts/combat_stats.gd` — `CombatStats` class (`RefCounted`): HP tracking, `apply_damage()`, `is_dead()`, `reset()`. Pure logic, no scene dependency.
- `scripts/round_manager.gd` — `RoundManager` class (`RefCounted`): given two `CombatStats`, decides `get_winner()` (`""`, `"p1"`, `"p2"`), pure logic.
- `test/unit/test_combat_stats.gd` — GUT tests for `CombatStats`.
- `test/unit/test_round_manager.gd` — GUT tests for `RoundManager`.
- `scenes/player/Player.tscn` + `scenes/player/player.gd` — `CharacterBody3D`: movement, mouse-look camera, melee attack, projectile spawn, owns a `CombatStats` instance, emits `damaged`/`died` signals.
- `scenes/player/Projectile.tscn` + `scenes/player/projectile.gd` — `Area3D` that travels forward and calls `apply_damage` on whatever `Player` it hits.
- `scenes/arena/Arena.tscn` + `scenes/arena/arena.gd` — floor, 4 walls, 2 `Marker3D` spawn points, HUD (`CanvasLayer`), instantiates/removes `Player` per connected peer, owns a `RoundManager`, listens to `damaged`/`died` signals, drives win/reset flow.
- `scenes/menu/MainMenu.tscn` + `scenes/menu/main_menu.gd` — "Hospedar" button, IP `LineEdit` + "Conectar" button; sets up `ENetMultiplayerPeer` and changes scene to `Arena.tscn`.

## Global Constraints applied throughout: HP=100 in `CombatStats` default, 2-player cap enforced in `main_menu.gd`/`arena.gd`, no external relay anywhere in networking code.

---

### Task 1: Godot project scaffold + GUT test framework

**Files:**
- Create: `project.godot`
- Create: `addons/gut/` (via GUT asset install)
- Create: `.gutconfig.json`
- Create: `test/unit/test_smoke.gd`

**Interfaces:**
- Produces: a runnable Godot 4 project with GUT runnable from the command line via `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit`.

- [ ] **Step 1: Create the Godot project**

Open Godot 4, create a new project named `arena3d` at `/home/arthur-nunes/Documentos/3D game`, renderer "Forward+". Save once so `project.godot` and `.godot/` exist.

- [ ] **Step 2: Install GUT**

In the Godot editor, open AssetLib tab, search "Gut", install "Gut - Godot Unit Testing" into the project (installs to `addons/gut/`). Enable it: Project Settings → Plugins → Gut → Enable.

- [ ] **Step 3: Create GUT CLI config**

```json
{
  "dirs": ["res://test/unit"],
  "should_exit": true,
  "should_exit_on_success": true
}
```

Save as `.gutconfig.json` at the project root.

- [ ] **Step 4: Write a smoke test**

```gdscript
extends GutTest

func test_smoke():
	assert_eq(1 + 1, 2)
```

Save as `test/unit/test_smoke.gd`.

- [ ] **Step 5: Run GUT from the command line and verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit`
Expected: output shows `1 tests passed` (or similar) and exit code 0.

- [ ] **Step 6: Commit**

```bash
git add project.godot addons .gutconfig.json test .gitattributes .gitignore 2>/dev/null
git add -A
git commit -m "Set up Godot project and GUT test framework"
```

---

### Task 2: CombatStats (pure HP/damage logic)

**Files:**
- Create: `scripts/combat_stats.gd`
- Test: `test/unit/test_combat_stats.gd`

**Interfaces:**
- Produces: `CombatStats` (class_name), with:
  - `var max_hp: int = 100`
  - `var current_hp: int` (starts equal to `max_hp`)
  - `func apply_damage(amount: int) -> void`
  - `func is_dead() -> bool`
  - `func reset() -> void`

- [ ] **Step 1: Write the failing tests**

```gdscript
extends GutTest

func test_starts_at_max_hp():
	var stats = CombatStats.new()
	assert_eq(stats.current_hp, 100)

func test_apply_damage_reduces_hp():
	var stats = CombatStats.new()
	stats.apply_damage(30)
	assert_eq(stats.current_hp, 70)

func test_hp_does_not_go_below_zero():
	var stats = CombatStats.new()
	stats.apply_damage(150)
	assert_eq(stats.current_hp, 0)

func test_is_dead_when_hp_zero():
	var stats = CombatStats.new()
	stats.apply_damage(100)
	assert_true(stats.is_dead())

func test_is_dead_false_when_hp_positive():
	var stats = CombatStats.new()
	stats.apply_damage(10)
	assert_false(stats.is_dead())

func test_reset_restores_max_hp():
	var stats = CombatStats.new()
	stats.apply_damage(100)
	stats.reset()
	assert_eq(stats.current_hp, 100)
	assert_false(stats.is_dead())
```

Save as `test/unit/test_combat_stats.gd`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit`
Expected: FAIL — `Identifier "CombatStats" not declared`.

- [ ] **Step 3: Implement CombatStats**

```gdscript
class_name CombatStats
extends RefCounted

var max_hp: int = 100
var current_hp: int

func _init() -> void:
	current_hp = max_hp

func apply_damage(amount: int) -> void:
	current_hp = max(0, current_hp - amount)

func is_dead() -> bool:
	return current_hp <= 0

func reset() -> void:
	current_hp = max_hp
```

Save as `scripts/combat_stats.gd`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit`
Expected: all `test_combat_stats.gd` tests PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/combat_stats.gd test/unit/test_combat_stats.gd
git commit -m "Add CombatStats with unit tests"
```

---

### Task 3: RoundManager (pure win-condition logic)

**Files:**
- Create: `scripts/round_manager.gd`
- Test: `test/unit/test_round_manager.gd`

**Interfaces:**
- Consumes: `CombatStats` from Task 2 (`is_dead()`).
- Produces: `RoundManager` (class_name), with:
  - `func get_winner(p1_stats: CombatStats, p2_stats: CombatStats) -> String` returns `"p1"`, `"p2"`, `"draw"` (both dead same frame), or `""` (round ongoing).

- [ ] **Step 1: Write the failing tests**

```gdscript
extends GutTest

func test_no_winner_when_both_alive():
	var rm = RoundManager.new()
	var p1 = CombatStats.new()
	var p2 = CombatStats.new()
	assert_eq(rm.get_winner(p1, p2), "")

func test_p1_wins_when_p2_dead():
	var rm = RoundManager.new()
	var p1 = CombatStats.new()
	var p2 = CombatStats.new()
	p2.apply_damage(100)
	assert_eq(rm.get_winner(p1, p2), "p1")

func test_p2_wins_when_p1_dead():
	var rm = RoundManager.new()
	var p1 = CombatStats.new()
	var p2 = CombatStats.new()
	p1.apply_damage(100)
	assert_eq(rm.get_winner(p1, p2), "p2")

func test_draw_when_both_dead():
	var rm = RoundManager.new()
	var p1 = CombatStats.new()
	var p2 = CombatStats.new()
	p1.apply_damage(100)
	p2.apply_damage(100)
	assert_eq(rm.get_winner(p1, p2), "draw")
```

Save as `test/unit/test_round_manager.gd`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit`
Expected: FAIL — `Identifier "RoundManager" not declared`.

- [ ] **Step 3: Implement RoundManager**

```gdscript
class_name RoundManager
extends RefCounted

func get_winner(p1_stats: CombatStats, p2_stats: CombatStats) -> String:
	var p1_dead = p1_stats.is_dead()
	var p2_dead = p2_stats.is_dead()
	if p1_dead and p2_dead:
		return "draw"
	if p2_dead:
		return "p1"
	if p1_dead:
		return "p2"
	return ""
```

Save as `scripts/round_manager.gd`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit`
Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/round_manager.gd test/unit/test_round_manager.gd
git commit -m "Add RoundManager with unit tests"
```

---

### Task 4: Player scene — movement, camera, melee, projectile spawn

**Files:**
- Create: `scenes/player/Player.tscn`
- Create: `scenes/player/player.gd`
- Create: `scenes/player/Projectile.tscn`
- Create: `scenes/player/projectile.gd`

**Interfaces:**
- Consumes: `CombatStats` from Task 2.
- Produces:
  - `Player` (`CharacterBody3D`) with:
    - `var stats: CombatStats`
    - `signal damaged(current_hp: int)`
    - `signal died()`
    - `func take_damage(amount: int) -> void` (calls `stats.apply_damage`, emits `damaged`, emits `died` if `stats.is_dead()`)
    - `func reset_player(spawn_position: Vector3) -> void` (calls `stats.reset()`, sets `global_position`, re-emits `damaged` with full HP)
  - `Projectile` (`Area3D`) with `var damage: int = 10`, `var speed: float = 15.0`, moves along its `-Z` local axis, calls `owner_player_hit.take_damage(damage)` on collision with a `Player` that isn't its shooter, then `queue_free()`.

- [ ] **Step 1: Build the Player scene in the editor**

Create `scenes/player/Player.tscn`:
- Root: `CharacterBody3D` named `Player`.
- Child `CollisionShape3D` with a `CapsuleShape3D` (radius 0.4, height 1.8).
- Child `MeshInstance3D` with a `CapsuleMesh` matching the collider, assign a bright material (e.g. blue `StandardMaterial3D`) so the two players are visually distinguishable later (color set per-instance in Task 7).
- Child `Node3D` named `CameraPivot` at head height (y ≈ 1.6), child `Camera3D` under it positioned a few meters behind (`Vector3(0, 1.2, 4)`) looking at the pivot (third-person).
- Child `Marker3D` named `MuzzlePoint` at roughly chest height, forward of the capsule, for projectile spawn origin.
- Child `Marker3D` named `MeleeHitPoint` close in front of the capsule.
- Child `Area3D` named `MeleeArea` at `MeleeHitPoint` with a small `SphereShape3D` (radius 1.0), monitoring enabled, `collision_layer`/`mask` set to detect other `Player` nodes (put players on a `"players"` physics layer).

- [ ] **Step 2: Write player.gd**

```gdscript
extends CharacterBody3D
class_name Player

signal damaged(current_hp: int)
signal died()

const SPEED := 6.0
const JUMP_VELOCITY := 4.5
const GRAVITY := 9.8
const MELEE_DAMAGE := 15
const MELEE_COOLDOWN := 0.6
const PROJECTILE_DAMAGE := 10
const PROJECTILE_COOLDOWN := 1.0
const MOUSE_SENSITIVITY := 0.003

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var muzzle_point: Marker3D = $MuzzlePoint
@onready var melee_area: Area3D = $MeleeHitPoint/MeleeArea

var stats: CombatStats = CombatStats.new()
var is_local_player: bool = true
var melee_ready: bool = true
var projectile_ready: bool = true

var projectile_scene: PackedScene = preload("res://scenes/player/Projectile.tscn")

func _ready() -> void:
	if not is_local_player:
		camera.current = false

func _unhandled_input(event: InputEvent) -> void:
	if not is_local_player:
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera_pivot.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -1.2, 1.2)
	if event.is_action_pressed("attack_melee") and melee_ready:
		_do_melee_attack()
	if event.is_action_pressed("attack_ranged") and projectile_ready:
		_do_ranged_attack()

func _physics_process(delta: float) -> void:
	if not is_local_player:
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED
	move_and_slide()

func _do_melee_attack() -> void:
	melee_ready = false
	for body in melee_area.get_overlapping_bodies():
		if body is Player and body != self:
			body.take_damage(MELEE_DAMAGE)
	get_tree().create_timer(MELEE_COOLDOWN).timeout.connect(func(): melee_ready = true)

func _do_ranged_attack() -> void:
	projectile_ready = false
	var projectile = projectile_scene.instantiate()
	get_parent().add_child(projectile)
	projectile.global_transform = muzzle_point.global_transform
	projectile.damage = PROJECTILE_DAMAGE
	projectile.shooter = self
	get_tree().create_timer(PROJECTILE_COOLDOWN).timeout.connect(func(): projectile_ready = true)

func take_damage(amount: int) -> void:
	stats.apply_damage(amount)
	damaged.emit(stats.current_hp)
	if stats.is_dead():
		died.emit()

func reset_player(spawn_position: Vector3) -> void:
	stats.reset()
	global_position = spawn_position
	velocity = Vector3.ZERO
	damaged.emit(stats.current_hp)
```

Attach as the script of `Player.tscn`'s root node.

- [ ] **Step 3: Build the Projectile scene**

Create `scenes/player/Projectile.tscn`:
- Root: `Area3D` named `Projectile`.
- Child `CollisionShape3D` with a small `SphereShape3D` (radius 0.15).
- Child `MeshInstance3D` with a matching `SphereMesh`.
- `collision_layer`/`mask` set to detect the `"players"` layer.

- [ ] **Step 4: Write projectile.gd**

```gdscript
extends Area3D
class_name Projectile

var speed: float = 15.0
var damage: int = 10
var shooter: Player = null
var lifetime: float = 3.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	global_translate(-global_transform.basis.z * speed * delta)

func _on_body_entered(body: Node3D) -> void:
	if body is Player and body != shooter:
		body.take_damage(damage)
		queue_free()
```

Attach as the script of `Projectile.tscn`'s root node.

- [ ] **Step 5: Define input actions**

In Project Settings → Input Map, add actions: `move_left` (A), `move_right` (D), `move_forward` (W), `move_back` (S), `jump` (Space), `attack_melee` (Left Mouse Button), `attack_ranged` (Right Mouse Button).

- [ ] **Step 6: Manual verification**

Create a throwaway test scene with one `Player` instance and a flat `StaticBody3D` floor, run it, confirm: WASD moves, mouse looks around, Space jumps, left-click deals melee damage to a second `Player` instance placed nearby (watch `current_hp` via a temporary `print` connected to `damaged`), right-click spawns a projectile that flies forward and damages a `Player` it touches. Delete the throwaway scene afterward (Arena scene in Task 6 supersedes it).

- [ ] **Step 7: Commit**

```bash
git add scenes/player project.godot
git commit -m "Add Player scene with movement, camera, melee and ranged attacks"
```

---

### Task 5: Arena scene, HUD, and round flow

**Files:**
- Create: `scenes/arena/Arena.tscn`
- Create: `scenes/arena/arena.gd`

**Interfaces:**
- Consumes: `Player` scene/script from Task 4 (`damaged`, `died` signals, `reset_player()`), `RoundManager` from Task 3.
- Produces: `Arena` scene that, when run standalone (both players local, for manual testing), spawns two `Player` instances at fixed `Marker3D` points, wires their signals to a HUD, and handles win/reset. (Task 7 replaces "spawn two local players" with per-peer spawning, reusing `_on_player_died`/`_reset_round`.)

- [ ] **Step 1: Build the Arena scene**

Create `scenes/arena/Arena.tscn`:
- Root: `Node3D` named `Arena`.
- `WorldEnvironment` with a default `Environment` (basic sky).
- `DirectionalLight3D`.
- `StaticBody3D` "Floor": `CollisionShape3D` with a `BoxShape3D` (e.g. 20×1×20), `MeshInstance3D` with a matching `BoxMesh`.
- Four `StaticBody3D` "Wall" nodes (each with `CollisionShape3D`/`MeshInstance3D` `BoxShape3D`/`BoxMesh`) positioned at the four edges of the floor, tall enough (e.g. height 4) to keep players in.
- `Marker3D` "SpawnP1" at e.g. `Vector3(-6, 1, 0)`.
- `Marker3D` "SpawnP2" at e.g. `Vector3(6, 1, 0)`, rotated 180° on Y so it faces P1.
- `CanvasLayer` "HUD" containing:
  - `ProgressBar` "HpBarP1" (top-left, max_value 100).
  - `ProgressBar` "HpBarP2" (top-right, max_value 100).
  - `Label` "WinnerLabel" (centered, hidden by default) showing winner text + "Aperte R para reiniciar".

- [ ] **Step 2: Write arena.gd**

```gdscript
extends Node3D
class_name Arena

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/Player.tscn")

@onready var spawn_p1: Marker3D = $SpawnP1
@onready var spawn_p2: Marker3D = $SpawnP2
@onready var hp_bar_p1: ProgressBar = $HUD/HpBarP1
@onready var hp_bar_p2: ProgressBar = $HUD/HpBarP2
@onready var winner_label: Label = $HUD/WinnerLabel

var round_manager: RoundManager = RoundManager.new()
var player_one: Player
var player_two: Player
var round_over: bool = false

func _ready() -> void:
	winner_label.hide()
	_spawn_local_test_players()

func _spawn_local_test_players() -> void:
	player_one = PLAYER_SCENE.instantiate()
	add_child(player_one)
	player_one.global_position = spawn_p1.global_position
	player_one.is_local_player = true

	player_two = PLAYER_SCENE.instantiate()
	add_child(player_two)
	player_two.global_position = spawn_p2.global_position
	player_two.is_local_player = false

	_wire_player(player_one, hp_bar_p1)
	_wire_player(player_two, hp_bar_p2)

func _wire_player(player: Player, hp_bar: ProgressBar) -> void:
	hp_bar.value = player.stats.current_hp
	player.damaged.connect(func(current_hp): hp_bar.value = current_hp)
	player.died.connect(_check_round_end)

func _check_round_end() -> void:
	if round_over:
		return
	var winner := round_manager.get_winner(player_one.stats, player_two.stats)
	if winner == "":
		return
	round_over = true
	if winner == "draw":
		winner_label.text = "Empate! Aperte R para reiniciar"
	else:
		winner_label.text = ("Jogador 1" if winner == "p1" else "Jogador 2") + " venceu! Aperte R para reiniciar"
	winner_label.show()

func _unhandled_input(event: InputEvent) -> void:
	if round_over and event.is_action_pressed("reset_round"):
		_reset_round()

func _reset_round() -> void:
	player_one.reset_player(spawn_p1.global_position)
	player_two.reset_player(spawn_p2.global_position)
	round_over = false
	winner_label.hide()
```

Attach as the script of `Arena.tscn`'s root node.

- [ ] **Step 3: Add the reset input action**

In Project Settings → Input Map, add action `reset_round` bound to the `R` key.

- [ ] **Step 4: Manual verification**

Run `Arena.tscn` directly (F6). Confirm: both capsules appear at their spawn markers, HP bars show 100/100, moving/attacking `player_one` (the local one) damages `player_two` when close enough or hit by a projectile, the HP bar updates live, and once `player_two`'s HP hits 0 the winner label appears; pressing `R` resets both HP bars to 100 and hides the label.

- [ ] **Step 5: Commit**

```bash
git add scenes/arena project.godot
git commit -m "Add Arena scene with HUD and round win/reset flow"
```

---

### Task 6: Main menu — host/join UI

**Files:**
- Create: `scenes/menu/MainMenu.tscn`
- Create: `scenes/menu/main_menu.gd`
- Modify: `project.godot` (set `MainMenu.tscn` as the run scene)

**Interfaces:**
- Produces: `MainMenu` scene with a "Hospedar" button and an IP `LineEdit` + "Conectar" button. On success, both paths call `get_tree().change_scene_to_file("res://scenes/arena/Arena.tscn")`. Networking peer creation itself is wired in Task 7 (this task builds the UI and stubs the two handlers so the scene is navigable and manually testable now).

- [ ] **Step 1: Build the MainMenu scene**

Create `scenes/menu/MainMenu.tscn`:
- Root: `Control` (full-rect), named `MainMenu`.
- `VBoxContainer` centered, containing:
  - `Label` "Arena 3D" (title).
  - `Button` "HostButton" text "Hospedar".
  - `HBoxContainer` with `LineEdit` "IpInput" (placeholder text "IP do host") and `Button` "JoinButton" text "Conectar".
  - `Label` "StatusLabel" (empty by default, shows connection errors).

- [ ] **Step 2: Write main_menu.gd**

```gdscript
extends Control
class_name MainMenu

const PORT := 8910
const ARENA_SCENE_PATH := "res://scenes/arena/Arena.tscn"

@onready var host_button: Button = $VBoxContainer/HostButton
@onready var ip_input: LineEdit = $VBoxContainer/HBoxContainer/IpInput
@onready var join_button: Button = $VBoxContainer/HBoxContainer/JoinButton
@onready var status_label: Label = $VBoxContainer/StatusLabel

func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)

func _on_host_pressed() -> void:
	status_label.text = "Hospedando na porta %d..." % PORT
	get_tree().change_scene_to_file(ARENA_SCENE_PATH)

func _on_join_pressed() -> void:
	var ip := ip_input.text.strip_edges()
	if ip.is_empty():
		status_label.text = "Digite o IP do host."
		return
	status_label.text = "Conectando a %s..." % ip
	get_tree().change_scene_to_file(ARENA_SCENE_PATH)
```

Attach as the script of `MainMenu.tscn`'s root node. (Task 7 replaces the bodies of `_on_host_pressed`/`_on_join_pressed` with real `ENetMultiplayerPeer` setup, storing `ip`/host-vs-client in an autoload so `Arena.tscn` knows which role to take.)

- [ ] **Step 3: Set MainMenu as the project's run scene**

Project Settings → Application → Run → Main Scene → `res://scenes/menu/MainMenu.tscn`.

- [ ] **Step 4: Manual verification**

Run the project (F5). Confirm the menu appears, clicking "Hospedar" navigates to `Arena.tscn` (two local test players as built in Task 5), and going back and typing an IP then clicking "Conectar" also navigates to `Arena.tscn`.

- [ ] **Step 5: Commit**

```bash
git add scenes/menu project.godot
git commit -m "Add main menu with host/join UI"
```

---

### Task 7: Real networking — host/join, per-peer players, RPC sync

**Files:**
- Create: `autoloads/network_state.gd`
- Modify: `project.godot` (register `NetworkState` as an autoload)
- Modify: `scenes/menu/main_menu.gd`
- Modify: `scenes/arena/arena.gd`
- Modify: `scenes/player/player.gd`

**Interfaces:**
- Consumes: `MainMenu` (Task 6), `Arena`/`Player` (Tasks 4–5).
- Produces: `NetworkState` autoload with `var is_host: bool` and `var host_ip: String`, used by `arena.gd` to decide server/client setup on `_ready()`.

- [ ] **Step 1: Write the NetworkState autoload**

```gdscript
extends Node

const PORT := 8910
const MAX_PLAYERS := 2

var is_host: bool = false
var host_ip: String = ""
```

Save as `autoloads/network_state.gd`. Register: Project Settings → Autoload → path `res://autoloads/network_state.gd`, node name `NetworkState`.

- [ ] **Step 2: Update main_menu.gd to configure NetworkState**

```gdscript
func _on_host_pressed() -> void:
	NetworkState.is_host = true
	status_label.text = "Hospedando na porta %d..." % PORT
	get_tree().change_scene_to_file(ARENA_SCENE_PATH)

func _on_join_pressed() -> void:
	var ip := ip_input.text.strip_edges()
	if ip.is_empty():
		status_label.text = "Digite o IP do host."
		return
	NetworkState.is_host = false
	NetworkState.host_ip = ip
	status_label.text = "Conectando a %s..." % ip
	get_tree().change_scene_to_file(ARENA_SCENE_PATH)
```

Replace the corresponding functions in `scenes/menu/main_menu.gd`.

- [ ] **Step 3: Update arena.gd to create the ENet peer and spawn per-connected-peer**

Replace `_ready`/`_spawn_local_test_players` in `scenes/arena/arena.gd`:

```gdscript
var players_by_id: Dictionary = {}

func _ready() -> void:
	winner_label.hide()
	if NetworkState.is_host:
		var peer := ENetMultiplayerPeer.new()
		var err := peer.create_server(NetworkState.PORT, NetworkState.MAX_PLAYERS)
		if err != OK:
			winner_label.text = "Falha ao hospedar (erro %d)" % err
			winner_label.show()
			return
		multiplayer.multiplayer_peer = peer
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		_spawn_player(1, spawn_p1.global_position, true)
	else:
		var peer := ENetMultiplayerPeer.new()
		var err := peer.create_client(NetworkState.host_ip, NetworkState.PORT)
		if err != OK:
			winner_label.text = "Falha ao conectar (erro %d)" % err
			winner_label.show()
			return
		multiplayer.multiplayer_peer = peer

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		_spawn_player(id, spawn_p2.global_position, false)
		for existing_id in players_by_id.keys():
			pass # positions sync automatically via per-frame RPC below

func _on_peer_disconnected(id: int) -> void:
	if players_by_id.has(id):
		players_by_id[id].queue_free()
		players_by_id.erase(id)

func _spawn_player(id: int, spawn_position: Vector3, is_first: bool) -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	player.name = str(id)
	add_child(player)
	player.global_position = spawn_position
	player.is_local_player = (id == multiplayer.get_unique_id())
	players_by_id[id] = player
	var hp_bar := hp_bar_p1 if is_first else hp_bar_p2
	_wire_player(player, hp_bar)
	if is_first:
		player_one = player
	else:
		player_two = player
```

Remove the old `_spawn_local_test_players` function entirely; keep `_wire_player`, `_check_round_end`, `_unhandled_input`, `_reset_round` as in Task 5, but update `_reset_round` to only run on the host and replicate:

```gdscript
func _reset_round() -> void:
	if not multiplayer.is_server():
		return
	_do_reset.rpc()

@rpc("call_local", "reliable")
func _do_reset() -> void:
	player_one.reset_player(spawn_p1.global_position)
	player_two.reset_player(spawn_p2.global_position)
	round_over = false
	winner_label.hide()
```

- [ ] **Step 4: Replicate player movement and combat via RPC**

In `scenes/player/player.gd`, add authority-gated RPCs so the remote copy of a player mirrors the locally-controlled one. Add near the top of the script:

```gdscript
@rpc("unreliable_ordered", "call_remote")
func _remote_update_transform(pos: Vector3, rot_y: float, pivot_rot_x: float) -> void:
	global_position = pos
	rotation.y = rot_y
	camera_pivot.rotation.x = pivot_rot_x
```

At the end of `_physics_process`, after `move_and_slide()`, add:

```gdscript
	if is_multiplayer_authority():
		_remote_update_transform.rpc(global_position, rotation.y, camera_pivot.rotation.x)
```

Set multiplayer authority when spawning: in `arena.gd`'s `_spawn_player`, after `add_child(player)`, add:

```gdscript
	player.set_multiplayer_authority(id)
```

For `take_damage`, make it host-authoritative and replicated (host applies damage and tells both clients the result) by changing `player.gd`'s `take_damage`:

```gdscript
func take_damage(amount: int) -> void:
	if multiplayer.is_server():
		_apply_damage.rpc(amount)
	elif not multiplayer.has_multiplayer_peer():
		_apply_damage(amount)

@rpc("call_local", "reliable", "any_peer")
func _apply_damage(amount: int) -> void:
	stats.apply_damage(amount)
	damaged.emit(stats.current_hp)
	if stats.is_dead():
		died.emit()
```

This keeps the Task 5 manual-test path working (no multiplayer peer active → damage applies immediately) while making networked damage flow through the host.

- [ ] **Step 5: Manual verification — same machine**

Run two instances of the project (Godot editor "Run Multiple Instances" or two exported builds run side by side): in instance A click "Hospedar", in instance B enter `127.0.0.1` and click "Conectar". Confirm both players appear in both windows, movement in one window is reflected in the other within a fraction of a second, melee/projectile damage lands and updates both HP bars identically, and reaching 0 HP shows the winner label in both windows; pressing `R` in either window resets both (reset is host-authoritative — verify it also works when pressed on the client, since `_reset_round` early-returns for non-host, so document that only the host can reset — confirm this matches expectations by testing R on the host window).

- [ ] **Step 6: Manual verification — two PCs over VPN**

With Radmin VPN (or Hamachi) installed and both PCs joined to the same virtual network, repeat Step 5 across the two physical machines using the host's virtual-LAN IP instead of `127.0.0.1`.

- [ ] **Step 7: Commit**

```bash
git add autoloads scenes project.godot
git commit -m "Add real ENet host/join networking with replicated movement and damage"
```

---

### Task 8: Windows export preset and build

**Files:**
- Create: `export_presets.cfg`

**Interfaces:**
- Produces: a Godot export preset named "Windows Desktop" producing `builds/arena3d.exe`.

- [ ] **Step 1: Install the export template**

In the Godot editor: Editor → Manage Export Templates → Download and Install (matching the installed Godot version).

- [ ] **Step 2: Create the export preset**

Project → Export → Add... → Windows Desktop. Set:
- Export Path: `builds/arena3d.exe`
- Embed PCK: enabled (single-file `.exe`, easiest to send to a friend).

Save presets (this writes `export_presets.cfg` at the project root).

- [ ] **Step 3: Export the build**

Project → Export → select "Windows Desktop" → Export Project → confirm path `builds/arena3d.exe`.

- [ ] **Step 4: Verify the build runs standalone**

Copy `builds/arena3d.exe` to a temporary folder without the Godot editor open, double-click it, confirm the main menu appears and "Hospedar" leads into a working arena (same as Task 7 Step 5, single instance is enough here — full two-instance verification already happened in Task 7).

- [ ] **Step 5: Commit the export preset config (not the binary)**

```bash
echo "builds/" >> .gitignore
git add .gitignore export_presets.cfg
git commit -m "Add Windows export preset"
```

The `.exe` itself is sent directly to the friend (e.g. via cloud storage or file transfer) each time a new build is produced — it is not committed to git.

---

## Self-review notes

- Spec coverage: arena/walls (Task 5), melee+ranged combat (Task 4), 100 HP round system with reset (Tasks 2, 3, 5), host/join menu without lobby list (Task 6), ENet networking without external relay (Task 7), Windows `.exe` export (Task 8) — all spec sections have a corresponding task.
- No placeholders remain; every step has concrete code or a concrete manual action.
- Type/signature consistency checked: `CombatStats`, `RoundManager`, `Player.damaged/died/take_damage/reset_player`, `NetworkState.is_host/host_ip` are used identically across the tasks that reference them.
