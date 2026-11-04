# res://scripts/ui/inventory_panel.gd
# Scopo: pannello dello zaino. A sinistra il manichino con i nove slot indossabili, a destra
#        la griglia 10x6 da 44 px e la cintura. Drag & drop senza rotazione, con controllo
#        della categoria: un oggetto rifiutato torna esattamente da dove e' partito.
#        Nessuna scena: si costruisce in _ready() come tutto il resto.
# Dipendenze: scripts/items/{inventory,equipment,item}.gd, scripts/ui/tooltip.gd
class_name InventoryPanel
extends CanvasLayer

const CELLA: float = 44.0
const PANNELLO: Vector2 = Vector2(712.0, 424.0)
const ORIGINE_GRIGLIA: Vector2 = Vector2(240.0, 56.0)
const ORIGINE_CINTURA: Vector2 = Vector2(240.0, 356.0)
const PASSO_CINTURA: float = 52.0
const LATO_SLOT: float = 58.0

# Posizione dei nove slot del manichino, nello stesso ordine di Equipment.Slot.
# Sono coordinate locali del pannello: tenerle in una tabella evita nove calcoli sparsi
# nel disegno e altri nove, inevitabilmente diversi, nel codice del mouse.
const POSTI_SLOT: Array[Vector2] = [
	Vector2(16.0, 142.0),   # ARMA
	Vector2(150.0, 142.0),  # SCUDO
	Vector2(83.0, 74.0),    # ELMO
	Vector2(83.0, 142.0),   # CORAZZA
	Vector2(16.0, 210.0),   # GUANTI
	Vector2(83.0, 278.0),   # STIVALI
	Vector2(16.0, 278.0),   # ANELLO_SX
	Vector2(150.0, 278.0),  # ANELLO_DX
	Vector2(150.0, 74.0),   # AMULETO
]

var inventory: Inventory
var equipment: Equipment
var giocatore: Player
var aperto: bool = false
var oro: int = 0

var _blocco: ColorRect
var _superficie: Control
var _tooltip: Tooltip

# Stato del trascinamento. L'oggetto NON viene tolto dal contenitore mentre lo trascini:
# si sposta solo al rilascio riuscito. Cosi' chiudere il pannello a meta' trascinamento,
# o rilasciare fuori, non puo' far sparire niente.
var _drag: Item = null
var _drag_pos: Vector2i = Vector2i.ZERO
var _drag_cintura: int = -1
var _drag_slot: int = -1

# La superficie e' una Control interna perche' CanvasLayer non e' un CanvasItem: non puo'
# disegnare ne' ricevere il mouse.
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

# Collega il pannello a un giocatore: dopo una morte il giocatore e' un nodo nuovo, ma
# zaino ed equipaggiamento sono gli stessi oggetti di prima.
func collega(p: Player) -> void:
	giocatore = p
	inventory = p.inventory if p != null else null
	equipment = p.equipment if p != null else null
	oro = p.gold if p != null else 0

func apri() -> void:
	if inventory == null:
		return
	aperto = true
	visible = true
	_centra()
	_superficie.queue_redraw()

func chiudi() -> void:
	# Chiudere mentre trascini non e' un caso raro: annulla il trascinamento e rimette
	# l'oggetto dov'era. Siccome non era mai stato tolto, basta azzerare lo stato.
	annulla_trascinamento()
	aperto = false
	visible = false
	_tooltip.nascondi()

func alterna() -> void:
	if aperto:
		chiudi()
	else:
		apri()

func _centra() -> void:
	var schermo := get_viewport().get_visible_rect().size
	_superficie.position = ((schermo - PANNELLO) * 0.5).floor()

func _process(_delta: float) -> void:
	if not aperto or inventory == null:
		return
	if giocatore != null:
		oro = giocatore.gold
	_centra()
	_superficie.queue_redraw()

	var punto := _superficie.get_local_mouse_position()
	if _drag != null or not _zona_pannello(punto):
		_tooltip.nascondi()
		return
	var item := oggetto_in(punto)
	if item == null:
		_tooltip.nascondi()
	else:
		_tooltip.mostra(item, _superficie.position + punto + Vector2(18.0, 18.0))

# Il rilascio va intercettato anche qui: se il cursore esce dal pannello mentre trascini,
# la Control non riceve piu' il rilascio e l'oggetto resterebbe appeso al mouse.
func _input(event: InputEvent) -> void:
	if not aperto or _drag == null:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and not mouse.pressed:
			rilascia(_superficie.get_local_mouse_position())

# --- Input ---

func input_superficie(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	var punto := _superficie.get_local_mouse_position()
	if mouse.pressed:
		prendi(oggetto_in(punto))
	else:
		rilascia(punto)

# Prende in mano un oggetto. Pubblica perche' la prova headless deve poter trascinare
# senza un mouse vero: la catena provata e' la stessa del gioco.
func prendi(item: Item) -> void:
	if item == null:
		return
	_drag = item
	_drag_pos = item.pos
	_drag_cintura = item.cintura
	_drag_slot = equipment.slot_di(item) if equipment != null else -1

func trascinato() -> Item:
	return _drag

func annulla_trascinamento() -> void:
	if _drag == null:
		return
	_ripristina(_drag)
	_drag = null

# Rilascia nel punto indicato (coordinate locali del pannello). Restituisce true se
# l'oggetto ha cambiato posto davvero.
func rilascia(punto: Vector2) -> bool:
	if _drag == null:
		return false
	var item := _drag
	_drag = null

	var slot := slot_manichino(punto)
	if slot >= 0:
		if _posa_in_equip(item, slot):
			_cambiato()
			return true
		_ripristina(item)
		return false

	var cintura := slot_cintura(punto)
	if cintura >= 0:
		if _posa_in_cintura(item, cintura):
			_cambiato()
			return true
		_ripristina(item)
		return false

	if zona_griglia(punto):
		var cella := Vector2i(((punto - ORIGINE_GRIGLIA) / CELLA).floor())
		if _posa_in_griglia(item, cella):
			_cambiato()
			return true

	# Rilascio fuori dalle zone utili, o posizione occupata, o categoria sbagliata:
	# l'oggetto torna esattamente da dove e' partito. Non si perde mai niente.
	_ripristina(item)
	return false

func _ripristina(item: Item) -> void:
	if _drag_slot >= 0:
		# Lo slot non e' mai stato svuotato durante il trascinamento: non serve altro.
		return
	item.pos = _drag_pos
	item.cintura = _drag_cintura

func _cambiato() -> void:
	EventBus.inventory_changed.emit()
	EventBus.equipment_changed.emit()

# --- Spostamenti, ognuno reversibile se fallisce a meta' ---

func _posa_in_equip(item: Item, slot: int) -> bool:
	if equipment == null or not equipment.accetta(slot, item):
		return false
	if equipment.oggetto(slot) == item:
		return true

	if _drag_slot >= 0:
		# Da uno slot a un altro: lo scambio vale solo se anche il pezzo spostato entra
		# nello slot di partenza, altrimenti deve esserci posto nello zaino.
		equipment.togli(_drag_slot)
		var spostato := equipment.equipaggia(slot, item)
		if spostato != null:
			if equipment.accetta(_drag_slot, spostato):
				equipment.equipaggia(_drag_slot, spostato)
			elif not inventory.aggiungi(spostato):
				equipment.equipaggia(slot, spostato)
				equipment.equipaggia(_drag_slot, item)
				return false
		return true

	inventory.rimuovi(item)
	var scambiato := equipment.equipaggia(slot, item)
	if scambiato != null:
		var sistemato := inventory.aggiungi_a(scambiato, _drag_pos)
		if not sistemato:
			sistemato = inventory.aggiungi(scambiato)
		if not sistemato:
			# Zaino pieno: niente scambio, si rimette tutto com'era.
			equipment.equipaggia(slot, scambiato)
			inventory.aggiungi_a(item, _drag_pos)
			return false
	return true

func _posa_in_griglia(item: Item, cella: Vector2i) -> bool:
	if _drag_slot >= 0:
		equipment.togli(_drag_slot)
		if inventory.aggiungi_a(item, cella):
			return true
		equipment.equipaggia(_drag_slot, item)
		return false
	return inventory.muovi(item, cella)

func _posa_in_cintura(item: Item, slot: int) -> bool:
	if _drag_slot >= 0:
		equipment.togli(_drag_slot)
		if inventory.metti_in_cintura(item, slot):
			return true
		equipment.equipaggia(_drag_slot, item)
		return false
	return inventory.metti_in_cintura(item, slot)

# --- Zone ---

func _zona_pannello(p: Vector2) -> bool:
	return Rect2(Vector2.ZERO, PANNELLO).has_point(p)

func zona_griglia(p: Vector2) -> bool:
	return Rect2(
		ORIGINE_GRIGLIA,
		Vector2(float(Inventory.COLONNE) * CELLA, float(Inventory.RIGHE) * CELLA)
	).has_point(p)

func slot_cintura(p: Vector2) -> int:
	for i in Inventory.SLOT_CINTURA:
		if Rect2(ORIGINE_CINTURA + Vector2(float(i) * PASSO_CINTURA, 0.0), Vector2(CELLA, CELLA)).has_point(p):
			return i
	return -1

func slot_manichino(p: Vector2) -> int:
	for i in POSTI_SLOT.size():
		if Rect2(POSTI_SLOT[i], Vector2(LATO_SLOT, LATO_SLOT)).has_point(p):
			return i
	return -1

func oggetto_in(p: Vector2) -> Item:
	var slot := slot_manichino(p)
	if slot >= 0:
		return equipment.oggetto(slot) if equipment != null else null
	var cintura := slot_cintura(p)
	if cintura >= 0:
		return inventory.oggetto_in_cintura(cintura)
	if not zona_griglia(p):
		return null
	return inventory.oggetto_a(Vector2i(((p - ORIGINE_GRIGLIA) / CELLA).floor()))

# Centro di una zona, in coordinate locali: lo usano i test per rilasciare "dentro" una
# cella senza ricalcolare la geometria del pannello.
func punto_cella(cella: Vector2i) -> Vector2:
	return ORIGINE_GRIGLIA + (Vector2(cella) + Vector2(0.5, 0.5)) * CELLA

func punto_slot(slot: int) -> Vector2:
	return POSTI_SLOT[slot] + Vector2(LATO_SLOT, LATO_SLOT) * 0.5

func punto_cintura(slot: int) -> Vector2:
	return ORIGINE_CINTURA + Vector2(float(slot) * PASSO_CINTURA + CELLA * 0.5, CELLA * 0.5)

# --- Disegno ---

func disegna(ci: Control) -> void:
	var font := ThemeDB.fallback_font
	ci.draw_rect(Rect2(Vector2.ZERO, PANNELLO), Color(0.05, 0.05, 0.06, 0.98))
	ci.draw_rect(Rect2(Vector2.ZERO, PANNELLO), Color(0.38, 0.32, 0.22), false, 2.0)

	ci.draw_string(font, Vector2(16.0, 34.0), "EQUIPAGGIAMENTO", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.88, 0.80, 0.60))
	ci.draw_string(font, Vector2(ORIGINE_GRIGLIA.x, 34.0), "ZAINO", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.88, 0.80, 0.60))
	ci.draw_string(
		font,
		Vector2(ORIGINE_GRIGLIA.x + 90.0, 34.0),
		"%d oggetti, %d oro" % [inventory.quantita(), oro],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.60, 0.60, 0.60)
	)
	ci.draw_line(Vector2(224.0, 48.0), Vector2(224.0, PANNELLO.y - 16.0), Color(0.20, 0.18, 0.16), 1.0)

	_disegna_manichino(ci)
	_disegna_griglia(ci)

	for item in inventory.oggetti:
		if item == _drag:
			continue
		_disegna_oggetto(ci, item, rect_oggetto(item))
	if equipment != null:
		for i in equipment.numero_slot():
			var indossato := equipment.oggetto(i)
			if indossato != null and indossato != _drag:
				_disegna_oggetto(ci, indossato, Rect2(POSTI_SLOT[i], Vector2(LATO_SLOT, LATO_SLOT)))

	ci.draw_string(
		font,
		Vector2(ORIGINE_GRIGLIA.x, PANNELLO.y - 12.0),
		"Trascina per spostare, equipaggiare o togliere. I o ESC per chiudere.",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.50, 0.50, 0.50)
	)

	if _drag != null:
		var mouse := _superficie.get_local_mouse_position()
		var dimensione := Vector2(_drag.size()) * CELLA
		_disegna_oggetto(ci, _drag, Rect2(mouse - dimensione * 0.5, dimensione))

func _disegna_manichino(ci: Control) -> void:
	var font := ThemeDB.fallback_font
	for i in POSTI_SLOT.size():
		var rect := Rect2(POSTI_SLOT[i], Vector2(LATO_SLOT, LATO_SLOT))
		ci.draw_rect(rect.grow(-1.0), Color(0.075, 0.075, 0.09))
		ci.draw_rect(rect, Color(0.22, 0.20, 0.18), false, 1.0)
		if equipment != null and equipment.oggetto(i) == null:
			var etichetta := Equipment.NOMI[i]
			var larghezza := font.get_string_size(etichetta, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
			ci.draw_string(
				font,
				rect.position + Vector2((LATO_SLOT - larghezza) * 0.5, LATO_SLOT * 0.5 + 3.0),
				etichetta,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.40, 0.40, 0.42)
			)

	# Riassunto: e' il motivo per cui si apre il pannello in mezzo a un combattimento.
	var danno := giocatore.danno_fendente() if giocatore != null else (equipment.danno() if equipment != null else 0)
	var difesa := equipment.difesa() if equipment != null else 0
	var riduzione := 0.0
	if difesa > 0:
		riduzione = minf(Entity.RIDUZIONE_MASSIMA, float(difesa) / (float(difesa) + Entity.COSTANTE_DIFESA))
	ci.draw_string(font, Vector2(16.0, 356.0), "Danno fendente: %d" % danno, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.86, 0.74, 0.50))
	ci.draw_string(
		font,
		Vector2(16.0, 374.0),
		"Difesa: %d  (danno fisico -%d%%)" % [difesa, int(round(riduzione * 100.0))],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.70, 0.78, 0.88)
	)
	if giocatore != null:
		ci.draw_string(
			font,
			Vector2(16.0, 392.0),
			"Vita: %d/%d   Velocita': %d" % [giocatore.hp, giocatore.max_hp, int(round(giocatore.velocita()))],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.72, 0.72, 0.70)
		)

func _disegna_griglia(ci: Control) -> void:
	var font := ThemeDB.fallback_font
	for y in Inventory.RIGHE:
		for x in Inventory.COLONNE:
			var rect := Rect2(ORIGINE_GRIGLIA + Vector2(float(x), float(y)) * CELLA, Vector2(CELLA, CELLA))
			var fondo := Color(0.085, 0.085, 0.10) if (x + y) % 2 == 0 else Color(0.070, 0.070, 0.085)
			ci.draw_rect(rect.grow(-1.0), fondo)
			ci.draw_rect(rect, Color(0.18, 0.17, 0.20), false, 1.0)

	ci.draw_string(font, Vector2(ORIGINE_CINTURA.x, 346.0), "CINTURA (solo 1x1)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.60, 0.60, 0.60))
	for i in Inventory.SLOT_CINTURA:
		var rect := Rect2(ORIGINE_CINTURA + Vector2(float(i) * PASSO_CINTURA, 0.0), Vector2(CELLA, CELLA))
		ci.draw_rect(rect.grow(-1.0), Color(0.075, 0.075, 0.09))
		ci.draw_rect(rect, Color(0.18, 0.17, 0.20), false, 1.0)

func rect_oggetto(item: Item) -> Rect2:
	if equipment != null:
		var slot := equipment.slot_di(item)
		if slot >= 0:
			return Rect2(POSTI_SLOT[slot], Vector2(LATO_SLOT, LATO_SLOT))
	if item.cintura >= 0:
		return Rect2(ORIGINE_CINTURA + Vector2(float(item.cintura) * PASSO_CINTURA, 0.0), Vector2(CELLA, CELLA))
	return Rect2(ORIGINE_GRIGLIA + Vector2(item.pos) * CELLA, Vector2(item.size()) * CELLA)

func _disegna_oggetto(ci: Control, item: Item, rect: Rect2) -> void:
	var colore := item.colore()
	var interno := rect.grow(-2.0)
	ci.draw_rect(interno, Color(colore.r, colore.g, colore.b, 0.16))
	ci.draw_rect(interno, colore, false, 2.0)
	_disegna_icona(ci, item, interno)

	# Il nome si scrive solo quando c'e' spazio: su una cella da 44 px qualunque parola
	# verrebbe tagliata, e l'icona basta a riconoscere la categoria.
	if rect.size.x >= CELLA * 2.0 - 4.0:
		var font := ThemeDB.fallback_font
		var testo: String = item.base.nome.split(" ")[0]
		var larghezza := font.get_string_size(testo, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		ci.draw_string(
			font,
			rect.position + Vector2((rect.size.x - larghezza) * 0.5, rect.size.y - 9.0),
			testo,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.90, 0.90, 0.88)
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
