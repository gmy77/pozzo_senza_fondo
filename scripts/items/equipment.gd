# res://scripts/items/equipment.gd
# Scopo: gli slot indossati. Ogni slot accetta una sola categoria (due per gli anelli, che
#        sono slot distinti della stessa categoria): il controllo sta qui e non nella UI,
#        altrimenti la stessa regola finirebbe scritta due volte e in due modi diversi.
# Dipendenze: item.gd, item_base.gd, affix.gd
class_name Equipment
extends RefCounted

enum Slot { ARMA, SCUDO, ELMO, CORAZZA, GUANTI, STIVALI, ANELLO_SX, ANELLO_DX, AMULETO }

const NOMI: Array[String] = [
	"Arma",
	"Scudo",
	"Elmo",
	"Corazza",
	"Guanti",
	"Stivali",
	"Anello sx",
	"Anello dx",
	"Amuleto",
]

# Categoria ammessa per ogni slot, nello stesso ordine dell'enum.
const CATEGORIE: Array[int] = [
	ItemBase.Categoria.ARMA,
	ItemBase.Categoria.SCUDO,
	ItemBase.Categoria.ELMO,
	ItemBase.Categoria.CORAZZA,
	ItemBase.Categoria.GUANTI,
	ItemBase.Categoria.STIVALI,
	ItemBase.Categoria.ANELLO,
	ItemBase.Categoria.ANELLO,
	ItemBase.Categoria.AMULETO,
]

var _slot: Array[Item] = [null, null, null, null, null, null, null, null, null]

func numero_slot() -> int:
	return _slot.size()

func nome_slot(slot: int) -> String:
	return NOMI[slot] if slot >= 0 and slot < NOMI.size() else ""

# Unica regola di ammissione: la categoria. Niente requisiti di forza o livello in fase 3,
# arrivano con il borgo (fase 5) quando ci sara' anche come leggerli a schermo.
func accetta(slot: int, item: Item) -> bool:
	if item == null or slot < 0 or slot >= _slot.size():
		return false
	return int(item.base.categoria) == CATEGORIE[slot]

func oggetto(slot: int) -> Item:
	if slot < 0 or slot >= _slot.size():
		return null
	return _slot[slot]

# Mette l'oggetto nello slot e restituisce quello che c'era prima (null se era vuoto).
# Chi chiama deve occuparsi di dove far finire lo spostato: qui non si butta via niente.
func equipaggia(slot: int, item: Item) -> Item:
	if not accetta(slot, item):
		return null
	var precedente := _slot[slot]
	_slot[slot] = item
	if item != null:
		item.cintura = -1
	return precedente

func togli(slot: int) -> Item:
	if slot < 0 or slot >= _slot.size():
		return null
	var precedente := _slot[slot]
	_slot[slot] = null
	return precedente

func slot_di(item: Item) -> int:
	for i in _slot.size():
		if _slot[i] == item:
			return i
	return -1

# Primo slot libero che accetta l'oggetto: serve all'equipaggiamento rapido e ai test.
func slot_adatto(item: Item) -> int:
	var occupato := -1
	for i in _slot.size():
		if not accetta(i, item):
			continue
		if _slot[i] == null:
			return i
		if occupato < 0:
			occupato = i
	return occupato

func tutti() -> Array[Item]:
	var out: Array[Item] = []
	for item in _slot:
		if item != null:
			out.append(item)
	return out

func quantita() -> int:
	return tutti().size()

func danno() -> int:
	var totale := 0
	for item in tutti():
		totale += item.danno()
	return totale

func difesa() -> int:
	var totale := 0
	for item in tutti():
		totale += item.difesa()
	return totale

func bonus(tipo: Affix.Tipo) -> int:
	var totale := 0
	for item in tutti():
		totale += item.bonus(tipo)
	return totale
