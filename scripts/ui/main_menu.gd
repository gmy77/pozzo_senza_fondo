# res://scripts/ui/main_menu.gd
# Scopo: menu del gioco, in due modi: titolo all'avvio e pausa durante la partita.
#        Disegnato a mano come il resto (niente temi, niente scene), si usa con mouse o
#        tastiera. Non decide niente: emette il segnale `azione` e lascia fare a Main.
# Dipendenze: scripts/core/game_state.gd
class_name MainMenu
extends CanvasLayer

signal azione(nome: String)

enum Modo { TITOLO, PAUSA }

const VOCI_TITOLO: Array[String] = ["NUOVA PARTITA", "CONTINUA", "ESCI"]
const AZIONI_TITOLO: Array[String] = ["nuova", "continua", "esci"]
const VOCI_PAUSA: Array[String] = ["RIPRENDI", "SALVA PARTITA", "CARICA PARTITA", "TORNA AL TITOLO", "ESCI"]
const AZIONI_PAUSA: Array[String] = ["riprendi", "salva", "carica", "titolo", "esci"]

const LARGHEZZA_VOCE: float = 360.0
const ALTEZZA_VOCE: float = 46.0
const PASSO_VOCE: float = 56.0
const TITOLO: String = "IL POZZO SENZA FONDO"
const SOTTOTITOLO: String = "Scendi. Nessuno torna con le mani vuote."

var modo: Modo = Modo.TITOLO
var selezione: int = 0
var aperto: bool = false

var _voci: Array[String] = []
var _azioni: Array[String] = []
var _attive: Array[bool] = []
var _riga_salvataggio: String = ""
var _superficie: Control

class Superficie extends Control:
	var menu: MainMenu

	func _draw() -> void:
		if menu != null:
			menu.disegna(self)

	func _gui_input(event: InputEvent) -> void:
		if menu != null:
			menu.input_superficie(event)

func _ready() -> void:
	layer = 30
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	_superficie = Superficie.new()
	_superficie.menu = self
	_superficie.set_anchors_preset(Control.PRESET_FULL_RECT)
	_superficie.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_superficie)

func apri(nuovo_modo: Modo, salvataggio_disponibile: bool) -> void:
	modo = nuovo_modo
	if modo == Modo.TITOLO:
		_voci = VOCI_TITOLO.duplicate()
		_azioni = AZIONI_TITOLO.duplicate()
		_attive = [true, salvataggio_disponibile, true]
	else:
		_voci = VOCI_PAUSA.duplicate()
		_azioni = AZIONI_PAUSA.duplicate()
		_attive = [true, true, salvataggio_disponibile, true, true]
	_riga_salvataggio = GameState.descrizione(GameState.SLOT_PREDEFINITO)
	selezione = _prima_attiva()
	aperto = true
	visible = true
	_superficie.queue_redraw()

func chiudi() -> void:
	aperto = false
	visible = false

# --- Navigazione, usabile anche senza mouse (e dai test) ---

func muovi(passo: int) -> void:
	if _voci.is_empty():
		return
	var i := selezione
	for _tentativo in _voci.size():
		i = wrapi(i + passo, 0, _voci.size())
		if _attive[i]:
			selezione = i
			break
	_superficie.queue_redraw()

func attiva() -> void:
	if selezione < 0 or selezione >= _azioni.size() or not _attive[selezione]:
		return
	azione.emit(_azioni[selezione])

func voce_attiva(indice: int) -> bool:
	return indice >= 0 and indice < _attive.size() and _attive[indice]

func voci() -> Array[String]:
	return _voci

func _prima_attiva() -> int:
	for i in _attive.size():
		if _attive[i]:
			return i
	return 0

# Il menu mangia tutti i tasti mentre e' aperto: senza questo, la I aprirebbe lo zaino
# dietro al menu e la R farebbe ripartire il mondo in pausa.
func _input(event: InputEvent) -> void:
	if not aperto or not (event is InputEventKey):
		return
	var tasto := event as InputEventKey
	if not tasto.pressed or tasto.echo:
		get_viewport().set_input_as_handled()
		return
	match tasto.physical_keycode:
		KEY_UP, KEY_W:
			muovi(-1)
		KEY_DOWN, KEY_S:
			muovi(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			attiva()
		KEY_ESCAPE:
			if modo == Modo.PAUSA:
				azione.emit("riprendi")
	get_viewport().set_input_as_handled()

func input_superficie(event: InputEvent) -> void:
	if not aperto:
		return
	if event is InputEventMouseMotion:
		var sopra := voce_sotto(_superficie.get_local_mouse_position())
		if sopra >= 0 and _attive[sopra] and sopra != selezione:
			selezione = sopra
			_superficie.queue_redraw()
		return
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
		return
	var scelta := voce_sotto(_superficie.get_local_mouse_position())
	if scelta >= 0 and _attive[scelta]:
		selezione = scelta
		attiva()

# --- Geometria ---

func origine() -> Vector2:
	var schermo := get_viewport().get_visible_rect().size
	var altezza := float(_voci.size()) * PASSO_VOCE
	return Vector2(
		(schermo.x - LARGHEZZA_VOCE) * 0.5,
		(schermo.y - altezza) * 0.5 + 60.0
	)

func rect_voce(indice: int) -> Rect2:
	return Rect2(
		origine() + Vector2(0.0, float(indice) * PASSO_VOCE),
		Vector2(LARGHEZZA_VOCE, ALTEZZA_VOCE)
	)

func voce_sotto(punto: Vector2) -> int:
	for i in _voci.size():
		if rect_voce(i).has_point(punto):
			return i
	return -1

# --- Disegno ---

func disegna(ci: Control) -> void:
	var font := ThemeDB.fallback_font
	var schermo := get_viewport().get_visible_rect().size

	# Velo scuro: il mondo resta visibile dietro, ma non compete con il menu.
	ci.draw_rect(Rect2(Vector2.ZERO, schermo), Color(0.02, 0.02, 0.03, 0.88 if modo == Modo.TITOLO else 0.72))

	var titolo := TITOLO if modo == Modo.TITOLO else "PAUSA"
	var misura := font.get_string_size(titolo, HORIZONTAL_ALIGNMENT_LEFT, -1, 44)
	var y_titolo := origine().y - 110.0
	ci.draw_string(font, Vector2((schermo.x - misura.x) * 0.5 + 2.0, y_titolo + 2.0), titolo, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(0.0, 0.0, 0.0, 0.8))
	ci.draw_string(font, Vector2((schermo.x - misura.x) * 0.5, y_titolo), titolo, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(0.86, 0.74, 0.42))

	if modo == Modo.TITOLO:
		var sotto := font.get_string_size(SOTTOTITOLO, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		ci.draw_string(font, Vector2((schermo.x - sotto.x) * 0.5, y_titolo + 26.0), SOTTOTITOLO, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.60, 0.56, 0.48))
	# Linea di separazione: un filo d'oro sotto al titolo.
	ci.draw_line(
		Vector2(schermo.x * 0.5 - 180.0, y_titolo + 44.0),
		Vector2(schermo.x * 0.5 + 180.0, y_titolo + 44.0),
		Color(0.45, 0.36, 0.20),
		1.0
	)

	for i in _voci.size():
		_disegna_voce(ci, i)

	var aiuto := "Frecce o W/S per scegliere, Invio per confermare"
	if modo == Modo.PAUSA:
		aiuto += ", ESC per riprendere"
	var misura_aiuto := font.get_string_size(aiuto, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	ci.draw_string(font, Vector2((schermo.x - misura_aiuto.x) * 0.5, schermo.y - 36.0), aiuto, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.48, 0.48, 0.48))

	var misura_salvataggio := font.get_string_size(_riga_salvataggio, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	ci.draw_string(
		font,
		Vector2((schermo.x - misura_salvataggio.x) * 0.5, schermo.y - 56.0),
		_riga_salvataggio,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.42, 0.44, 0.40)
	)

func _disegna_voce(ci: Control, indice: int) -> void:
	var font := ThemeDB.fallback_font
	var rect := rect_voce(indice)
	var attiva_voce: bool = _attive[indice]
	var scelta := indice == selezione and attiva_voce

	var fondo := Color(0.10, 0.09, 0.08, 0.95) if scelta else Color(0.06, 0.06, 0.07, 0.85)
	var bordo := Color(0.78, 0.62, 0.30) if scelta else Color(0.24, 0.22, 0.20)
	if not attiva_voce:
		fondo = Color(0.05, 0.05, 0.05, 0.7)
		bordo = Color(0.16, 0.16, 0.16)
	ci.draw_rect(rect, fondo)
	ci.draw_rect(rect, bordo, false, 2.0)

	var colore := Color(0.95, 0.88, 0.68) if scelta else Color(0.74, 0.72, 0.66)
	if not attiva_voce:
		colore = Color(0.36, 0.36, 0.36)
	var testo := _voci[indice]
	var misura := font.get_string_size(testo, HORIZONTAL_ALIGNMENT_LEFT, -1, 19)
	ci.draw_string(
		font,
		rect.position + Vector2((rect.size.x - misura.x) * 0.5, rect.size.y * 0.5 + 7.0),
		testo,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 19, colore
	)

	# Freccia sulla voce scelta: si capisce dove si e' anche senza colore.
	if scelta:
		var punta := rect.position + Vector2(-14.0, rect.size.y * 0.5)
		Art.poly(ci, PackedVector2Array([
			punta + Vector2(-8.0, -7.0),
			punta,
			punta + Vector2(-8.0, 7.0),
		]), Color(0.86, 0.70, 0.34))
