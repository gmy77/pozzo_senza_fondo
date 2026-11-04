# res://scripts/entities/player.gd
# Scopo: il giocatore. Movimento WASD, click-to-move con NavigationAgent2D, attacco melee
#        con clic su un nemico (il personaggio ci cammina prima di menare), telecamera con
#        smorzamento e limiti di stanza, disegno procedurale di un combattente incappucciato.
# Dipendenze: entity.gd, stats.gd, damage.gd, hitbox.gd, constants.gd, art.gd, scene_factory.gd
class_name Player
extends Entity

const RADIO_CORPO: float = 11.0
# Ingombro del disegno, in pixel. Serve al world_root per capire se un muro copre il
# personaggio: se il disegno fosse piatto ai piedi (altezza zero) nessun muro potrebbe
# mai coprirlo e l'y-sort sarebbe corretto ma inutile.
const LARGHEZZA_DISEGNO: float = 28.0
const ALTEZZA_DISEGNO: float = 43.0

const PORTATA_MISCHIA: float = 34.0
const RAGGIO_COLPO: float = 17.0
const TEMPO_RECUPERO: float = 0.42
const TEMPO_FENDENTE: float = 0.18

var agent: NavigationAgent2D
var camera: Camera2D
var has_target: bool = false

# Nemico su cui il giocatore sta andando: null quando si sta solo spostando.
var attack_target: Entity = null
var gold: int = 0
var inventory: Inventory

var _marker_pos: Vector2 = Vector2.ZERO
var _marker_alpha: float = 0.0
var _cooldown: float = 0.0
var _swing: float = 0.0
var _repath: float = 0.0

# Tasto sinistro tenuto premuto: il comando viene rinnovato, non eseguito una volta sola.
var _mouse_held: bool = false
var _cursor_last: Vector2 = Vector2.ZERO
var _hold_repath: float = 0.0

func _ready() -> void:
	collision_layer = GameConsts.L_GIOCATORE
	collision_mask = GameConsts.M_GIOCATORE
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("player")

	stats = Stats.new(12, 12, 8, 12)
	setup_vitals()
	inventory = Inventory.new()
	add_child(SceneFactory.circle_shape(RADIO_CORPO))

	agent = NavigationAgent2D.new()
	agent.radius = RADIO_CORPO
	agent.path_desired_distance = 6.0
	agent.target_desired_distance = 8.0
	agent.avoidance_enabled = false
	add_child(agent)

	camera = Camera2D.new()
	camera.zoom = Vector2(1.4, 1.4)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	add_child(camera)
	camera.make_current()

func _physics_process(delta: float) -> void:
	if not alive:
		apply_motion(Vector2.ZERO, 0.0, delta)
		return

	_cooldown = maxf(0.0, _cooldown - delta)
	_swing = maxf(0.0, _swing - delta)

	var direction := _input_direction()
	if direction != Vector2.ZERO:
		has_target = false
		attack_target = null
		_swing = 0.0
	else:
		# Tasto premuto = ordine continuo: il cursore resta la destinazione finche' non
		# viene rilasciato. WASD ha sempre la precedenza e annulla l'ordine.
		_hold_tick(delta)

	if direction == Vector2.ZERO and _try_attack(delta):
		pass
	elif direction == Vector2.ZERO and has_target:
		direction = _path_direction()
		if direction == Vector2.ZERO and agent.is_navigation_finished():
			has_target = false

	apply_motion(direction, stats.move_speed(), delta)
	if _marker_alpha > 0.0:
		_marker_alpha = maxf(0.0, _marker_alpha - delta * 1.8)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	# Trascinare con il tasto giu' sposta la destinazione: e' il senso del "tieni premuto".
	if event is InputEventMouseMotion and _mouse_held:
		_cursor_last = get_global_mouse_position()
		return
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse.pressed:
		set_hold(true, get_global_mouse_position())
	else:
		set_hold(false, get_global_mouse_position())

# Esegue un ordine nel punto indicato: mostro se c'e', altrimenti terreno.
func command_at(point: Vector2) -> void:
	var enemy := _enemy_at(point)
	if enemy != null:
		attack_target = enemy
		set_move_target(enemy.global_position)
		_repath = 0.0
	else:
		attack_target = null
		set_move_target(point)

# Tasto sinistro: true alla pressione, false al rilascio. E' separato dall'input vero
# perche' il selftest headless non ha un mouse e deve provare la stessa catena.
func set_hold(held: bool, point: Vector2) -> void:
	_mouse_held = held
	_cursor_last = point
	if held:
		_hold_repath = 0.0
		command_at(point)
	else:
		# Al rilascio si smette di menare, ma si finisce di camminare verso l'ultimo punto:
		# annullare anche il percorso darebbe un personaggio che si pianta a meta' passo.
		attack_target = null

# Comando continuo. Se il bersaglio e' vivo non fa niente: _try_attack ricalcola gia' il
# percorso da solo. Se e' morto, o il cursore e' finito su qualcos'altro, rilegge il punto
# senza aspettare un nuovo clic.
func _hold_tick(delta: float) -> void:
	if not _mouse_held:
		return
	if attack_target != null and is_instance_valid(attack_target) and attack_target.alive:
		return
	_hold_repath -= delta
	if _hold_repath <= 0.0:
		_hold_repath = 0.15
		command_at(_cursor_last)

func set_move_target(target: Vector2) -> void:
	agent.target_position = target
	has_target = true
	_marker_pos = target
	_marker_alpha = 1.0
	queue_redraw()

# Ferma il personaggio e cancella l'ordine di movimento. Serve al selftest quando sposta
# il giocatore a mano: senza questo il percorso vecchio continua a trascinarlo.
func stop() -> void:
	_mouse_held = false
	has_target = false
	attack_target = null
	velocity = Vector2.ZERO
	agent.target_position = global_position
	_marker_alpha = 0.0

func set_camera_limits(bounds: Rect2) -> void:
	camera.limit_left = int(bounds.position.x)
	camera.limit_top = int(bounds.position.y)
	camera.limit_right = int(bounds.end.x)
	camera.limit_bottom = int(bounds.end.y)

# Attacco: se c'e' un bersaglio vivo e a portata, mena e ferma il movimento.
# Restituisce true solo se il colpo e' partito (o e' in ricarica) e il personaggio deve
# restare fermo. Fuori portata restituisce false: il chiamante deve seguire il percorso,
# altrimenti il giocatore resta piantato a guardare il mostro (era il difetto della fase 2).
func _try_attack(delta: float) -> bool:
	if attack_target == null:
		return false
	if not is_instance_valid(attack_target) or not attack_target.alive:
		attack_target = null
		return false

	var to_target := attack_target.global_position - global_position
	if to_target.length() > PORTATA_MISCHIA:
		# Fuori portata: si continua a camminare verso il bersaglio, ricalcolando il
		# percorso ogni quarto di secondo perche' il mostro si muove.
		_repath -= delta
		if _repath <= 0.0:
			agent.target_position = attack_target.global_position
			has_target = true
			_repath = 0.25
		return false

	has_target = false
	facing = to_target.normalized()
	if _cooldown <= 0.0:
		_swing = TEMPO_FENDENTE
		_cooldown = TEMPO_RECUPERO
		_swing_hit()
	return true

func _swing_hit() -> void:
	var crit_chance := 0.08 + float(stats.dexterity) * 0.004
	var crit := randf() < crit_chance
	var amount := int(round(6.0 + float(stats.strength) * 0.75))
	if crit:
		amount = int(round(float(amount) * 1.8))
	var dmg := Damage.make(amount, Damage.Kind.FISICO, facing, 150.0, crit)
	Hitbox.spawn(
		get_parent(),
		global_position + facing * 18.0,
		RAGGIO_COLPO,
		GameConsts.L_COLPI_GIOCATORE,
		GameConsts.L_NEMICI | GameConsts.L_PROPS,
		dmg,
		0.12
	)

func _enemy_at(point: Vector2) -> Entity:
	var best: Entity = null
	var best_distance := 26.0
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Entity
		if enemy == null or not enemy.alive:
			continue
		var distance := enemy.global_position.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best

func add_gold(amount: int) -> void:
	gold += amount
	EventBus.gold_changed.emit(gold)

# Raccoglie un oggetto se c'e' spazio. Restituisce false se lo zaino e' pieno: il chiamante
# (GroundItem) lascia l'oggetto a terra invece di distruggerlo.
func pick_item(item: Item) -> bool:
	if item == null or inventory == null:
		return false
	if not inventory.aggiungi(item):
		return false
	EventBus.inventory_changed.emit()
	return true

func on_death() -> void:
	velocity = Vector2.ZERO
	attack_target = null
	has_target = false
	EventBus.player_died.emit()

func altezza_numero() -> float:
	return 44.0

func _input_direction() -> Vector2:
	var dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if dir.length() < 0.2:
		return Vector2.ZERO
	return dir.normalized()

func _path_direction() -> Vector2:
	if agent.is_navigation_finished():
		return Vector2.ZERO
	var to_next := agent.get_next_path_position() - global_position
	if to_next.length() < 2.0:
		return Vector2.ZERO
	return to_next.normalized()

func _draw() -> void:
	if _marker_alpha > 0.0:
		var ring := 9.0 + (1.0 - _marker_alpha) * 7.0
		draw_arc(_marker_pos - global_position, ring, 0.0, TAU, 28, Color(0.85, 0.76, 0.45, _marker_alpha * 0.85), 2.0)

	Art.shadow(self, Vector2(0.0, -1.0), 13.0, 0.42)

	var bob := sin(walk_phase) * 1.6 if is_moving else 0.0
	var step := sin(walk_phase) * 3.0 if is_moving else 0.0
	var base := Vector2(0.0, bob)

	# stivali
	Art.rect_outlined(self, Rect2(base + Vector2(-7.0 + step, -9.0), Vector2(6.0, 9.0)), Color(0.20, 0.14, 0.11), Color(0.08, 0.06, 0.05), 1.0)
	Art.rect_outlined(self, Rect2(base + Vector2(1.0 - step, -9.0), Vector2(6.0, 9.0)), Color(0.20, 0.14, 0.11), Color(0.08, 0.06, 0.05), 1.0)

	# mantello
	var cloak := PackedVector2Array([
		base + Vector2(-12.0, -30.0),
		base + Vector2(12.0, -30.0),
		base + Vector2(14.0, -4.0),
		base + Vector2(-14.0, -4.0),
	])
	Art.poly(self, cloak, Color(0.36, 0.12, 0.13))
	Art.outline(self, cloak, Color(0.13, 0.05, 0.06), 1.5)

	# corazza, cintura, spalline
	Art.rect_outlined(self, Rect2(base + Vector2(-8.0, -29.0), Vector2(16.0, 16.0)), Color(0.42, 0.44, 0.50), Color(0.15, 0.16, 0.19), 1.0)
	Art.rect_outlined(self, Rect2(base + Vector2(-9.0, -15.0), Vector2(18.0, 4.0)), Color(0.25, 0.17, 0.10), Color(0.10, 0.07, 0.04), 1.0)
	draw_circle(base + Vector2(-9.0, -28.0), 4.5, Color(0.55, 0.57, 0.62))
	draw_circle(base + Vector2(9.0, -28.0), 4.5, Color(0.55, 0.57, 0.62))

	# testa: cappuccio, e viso solo se non e' di spalle
	draw_circle(base + Vector2(0.0, -36.0), 6.5, Color(0.30, 0.26, 0.24))
	draw_circle(base + Vector2(0.0, -37.0), 5.0, Color(0.16, 0.13, 0.12))
	if facing.y >= -0.3:
		draw_circle(base + Vector2(facing.x * 2.0, -35.5), 2.2, Color(0.80, 0.70, 0.55))

	# spada sul lato verso cui si guarda
	var sword_x := 15.0 if facing.x >= 0.0 else -15.0
	var blade := PackedVector2Array([
		base + Vector2(sword_x, -30.0),
		base + Vector2(sword_x + 3.0, -28.0),
		base + Vector2(sword_x + 3.0, -8.0),
		base + Vector2(sword_x, -6.0),
	])
	Art.poly(self, blade, Color(0.72, 0.74, 0.80))
	Art.outline(self, blade, Color(0.30, 0.32, 0.36), 1.0)
	draw_rect(Rect2(base + Vector2(sword_x - 2.0, -8.0), Vector2(7.0, 2.0)), Color(0.42, 0.30, 0.12))

	# Fendente: arco che si apre davanti al personaggio per TEMPO_FENDENTE secondi.
	if _swing > 0.0:
		var t := 1.0 - _swing / TEMPO_FENDENTE
		var start := facing.angle() - 1.1 + t * 1.4
		var alpha := 1.0 - t
		draw_arc(Vector2.ZERO, 26.0, start, start + 1.2, 12, Color(0.95, 0.93, 0.80, alpha * 0.9), 3.0)
