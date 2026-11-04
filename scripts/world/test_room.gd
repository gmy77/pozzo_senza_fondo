# res://scripts/world/test_room.gd
# Scopo: stanza di prova della fase 1. Produce la stessa griglia che in fase 4 produrra' il
#        generatore di dungeon, quindi non e' codice da buttare: cambia solo chi riempie la griglia.
# Dipendenze: floor_builder.gd, prop_body.gd, constants.gd
class_name TestRoom
extends RefCounted

const LARGHEZZA: int = 24
const ALTEZZA: int = 16

static func build(parent: Node2D, rng: Rng) -> Dictionary:
	var grid: Array[PackedByteArray] = []
	for y in ALTEZZA:
		var row := PackedByteArray()
		row.resize(LARGHEZZA)
		for x in LARGHEZZA:
			var border := x == 0 or y == 0 or x == LARGHEZZA - 1 or y == ALTEZZA - 1
			row[x] = GameConsts.CELL_MURO if border else GameConsts.CELL_PAVIMENTO
		grid.append(row)

	# Pilastri e muretti interni: servono a vedere l'ordinamento dei muri verticali.
	_fill_rect(grid, 7, 5, 1, 4)
	_fill_rect(grid, 17, 4, 1, 3)
	_fill_rect(grid, 14, 10, 3, 1)
	_fill_rect(grid, 11, 12, 3, 1)
	# Corridoio largo una cella (riga 3): due muri paralleli da x=6 a x=20. Serve alla
	# prova con quattro mostri affiancati: qui il navmesh ha solo 8 px di larghezza utile,
	# quindi se il bake fosse sbagliato gli agenti si incastrerebbero subito.
	_fill_rect(grid, 6, 2, 15, 1)
	_fill_rect(grid, 6, 4, 15, 1)

	var info := FloorBuilder.build(parent, grid, rng)
	info["grid"] = grid
	info["spawn"] = FloorBuilder.cell_center(Vector2i(11, 8))
	info["props"] = _spawn_props(parent, rng)
	return info

static func _fill_rect(grid: Array, x0: int, y0: int, width: int, height: int) -> void:
	for y in range(y0, y0 + height):
		var row: PackedByteArray = grid[y]
		for x in range(x0, x0 + width):
			row[x] = GameConsts.CELL_MURO

static func _spawn_props(parent: Node2D, rng: Rng) -> Array[PropBody]:
	var barrels := [Vector2i(3, 3), Vector2i(4, 3), Vector2i(21, 6), Vector2i(3, 12), Vector2i(20, 12), Vector2i(9, 9)]
	var crates := [Vector2i(16, 6), Vector2i(6, 11)]
	var props: Array[PropBody] = []
	for cell in barrels:
		props.append(_make_prop(parent, PropBody.Kind.BARILE, cell, rng))
	for cell in crates:
		props.append(_make_prop(parent, PropBody.Kind.CASSA, cell, rng))
	return props

static func _make_prop(parent: Node2D, kind: PropBody.Kind, cell: Vector2i, rng: Rng) -> PropBody:
	var prop := PropBody.new()
	prop.setup(kind, rng.randf_range(0.0, 0.05))
	parent.add_child(prop)
	prop.global_position = FloorBuilder.cell_bottom(cell) + Vector2(rng.randf_range(-4.0, 4.0), -2.0)
	return prop
