# res://scripts/ui/tooltip.gd
# Scopo: riquadro con nome, rarita' e proprieta' di un oggetto. Si posiziona accanto al
#        cursore e resta dentro lo schermo; non prende il mouse.
# Dipendenze: scripts/items/item.gd
class_name Tooltip
extends Control

const LARGHEZZA_MINIMA: float = 190.0
const RIGA: float = 16.0

var _titolo: String = ""
var _colore: Color = Color.WHITE
var _righe: PackedStringArray = PackedStringArray()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func mostra(item: Item, punto: Vector2) -> void:
	if item == null:
		nascondi()
		return
	var font := ThemeDB.fallback_font
	_titolo = item.nome()
	_colore = item.colore()
	_righe = item.righe()

	var larghezza := LARGHEZZA_MINIMA
	larghezza = maxf(larghezza, font.get_string_size(_titolo, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 22.0)
	for riga in _righe:
		larghezza = maxf(larghezza, font.get_string_size(riga, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 22.0)
	size = Vector2(larghezza, 30.0 + float(_righe.size()) * RIGA)

	visible = true
	position = punto
	# Non esce dallo schermo: il tooltip di un oggetto sull'ultima colonna verrebbe
	# tagliato proprio quando serve.
	var schermo := get_viewport().get_visible_rect().size
	position.x = clampf(position.x, 4.0, maxf(4.0, schermo.x - size.x - 4.0))
	position.y = clampf(position.y, 4.0, maxf(4.0, schermo.y - size.y - 4.0))
	queue_redraw()

func nascondi() -> void:
	visible = false

func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.03, 0.045, 0.97))
	draw_rect(Rect2(Vector2.ZERO, size), _colore, false, 1.5)
	draw_string(font, Vector2(11.0, 19.0), _titolo, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, _colore)

	var y := 38.0
	for riga in _righe:
		draw_string(font, Vector2(11.0, y), riga, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.86, 0.86, 0.82))
		y += RIGA
