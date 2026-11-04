# res://scripts/entities/entity.gd
# Scopo: comportamento comune a giocatore e mostri: vita, movimento con orientamento, ciclo
#        del passo, spinta dei corpi fisici (RigidBody2D) che si incontrano lungo il cammino,
#        ricezione del danno con contraccolpo e lampeggio.
# Dipendenze: scripts/combat/stats.gd, scripts/combat/damage.gd, scripts/core/constants.gd,
#             scripts/fx/damage_number.gd
class_name Entity
extends CharacterBody2D

# Forza applicata ai barili: e' continua, quindi la velocita' dei props si autolimita
# con lo smorzamento (v ~ forza / (massa * linear_damp)).
const FORZA_SPINTA: float = GameConsts.FORZA_SPINTA
const TEMPO_LAMPEGGIO: float = 0.14
# Frenata quando la direzione richiesta e' zero. Prima era proporzionale alla velocita'
# passata, quindi con speed 0 (mostro in IDLE o in ATTACK) la velocita' residua non calava
# mai: un mostro respinto contro un muro restava a spingere per sempre. Misurato: 0,52 s per
# fermare un residuo di 720 px/s.
const FRENATA: float = 1400.0
# Difesa: curva a rendimento decrescente invece di una sottrazione secca. Con 16 di difesa
# (elmo + scudo + corazza leggera) il danno fisico cala del 24%, con 50 del 50%, e non
# scende mai sotto il 25% di quello originale. La sottrazione secca, a questi numeri,
# avrebbe reso immortali: 16 di difesa contro i 6 danni di uno scheletro vuol dire 1 fisso.
const COSTANTE_DIFESA: float = 50.0
const RIDUZIONE_MASSIMA: float = 0.75

var stats: Stats
var hp: int = 1
var max_hp: int = 1
var alive: bool = true

var facing: Vector2 = Vector2.DOWN
var walk_phase: float = 0.0
var is_moving: bool = false

# Contraccolpo: mentre dura, il movimento e' deciso dal colpo e non dall'input.
var stagger: float = 0.0
var _knockback: Vector2 = Vector2.ZERO
var _flash: float = 0.0

# Da chiamare dopo aver assegnato stats.
func setup_vitals() -> void:
	max_hp = stats.max_hp()
	hp = max_hp

func apply_motion(direction: Vector2, speed: float, delta: float) -> void:
	# Durante il contraccolpo il controllo e' del colpo, non di chi muove: e' anche il
	# motivo per cui un mostro colpito non continua a camminare dentro l'attacco.
	if stagger > 0.0:
		stagger -= delta
		velocity = _knockback
		_knockback = _knockback.move_toward(Vector2.ZERO, 1100.0 * delta)
		move_and_slide()
		queue_redraw()
		return

	if direction.length() > 0.05:
		var dir := direction.normalized()
		velocity = dir * speed
		facing = dir
		is_moving = true
		walk_phase += delta * 9.0
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRENATA * delta)
		is_moving = velocity.length() > 4.0
		if not is_moving:
			walk_phase = 0.0
	# La velocita' va letta PRIMA di move_and_slide: dopo, la scivolata lungo un ostacolo
	# ne ha gia' tagliato la componente contro il muro, e la spinta partirebbe sbagliata.
	var intended := velocity
	move_and_slide()
	_push_rigid_bodies(intended)
	queue_redraw()

# Il CharacterBody2D non spinge i RigidBody2D: la spinta va applicata a mano,
# una volta per ogni contatto registrato da move_and_slide().
# Direzione = media tra normale del contatto e direzione di marcia. Solo la normale perde
# un terzo della spinta (misurato: 39,4 px contro 53,9 px), perche' i collisori dei props
# stanno piu' in alto dei piedi e la normale ha una componente verso l'alto; solo la
# direzione di marcia ignora gli spigoli e farebbe "sparare" il barile nei muri.
func _push_rigid_bodies(intended_velocity: Vector2) -> void:
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var body := hit.get_collider() as RigidBody2D
		if body == null:
			continue
		var normal_dir := -hit.get_normal()
		var direction := normal_dir
		if intended_velocity.length() > 1.0:
			direction = (normal_dir + intended_velocity.normalized()).normalized()
		body.apply_central_force(direction * FORZA_SPINTA)

func apply_knockback(direction: Vector2, force: float, seconds: float = 0.16) -> void:
	if direction.length() < 0.01:
		return
	_knockback = direction.normalized() * force
	stagger = seconds

# Difesa totale di chi riceve il colpo. Entity non ha equipaggiamento: lo sovrascrive chi
# ce l'ha (il giocatore adesso, i campioni e i boss in fase 6).
func difesa() -> int:
	return 0

func danno_ridotto(dmg: Damage) -> int:
	var dif := difesa()
	# Solo il danno fisico e' fermato dall'armatura. Fuoco, gelo e veleno avranno le
	# resistenze, che sono un'altra statistica e non questa.
	if dif <= 0 or dmg.kind != Damage.Kind.FISICO:
		return dmg.amount
	var riduzione := minf(RIDUZIONE_MASSIMA, float(dif) / (float(dif) + COSTANTE_DIFESA))
	return maxi(1, int(round(float(dmg.amount) * (1.0 - riduzione))))

func take_hit(dmg: Damage) -> int:
	if not alive or dmg == null:
		return 0
	var subito := danno_ridotto(dmg)
	var applied := mini(subito, hp)
	hp = maxi(0, hp - subito)
	_flash = TEMPO_LAMPEGGIO
	if dmg.knockback > 0.0:
		apply_knockback(dmg.direction, dmg.knockback)
	EventBus.damage_dealt.emit(get_instance_id(), applied, dmg.kind_name(), dmg.is_crit)
	DamageNumber.spawn(get_parent(), global_position + Vector2(0.0, -altezza_numero()), applied, dmg.is_crit)
	if is_in_group("player"):
		EventBus.player_hp_changed.emit(hp, max_hp)
	queue_redraw()
	if hp <= 0:
		alive = false
		on_death()
	return applied

# Punto da cui parte il numero del danno: sopra la testa, che ogni sottoclasse conosce.
func altezza_numero() -> float:
	return 42.0

func on_death() -> void:
	queue_free()

func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		modulate = Color(1.7, 1.7, 1.7) if _flash > 0.0 else Color.WHITE
