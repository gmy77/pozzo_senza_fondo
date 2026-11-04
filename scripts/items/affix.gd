# res://scripts/items/affix.gd
# Scopo: modificatori casuali di un oggetto (affissi). Ogni affisso e' un tipo e un valore;
#        il nome dell'oggetto prende il nome del primo affisso, cosi' due spade corte non si
#        chiamano mai allo stesso modo.
# Dipendenze: scripts/core/rng.gd
class_name Affix
extends RefCounted

enum Tipo { FORZA, DESTREZZA, VITALITA, VITA, DANNO, DIFESA, VELOCITA, CRITICO }

const ETICHETTE: Array[String] = [
	"Forza",
	"Destrezza",
	"Vitalita'",
	"Vita massima",
	"Danno",
	"Difesa",
	"Velocita' di movimento",
	"Probabilita' critica",
]

const NOMI: Array[String] = [
	"del Bue",
	"della Volpe",
	"del Gigante",
	"del Cuore",
	"della Lama",
	"della Roccia",
	"del Vento",
	"del Falco",
]

# Valore di partenza a livello 1, prima della scala e della variazione casuale.
const BASE: Array[int] = [1, 1, 1, 8, 1, 1, 4, 1]

var tipo: Tipo = Tipo.FORZA
var valore: int = 1

func etichetta() -> String:
	return ETICHETTE[int(tipo)]

func nome() -> String:
	return NOMI[int(tipo)]

# Genera un affisso mai usato prima su questo oggetto: due "+Forza" sullo stesso pezzo
# sarebbero leciti ma illeggibili, e non aggiungono niente alla scelta.
static func genera(rng: Rng, livello: int, usati: Array[int]) -> Affix:
	var disponibili: Array[int] = []
	for i in ETICHETTE.size():
		if not usati.has(i):
			disponibili.append(i)
	var scelto: int = rng.pick(disponibili)
	usati.append(scelto)

	var affisso := Affix.new()
	affisso.tipo = scelto as Tipo
	var scala := 1.0 + 0.30 * float(maxi(1, livello) - 1)
	affisso.valore = maxi(1, int(round(float(BASE[scelto]) * scala + rng.randf_range(0.0, 1.0))))
	return affisso
