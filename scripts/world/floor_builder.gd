# res://scripts/world/floor_builder.gd
# Scopo: trasforma una griglia di celle in un piano giocabile: pavimento disegnato, un pezzo
#        di muro visivo per cella (per l'y-sort), collisioni fuse per tratto di riga,
#        una NavigationRegion2D per tratto camminabile.
#        E' il ponte tra il generatore (fase 4) e la scena: nessun altro sistema costruisce geometria.
# Dipendenze: constants.gd, floor_painter.gd, wall_block.gd, scene_factory.gd
class_name FloorBuilder
extends RefCounted

# Raggio usato per erodere il navmesh: deve coprire il raggio del corpo del giocatore
# e dei mostri, altrimenti i percorsi passano dentro i muri.
const RAGGIO_AGENTE: float = 12.0

static func build(parent: Node2D, grid: Array, rng: Rng) -> Dictionary:
	var painter := FloorPainter.new()
	painter.name = "FloorPainter"
	painter.grid = grid
	painter.z_index = GameConsts.Z_PAVIMENTO
	parent.add_child(painter)

	var walls := SceneFactory.static_walls()
	walls.name = "Walls"
	parent.add_child(walls)

	var nav := NavigationRegion2D.new()
	nav.name = "Navigation"
	parent.add_child(nav)

	var width: int = (grid[0] as PackedByteArray).size()
	var height: int = grid.size()
	var bounds := Rect2(
		0.0,
		0.0,
		float(width * GameConsts.CELL),
		float(height * GameConsts.CELL)
	)
	var walkable_cells: Array[Vector2i] = []
	var floor_runs: Array[Rect2] = []

	for y in height:
		var row: PackedByteArray = grid[y]

		var wall_start: int = -1
		var floor_start: int = -1
		for x in width + 1:
			var is_wall := false
			var is_floor := false
			if x < width:
				is_wall = row[x] == GameConsts.CELL_MURO
				is_floor = row[x] == GameConsts.CELL_PAVIMENTO

			if is_wall and wall_start < 0:
				wall_start = x
			elif not is_wall and wall_start >= 0:
				_add_wall_run(walls, wall_start, x - 1, y)
				wall_start = -1

			if is_floor and floor_start < 0:
				floor_start = x
			elif not is_floor and floor_start >= 0:
				floor_runs.append(Rect2(
					float(floor_start * GameConsts.CELL),
					float(y * GameConsts.CELL),
					float((x - floor_start) * GameConsts.CELL),
					float(GameConsts.CELL)
				))
				floor_start = -1

	for y in height:
		var row: PackedByteArray = grid[y]
		for x in width:
			var cell := row[x]
			if cell == GameConsts.CELL_PAVIMENTO:
				walkable_cells.append(Vector2i(x, y))
				continue
			if cell != GameConsts.CELL_MURO:
				continue
			var block := WallBlock.new()
			block.position = cell_bottom(Vector2i(x, y))
			block.has_wall_above = y > 0 and (grid[y - 1] as PackedByteArray)[x] == GameConsts.CELL_MURO
			block.shade = float((x * 7 + y * 13) % 5) * 0.004
			parent.add_child(block)

	_build_navigation(nav, floor_runs)

	return {
		"bounds": bounds,
		"walkable_cells": walkable_cells,
		"walls": walls,
		"navigation": nav,
		"floor_runs": floor_runs,
	}

# Centro della cella: punto d'appoggio naturale per gli oggetti.
static func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(
		float(cell.x * GameConsts.CELL) + GameConsts.CELL * 0.5,
		float(cell.y * GameConsts.CELL) + GameConsts.CELL * 0.5
	)

# Bordo inferiore della cella: origine corretta per l'y-sort di muri e props.
static func cell_bottom(cell: Vector2i) -> Vector2:
	return Vector2(
		float(cell.x * GameConsts.CELL) + GameConsts.CELL * 0.5,
		float((cell.y + 1) * GameConsts.CELL)
	)

static func _add_wall_run(walls: StaticBody2D, x0: int, x1: int, y: int) -> void:
	var cells := float(x1 - x0 + 1)
	var size := Vector2(cells * GameConsts.CELL, float(GameConsts.CELL))
	var center := Vector2(
		(float(x0) + cells * 0.5) * GameConsts.CELL,
		(float(y) + 0.5) * GameConsts.CELL
	)
	walls.add_child(SceneFactory.rect_shape(size, center))

# Navmesh: UNA regione per piano, cotta con agent_radius. Le regioni costruite a mano
# ignorano il raggio dell'agente: il percorso passa a 0 px dal muro e in un corridoio largo
# una cella l'agente si incastra (misurato: 867 frame contro i muri, mai arrivato).
# Con il bake il percorso tiene 15,6 px di distanza e l'agente arriva.
static func _build_navigation(region: NavigationRegion2D, runs: Array[Rect2]) -> void:
	var source := NavigationMeshSourceGeometryData2D.new()
	for rect in runs:
		# Avvolgimento richiesto dal bake: alto-sx, basso-sx, basso-dx, alto-dx.
		source.add_traversable_outline(PackedVector2Array([
			rect.position,
			Vector2(rect.position.x, rect.end.y),
			rect.end,
			Vector2(rect.end.x, rect.position.y),
		]))
	var polygon := NavigationPolygon.new()
	polygon.agent_radius = RAGGIO_AGENTE
	NavigationServer2D.bake_from_source_geometry_data(polygon, source)
	region.navigation_polygon = polygon
