# res://scripts/entities/enemies/skeleton.gd
# Scopo: lo scheletro, primo mostro del gioco. Statistiche, velocita' e disegno; il
#        comportamento (FSM, inseguimento, attacco) sta tutto in Enemy.
# Dipendenze: enemy.gd, stats.gd, art.gd, constants.gd
class_name Skeleton
extends Enemy

const OSSO: Color = Color(0.82, 0.80, 0.72)
const OSSO_SCURO: Color = Color(0.52, 0.50, 0.44)

func _ready() -> void:
	monster_id = "scheletro"
	level = 1
	stats = Stats.new(8, 6, 1, 4)
	setup_vitals()
	# Piu' lento del giocatore (214 px/s) di un buon margine: deve poter essere seminato
	# camminando, altrimenti disimpegnarsi da un combattimento e' impossibile.
	speed = 96.0
	aggro_radius = 240.0
	attack_range = 30.0
	attack_damage = 6
	attack_cooldown = 1.2
	loot_min = 1
	loot_max = 4
	area_id = "cripta"
	super._ready()

func _draw() -> void:
	super._draw()

	var step := sin(walk_phase) * 3.0 if is_moving else 0.0
	var base := Vector2.ZERO

	# gambe
	draw_line(base + Vector2(-3.0, -16.0), base + Vector2(-5.0 + step, -1.0), OSSO, 2.5)
	draw_line(base + Vector2(3.0, -16.0), base + Vector2(5.0 - step, -1.0), OSSO, 2.5)
	draw_circle(base + Vector2(-5.0 + step, -1.0), 2.0, OSSO_SCURO)
	draw_circle(base + Vector2(5.0 - step, -1.0), 2.0, OSSO_SCURO)

	# bacino e colonna
	draw_rect(Rect2(base + Vector2(-6.0, -20.0), Vector2(12.0, 4.0)), OSSO)
	draw_line(base + Vector2(0.0, -20.0), base + Vector2(0.0, -32.0), OSSO, 2.0)

	# costole: archi che si stringono verso l'alto
	var rib := 7.0
	var y := -22.0
	while y > -31.0:
		draw_arc(base + Vector2(0.0, y), rib, PI, TAU, 10, OSSO, 1.6)
		rib -= 1.0
		y -= 3.0

	# braccio sinistro e spada
	draw_line(base + Vector2(-6.0, -29.0), base + Vector2(-11.0, -18.0), OSSO, 2.0)
	var sword_x := 12.0 if facing.x >= 0.0 else -12.0
	draw_line(base + Vector2(6.0, -29.0), base + Vector2(sword_x, -18.0), OSSO, 2.0)
	var blade := PackedVector2Array([
		base + Vector2(sword_x, -20.0),
		base + Vector2(sword_x + 3.0, -18.0),
		base + Vector2(sword_x + 3.0, -3.0),
		base + Vector2(sword_x, -1.0),
	])
	Art.poly(self, blade, Color(0.52, 0.50, 0.46))
	Art.outline(self, blade, Color(0.24, 0.22, 0.20), 1.0)
	draw_rect(Rect2(base + Vector2(sword_x - 3.0, -3.0), Vector2(9.0, 2.0)), Color(0.30, 0.22, 0.12))

	# cranio: due occhiaie vuote, la parte che rende riconoscibile il mostro a colpo d'occhio
	draw_circle(base + Vector2(0.0, -36.0), 7.0, OSSO)
	draw_rect(Rect2(base + Vector2(-4.0, -32.0), Vector2(8.0, 3.0)), OSSO)
	draw_circle(base + Vector2(-2.5, -37.0), 2.0, Color(0.08, 0.08, 0.09))
	draw_circle(base + Vector2(2.5, -37.0), 2.0, Color(0.08, 0.08, 0.09))
	draw_line(base + Vector2(-1.5, -33.0), base + Vector2(1.5, -33.0), OSSO_SCURO, 1.0)
