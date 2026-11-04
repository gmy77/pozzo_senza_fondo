# res://scripts/core/rng.gd
# Scopo: unica sorgente di casualita' del gioco, con seed esplicito per rendere
#        riproducibili loot, dungeon e spawn.
# Dipendenze: nessuna.
class_name Rng
extends RefCounted

var _rng: RandomNumberGenerator

func _init(seed_value: int = 0) -> void:
	_rng = RandomNumberGenerator.new()
	if seed_value == 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value

func seed_value() -> int:
	return _rng.seed

func randf() -> float:
	return _rng.randf()

func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)

func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)

func chance(probability: float) -> bool:
	return _rng.randf() < probability

func pick(items: Array) -> Variant:
	if items.is_empty():
		return null
	return items[_rng.randi_range(0, items.size() - 1)]

func pick_cell(cells: Array[Vector2i]) -> Vector2i:
	if cells.is_empty():
		return Vector2i.ZERO
	return cells[_rng.randi_range(0, cells.size() - 1)]
