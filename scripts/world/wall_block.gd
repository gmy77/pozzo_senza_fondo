# res://scripts/world/wall_block.gd
# Scopo: un pezzo di muro grande una cella. L'origine sta sul bordo inferiore della cella:
#        cosi' l'ordinamento y-sort lo mette davanti a chi gli sta sotto e dietro a chi gli
#        sta sopra. Un pezzo per cella (non un blocco unico) e' obbligatorio sui muri
#        verticali lunghi, altrimenti il giocatore che ci cammina accanto finirebbe dietro
#        al muro per tutta la sua lunghezza.
#        La faccia e' alta 64 px e la cappa 24: in tutto 88 px sopra l'origine. Un muro
#        piatto (alto quanto la cella) non coprirebbe nessuno, e l'y-sort sarebbe corretto
#        ma invisibile.
# Dipendenze: scripts/core/constants.gd
class_name WallBlock
extends Node2D

# Altezza della faccia misurata dall'origine (bordo inferiore della cella) verso l'alto.
# Deve superare la distanza a cui il giocatore puo' arrivare (cella + raggio del corpo)
# piu' la sua altezza, altrimenti la testa resta scoperta.
const ALTEZZA_FACCIA: float = 68.0
const ALTEZZA_CAPPA: float = 24.0
const ALTEZZA_TOTALE: float = ALTEZZA_FACCIA + ALTEZZA_CAPPA

var has_wall_above: bool = false
var shade: float = 0.0

func _ready() -> void:
	add_to_group("wall_block")

# Rettangolo occupato dal disegno, in coordinate locali. Serve a chi decide se il muro
# sta coprendo il giocatore.
func drawn_rect() -> Rect2:
	var width := float(GameConsts.CELL)
	return Rect2(-width * 0.5, -ALTEZZA_TOTALE, width, ALTEZZA_TOTALE)

func _draw() -> void:
	var width := float(GameConsts.CELL)
	var half := width * 0.5

	var front := Color(
		GameConsts.COL_MURO_FRONTE.r + shade,
		GameConsts.COL_MURO_FRONTE.g + shade,
		GameConsts.COL_MURO_FRONTE.b + shade
	)
	var coping := Color(
		GameConsts.COL_MURO_COPING.r + shade,
		GameConsts.COL_MURO_COPING.g + shade,
		GameConsts.COL_MURO_COPING.b + shade
	)

	# Faccia: dalla base fino a 64 px sopra l'origine. Copre la cella e due celle sopra,
	# che e' esattamente lo spazio in cui cammina chi passa dietro al muro.
	draw_rect(Rect2(-half, -ALTEZZA_FACCIA, width, ALTEZZA_FACCIA), front)

	# Corsi di pietra: righe ogni 16 px, sfalsate di 8 px per cella, altrimenti tutti i muri
	# hanno le stesse fughe e il piano sembra una griglia.
	var offset := 8.0 if int(global_position.x / float(GameConsts.CELL)) % 2 == 0 else 0.0
	var y := -8.0
	while y > -ALTEZZA_FACCIA:
		draw_line(Vector2(-half, y), Vector2(half, y), Color(0.0, 0.0, 0.0, 0.28), 1.0)
		var x := -half + offset
		while x < half:
			draw_line(Vector2(x, y), Vector2(x, y - 8.0), Color(0.0, 0.0, 0.0, 0.22), 1.0)
			x += 16.0
		y -= 16.0
		offset = 16.0 - offset

	draw_rect(Rect2(-half, -ALTEZZA_FACCIA, width, ALTEZZA_FACCIA), Color(0.0, 0.0, 0.0, 0.55), false, 1.0)

	# Sfumatura: piu' scuro verso l'alto, come se la luce arrivasse dal basso della stanza.
	draw_rect(Rect2(-half, -ALTEZZA_FACCIA, width, ALTEZZA_FACCIA * 0.45), Color(0.0, 0.0, 0.0, 0.22))

	# Ombra di contatto sul pavimento.
	draw_rect(Rect2(-half, 0.0, width, 7.0), Color(0.0, 0.0, 0.0, 0.38))

	# Cappa: solo sul pezzo piu' in alto di ogni colonna, altrimenti si vedrebbero tante
	# fasce orizzontali una sopra l'altra.
	if not has_wall_above:
		var cap := Rect2(-half, -ALTEZZA_TOTALE, width, ALTEZZA_CAPPA)
		draw_rect(cap, coping)
		draw_rect(cap, Color(0.0, 0.0, 0.0, 0.45), false, 1.0)
		draw_line(
			Vector2(-half, -ALTEZZA_TOTALE + 3.0),
			Vector2(half, -ALTEZZA_TOTALE + 3.0),
			Color(1.0, 1.0, 1.0, 0.12),
			1.5
		)
		# Bordo inferiore della cappa: stacco netto tra superficie superiore e faccia.
		draw_line(
			Vector2(-half, -ALTEZZA_FACCIA),
			Vector2(half, -ALTEZZA_FACCIA),
			Color(0.0, 0.0, 0.0, 0.55),
			2.0
		)
