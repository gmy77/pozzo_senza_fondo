# res://scripts/world/gold_pickup.gd
# Scopo: monete lasciate a terra da un mostro. Raccolta automatica camminandoci sopra.
#        E' il bottino minimo della fase 2: gli oggetti veri arrivano in fase 3.
# Dipendenze: scripts/core/constants.gd, scripts/core/scene_factory.gd, scripts/core/art.gd
class_name GoldPickup
extends Area2D

var amount: int = 1

var _t: float = 0.0

static func spawn(parent: Node, world_position: Vector2, value: int) -> GoldPickup:
	var pickup := GoldPickup.new()
	pickup.amount = value
	pickup.collision_layer = GameConsts.L_BOTTINO
	pickup.collision_mask = GameConsts.L_GIOCATORE
	pickup.add_child(SceneFactory.circle_shape(11.0))
	pickup.add_to_group("loot")
	parent.add_child(pickup)
	pickup.global_position = world_position + Vector2(0.0, -6.0)
	return pickup

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	# Duck typing: qualunque corpo con add_gold() raccoglie, non solo Player.
	if not body.has_method("add_gold"):
		return
	body.add_gold(amount)
	queue_free()

func _draw() -> void:
	var bob := sin(_t * 4.0) * 1.5
	var center := Vector2(0.0, -8.0 + bob)
	Art.shadow(self, Vector2(0.0, 0.0), 7.0, 0.35)
	Art.ellipse(self, center + Vector2(-4.0, 2.0), 5.0, 2.5, Color(0.62, 0.46, 0.14))
	Art.ellipse(self, center, 5.0, 2.5, Color(0.90, 0.72, 0.24))
	Art.ellipse(self, center + Vector2(0.0, -3.0), 4.0, 2.0, Color(0.96, 0.82, 0.36))
	draw_line(center + Vector2(-2.0, 0.0), center + Vector2(2.0, 0.0), Color(1.0, 0.92, 0.62, 0.8), 1.0)
