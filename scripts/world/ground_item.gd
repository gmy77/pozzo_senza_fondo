# res://scripts/world/ground_item.gd
# Scopo: un oggetto caduto a terra. Si raccoglie camminandoci sopra, se c'e' spazio;
#        altrimenti resta li' e il gioco lo dice, invece di sparire in silenzio.
# Dipendenze: scripts/items/item.gd, scripts/core/constants.gd, scripts/core/art.gd,
#             scripts/core/scene_factory.gd
class_name GroundItem
extends Area2D

var item: Item
var _t: float = 0.0

static func spawn(parent: Node, world_position: Vector2, p_item: Item) -> GroundItem:
	var pickup := GroundItem.new()
	pickup.item = p_item
	pickup.collision_layer = GameConsts.L_BOTTINO
	pickup.collision_mask = GameConsts.L_GIOCATORE
	pickup.monitorable = false
	pickup.add_child(SceneFactory.circle_shape(12.0))
	parent.add_child(pickup)
	pickup.global_position = world_position
	return pickup

func _ready() -> void:
	add_to_group("ground_item")
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if item == null:
		return
	# Duck typing: chi sa raccogliere espone pick_item(). Cosi' il test puo' usare un
	# finto raccoglitore senza costruire un Player intero.
	if not body.has_method("pick_item"):
		return
	if body.pick_item(item):
		EventBus.item_picked.emit(item)
		queue_free()
	else:
		EventBus.notice.emit("Zaino pieno")

# Disegno: sacchetto con il colore della rarita'. Il colore e' l'unica informazione che
# deve arrivare da lontano; il resto lo dice il tooltip.
func _draw() -> void:
	var bob := sin(_t * 3.2 + float(uid_corrente()) * 0.4) * 1.5
	var centro := Vector2(0.0, -9.0 + bob)
	var colore := item.colore() if item != null else Color(0.8, 0.8, 0.8)

	Art.shadow(self, Vector2(0.0, 0.0), 8.0, 0.35)

	var sacco := PackedVector2Array([
		centro + Vector2(-7.0, -2.0),
		centro + Vector2(7.0, -2.0),
		centro + Vector2(5.0, 5.0),
		centro + Vector2(-5.0, 5.0),
	])
	Art.poly(self, sacco, Color(0.24, 0.19, 0.13))
	Art.outline(self, sacco, colore, 1.5)
	draw_line(centro + Vector2(-4.0, -2.0), centro + Vector2(0.0, -6.0), colore, 1.5)
	draw_line(centro + Vector2(4.0, -2.0), centro + Vector2(0.0, -6.0), colore, 1.5)
	draw_circle(centro + Vector2(0.0, -6.0), 1.8, colore)

# Scostamento deterministico per non far oscillare tutti i sacchetti all'unisono.
func uid_corrente() -> int:
	return item.uid if item != null else 0
