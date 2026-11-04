# res://scripts/items/item.gd
# Scopo: un oggetto concreto: forma base, rarita', livello, affissi e posizione
#        nell'inventario. Non conosce la UI e non conosce il mondo: si puo' creare e
#        misurare in un test senza scena.
# Dipendenze: item_base.gd, affix.gd
class_name Item
extends RefCounted

enum Rarita { NORMALE, MAGICO, RARO, UNICO }

const COLORI: Array[Color] = [
	Color(0.93, 0.93, 0.93),
	Color(0.44, 0.66, 1.00),
	Color(0.96, 0.84, 0.28),
	Color(0.88, 0.54, 0.18),
]

const NOMI_RARITA: Array[String] = ["Normale", "Magico", "Raro", "Unico"]

var base: ItemBase
var rarita: Rarita = Rarita.NORMALE
var livello: int = 1
var affissi: Array[Affix] = []

# Posizione nell'inventario. `pos` vale solo per lo zaino; se `cintura` e' >= 0 l'oggetto
# sta in uno dei quattro slot della cintura e `pos` viene ignorato.
var pos: Vector2i = Vector2i.ZERO
var cintura: int = -1

# Identificatore univoco di sessione: serve a distinguere due oggetti identici nel drag &
# drop e nei test. Non e' un id di salvataggio (quello arriva in fase 7).
var uid: int = 0

static var _prossimo_uid: int = 1

func _init(p_base: ItemBase) -> void:
	base = p_base
	uid = _prossimo_uid
	_prossimo_uid += 1

# Un oggetto caricato da file deve tenersi il suo uid, altrimenti due oggetti diversi
# potrebbero finire con lo stesso numero: il contatore va spinto oltre quelli gia' usati.
static func registra_uid(usato: int) -> void:
	if usato >= _prossimo_uid:
		_prossimo_uid = usato + 1

func to_dict() -> Dictionary:
	var lista: Array = []
	for affisso in affissi:
		lista.append(affisso.to_dict())
	return {
		"base": base.id,
		"rarita": int(rarita),
		"livello": livello,
		"pos_x": pos.x,
		"pos_y": pos.y,
		"cintura": cintura,
		"uid": uid,
		"affissi": lista,
	}

# Restituisce null se la forma base non esiste piu': meglio perdere un oggetto di un
# salvataggio vecchio che caricare una partita con un oggetto senza dimensioni.
static func from_dict(dati: Dictionary) -> Item:
	var base_salvata := ItemBase.per_id(String(dati.get("base", "")))
	if base_salvata == null:
		return null
	var item := Item.new(base_salvata)
	item.rarita = clampi(int(dati.get("rarita", 0)), 0, NOMI_RARITA.size() - 1) as Rarita
	item.livello = maxi(1, int(dati.get("livello", 1)))
	item.pos = Vector2i(int(dati.get("pos_x", 0)), int(dati.get("pos_y", 0)))
	item.cintura = int(dati.get("cintura", -1))
	item.uid = int(dati.get("uid", item.uid))
	registra_uid(item.uid)
	for voce in dati.get("affissi", []):
		item.affissi.append(Affix.from_dict(voce))
	return item

func size() -> Vector2i:
	return base.size

func nome() -> String:
	if affissi.is_empty():
		return base.nome
	return "%s %s" % [base.nome, affissi[0].nome()]

func colore() -> Color:
	return COLORI[int(rarita)]

func danno() -> int:
	var v := float(base.danno) * (1.0 + 0.08 * float(maxi(1, livello) - 1))
	for affisso in affissi:
		if affisso.tipo == Affix.Tipo.DANNO:
			v += float(affisso.valore)
	return int(round(v))

func difesa() -> int:
	var v := float(base.difesa) * (1.0 + 0.08 * float(maxi(1, livello) - 1))
	for affisso in affissi:
		if affisso.tipo == Affix.Tipo.DIFESA:
			v += float(affisso.valore)
	return int(round(v))

# Somma di tutte le proprieta' positive: la usano le formule di combattimento quando
# l'equipaggiamento entrera' in gioco (fase 5). In fase 3 serve solo al tooltip e ai test.
func bonus(tipo: Affix.Tipo) -> int:
	var totale := 0
	for affisso in affissi:
		if affisso.tipo == tipo:
			totale += affisso.valore
	return totale

func valore() -> int:
	var v := float(base.valore) * (1.0 + 0.25 * float(maxi(1, livello) - 1))
	v *= 1.0 + 0.35 * float(rarita)
	for affisso in affissi:
		v += float(affisso.valore) * 2.0
	return maxi(1, int(round(v)))

# Righe del tooltip, titolo escluso: il titolo e' l'unica riga colorata dalla rarita'.
func righe() -> PackedStringArray:
	var out := PackedStringArray()
	out.append("%s, %dx%d, livello %d" % [NOMI_RARITA[int(rarita)], base.size.x, base.size.y, livello])
	if danno() > 0:
		out.append("Danno: %d" % danno())
	if difesa() > 0:
		out.append("Difesa: %d" % difesa())
	for affisso in affissi:
		out.append("+%d %s" % [affisso.valore, affisso.etichetta()])
	out.append("Valore: %d oro" % valore())
	return out
