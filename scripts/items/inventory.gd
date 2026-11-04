# res://scripts/items/inventory.gd
# Scopo: griglia 10x6 senza rotazione piu' cintura a 4 slot da 1x1. Tiene solo dati e
#        regole di occupazione: niente nodi, niente disegno, quindi si prova in headless.
# Dipendenze: item.gd
class_name Inventory
extends RefCounted

const COLONNE: int = 10
const RIGHE: int = 6
const CELLA: int = 44
const SLOT_CINTURA: int = 4

var oggetti: Array[Item] = []

func to_dict() -> Dictionary:
	var lista: Array = []
	for item in oggetti:
		lista.append(item.to_dict())
	return {"oggetti": lista}

# Ricostruisce la griglia rispettando le posizioni salvate. Se una posizione non e' piu'
# valida (succede solo se cambiano le misure della griglia) l'oggetto viene sistemato nel
# primo posto libero: non si butta via niente per un dettaglio di impaginazione.
static func from_dict(dati: Dictionary) -> Inventory:
	var inv := Inventory.new()
	for voce in dati.get("oggetti", []):
		var item := Item.from_dict(voce)
		if item == null:
			continue
		if item.cintura >= 0:
			var slot := item.cintura
			item.cintura = -1
			if inv.metti_in_cintura(item, slot):
				continue
		if not inv.aggiungi_a(item, item.pos):
			inv.aggiungi(item)
	return inv

func rect_of(item: Item) -> Rect2i:
	return Rect2i(item.pos, item.size())

func dentro(rect: Rect2i) -> bool:
	return (
		rect.position.x >= 0
		and rect.position.y >= 0
		and rect.end.x <= COLONNE
		and rect.end.y <= RIGHE
	)

# `ignora` serve al drag & drop: l'oggetto che stai trascinando non deve ostacolare se
# stesso. Gli oggetti in cintura non occupano celle dello zaino.
func occupata(rect: Rect2i, ignora: Item = null) -> bool:
	for altro in oggetti:
		if altro == ignora or altro.cintura >= 0:
			continue
		if rect.intersects(Rect2i(altro.pos, altro.size())):
			return true
	return false

# Primo posto libero, scorrendo dall'alto a sinistra: e' anche l'ordine in cui il giocatore
# si aspetta di vedere riempito lo zaino.
func posto_libero(item: Item) -> Vector2i:
	for y in RIGHE - item.size().y + 1:
		for x in COLONNE - item.size().x + 1:
			if not occupata(Rect2i(x, y, item.size().x, item.size().y), item):
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func aggiungi(item: Item) -> bool:
	if item == null:
		return false
	var posto := posto_libero(item)
	if posto.x < 0:
		return false
	return aggiungi_a(item, posto)

func aggiungi_a(item: Item, posizione: Vector2i) -> bool:
	if item == null:
		return false
	var rect := Rect2i(posizione, item.size())
	if not dentro(rect) or occupata(rect, item):
		return false
	item.pos = posizione
	item.cintura = -1
	if not oggetti.has(item):
		oggetti.append(item)
	return true

func muovi(item: Item, posizione: Vector2i) -> bool:
	if item == null or not oggetti.has(item):
		return false
	var rect := Rect2i(posizione, item.size())
	if not dentro(rect) or occupata(rect, item):
		return false
	item.pos = posizione
	item.cintura = -1
	return true

func metti_in_cintura(item: Item, slot: int) -> bool:
	if item == null or slot < 0 or slot >= SLOT_CINTURA:
		return false
	# La cintura accetta solo 1x1: e' il vincolo che rende scomodo portarsi dietro uno
	# spadone, ed e' voluto.
	if item.size() != Vector2i(1, 1):
		return false
	for altro in oggetti:
		if altro != item and altro.cintura == slot:
			return false
	item.cintura = slot
	if not oggetti.has(item):
		oggetti.append(item)
	return true

func rimuovi(item: Item) -> void:
	oggetti.erase(item)
	item.cintura = -1

func oggetto_a(posizione: Vector2i) -> Item:
	for item in oggetti:
		if item.cintura >= 0:
			continue
		if Rect2i(item.pos, item.size()).has_point(posizione):
			return item
	return null

func oggetto_in_cintura(slot: int) -> Item:
	for item in oggetti:
		if item.cintura == slot:
			return item
	return null

func quantita() -> int:
	return oggetti.size()

# Vero solo se non c'e' nemmeno una cella libera: la domanda che conta per il raccoglimento
# automatico e' "ci sta un anello?", non "ci sta lo spadone che ho in mano".
func pieno() -> bool:
	for y in RIGHE:
		for x in COLONNE:
			if not occupata(Rect2i(x, y, 1, 1)):
				return false
	return true
