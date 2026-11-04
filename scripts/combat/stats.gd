# res://scripts/combat/stats.gd
# Scopo: blocco statistiche di un personaggio e relativi valori derivati.
#        Fase 1: muove la velocita'. Le formule di danno arriveranno con stats complete in fase 2.
# Dipendenze: scripts/core/constants.gd
class_name Stats
extends RefCounted

var strength: int = 10
var dexterity: int = 10
var magic: int = 10
var vitality: int = 10

func _init(p_strength: int = 10, p_dexterity: int = 10, p_magic: int = 10, p_vitality: int = 10) -> void:
	strength = p_strength
	dexterity = p_dexterity
	magic = p_magic
	vitality = p_vitality

func move_speed() -> float:
	return GameConsts.VELOCITA_BASE + float(dexterity) * GameConsts.VELOCITA_PER_DESTREZZA

func max_hp() -> int:
	return 40 + vitality * 6

func max_mana() -> int:
	return 20 + magic * 4

func to_dict() -> Dictionary:
	return {
		"strength": strength,
		"dexterity": dexterity,
		"magic": magic,
		"vitality": vitality,
	}

static func from_dict(data: Dictionary) -> Stats:
	var stats := Stats.new()
	stats.strength = int(data.get("strength", 10))
	stats.dexterity = int(data.get("dexterity", 10))
	stats.magic = int(data.get("magic", 10))
	stats.vitality = int(data.get("vitality", 10))
	return stats
