# res://scripts/world/prop_body.gd
# Scopo: barili e casse fisici. Si spingono camminandoci contro, si fermano sui muri,
#        e in fase 2 si romperanno con i colpi lasciando detriti.
#        L'origine sta alla base: il collisore e' spostato verso l'alto, cosi' l'ordinamento
#        y-sort e' coerente con quello di giocatore e mostri.
# Dipendenze: scripts/core/constants.gd, scripts/core/art.gd, scripts/core/scene_factory.gd
class_name PropBody
extends RigidBody2D

enum Kind { BARILE, CASSA, DETRITO }

const RADIO_BARILE: float = 13.0
const LATO_CASSA: float = 26.0
const RADIO_DETRITO: float = 5.0
const VITA_DETRITO: float = 4.0
const DURABILITA_BARILE: int = 14
const DURABILITA_CASSA: int = 18

var kind: Kind = Kind.BARILE
var shade: float = 0.0
var hp: int = DURABILITA_BARILE

var _life: float = 0.0

func setup(prop_kind: Kind, color_shade: float) -> void:
	kind = prop_kind
	shade = color_shade

	collision_layer = GameConsts.L_PROPS
	collision_mask = GameConsts.M_PROPS
	mass = 2.2
	gravity_scale = 0.0
	linear_damp = 3.0
	angular_damp = 6.0
	lock_rotation = true

	var material := PhysicsMaterial.new()
	material.friction = 0.55
	material.bounce = 0.05
	physics_material_override = material

	match kind:
		Kind.BARILE:
			hp = DURABILITA_BARILE
			add_child(SceneFactory.circle_shape(RADIO_BARILE, Vector2(0.0, -RADIO_BARILE)))
		Kind.CASSA:
			hp = DURABILITA_CASSA
			add_child(SceneFactory.rect_shape(Vector2(LATO_CASSA, LATO_CASSA), Vector2(0.0, -LATO_CASSA * 0.5)))
		Kind.DETRITO:
			# Scheggia: leggera, senza vita utile. Sparisce da sola.
			hp = 1
			mass = 0.5
			linear_damp = 5.0
			_life = VITA_DETRITO
			add_child(SceneFactory.circle_shape(RADIO_DETRITO, Vector2(0.0, -RADIO_DETRITO)))

	queue_redraw()

func _ready() -> void:
	add_to_group("prop")

func _process(delta: float) -> void:
	if _life <= 0.0:
		return
	_life -= delta
	if _life < 0.8:
		modulate.a = maxf(0.0, _life / 0.8)
	if _life <= 0.0:
		queue_free()

func _draw() -> void:
	Art.shadow(self, Vector2(0.0, -1.0), 14.0, 0.45)
	match kind:
		Kind.BARILE:
			_draw_barrel()
		Kind.CASSA:
			_draw_crate()
		Kind.DETRITO:
			_draw_debris()

# Il colpo rompe il prop: le schegge escono nella direzione del colpo. Senza questo,
# un barile attraversato da una spada resta li' immobile e il combattimento non convince.
func take_hit(dmg: Damage) -> int:
	var applied := mini(dmg.amount, hp)
	hp = maxi(0, hp - dmg.amount)
	apply_central_impulse(dmg.direction.normalized() * 60.0)
	if hp <= 0:
		_break_apart(dmg.direction)
		queue_free()
	return applied

func _break_apart(direction: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var push := direction.normalized() if direction.length() > 0.01 else Vector2.DOWN
	for i in 3:
		var piece := PropBody.new()
		piece.setup(Kind.DETRITO, shade)
		parent.add_child(piece)
		piece.global_position = global_position + Vector2(float(i - 1) * 7.0, -4.0)
		piece.apply_central_impulse((push + Vector2(float(i - 1) * 0.7, -0.5)).normalized() * 40.0)

func _draw_debris() -> void:
	var color := Color(0.30 + shade, 0.21 + shade, 0.12 + shade)
	Art.rect_outlined(self, Rect2(-5.0, -9.0, 10.0, 7.0), color, Color(0.10, 0.07, 0.04), 1.0)
	draw_line(Vector2(-4.0, -6.0), Vector2(4.0, -7.0), Color(0.0, 0.0, 0.0, 0.35), 1.0)

func _draw_barrel() -> void:
	var radius := RADIO_BARILE
	var center := Vector2(0.0, -radius)
	var wood := Color(0.33 + shade, 0.22 + shade, 0.12 + shade)
	var iron := Color(0.35, 0.35, 0.38)

	Art.rect_outlined(
		self,
		Rect2(center + Vector2(-radius, -radius * 0.85), Vector2(radius * 2.0, radius * 1.7)),
		wood,
		Color(0.10, 0.07, 0.04),
		1.5
	)
	for i in 4:
		var x := center.x - radius + 4.0 + float(i) * 6.0
		draw_line(
			Vector2(x, center.y - radius * 0.85),
			Vector2(x, center.y + radius * 0.85),
			Color(0.0, 0.0, 0.0, 0.25),
			1.0
		)
	draw_rect(Rect2(center + Vector2(-radius, -radius * 0.55), Vector2(radius * 2.0, 3.0)), iron)
	draw_rect(Rect2(center + Vector2(-radius, radius * 0.42), Vector2(radius * 2.0, 3.0)), iron)
	Art.ellipse(self, center + Vector2(0.0, -radius * 0.85), radius, radius * 0.42, Color(0.40 + shade, 0.28 + shade, 0.15 + shade))

func _draw_crate() -> void:
	var side := LATO_CASSA
	var center := Vector2(0.0, -side * 0.5)
	var wood := Color(0.36 + shade, 0.27 + shade, 0.16 + shade)
	var nail := Color(0.45, 0.45, 0.48)

	Art.rect_outlined(
		self,
		Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side)),
		wood,
		Color(0.12, 0.08, 0.05),
		1.5
	)
	draw_line(center + Vector2(-side * 0.5, -side * 0.5), center + Vector2(side * 0.5, side * 0.5), Color(0.14, 0.09, 0.05), 2.0)
	draw_line(center + Vector2(side * 0.5, -side * 0.5), center + Vector2(-side * 0.5, side * 0.5), Color(0.14, 0.09, 0.05), 2.0)
	draw_rect(Rect2(center - Vector2(side * 0.5, side * 0.5), Vector2(side, 3.0)), nail)
	draw_rect(Rect2(center + Vector2(-side * 0.5, side * 0.5 - 3.0), Vector2(side, 3.0)), nail)
