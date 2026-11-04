# res://scripts/core/scene_factory.gd
# Scopo: costruzione di nodi e collisori da codice, per non ripetere lo stesso boilerplate
#        in ogni sistema.
# Dipendenze: scripts/core/constants.gd
class_name SceneFactory
extends RefCounted

static func rect_shape(size: Vector2, offset: Vector2 = Vector2.ZERO) -> CollisionShape2D:
	var shape := RectangleShape2D.new()
	shape.size = size
	var node := CollisionShape2D.new()
	node.shape = shape
	node.position = offset
	return node

static func circle_shape(radius: float, offset: Vector2 = Vector2.ZERO) -> CollisionShape2D:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var node := CollisionShape2D.new()
	node.shape = shape
	node.position = offset
	return node

static func static_walls() -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = GameConsts.L_MONDO
	body.collision_mask = 0
	return body
