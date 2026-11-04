# res://scripts/fx/damage_number.gd
# Scopo: numero del danno che sale e svanisce. Vive sopra la nebbia (Z_NUMERI), perche' un
#        colpo andato a segno deve leggersi anche in una stanza buia.
#        Niente pool per ora: un nodo per colpo, liberato da solo. Il pool arriva in fase 7,
#        quando i colpi al secondo saranno molti di piu'.
# Dipendenze: scripts/core/constants.gd
class_name DamageNumber
extends Node2D

const DURATA: float = 0.75
const SALITA: float = 26.0
const ATTESA_PRIMA_DI_SVANIRE: float = 0.45

var amount: int = 0
var is_crit: bool = false

var _t: float = 0.0

static func spawn(parent: Node, world_position: Vector2, value: int, crit: bool) -> DamageNumber:
	var node := DamageNumber.new()
	node.amount = value
	node.is_crit = crit
	node.z_index = GameConsts.Z_NUMERI
	node.add_to_group("damage_number")
	parent.add_child(node)
	# Scostamento deterministico, per non sovrapporre due numeri dello stesso colpo.
	var jitter := fmod(float(value) * 7.3, 13.0) - 6.0
	node.global_position = world_position + Vector2(jitter, 0.0)
	return node

func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATA:
		queue_free()
		return
	position.y -= SALITA * delta / DURATA
	queue_redraw()

func _draw() -> void:
	var alpha := 1.0
	if _t > ATTESA_PRIMA_DI_SVANIRE:
		alpha = 1.0 - (_t - ATTESA_PRIMA_DI_SVANIRE) / (DURATA - ATTESA_PRIMA_DI_SVANIRE)
	var size := 22 if is_crit else 16
	var text := str(amount)
	var color := Color(1.0, 0.86, 0.35, alpha) if is_crit else Color(0.94, 0.93, 0.88, alpha)
	var outline := Color(0.0, 0.0, 0.0, alpha * 0.9)

	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var origin := Vector2(-text_size.x * 0.5, 0.0)
	draw_string(font, origin + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline)
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
