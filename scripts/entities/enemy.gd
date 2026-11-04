# res://scripts/entities/enemy.gd
# Scopo: mostro generico con macchina a stati finiti (un solo match, nessun nodo di stato),
#        inseguimento con NavigationAgent2D, attacco a contatto e bottino in oro.
#        Le sottoclassi decidono statistiche e disegno; il comportamento sta qui.
# Dipendenze: entity.gd, damage.gd, hitbox.gd, constants.gd, art.gd, gold_pickup.gd
class_name Enemy
extends Entity

enum Stato { IDLE, PATROL, CHASE, ATTACK, FLEE }

const TEMPO_PATTUGLIA: float = 2.4
const TEMPO_PERDITA: float = 3.0
const RAGGIO_COLPO: float = 15.0

var monster_id: String = "mostro"
var level: int = 1
var speed: float = 118.0
var aggro_radius: float = 230.0
var attack_range: float = 30.0
var attack_damage: int = 6
var attack_cooldown: float = 1.15
var loot_min: int = 1
var loot_max: int = 4
var area_id: String = "cripta"
# Probabilita' che alla morte cada un oggetto. L'oro e' sempre garantito, l'oggetto no.
var drop_chance: float = 0.30
# Sorgente casuale del mondo. Assegnata da WorldRoot allo spawn; se manca (test isolato) si
# crea un generatore locale, cosi' il mostro non dipende da chi lo ha messo in scena.
var rng: Rng

var state: Stato = Stato.IDLE
var agent: NavigationAgent2D

var _target: Entity = null
var _cooldown: float = 0.0
var _repath: float = 0.0
var _lost: float = 0.0
var _patrol_timer: float = 0.0
var _home: Vector2 = Vector2.ZERO
var _home_set: bool = false

func _ready() -> void:
	collision_layer = GameConsts.L_NEMICI
	collision_mask = GameConsts.M_NEMICO
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("enemy")
	add_child(SceneFactory.circle_shape(10.0))

	agent = NavigationAgent2D.new()
	agent.radius = 10.0
	agent.path_desired_distance = 8.0
	agent.target_desired_distance = 10.0
	agent.avoidance_enabled = false
	add_child(agent)

	state = Stato.IDLE
	_patrol_timer = TEMPO_PATTUGLIA

func _physics_process(delta: float) -> void:
	if not alive:
		return
	if not _home_set:
		_home = global_position
		_home_set = true
	if _target == null or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("player") as Entity
	_cooldown = maxf(0.0, _cooldown - delta)

	match state:
		Stato.IDLE:
			_idle(delta)
		Stato.PATROL:
			_patrol(delta)
		Stato.CHASE:
			_chase(delta)
		Stato.ATTACK:
			_attack(delta)
		Stato.FLEE:
			_flee(delta)

# --- Stati ---

func _idle(delta: float) -> void:
	apply_motion(Vector2.ZERO, 0.0, delta)
	_patrol_timer -= delta
	if _sees_target():
		_enter_chase()
	elif _patrol_timer <= 0.0:
		_patrol_timer = TEMPO_PATTUGLIA
		agent.target_position = _home + Vector2(cos(float(get_instance_id() % 7) + Time.get_ticks_msec() * 0.001) * 40.0, 0.0)
		state = Stato.PATROL

func _patrol(delta: float) -> void:
	if _sees_target():
		_enter_chase()
		return
	if agent.is_navigation_finished():
		state = Stato.IDLE
		return
	var dir := _next_path_direction()
	apply_motion(dir, speed * 0.55, delta)

func _chase(delta: float) -> void:
	if _target == null or not _target.alive:
		state = Stato.IDLE
		return
	var distance := global_position.distance_to(_target.global_position)
	if distance <= attack_range:
		state = Stato.ATTACK
		return
	if distance > aggro_radius * 1.7:
		_lost += delta
		if _lost > TEMPO_PERDITA:
			state = Stato.IDLE
			_lost = 0.0
			return
	else:
		_lost = 0.0

	_repath -= delta
	if _repath <= 0.0:
		agent.target_position = _target.global_position
		_repath = 0.25
	apply_motion(_next_path_direction(), speed, delta)

func _attack(delta: float) -> void:
	if _target == null or not _target.alive:
		state = Stato.IDLE
		return
	var to_target := _target.global_position - global_position
	facing = to_target.normalized()
	apply_motion(Vector2.ZERO, 0.0, delta)
	if to_target.length() > attack_range * 1.35:
		state = Stato.CHASE
		return
	if _cooldown <= 0.0:
		_cooldown = attack_cooldown
		_strike()

func _flee(delta: float) -> void:
	var away := (global_position - _target.global_position).normalized() if _target != null else Vector2.DOWN
	apply_motion(away, speed * 1.15, delta)

# --- Comportamenti ---

func _enter_chase() -> void:
	state = Stato.CHASE
	_repath = 0.0
	_lost = 0.0

func _strike() -> void:
	var dmg := Damage.make(attack_damage, Damage.Kind.FISICO, facing, 110.0, false)
	Hitbox.spawn(
		get_parent(),
		global_position + facing * 16.0,
		RAGGIO_COLPO,
		GameConsts.L_COLPI_NEMICI,
		GameConsts.L_GIOCATORE | GameConsts.L_PROPS,
		dmg,
		0.12
	)

# Area cliccabile, in coordinate mondo. NON e' il collisore: quello sta ai piedi, mentre
# il disegno sale una quarantina di pixel. Chi gioca clicca il teschio, non le caviglie.
func rect_selezione() -> Rect2:
	return Rect2(global_position + Vector2(-19.0, -48.0), Vector2(38.0, 56.0))

func _sees_target() -> bool:
	if _target == null or not _target.alive:
		return false
	if global_position.distance_to(_target.global_position) > aggro_radius:
		return false
	return _line_of_sight(_target.global_position)

# Linea di vista: un raggio sui soli muri. Senza questo controllo un mostro inseguirebbe
# attraverso un muro, che e' il difetto piu' comune delle FSM scritte di fretta.
func _line_of_sight(point: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position + Vector2(0.0, -20.0),
		point + Vector2(0.0, -20.0),
		GameConsts.L_MONDO
	)
	query.exclude = [get_rid()]
	return space.intersect_ray(query).is_empty()

func _next_path_direction() -> Vector2:
	if agent.is_navigation_finished():
		return Vector2.ZERO
	var to_next := agent.get_next_path_position() - global_position
	if to_next.length() < 2.0:
		return Vector2.ZERO
	return to_next.normalized()

# --- Danno e morte ---

func take_hit(dmg: Damage) -> int:
	var applied := super.take_hit(dmg)
	# Chi viene colpito si accorge di chi lo ha colpito solo se lo vede davvero: senza il
	# controllo, un mostro colpito da lontano o attraverso un muro si metterebbe a inseguire
	# una posizione che non conosce, contro la parete.
	if applied > 0 and state == Stato.IDLE and _sees_target():
		_enter_chase()
	return applied

# Sveglia il mostro senza passare dalla linea di vista. Serve ai test e, in fase 4, ai
# trigger di stanza ("il branco si accorge di te quando apri la porta").
func alert() -> void:
	if not alive:
		return
	_enter_chase()

# Ferma la FSM e la tiene ferma: niente pattuglia, niente inseguimento a caso. E' il modo
# pulito per dire "questo mostro aspetta un segnale", invece di spegnere il processo.
func stand_down() -> void:
	state = Stato.IDLE
	_patrol_timer = 3600.0
	velocity = Vector2.ZERO
	_knockback = Vector2.ZERO
	stagger = 0.0

func on_death() -> void:
	EventBus.enemy_killed.emit(monster_id, level, area_id)
	var generatore: Rng = rng
	if generatore == null:
		generatore = Rng.new(get_instance_id())
	var gold_amount := loot_min + int(fmod(float(get_instance_id()), float(loot_max - loot_min + 1)))
	if gold_amount > 0:
		GoldPickup.spawn(get_parent(), global_position, gold_amount)
	if drop_chance > 0.0 and generatore.chance(drop_chance):
		var item := ItemGenerator.roll(generatore, maxi(1, level))
		GroundItem.spawn(get_parent(), global_position, item)
		EventBus.item_dropped.emit(item)
	queue_free()

func altezza_numero() -> float:
	return 46.0

# Ombra e barra della vita: comuni a tutti i mostri. Le sottoclassi chiamano super().
func _draw() -> void:
	Art.shadow(self, Vector2(0.0, -1.0), 12.0, 0.40)
	if hp < max_hp and hp > 0:
		var width := 26.0
		var top := Vector2(-width * 0.5, -52.0)
		draw_rect(Rect2(top, Vector2(width, 4.0)), Color(0.0, 0.0, 0.0, 0.65))
		draw_rect(Rect2(top + Vector2(1.0, 1.0), Vector2((width - 2.0) * float(hp) / float(max_hp), 2.0)), Color(0.72, 0.16, 0.14))
