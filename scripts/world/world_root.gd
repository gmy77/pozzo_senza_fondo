# res://scripts/world/world_root.gd
# Scopo: contenitore del mondo attivo (pavimento, muri, props, giocatore). Attiva l'y-sort:
#        ogni figlio viene disegnato in base alla propria y, quindi chi ha i piedi piu' in
#        basso sta davanti.
#        Tiene anche l'unica regola di trasparenza del gioco: un muro che copre il giocatore
#        sbiadisce, altrimenti con muri alti 88 px il personaggio sparirebbe ogni volta che
#        cammina davanti a un muro.
# Dipendenze: test_room.gd, player.gd, rng.gd, prop_body.gd, wall_block.gd
class_name WorldRoot
extends Node2D

# Opacita' che assume un muro quando si mette davanti al giocatore.
const ALFA_MURO_OCCLUDENTE: float = 0.4
# Velocita' della transizione, in unita' di alpha al secondo.
const VELOCITA_SFUMATURA: float = 7.0

var rng: Rng
var player: Player
var floor_info: Dictionary = {}
var props: Array[PropBody] = []
var enemies: Array[Enemy] = []

var _walls: Array[WallBlock] = []
var _fade_enabled: bool = true

func _ready() -> void:
	y_sort_enabled = true
	# Interruttore di debug: con POZZO_NO_FADE=1 i muri restano opachi, cosi' si puo'
	# fotografare l'occlusione vera senza la sfumatura che la nasconde.
	_fade_enabled = OS.get_environment("POZZO_NO_FADE") != "1"

func build_test_room(seed_value: int) -> void:
	rng = Rng.new(seed_value)
	floor_info = TestRoom.build(self, rng)
	props.assign(floor_info["props"])

	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.global_position = floor_info["spawn"]
	var bounds: Rect2 = floor_info["bounds"]
	player.set_camera_limits(bounds.grow(float(GameConsts.CELL * 3)))

	_walls.assign(get_tree().get_nodes_in_group("wall_block"))
	spawn_demo_enemies()

# Mostri della stanza di prova. In fase 4 saranno il generatore a decidere chi e dove.
func spawn_demo_enemies() -> void:
	var cells: Array[Vector2i] = [Vector2i(5, 10), Vector2i(19, 12), Vector2i(12, 6)]
	for cell in cells:
		spawn_skeleton(cell)

func spawn_skeleton(cell: Vector2i) -> Skeleton:
	var skeleton := Skeleton.new()
	skeleton.rng = rng
	add_child(skeleton)
	skeleton.global_position = FloorBuilder.cell_bottom(cell) + Vector2(0.0, -2.0)
	enemies.append(skeleton)
	return skeleton

func _process(delta: float) -> void:
	if not _fade_enabled or player == null or _walls.is_empty():
		return
	_update_wall_fade(delta)

# Un muro e' occludente quando sta davanti al giocatore (origine piu' in basso) e la sua
# faccia sale sopra i piedi del giocatore. Il controllo e' rettangolare, non per pixel:
# basta e avanza, e costa 89 confronti per frame.
func _update_wall_fade(delta: float) -> void:
	var px := player.global_position.x
	var py := player.global_position.y
	var half_body := Player.LARGHEZZA_DISEGNO * 0.5
	for wall in _walls:
		var wy := wall.global_position.y
		var covers := wy > py and wy - WallBlock.ALTEZZA_TOTALE < py and absf(wall.global_position.x - px) < half_body + float(GameConsts.CELL) * 0.5
		var target := ALFA_MURO_OCCLUDENTE if covers else 1.0
		if not is_equal_approx(wall.modulate.a, target):
			wall.modulate.a = move_toward(wall.modulate.a, target, VELOCITA_SFUMATURA * delta)

# Svuota il mondo. Serve da subito per la transizione borgo <-> dungeon della fase 5,
# ed e' gia' usata dal selftest per ripartire da zero.
func clear() -> void:
	for child in get_children():
		child.queue_free()
	props.clear()
	enemies.clear()
	_walls.clear()
	floor_info.clear()
	player = null
