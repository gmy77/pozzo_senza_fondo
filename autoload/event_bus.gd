# res://autoload/event_bus.gd
# Scopo: segnali globali del gioco. Nessuna logica, nessuno stato: solo il contratto
#        di comunicazione tra sistemi che non devono conoscersi.
# Dipendenze: nessuna. Registrato in project.godot come primo autoload.
extends Node

# --- Giocatore ---
signal player_hp_changed(current: int, maximum: int)
signal player_mana_changed(current: int, maximum: int)
signal player_xp_changed(current: int, next_level: int)
signal player_level_up(level: int)
signal player_stats_changed()
signal player_died()

# --- Combattimento ---
signal damage_dealt(target_id: int, amount: int, kind: String, is_crit: bool)
signal enemy_killed(monster_id: String, level: int, area_id: String)
signal boss_spawned(boss_id: String)
signal boss_defeated(boss_id: String)

# --- Oggetti ---
signal item_dropped(item)
signal item_picked(item)
signal item_identified(item)
signal gold_changed(amount: int)
signal inventory_changed()
signal equipment_changed()

# --- Quest ---
signal quest_started(quest_id: String)
signal quest_updated(quest_id: String, objective_index: int, progress: int, goal: int)
signal quest_completed(quest_id: String)

# --- Mondo e applicazione ---
signal zone_entered(zone_id: String)
signal floor_changed(area_id: String, floor_index: int)
signal dialog_requested(npc_id: String)
signal dialog_closed()
signal notice(text: String)
signal app_state_changed(state: int)
signal game_saved(slot: int)
signal game_loaded(slot: int)
