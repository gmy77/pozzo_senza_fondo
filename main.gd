# res://main.gd
# Scopo: radice dell'applicazione. Stato di gioco, mappatura dei tasti, costruzione del mondo,
#        overlay di debug e aggancio del selftest headless.
# Dipendenze: scripts/world/world_root.gd, tools/selftest.gd, autoload/event_bus.gd
class_name Main
extends Node2D

enum AppState { BOOT, MENU, PLAY, PAUSE, DEAD }

const MAPPA_INPUT: Dictionary = {
	"move_up": KEY_W,
	"move_down": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
}

var state: AppState = AppState.BOOT
var world: WorldRoot
var overlay: Label
var inventory_panel: InventoryPanel
var menu: MainMenu
var notice_text: String = ""
var notice_left: float = 0.0

func _ready() -> void:
	# Main e il menu girano anche a gioco fermo; il mondo no. Senza questa riga la pausa
	# bloccherebbe anche chi deve toglierla.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_setup_input()
	_setup_overlay()

	world = WorldRoot.new()
	world.name = "WorldRoot"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	world.build_test_room(_seed_value())
	_apply_debug_pose()
	_setup_inventory()
	_setup_menu()

	EventBus.player_died.connect(_on_player_died)
	EventBus.notice.connect(_on_notice)

	if OS.get_environment("POZZO_SELFTEST") == "1":
		# Il selftest gioca da solo: niente menu e niente pausa, altrimenti i frame fisici
		# che aspetta non arriverebbero mai.
		state = AppState.PLAY
		EventBus.app_state_changed.emit(int(state))
		await Selftest.run(self)
		return

	if OS.get_environment("POZZO_ZAINO") == "1":
		# Gancio per le fotografie della UI: si parte in gioco, non al titolo.
		state = AppState.PLAY
		EventBus.app_state_changed.emit(int(state))
		return

	apri_menu(MainMenu.Modo.TITOLO)

func _process(delta: float) -> void:
	if notice_left > 0.0:
		notice_left = maxf(0.0, notice_left - delta)
	if overlay == null or world == null or world.player == null:
		return
	# Col menu aperto l'HUD di debug non serve e sporca il titolo.
	overlay.visible = state != AppState.MENU
	if not overlay.visible:
		return
	var pos := world.player.global_position
	var cell := Vector2i(
		floori(pos.x / float(GameConsts.CELL)),
		floori(pos.y / float(GameConsts.CELL))
	)
	var player := world.player
	if inventory_panel != null:
		inventory_panel.oro = player.gold
	var hint := "WASD o clic per muoversi e attaccare, I per lo zaino, ESC per il menu"
	if state == AppState.DEAD:
		hint = "SEI MORTO - premi R per ricominciare"
	elif notice_left > 0.0:
		hint = notice_text
	overlay.text = "FPS %d | cella %s | vita %d/%d | oro %d | zaino %d\n%s" % [
		Engine.get_frames_per_second(),
		cell,
		player.hp,
		player.max_hp,
		player.gold,
		player.inventory.quantita() if player.inventory != null else 0,
		hint,
	]

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match (event as InputEventKey).physical_keycode:
		KEY_I:
			_toggle_inventory()
		KEY_ESCAPE:
			# ESC chiude prima quello che e' aperto: lo zaino, poi il gioco stesso.
			if inventory_panel != null and inventory_panel.aperto:
				inventory_panel.chiudi()
			elif state == AppState.PLAY or state == AppState.DEAD:
				apri_menu(MainMenu.Modo.PAUSA)
		KEY_R:
			if state == AppState.DEAD:
				_restart()

func _toggle_inventory() -> void:
	if world == null or world.player == null:
		return
	inventory_panel.alterna()

func _setup_inventory() -> void:
	inventory_panel = InventoryPanel.new()
	inventory_panel.name = "InventoryPanel"
	add_child(inventory_panel)
	inventory_panel.collega(world.player)
	if OS.get_environment("POZZO_ZAINO") == "1":
		_zaino_di_prova()

# Gancio di debug: POZZO_ZAINO=1 riempie lo zaino di bottino generato, indossa quello che
# puo' e apre il pannello. Serve a fotografare la UI senza giocare mezz'ora.
func _zaino_di_prova() -> void:
	var player := world.player
	var rng := Rng.new(4242)
	for i in 14:
		var item := ItemGenerator.roll(rng, 1 + i % 6)
		var slot := player.equipment.slot_adatto(item)
		if slot >= 0 and player.equipment.oggetto(slot) == null:
			player.equipment.equipaggia(slot, item)
		else:
			player.inventory.aggiungi(item)
	player.gold = 173
	EventBus.equipment_changed.emit()
	inventory_panel.apri()

func _on_notice(text: String) -> void:
	notice_text = text
	notice_left = 2.2

# --- Menu: titolo all'avvio, pausa in partita ---

func _setup_menu() -> void:
	menu = MainMenu.new()
	menu.name = "MainMenu"
	add_child(menu)
	menu.azione.connect(_on_menu)

func apri_menu(modo: MainMenu.Modo) -> void:
	if inventory_panel != null:
		inventory_panel.chiudi()
	menu.apri(modo, GameState.esiste(GameState.SLOT_PREDEFINITO))
	get_tree().paused = true
	state = AppState.MENU
	EventBus.app_state_changed.emit(int(state))

func chiudi_menu() -> void:
	menu.chiudi()
	get_tree().paused = false
	state = AppState.PLAY
	EventBus.app_state_changed.emit(int(state))

func _on_menu(nome: String) -> void:
	match nome:
		"nuova":
			await nuova_partita()
		"continua", "carica":
			await carica_partita(GameState.SLOT_PREDEFINITO)
		"riprendi":
			chiudi_menu()
		"salva":
			salva_partita(GameState.SLOT_PREDEFINITO)
			chiudi_menu()
		"titolo":
			apri_menu(MainMenu.Modo.TITOLO)
		"esci":
			get_tree().quit()

# --- Partita: nuova, salva, carica ---

func nuova_partita() -> void:
	inventory_panel.chiudi()
	world.clear()
	await get_tree().process_frame
	world.build_test_room(_seed_value())
	inventory_panel.collega(world.player)
	chiudi_menu()

func salva_partita(slot: int) -> bool:
	if world.player == null:
		return false
	var dati := {
		"seed": _seed_value(),
		"giocatore": world.player.dati_salvataggio(),
	}
	var riuscito := GameState.salva(slot, dati)
	EventBus.notice.emit("Partita salvata" if riuscito else "Salvataggio fallito")
	if riuscito:
		EventBus.game_saved.emit(slot)
	return riuscito

func carica_partita(slot: int) -> bool:
	var dati := GameState.carica(slot)
	if dati.is_empty():
		EventBus.notice.emit("Nessun salvataggio da caricare")
		return false
	inventory_panel.chiudi()
	world.clear()
	await get_tree().process_frame
	world.build_test_room(int(dati.get("seed", _seed_value())))
	world.player.applica_salvataggio(dati.get("giocatore", {}))
	inventory_panel.collega(world.player)
	if menu.aperto:
		chiudi_menu()
	EventBus.game_loaded.emit(slot)
	EventBus.notice.emit("Partita caricata")
	return true

# Morte e ritorno. Regola di progetto: non si perde nessun oggetto. Zaino, cintura ed
# equipaggiamento passano al corpo nuovo con gli stessi uid; la penalita' e' sull'oro
# (GameConsts.PENALITA_ORO_MORTE) e sul piano, che si rigenera con tutti i mostri in piedi.
# Il personaggio riparte dal punto di ritorno della mappa: dalla fase 5 sara' il borgo.
func _restart() -> void:
	var sacca: Dictionary = {}
	if world.player != null:
		sacca = world.player.esporta_sacca()
		var oro: int = int(sacca.get("gold", 0))
		var perso := int(floor(float(oro) * GameConsts.PENALITA_ORO_MORTE))
		sacca["gold"] = oro - perso
		if perso > 0:
			EventBus.notice.emit("Sei morto: hai perso %d oro, gli oggetti no" % perso)
	inventory_panel.chiudi()
	world.clear()
	await get_tree().physics_frame
	world.build_test_room(_seed_value())
	world.player.importa_sacca(sacca)
	inventory_panel.collega(world.player)
	state = AppState.PLAY
	EventBus.app_state_changed.emit(int(state))

func _on_player_died() -> void:
	state = AppState.DEAD
	EventBus.app_state_changed.emit(int(state))

# Seed fisso: la stanza di prova e' sempre la stessa. Si puo' forzare da ambiente
# (POZZO_SEED=12345) per provare altre disposizioni di props.
func _seed_value() -> int:
	var raw := OS.get_environment("POZZO_SEED")
	if raw == "":
		return 20261104
	return raw.to_int()

# Sposta il giocatore in coordinate mondo, per riprodurre un bug o scattare una prova
# di ordinamento: POZZO_PLAYER_AT="368,400". Nessun effetto se la variabile non c'e'.
func _apply_debug_pose() -> void:
	var raw := OS.get_environment("POZZO_PLAYER_AT")
	if raw == "":
		return
	var parts := raw.split(",")
	if parts.size() != 2:
		return
	world.player.global_position = Vector2(parts[0].to_float(), parts[1].to_float())

func _setup_input() -> void:
	for action in MAPPA_INPUT:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var key_event := InputEventKey.new()
		key_event.physical_keycode = int(MAPPA_INPUT[action])
		InputMap.action_add_event(action, key_event)

func _setup_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Overlay"
	layer.layer = 10
	add_child(layer)

	overlay = Label.new()
	overlay.position = Vector2(16.0, 12.0)
	overlay.add_theme_font_size_override("font_size", 15)
	overlay.add_theme_color_override("font_color", Color(0.86, 0.83, 0.74))
	overlay.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	overlay.add_theme_constant_override("outline_size", 4)
	layer.add_child(overlay)
