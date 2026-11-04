# res://scripts/world/floor_painter.gd
# Scopo: disegna il pavimento di una griglia con variazione cromatica deterministica
#        (stessa griglia = stesso disegno, nessun flicker tra un caricamento e l'altro).
# Dipendenze: scripts/core/constants.gd
class_name FloorPainter
extends Node2D

var grid: Array[PackedByteArray] = []

func _draw() -> void:
	# Fondo di roccia oltre i muri: la telecamera puo' scorrere di poco oltre il bordo
	# del piano, e senza questo si vedrebbe il vuoto della finestra.
	if not grid.is_empty():
		var floor_width := float(grid[0].size() * GameConsts.CELL)
		var floor_height := float(grid.size() * GameConsts.CELL)
		var margin := float(GameConsts.CELL * 4)
		draw_rect(Rect2(-margin, -margin, floor_width + margin * 2.0, floor_height + margin * 2.0), GameConsts.COL_VUOTO)

	for y in grid.size():
		var row: PackedByteArray = grid[y]
		for x in row.size():
			if row[x] != GameConsts.CELL_PAVIMENTO:
				continue
			var rect := Rect2(
				float(x * GameConsts.CELL),
				float(y * GameConsts.CELL),
				float(GameConsts.CELL),
				float(GameConsts.CELL)
			)
			var h := _hash(x, y)
			var tint := float(h % 9) * 0.005
			draw_rect(rect, Color(
				GameConsts.COL_PAVIMENTO.r + tint,
				GameConsts.COL_PAVIMENTO.g + tint,
				GameConsts.COL_PAVIMENTO.b + tint
			))
			draw_rect(rect, Color(0.0, 0.0, 0.0, 0.14), false, 1.0)
			if h % 29 == 0:
				draw_rect(Rect2(rect.position + Vector2(7.0, 8.0), Vector2(5.0, 3.0)), GameConsts.COL_PAVIMENTO_SCURO)
			elif h % 23 == 0:
				draw_circle(rect.position + Vector2(19.0, 21.0), 2.0, Color(0.0, 0.0, 0.0, 0.14))

func _hash(x: int, y: int) -> int:
	return absi(x * 73856093 ^ y * 19349663)
