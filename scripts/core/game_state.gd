# res://scripts/core/game_state.gd
# Scopo: salvataggio e caricamento su file. JSON leggibile in `user://`, scrittura in due
#        mosse con copia di sicurezza: una partita non si perde perche' il gioco e' stato
#        chiuso mentre scriveva.
# Dipendenze: nessuna (riceve e restituisce Dictionary gia' pronti).
class_name GameState
extends RefCounted

# Numero di versione del formato. Un salvataggio di versione diversa viene rifiutato invece
# di essere indovinato: caricare a meta' e' peggio che non caricare.
const VERSIONE: int = 1
const SLOT_PREDEFINITO: int = 1

static func nome_file(slot: int) -> String:
	return "salvataggio_%d.json" % slot

static func percorso(slot: int) -> String:
	return "user://%s" % nome_file(slot)

static func esiste(slot: int) -> bool:
	return FileAccess.file_exists(percorso(slot))

# Scrittura: prima il file temporaneo, poi lo scambio. Se il gioco muore durante la
# scrittura, il salvataggio buono e' ancora al suo posto; se muore durante lo scambio,
# resta la copia .bak.
static func salva(slot: int, dati: Dictionary) -> bool:
	var completo := dati.duplicate(true)
	completo["versione"] = VERSIONE
	completo["salvato_il"] = Time.get_datetime_string_from_system(false, true)

	var temporaneo := percorso(slot) + ".tmp"
	var file := FileAccess.open(temporaneo, FileAccess.WRITE)
	if file == null:
		push_error("Salvataggio: non riesco a scrivere %s" % temporaneo)
		return false
	file.store_string(JSON.stringify(completo, "\t"))
	file.close()

	var cartella := DirAccess.open("user://")
	if cartella == null:
		return false
	var finale := nome_file(slot)
	var copia := finale + ".bak"
	if cartella.file_exists(finale):
		if cartella.file_exists(copia):
			cartella.remove(copia)
		cartella.rename(finale, copia)
	return cartella.rename(finale + ".tmp", finale) == OK

# Dizionario vuoto = niente da caricare. Il chiamante decide cosa dire all'utente.
static func carica(slot: int) -> Dictionary:
	if not esiste(slot):
		return {}
	var file := FileAccess.open(percorso(slot), FileAccess.READ)
	if file == null:
		return {}
	var testo := file.get_as_text()
	file.close()

	var letto: Variant = JSON.parse_string(testo)
	if typeof(letto) != TYPE_DICTIONARY:
		push_error("Salvataggio %d illeggibile" % slot)
		return {}
	var dati: Dictionary = letto
	if int(dati.get("versione", 0)) != VERSIONE:
		push_error("Salvataggio %d di versione %s, atteso %d" % [slot, str(dati.get("versione", 0)), VERSIONE])
		return {}
	return dati

static func cancella(slot: int) -> void:
	var cartella := DirAccess.open("user://")
	if cartella == null:
		return
	for nome in [nome_file(slot), nome_file(slot) + ".bak", nome_file(slot) + ".tmp"]:
		if cartella.file_exists(nome):
			cartella.remove(nome)

# Riga da mostrare nel menu accanto a "Continua": data e contenuto, non solo "slot 1".
static func descrizione(slot: int) -> String:
	var dati := carica(slot)
	if dati.is_empty():
		return "nessun salvataggio"
	var giocatore: Dictionary = dati.get("giocatore", {})
	var zaino: Dictionary = giocatore.get("inventario", {})
	var oggetti: Array = zaino.get("oggetti", [])
	return "%s - %d oro, %d oggetti" % [
		str(dati.get("salvato_il", "data ignota")),
		int(giocatore.get("oro", 0)),
		oggetti.size(),
	]
