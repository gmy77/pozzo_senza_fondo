# res://scripts/ui/inventory_panel.gd
# Scopo: pannello dello zaino. Griglia 10x6 da 44 px, cintura a 4 slot, drag & drop senza
#        rotazione, tooltip sull'oggetto sotto il cursore. Nessuna scena: si costruisce in
#        _ready() come tutto il resto.
# Dipendenze: scripts/items/inventory.gd, item.gd, scripts/ui/tooltip.gd
class_name InventoryPanel
extends CanvasLayer

const CELLA: float = 44.0
const PANNELLO: Vector2 = Vector2(488.0, 420.0)
const ORIGINE_GRIGLIA: Vector2 = Vector2(24.0, 56.0)
const ORIGINE_CINTURA: Vector2 = Vector2(24.0, 356.0)
const PASSO_CINTURA: float = 52.0

var inventory: Inventory
var aperto: bool = false
var oro: int = 0

var _blocco: ColorRect
var _superficie: Control
var _tooltip: Tooltip
var _drag: Item = null
var _drag_origin: Vector2i = Vector2i.ZERO
var _drag_belt: int = -1

# La superficie e' una Control interna perche' CanvasLayer non e' un CanvasItem: non puo'
# disegnare. Tiene il riferimento al pannello per disegnare e ricevere il mouse.
class Superficie extends Control:
	var pannello: InventoryPanel

	func _draw() -> void:
		if pannello != null:
			pannello.disegna(self)

	func _gui_input(event: InputEvent) -> void:
		if pannello != null:
			pannello.input_superficie(event)

func _ready() -> void:
	layer = 20
	visible = false

	_blocco = ColorRect.new()
	_blocco.color = Color(0.0, 0.0, 0.0, 0.55)
	_blocco.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blocco.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_blocco)

	_superficie = Superficie.new()
	_superficie.pannello = self
	_superficie.size = PANNELLO
	_superficie.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_superficie)

	_tooltip = Tooltip.new()
	add_child(_tooltip)

func apri(inv: Inventory) -> void:
	inventory = inv
	aperto = true
	visible = true
	_drag = null
	_centra()
	_superficie.queue_redraw()

func chiudi() -> void:
	aperto = false
	visible = false
	_drag = null
	_tooltip.nascondi()

func alterna(inv: Inventory) -> void:
	if aperto:
		chiudi()
	else:
		apri(inv)

func _centra() -> void:
	var schermo := get_viewport().get_visible_rect().size
	_superficie.position = ((schermo - PANNELLO) * 0.5).floor()

func _process(_delta: float) -> void:
	if not aperto or inventory == null:
		return
	_centra()
	_superficie.queue_redraw()

	var punto := _superficie.get_local_mouse_position()
	if _drag != null or not _zona_pannello(punto):
		_tooltip.nascondi()
		return
	var item := _oggetto_in(punto)
	if item == null:
		_tooltip.nascondi()
	else:
		_tooltip.mostra(item, _superficie.position + punto + Vector2(18.0, 18.0))

# Il rilascio va gestito anche qui: se il cursore esce dal pannello mentre trascini, il
# Control non riceve piu' il rilascio e l'oggetto resterebbe appeso al mouse per sempre.
func _input(event: InputEvent) -> void:
	if not aperto or _drag == null:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and not mouse.pressed:
			_finisci_trascinamento(_superficie.get_local_mouse_position())

# --- Input della superficie ---

func input_superficie(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	var punto := _superficie.get_local_mouse_position()
	if mouse.pressed:
		var item := _oggetto_in(punto)
		if item != null:
			_drag = item
			_drag_origin = item.pos
			_drag_belt = item.cintura
	else:
		_finisci_trascinamento(punto)

func _finisci_trascinamento(punto: Vector2) -> void:
	if _drag == null:
		return
	var item := _drag
	_drag = null

	var slot := _slot_cintura(punto)
	if slot >= 0 and inventory.metti_in_cintura(item, slot):
		return
	if _zona_griglia(punto):
		var cella := Vector2i(((punto - ORIGINE_GRIGLIA) / CELLA).floor())
		if inventory.muovi(item, cella):
			return
	# Riposizionamento fallito: l'oggetto torna esattamente da dove e' partito. Non si
	# perde mai un oggetto per un drop sbagliato.
	item.pos = _drag_origin
	item.cintura = _drag_belt

# --- Zone ---

func _zona_pannello(p: Vector2) -> bool:
	return Rect2(Vector2.ZERO, PANNELLO).has_point(p)

func _zona_griglia(p: Vector2) -> bool:
	return Rect2(
		ORIGINE_GRIGLIA,
		Vector2(float(Inventory.COLONNE) * CELLA, float(Inventory.RIGHE) * CELLA)
	).has_point(p)

func _slot_cintura(p: Vector2) -> int:
	for i in Inventory.SLOT_CINTURA:
		var rect := Rect2(ORIGINE_CINTURA + Vector2(float(i) * PASSO_CINTURA, 0.0), Vector2(CELLA, CELLA))
		if rect.has_point(p):
			return i
	return -1

func _oggetto_in(p: Vector2) -> Item:
	var slot := _slot_cintura(p)
	if slot >= 0:
		return inventory.oggetto_in_cintura(slot)
	if not _zona_griglia(p):
		return null
	var cella := Vector2i(((p - ORIGINE_GRIGLIA) / CELLA).floor())
	return inventory.oggetto_a(cella)

# --- Disegno ---

func disegna(ci: Control) -> void:
	var font := ThemeDB.fallback_font
	ci.draw_rect(Rect2(Vector2.ZERO, PANNELLO), Color(0.05, 0.05, 0.06, 0.98))
	ci.draw_rect(Rect2(Vector2.ZERO, PANNELLO), Color(0.38, 0.32, 0.22), false, 2.0)

	ci.draw_string(font, Vector2(ORIGINE_GRIGLIA.x, 34.0), "ZAINO", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.88, 0.80, 0.60))
	var conteggio := "%d oggetti, %d oro" % [inventory.quantita(), oro]
	ci.draw_string(font, Vector2(300.0, 34.0), conteggio, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.60, 0.60, 0.60))

	for y in Inventory.RIGHE:
		for x in Inventory.COLONNE:
			var rect := Rect2(
				ORIGINE_GRIGLIA + Vector2(float(x), float(y)) * CELLA,
				Vector2(CELLA, CELLA)
			)
			var fondo := Color(0.085, 0.085, 0.10) if (x + y) % 2 == 0 else Color(0.070, 0.070, 0.085)
			ci.draw_rect(rect.grow(-1.0), fondo)
			ci.draw_rect(rect, Color(0.18, 0.17, 0.20), false, 1.0)

	ci.draw_string(font, Vector2(ORIGINE_CINTURA.x, 344.0), "CINTURA (solo 1x1)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.60, 0.60, 0.60))
	for i in Inventory.SLOT_CINTURA:
		var rect := Rect2(ORIGINE_CINTURA + Vector2(float(i) * PASSO_CINTURA, 0.0), Vector2(CELLA, CELLA))
		ci.draw_rect(rect.grow(-1.0), Color(0.075, 0.075, 0.09))
		ci.draw_rect(rect, Color(0.18, 0.17, 0.20), false, 1.0)

	for item in inventory.oggetti:
		if item == _drag:
			continue
		_disegna_oggetto(ci, item, _rect_oggetto(item))

	ci.draw_string(font, Vector2(24.0, 404.0), "Tieni premuto e trascina. I o ESC per chiudere.", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.50, 0.50, 0.50))

	if _drag != null:
		var mouse := _superficie.get_local_mouse_position()
		var rect := Rect2(mouse - Vector2(_drag.size()) * CELLA * 0.5, Vector2(_drag.size()) * CELLA)
		_disegna_oggetto(ci, _drag, rect)

func _rect_oggetto(item: Item) -> Rect2:
	if item.cintura >= 0:
		return Rect2(ORIGINE_CINTURA + Vector2(float(item.cintura) * PASSO_CINTURA, 0.0), Vector2(CELLA, CELLA))
	return Rect2(ORIGINE_GRIGLIA + Vector2(item.pos) * CELLA, Vector2(item.size()) * CELLA)

func _disegna_oggetto(ci: Control, item: Item, rect: Rect2) -> void:
	var colore := item.colore()
	var interno := rect.grow(-2.0)
	ci.draw_rect(interno, Color(colore.r, colore.g, colore.b, 0.16))
	ci.draw_rect(interno, colore, false, 2.0)
	_disegna_icona(ci, item, interno)

	# Il nome si scrive solo quando c'e' spazio per almeno due celle: su una cella da 44 px
	# qualunque parola verrebbe tagliata, e un'icona basta a riconoscere la categoria.
	if rect.size.x >= CELLA * 2.0 - 4.0:
		var font := ThemeDB.fallback_font
		var testo: String = item.base.nome.split(" ")[0]
		var larghezza := font.get_string_size(testo, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		ci.draw_string(
			font,
			rect.position + Vector2((rect.size.x - larghezza) * 0.5, rect.size.y - 9.0),
			testo,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10,
			Color(0.90, 0.90, 0.88)
		)

func _disegna_icona(ci: Control, item: Item, rect: Rect2) -> void:
	var centro := rect.get_center()
	var acciaio := Color(0.72, 0.74, 0.80)
	var scuro := Color(0.34, 0.32, 0.30)
	match item.base.categoria:
		ItemBase.Categoria.ARMA:
			ci.draw_line(centro + Vector2(-9.0, 12.0), centro + Vector2(9.0, -12.0), acciaio, 3.0)
			ci.draw_line(centro + Vector2(-1.0, 5.0), centro + Vector2(5.0, 1.0), scuro, 2.5)
		ItemBase.Categoria.SCUDO:
			var scudo := PackedVector2Array([
				centro + Vector2(-10.0, -11.0),
				centro + Vector2(10.0, -11.0),
				centro + Vector2(10.0, 3.0),
				centro + Vector2(0.0, 13.0),
				centro + Vector2(-10.0, 3.0),
			])
			Art.poly(ci, scudo, Color(0.36, 0.38, 0.42))
			Art.outline(ci, scudo, acciaio, 1.5)
		ItemBase.Categoria.ELMO:
			ci.draw_circle(centro + Vector2(0.0, -2.0), 10.0, Color(0.40, 0.42, 0.46))
			ci.draw_rect(Rect2(centro + Vector2(-10.0, -2.0), Vector2(20.0, 9.0)), Color(0.40, 0.42, 0.46))
			ci.draw_line(centro + Vector2(-10.0, 0.0), centro + Vector2(10.0, 0.0), acciaio, 1.5)
		ItemBase.Categoria.CORAZZA:
			ci.draw_rect(Rect2(centro + Vector2(-10.0, -9.0), Vector2(20.0, 20.0)), Color(0.40, 0.42, 0.46))
			ci.draw_circle(centro + Vector2(-10.0, -9.0), 4.0, Color(0.48, 0.50, 0.55))
			ci.draw_circle(centro + Vector2(10.0, -9.0), 4.0, Color(0.48, 0.50, 0.55))
		ItemBase.Categoria.GUANTI:
			ci.draw_rect(Rect2(centro + Vector2(-11.0, -6.0), Vector2(9.0, 14.0)), scuro)
			ci.draw_rect(Rect2(centro + Vector2(2.0, -6.0), Vector2(9.0, 14.0)), scuro)
			ci.draw_line(centro + Vector2(-11.0, -6.0), centro + Vector2(-11.0, 8.0), acciaio, 1.0)
		ItemBase.Categoria.STIVALI:
			ci.draw_rect(Rect2(centro + Vector2(-11.0, -10.0), Vector2(8.0, 20.0)), Color(0.30, 0.22, 0.16))
			ci.draw_rect(Rect2(centro + Vector2(3.0, -10.0), Vector2(8.0, 20.0)), Color(0.30, 0.22, 0.16))
		ItemBase.Categoria.ANELLO:
			ci.draw_arc(centro, 9.0, 0.0, TAU, 20, Color(0.90, 0.74, 0.30), 2.5)
		ItemBase.Categoria.AMULETO:
			ci.draw_line(centro + Vector2(-8.0, -10.0), centro + Vector2(0.0, -2.0), acciaio, 1.5)
			ci.draw_line(centro + Vector2(8.0, -10.0), centro + Vector2(0.0, -2.0), acciaio, 1.5)
			ci.draw_circle(centro + Vector2(0.0, 3.0), 6.0, Color(0.86, 0.42, 0.34))
