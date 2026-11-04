# res://scripts/combat/hitbox.gd
# Scopo: area di danno di breve durata. Colpisce una volta sola per bersaglio e poi sparisce.
#        Non usa i segnali body_entered perche' un bersaglio gia' dentro l'area al momento
#        della creazione non emette "entered": si interroga get_overlapping_bodies() a ogni
#        frame fisico, che copre entrambi i casi.
# Dipendenze: damage.gd, constants.gd
class_name Hitbox
extends Area2D

var damage: Damage
var life: float = 0.10

var _hit_ids: Array[int] = []

static func spawn(
	parent: Node,
	world_position: Vector2,
	radius: float,
	layer: int,
	mask: int,
	dmg: Damage,
	lifetime: float = 0.10
) -> Hitbox:
	var box := Hitbox.new()
	box.damage = dmg
	box.life = lifetime
	box.collision_layer = layer
	box.collision_mask = mask
	box.monitorable = false

	var shape := CircleShape2D.new()
	shape.radius = radius
	var collider := CollisionShape2D.new()
	collider.shape = shape
	box.add_child(collider)

	parent.add_child(box)
	box.global_position = world_position
	return box

func _physics_process(delta: float) -> void:
	for body in get_overlapping_bodies():
		_try_hit(body)
	life -= delta
	if life <= 0.0:
		queue_free()

# Duck typing invece di "is Entity": cosi' i colpi funzionano anche su barili e casse,
# che non ereditano da Entity ma espongono take_hit().
func _try_hit(body: Node) -> void:
	var id := body.get_instance_id()
	if _hit_ids.has(id):
		return
	if not body.has_method("take_hit"):
		return
	_hit_ids.append(id)
	body.take_hit(damage)
