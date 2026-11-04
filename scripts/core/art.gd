# res://scripts/core/art.gd
# Scopo: primitive di disegno condivise da tutti i _draw() del gioco, per non ripetere
#        ogni volta ombre, ellissi e contorni.
# Dipendenze: nessuna.
class_name Art
extends RefCounted

# Ombra ellittica a terra. Il CanvasItem deve avere l'origine ai piedi.
static func shadow(ci: CanvasItem, center: Vector2, radius: float, alpha: float = 0.35) -> void:
	ci.draw_set_transform(center, 0.0, Vector2(1.0, 0.45))
	ci.draw_circle(Vector2.ZERO, radius, Color(0.0, 0.0, 0.0, alpha))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# Ellisse piena: cerchio disegnato con il transform schiacciato sull'asse Y.
static func ellipse(ci: CanvasItem, center: Vector2, radius_x: float, radius_y: float, color: Color) -> void:
	if radius_x <= 0.0:
		return
	ci.draw_set_transform(center, 0.0, Vector2(1.0, radius_y / radius_x))
	ci.draw_circle(Vector2.ZERO, radius_x, color)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func poly(ci: CanvasItem, points: PackedVector2Array, color: Color) -> void:
	if points.size() < 3:
		return
	ci.draw_colored_polygon(points, color)

static func outline(ci: CanvasItem, points: PackedVector2Array, color: Color, width: float = 1.5) -> void:
	if points.size() < 2:
		return
	var closed := points.duplicate()
	closed.append(points[0])
	ci.draw_polyline(closed, color, width)

static func rect_outlined(ci: CanvasItem, rect: Rect2, fill: Color, stroke: Color, width: float = 1.5) -> void:
	ci.draw_rect(rect, fill, true)
	ci.draw_rect(rect, stroke, false, width)
