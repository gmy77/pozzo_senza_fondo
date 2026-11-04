# res://scripts/combat/damage.gd
# Scopo: un colpo, come dato immutabile. Chi lo produce non sa chi lo riceve; chi lo riceve
#        non sa chi lo ha prodotto. Serve a poter testare il danno senza una scena.
# Dipendenze: nessuna.
class_name Damage
extends RefCounted

enum Kind { FISICO, FUOCO, GELO, VELENO }

const NOMI: Array[String] = ["fisico", "fuoco", "gelo", "veleno"]

var amount: int = 0
var kind: Kind = Kind.FISICO
var is_crit: bool = false
# Direzione in cui spingere il bersaglio. Non e' il vettore dal colpitore al colpito:
# e' la direzione in cui il bersaglio deve arretrare.
var direction: Vector2 = Vector2.ZERO
var knockback: float = 0.0

static func make(
	p_amount: int,
	p_kind: Kind = Kind.FISICO,
	p_direction: Vector2 = Vector2.ZERO,
	p_knockback: float = 0.0,
	p_crit: bool = false
) -> Damage:
	var dmg := Damage.new()
	dmg.amount = p_amount
	dmg.kind = p_kind
	dmg.direction = p_direction
	dmg.knockback = p_knockback
	dmg.is_crit = p_crit
	return dmg

func kind_name() -> String:
	return NOMI[int(kind)]
