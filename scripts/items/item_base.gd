# res://scripts/items/item_base.gd
# Scopo: catalogo delle forme base degli oggetti. Ogni voce e' una forma fissa, con la
#        dimensione in celle che l'inventario usa senza rotazione. I valori sono quelli di
#        livello 1: il generatore li scala con il livello dell'oggetto.
# Dipendenze: nessuna.
class_name ItemBase
extends RefCounted

enum Categoria { ARMA, SCUDO, ELMO, CORAZZA, GUANTI, STIVALI, ANELLO, AMULETO }

var id: String
var nome: String
var categoria: Categoria
var size: Vector2i
var danno: int = 0
var difesa: int = 0
var valore: int = 1

func _init(
	p_id: String,
	p_nome: String,
	p_categoria: Categoria,
	p_size: Vector2i,
	p_danno: int,
	p_difesa: int,
	p_valore: int
) -> void:
	id = p_id
	nome = p_nome
	categoria = p_categoria
	size = p_size
	danno = p_danno
	difesa = p_difesa
	valore = p_valore

# Il catalogo si costruisce una volta sola. Le forme sono tutte comprese fra 1x1 e 2x4,
# cioe' le sei misure ammesse dalla griglia: se ne aggiungi una fuori elenco il selftest
# cade subito.
static var _catalogo: Array[ItemBase] = []

static func tutte() -> Array[ItemBase]:
	if _catalogo.is_empty():
		_catalogo = [
			ItemBase.new("pugnale", "Pugnale", Categoria.ARMA, Vector2i(1, 2), 4, 0, 12),
			ItemBase.new("spada_corta", "Spada corta", Categoria.ARMA, Vector2i(1, 3), 6, 0, 22),
			ItemBase.new("mazza", "Mazza", Categoria.ARMA, Vector2i(1, 3), 7, 0, 26),
			ItemBase.new("spadone", "Spadone", Categoria.ARMA, Vector2i(2, 4), 13, 0, 60),
			ItemBase.new("elmo", "Elmo", Categoria.ELMO, Vector2i(2, 2), 0, 3, 18),
			ItemBase.new("scudo_piccolo", "Scudo piccolo", Categoria.SCUDO, Vector2i(2, 2), 0, 4, 22),
			ItemBase.new("corazza_leggera", "Corazza leggera", Categoria.CORAZZA, Vector2i(2, 3), 0, 6, 34),
			ItemBase.new("corazza_pesante", "Corazza pesante", Categoria.CORAZZA, Vector2i(2, 4), 0, 9, 52),
			ItemBase.new("guanti", "Guanti", Categoria.GUANTI, Vector2i(1, 2), 0, 1, 8),
			ItemBase.new("stivali", "Stivali", Categoria.STIVALI, Vector2i(1, 2), 0, 1, 8),
			ItemBase.new("anello", "Anello", Categoria.ANELLO, Vector2i(1, 1), 0, 0, 14),
			ItemBase.new("amuleto", "Amuleto", Categoria.AMULETO, Vector2i(1, 1), 0, 0, 16),
		]
	return _catalogo

static func per_id(id_cercato: String) -> ItemBase:
	for base in tutte():
		if base.id == id_cercato:
			return base
	return null

static func per_categoria(categoria_cercata: Categoria) -> Array[ItemBase]:
	var out: Array[ItemBase] = []
	for base in tutte():
		if base.categoria == categoria_cercata:
			out.append(base)
	return out
