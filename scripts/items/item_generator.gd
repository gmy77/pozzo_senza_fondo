# res://scripts/items/item_generator.gd
# Scopo: produce il bottino casuale. Rarita', numero di affissi e valori dipendono dal
#        livello; tutto passa dall'Rng di gioco, quindi lo stesso seed da lo stesso bottino.
# Dipendenze: item.gd, item_base.gd, affix.gd, rng.gd
class_name ItemGenerator
extends RefCounted

# Probabilita' di partenza a livello 1. La fortuna (bottino dei boss, anello, quest)
# sposta i due confini verso l'alto; non inventa rarita' che non esistono.
const SOGLIA_MAGICO: float = 0.42
const SOGLIA_RARO: float = 0.10
const BONUS_FORTUNA_MAGICO: float = 0.15
const BONUS_FORTUNA_RARO: float = 0.10

static func roll(rng: Rng, livello: int, fortuna: float = 0.0) -> Item:
	var liv := maxi(1, livello)
	var basi := ItemBase.tutte()
	var base: ItemBase = rng.pick(basi)
	var item := Item.new(base)
	item.livello = liv

	# Un solo randf per la rarita': cosi' il consumo di numeri casuali e' prevedibile e
	# il seed resta riproducibile anche se domani cambiano le soglie.
	var r := rng.randf()
	var soglia_raro := SOGLIA_RARO + fortuna * BONUS_FORTUNA_RARO
	var soglia_magico := SOGLIA_MAGICO + fortuna * BONUS_FORTUNA_MAGICO
	if r < soglia_raro:
		item.rarita = Item.Rarita.RARO
	elif r < soglia_magico:
		item.rarita = Item.Rarita.MAGICO
	else:
		item.rarita = Item.Rarita.NORMALE

	var quanti := 0
	match item.rarita:
		Item.Rarita.MAGICO:
			quanti = 1 + rng.randi_range(0, 1)
		Item.Rarita.RARO:
			quanti = 2 + rng.randi_range(0, 1)
		_:
			quanti = 0

	var usati: Array[int] = []
	for i in quanti:
		item.affissi.append(Affix.genera(rng, liv, usati))
	return item

# Bottino garantito di una certa categoria: lo useranno le quest ("il martello perduto")
# e i boss. Non e' un caso speciale del generatore, e' lo stesso generatore con la forma
# scelta a monte.
static func roll_di_categoria(rng: Rng, livello: int, categoria: ItemBase.Categoria, fortuna: float = 0.0) -> Item:
	var candidate := ItemBase.per_categoria(categoria)
	var scelta: ItemBase = rng.pick(candidate)
	var item := roll(rng, livello, fortuna)
	item.base = scelta
	return item
