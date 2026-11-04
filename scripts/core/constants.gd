# res://scripts/core/constants.gd
# Scopo: costanti condivise (misure di cella, codici della griglia, layer di collisione,
#        maschere pronte, colori base, valori di movimento).
# Dipendenze: nessuna.
class_name GameConsts
extends RefCounted

# --- Griglia ---
const CELL: int = 32

const CELL_VUOTA: int = 0
const CELL_PAVIMENTO: int = 1
const CELL_MURO: int = 2

# --- Layer di collisione (bit) ---
const L_MONDO: int = 1 << 0
const L_GIOCATORE: int = 1 << 1
const L_NEMICI: int = 1 << 2
const L_COLPI_GIOCATORE: int = 1 << 3
const L_COLPI_NEMICI: int = 1 << 4
const L_PROPS: int = 1 << 5
const L_BOTTINO: int = 1 << 6
const L_INTERAGIBILI: int = 1 << 7
const L_ZONE: int = 1 << 8
const L_EFFETTI_TERRA: int = 1 << 9
# Detriti: le schegge di barili e casse. Layer separato dai props perche' NON devono
# fermare nessuno. Misurato: con i detriti sul layer 6 il giocatore che ne aveva tre
# intorno avanzava a 0,4 px per frame invece di 3,6, cioe' restava inchiodato dove aveva
# appena rotto un barile.
const L_DETRITI: int = 1 << 10

# --- Maschere pronte all'uso ---
const M_GIOCATORE: int = L_MONDO | L_NEMICI | L_PROPS
const M_NEMICO: int = L_MONDO | L_GIOCATORE | L_NEMICI | L_PROPS
const M_PROPS: int = L_MONDO | L_GIOCATORE | L_NEMICI | L_PROPS
# I detriti urtano solo i muri e se stessi: rotolano, si accumulano negli angoli, ma non
# sono un ostacolo per nessuno e non si possono colpire.
const M_DETRITI: int = L_MONDO | L_DETRITI

# --- Colori del mondo ---
const COL_VUOTO: Color = Color(0.045, 0.042, 0.052)
const COL_PAVIMENTO: Color = Color(0.105, 0.105, 0.125)
const COL_PAVIMENTO_SCURO: Color = Color(0.075, 0.075, 0.095)
const COL_MURO_FRONTE: Color = Color(0.22, 0.21, 0.23)
const COL_MURO_COPING: Color = Color(0.30, 0.29, 0.31)

# --- Movimento ---
const VELOCITA_BASE: float = 190.0
const VELOCITA_PER_DESTREZZA: float = 2.0
const FORZA_SPINTA: float = 520.0

# --- Morte del giocatore ---
# Regola di progetto: morendo non si perde nessun oggetto (zaino, cintura,
# equipaggiamento). L'unica penalita' e' l'oro: il 5% resta sul pavimento del piano, che si
# rigenera con tutti i mostri in piedi. Il personaggio riappare al punto di ritorno (il
# borgo, dalla fase 5). Il 5% e' una multa che si sente senza diventare una punizione:
# la vera perdita e' il piano da rifare.
const PENALITA_ORO_MORTE: float = 0.05

# --- Profondita' di disegno (z_index) ---
# L'y-sort ordina solo i figli di WorldRoot con z_index 0 (muri, props, giocatore, mostri,
# bottino). Chi ha uno z_index diverso esce da quel confronto e va disegnato in una fascia
# precisa. La nebbia deve stare SOPRA le entita': se stesse sotto, i mostri resterebbero
# visibili nelle zone che il giocatore non ha ancora esplorato.
const Z_PAVIMENTO: int = -10
const Z_DECALCOMANIE: int = 20
const Z_EFFETTI: int = 50
const Z_NEBBIA: int = 60
const Z_NUMERI: int = 70
