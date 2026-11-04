# IL POZZO SENZA FONDO — Fase 0: architettura

Action RPG 2D top-down 3/4, Godot 4.3+, GDScript 2.0 tipizzato.
Tutto originale: nessun nome, personaggio, luogo o asset derivato da altre opere.
Nessun asset esterno: ogni pixel viene da `_draw()`, da `ImageTexture` generate a runtime
o da `Polygon2D`.

---

## 1. Scelte di fondo (e perche')

**Prospettiva: top-down 3/4, non isometrica.**
Motivo tecnico, non estetico: con l'isometrico ogni sistema deve convertire coordinate
(clic → cella → mondo, navmesh, nebbia di guerra, occlusori di luce) e un errore di mezzo
tile si vede subito. Con il 3/4 ortogonale ho:

- griglia di celle allineate agli assi → collisioni, navmesh e nebbia condividono la stessa
  geometria (`Rect2` in pixel-mondo);
- click-to-move banale: `NavigationAgent2D.target_position = get_global_mouse_position()`;
- muri disegnati con una faccia frontale (altezza finta ~20 px) per dare profondita'
  senza pagare il costo dell'isometrico.

**Mondo costruito per geometria, non per tile.**
Stanze e corridoi sono `Rect2`. Dallo stesso elenco di rettangoli derivano:
disegno del pavimento, muri di collisione, poligoni di navigazione, occlusori di luce,
celle di nebbia. Una sola verita', zero disallineamenti tra collisione e grafica.

**Ordinamento in profondita'.** Ogni entita' ha l'origine **ai piedi**, non al centro, e
`WorldRoot` ha `y_sort_enabled = true`: ordinare per `global_position.y` equivale a ordinare
per profondita' reale.
I muri **non** sono un blocco unico: ogni cella di muro e' un nodo separato con origine sul
proprio bordo inferiore. Serve soprattutto sui muri verticali: un muro alto quattro celle
disegnato come un pezzo solo verrebbe ordinato per la sua origine, e chi cammina accanto
risulterebbe dietro al muro per tutta la lunghezza. Un pezzo per cella risolve il caso.
La collisione, che non disegna, resta invece fusa per tratti di riga (39 tratti per la
stanza di prova contro 89 celle di muro).

**Il disegno deve avere altezza, o l'y-sort non serve a niente.** Se muri e personaggi fossero
piatti ai piedi, l'ordinamento sarebbe corretto e invisibile: nessuna occlusione possibile.
Numeri concreti, che sono anche il vincolo di progetto:

| Elemento | Misura |
|---|---|
| altezza del personaggio dall'origine ai piedi | **43 px** (testa compresa) |
| faccia del muro sopra l'origine | **68 px** |
| cappa del muro (superficie vista da sopra) | **24 px** |
| altezza totale del muro dall'origine | **92 px** |
| distanza minima del giocatore dal fondo di una cella di muro | **43 px** (32 di cella + 11 di raggio) |

Con questi numeri un muro copre il giocatore da 43 px fino a 92 px sopra l'origine, cioe'
tutti i 43 px del personaggio: la testa sparisce dietro la faccia. Servono almeno
`43 + 43 = 86 px` di muro, e 92 lascia 6 px di margine per l'assestamento del solver.
Un muro di 34 px (quello della prima stesura) copriva **0 px**: la verifica ha senso solo
dopo aver alzato il disegno.

**I muri che coprono il giocatore sbiadiscono.** Con 92 px di muro, chi cammina davanti al
muro sud della stanza sparisce del tutto. `WorldRoot._update_wall_fade()` porta a
`modulate.a = 0.4` il muro che sta davanti al giocatore e la cui faccia sale sopra i suoi
piedi: 89 confronti per frame, nessun raycast. La trasparenza e' l'unica eccezione alla
regola "il muro sta davanti", e c'e' solo perche' senza di essa il personaggio diventa
invisibile a ogni muro attraversato. `POZZO_NO_FADE=1` disattiva la sfumatura per fotografare
l'occlusione pura.

**Fasce di profondita' (`z_index`).** Solo chi ha `z_index = 0` partecipa all'y-sort. Gli
altri stanno in fasce fisse, e la nebbia e' sopra le entita', non sotto:

| `z_index` | Cosa | Partecipa all'y-sort |
|---|---|---|
| `-10` | pavimento (`Z_PAVIMENTO`) | no |
| `0` | muri, props, giocatore, mostri, NPC, bottino | **si'** |
| `20` | decalcomanie a terra: sangue, crepe (`Z_DECALCOMANIE`) | no |
| `50` | effetti sopra le entita': scintille, fumo (`Z_EFFETTI`) | no |
| `60` | **nebbia di guerra** (`Z_NEBBIA`) | no |
| `70` | numeri del danno, indicatori (`Z_NUMERI`) | no |
| `CanvasLayer 10` | HUD | fuori dal mondo |
| `CanvasLayer 20` | menu, pausa | fuori dal mondo |

La nebbia a 60 e' la correzione: sotto le entita' avrebbe lasciato i mostri visibili nelle
zone inesplorate, che e' esattamente il difetto che la nebbia deve evitare. Sopra la nebbia
restano solo i numeri del danno (devono leggersi anche nell'ombra) e la UI.

**Navigazione: una regione per piano, cotta con `agent_radius`.** Verificato con una prova
dedicata (stanza → corridoio largo una cella ad angolo a L → stanza), perche' le due
soluzioni sembrano equivalenti e non lo sono:

| Costruzione | Distanza minima dai muri | Agente |
|---|---|---|
| una `NavigationRegion2D` per tratto (poligoni a mano) | **0,0 px** | **non arriva**, 867 frame contro i muri, 824 fermo |
| una regione con `bake_from_source_geometry_data`, `agent_radius = 12` | **15,6 px** | **arriva**, 4 frame di contatto, 0 fermo |

Costo del bake misurato: **0,8 ms** per un piano 96x96 con 80 tratti camminabili → 9 poligoni.
Trascurabile: la generazione di un piano non e' un problema di prestazioni per la navigazione.

**Ordine di avvio.** Alla prima esecuzione su un progetto nuovo la cache delle classi globali
non esiste e ogni `class_name` risulta "non trovato". Non e' un errore di codice: va eseguita
una importazione una volta sola, poi il gioco parte.
`godot --headless --path . --import`

**Niente .tscn a mano.** L'unica scena e' `main.tscn` (`Node2D` + `main.gd`).
Tutto il resto nasce in `_ready()` da codice.

---

## 2. Struttura delle cartelle

```
res://
├─ project.godot
├─ main.tscn                     unica scena: Node2D + script main.gd
├─ main.gd                       macchina a stati dell'applicazione
├─ autoload/
│  ├─ event_bus.gd               segnali globali, nessuna logica
│  ├─ item_database.gd           basi oggetti, affissi, tabelle di loot
│  ├─ game_state.gd              stato run, RNG con seed, salvataggi JSON
│  ├─ quest_manager.gd           quest: stati, obiettivi, ricompense
│  └─ audio_manager.gd           sintesi procedurale, bus audio
├─ scripts/
│  ├─ core/
│  │  ├─ constants.gd            layer, misure celle, colori condivisi
│  │  ├─ rng.gd                  RandomNumberGenerator deterministico
│  │  ├─ scene_factory.gd        helper: nodi, collisori, sprite da codice
│  │  └─ art.gd                  primitive di disegno (forme, ombre, contorni)
│  ├─ world/
│  │  ├─ world_root.gd           contenitore del mondo vivo, transizioni
│  │  ├─ dungeon_generator.gd    BSP + corridoi, 4 aree x 4 piani
│  │  ├─ dungeon_floor.gd        un piano: stanze, corridoi, scala, portale
│  │  ├─ room.gd                 dati stanza: rettangolo, tipo, tabella spawn
│  │  ├─ floor_painter.gd        disegno pavimento/muri/decori
│  │  ├─ village.gd              borgo sicuro, edifici, NPC
│  │  ├─ fog_of_war.gd           ImageTexture mascherata, rivelazione per stanza
│  │  └─ lighting.gd             CanvasModulate, PointLight2D, occlusori
│  ├─ entities/
│  │  ├─ entity.gd               base: hp, statistiche, colpo, morte, knockback
│  │  ├─ player.gd               CharacterBody2D + NavigationAgent2D + classi
│  │  ├─ enemy.gd                base con FSM completa
│  │  ├─ enemies/                skeleton, zombie, bat, archer, shaman, demon
│  │  ├─ bosses/                 boss_base + guardiano, vedova, bocca, re
│  │  └─ npc.gd                  fabbro, guaritrice, saggio, cantastorie
│  ├─ combat/
│  │  ├─ stats.gd                StatBlock: for/des/mag/vit e valori derivati
│  │  ├─ damage.gd               to-hit, danno, critico, resistenze, ritorno
│  │  ├─ hitbox.gd               Area2D usa e getta con durata
│  │  ├─ projectile.gd           frecce e palle di fuoco, muri, esplosione
│  │  ├─ damage_number.gd        numeri fluttuanti, in pool
│  │  └─ knockback.gd            spinta su CharacterBody2D e RigidBody2D
│  ├─ items/
│  │  ├─ item.gd                 Resource: base, affissi, qualita', usura
│  │  ├─ affix.gd                modificatore singolo, con tag di slot
│  │  ├─ item_generator.gd       roll qualita'/affissi/valori per livello
│  │  ├─ loot_table.gd           tabelle per area e per mostro
│  │  ├─ ground_item.gd          Area2D con salto parabolico, etichetta colore
│  │  ├─ inventory.gd            griglia, occupazione, spostamento, fusione
│  │  └─ equipment.gd            slot, bonus aggregati, requisiti
│  ├─ quest/
│  │  ├─ quest.gd                definizione + stato runtime
│  │  └─ quest_objective.gd      uccidi / trova / raggiungi livello
│  ├─ ui/
│  │  ├─ hud.gd                  globi, xp, cintura, minimappa, tooltip
│  │  ├─ inventory_panel.gd      griglia + manichino + drag & drop
│  │  ├─ tooltip.gd              riquadro con confronto e colori qualita'
│  │  ├─ dialog_panel.gd         finestra di dialogo NPC
│  │  ├─ shop_panel.gd           compra/vendi/ripara
│  │  ├─ minimap.gd              pianta del piano corrente
│  │  └─ menu_panel.gd           pausa, salva, carica, nuova partita
│  ├─ fx/
│  │  └─ fx.gd                   particelle procedurali, screen shake
│  └─ audio/
│     └─ synth.gd                generatore di onde per gli effetti
├─ data/
│  ├─ classes.gd                 Guerriero, Arciera, Mago: crescita e abilita'
│  ├─ affixes.gd                 prefissi/suffissi e valori per livello
│  ├─ monsters.gd                tabelle mostri per area, varianti campione
│  └─ quests.gd                  le 6 quest fisse + il pool di quelle casuali
├─ docs/
│  ├─ ARCHITETTURA.md            questo file
│  └─ LAYER_COLLISIONE.md        tabella layer e matrice delle maschere
└─ tools/
   └─ selftest.gd                test headless (eseguito con POZZO_SELFTEST=1)
```

Prefissi: `snake_case` per i file, `PascalCase` per le `class_name`.
Ogni script apre con un commento `res://...`, scopo, dipendenze.

Stato reale (fine fase 3): `autoload/event_bus.gd`, `scripts/core/*`,
`scripts/combat/{stats,damage,hitbox}.gd`, `scripts/entities/{entity,player,enemy}.gd`,
`scripts/entities/enemies/skeleton.gd`, `scripts/fx/damage_number.gd`,
`scripts/items/{item_base,affix,item,item_generator,inventory,equipment}.gd`,
`scripts/ui/{inventory_panel,tooltip}.gd`,
`scripts/world/{world_root,floor_builder,floor_painter,wall_block,prop_body,test_room,gold_pickup,ground_item}.gd`,
`main.gd`, `tools/selftest.gd`. Il resto arriva con le fasi indicate nella tabella finale.

---

## 3. Autoload

Registrazione in `project.godot`, **in questo ordine** (l'ordine di caricamento conta:
chi dipende da un altro singleton deve venire dopo).

```ini
[autoload]

EventBus="*res://autoload/event_bus.gd"
ItemDatabase="*res://autoload/item_database.gd"
GameState="*res://autoload/game_state.gd"
QuestManager="*res://autoload/quest_manager.gd"
AudioManager="*res://autoload/audio_manager.gd"
```

| Singleton | Responsabilita' | Dipende da |
|---|---|---|
| `EventBus` | solo `signal`, nessuna variabile di stato | — |
| `ItemDatabase` | basi oggetti, affissi, nomi, tabelle loot, colori qualita' | `data/affixes.gd` |
| `GameState` | stato della run, RNG con seed, oro, salvataggio/caricamento | `EventBus`, `ItemDatabase` |
| `QuestManager` | quest attive, progressi, ricompense | `EventBus`, `GameState` |
| `AudioManager` | bus, sintesi, drone d'atmosfera | — |

Segnali di `EventBus` (elenco chiuso, si aggiunge solo se serve):

```
player_hp_changed(current: int, maximum: int)
player_mana_changed(current: int, maximum: int)
player_xp_changed(current: int, next_level: int)
player_level_up(level: int)
player_stats_changed()
player_died()
damage_dealt(target_id: int, amount: int, kind: String, is_crit: bool)
enemy_killed(monster_id: String, level: int, area_id: String)
boss_spawned(boss_id: String)
boss_defeated(boss_id: String)
item_dropped(item: Resource)
item_picked(item: Resource)
item_identified(item: Resource)
gold_changed(amount: int)
inventory_changed()
equipment_changed()
quest_started(quest_id: String)
quest_updated(quest_id: String, objective_index: int, progress: int, goal: int)
quest_completed(quest_id: String)
zone_entered(zone_id: String)
floor_changed(area_id: String, floor_index: int)
dialog_requested(npc_id: String)
dialog_closed()
app_state_changed(state: int)
game_saved(slot: int)
game_loaded(slot: int)
```

---

## 4. Layer di collisione

Bit 1 = valore 1, bit 2 = 2, bit 3 = 4, ... bit 10 = 512.

Tabella completa, matrice delle maschere con i valori numerici e regole non negoziabili:
`docs/LAYER_COLLISIONE.md`. Qui la versione breve, che deve restare identica.

| Bit | Valore | Nome | Contenuto |
|---|---|---|---|
| 1 | 1 | `MONDO` | muri statici, roccia, edifici del borgo |
| 2 | 2 | `GIOCATORE` | corpo del giocatore |
| 3 | 4 | `NEMICI` | corpi dei mostri |
| 4 | 8 | `COLPI_GIOCATORE` | hitbox melee e proiettili del giocatore |
| 5 | 16 | `COLPI_NEMICI` | hitbox e proiettili dei mostri |
| 6 | 32 | `FISICA_PROPS` | barili, casse, detriti (RigidBody2D) |
| 7 | 64 | `BOTTINO` | oggetti a terra, oro |
| 8 | 128 | `INTERAGIBILI` | NPC, scale, portale, bauli |
| 9 | 256 | `ZONE` | trigger di stanza, ingresso area, nebbia |
| 10 | 512 | `EFFETTI_TERRA` | chiazze di fuoco, aura dei campioni, terreno dannoso |
| 11-32 | — | liberi | riservati |

### Matrice layer / maschera

| Nodo | Layer | Maschera | Note |
|---|---|---|---|
| Corpo giocatore | 2 | 1, 3, 6 | urta muri, mostri, props |
| Corpo nemico | 3 | 1, 2, 3, 6 | i mostri non si sovrappongono tra loro |
| Corpo NPC | 1 | 0 | statico, blocca il passo |
| Prop (barile/cassa) | 6 | 1, 2, 3, 6 | spinto da corpi, si rompe coi colpi |
| Hitbox giocatore | 4 | 3, 6 | colpisce mostri e props |
| Hitbox nemico | 5 | 2, 6 | colpisce giocatore e props |
| Proiettile giocatore | 4 | 1, 3, 6 | si ferma sui muri |
| Proiettile nemico | 5 | 1, 2, 6 | si ferma sui muri |
| Oggetto a terra | 7 | 2 | rileva il giocatore |
| Interagibile | 8 | 2 | rileva il giocatore |
| Zona / trigger | 9 | 2 | rileva il giocatore |
| Effetto a terra | 10 | 2, 3 | danneggia chi sta dentro |

Nota implementativa: `CharacterBody2D` **non** spinge i `RigidBody2D` da solo. Il giocatore
legge `get_slide_collision_count()` in `_physics_process` e applica `apply_central_force()`
al prop colpito. Due dettagli che sembrano irrilevanti e non lo sono, misurati sulla stanza
di prova:

1. **La velocita' si legge prima di `move_and_slide()`.** Dopo, la scivolata lungo l'ostacolo
   ha gia' tagliato la componente contro il muro, e la spinta parte sbagliata.
2. **La direzione e' la media tra `-normal` del contatto e direzione di marcia.** Solo la
   normale sposta il barile di 39,4 px, solo la direzione di marcia di 57,6 px, la media di
   53,9 px. La normale da sola perde un terzo della spinta perche' i collisori dei props
   stanno piu' in alto dei piedi e hanno una componente verticale; la direzione di marcia
   da sola ignora gli spigoli e farebbe "sparare" il barile nei muri.

I props rispondono con `lock_rotation = true`, `mass 2.2`, `linear_damp 3.0`,
`angular_damp 6.0`, `friction 0.55`: senza lo smorzamento la forza continua li accelera
senza limite; senza `lock_rotation` i barili cilindrici rotolano via come monete.

---

## 5. Nebbia, luci e occlusori

Il punto delicato: la nebbia non e' un effetto grafico aggiunto dopo, e' una maschera che deve
restare allineata al pavimento gia' disegnato. Per questo nasce dalla stessa `Rect2`/griglia.

**Nebbia di guerra: `Image` a risoluzione di cella, non di pixel.**
Una `Image` in `FORMAT_R8` grande quanto la griglia (96x96 = 9216 byte per un piano intero),
un byte per cella con tre stati: `0` mai visto, `128` visto ma fuori vista, `255` visibile.
Si converte in `ImageTexture` e si mette su uno `Sprite2D` con `texture_filter = NEAREST` e
`scale = Vector2(32, 32)`: ogni pixel dell'immagine diventa una cella di 32 px, senza
sfumature interpolate e senza un pixel di disallineamento.

Lo sprite sta a **`z_index = GameConsts.Z_NEBBIA` (60)**, quindi **sopra** muri, props,
giocatore, mostri e bottino, e **sotto** solo i numeri del danno (70) e la UI (CanvasLayer).
Messa sotto le entita', come avevo scritto nella prima stesura, la nebbia nascondeva il
pavimento e lasciava in bella vista i mostri nelle stanze non ancora esplorate: il contrario
di quello che deve fare. Il `y_sort` del `WorldRoot` non la tocca, perche' ordina solo i figli
con `z_index = 0`.

Aggiornamento **solo al cambio di cella** del giocatore, con una cadenza massima di 0,15 s
(al massimo ~7 aggiornamenti al secondo anche correndo). Il calcolo della visibilita' e'
shadowcasting a 8 ottanti su raggio 9 celle: circa 250 celle visitate per aggiornamento.
La `ImageTexture` si aggiorna con `ImageTexture.update()` sulla stessa texture: non si
ricrea la risorsa, non si ricarica il materiale.

Costo stimato: 0,1-0,3 ms per lo shadowcasting, ~0,05 ms per l'upload di 9 KB.
**Sotto 0,5 ms per cambio di cella**, e solo poche volte al secondo. Non e' una stima
ottimistica: il lavoro e' proporzionale alle celle nel raggio, non ai pixel dello schermo.

**Luci: `CanvasModulate` + `PointLight2D`, occlusori fusi per segmento.**
Il piano e' scuro (`CanvasModulate` a 0,28), le torce e il fuoco sono `PointLight2D`.
Gli occlusori sono `LightOccluder2D` con un `OccluderPolygon2D` per **tratto di muro**, non
per cella: si riusa lo stesso elenco di tratti gia' calcolato per le collisioni. Sulla stanza
di prova sono 39 occlusori invece di 89, e su un piano 96x96 la differenza e' di un ordine
di grandezza. Un occludente per cella, oltre a costare, produce cuciture visibili tra le
ombre di due celle adiacenti.

Costo stimato in `gl_compatibility`: ~0,15-0,25 ms per luce con 40 occlusori a 1280x720.
Con 4-6 luci accese contemporaneamente si resta attorno a 1 ms di rendering luci.
Se il piano ne avesse molte di piu', si accendono solo quelle nella stanza corrente: il
`WorldRoot` conosce gia' la stanza del giocatore.

Nota onesta: questi due costi sono **stime da modello**, non misure. L'unico numero misurato
finora e' il bake della navigazione (0,8 ms). La nebbia e le luci si misurano in fase 4, con
il profiler, e se sforano si taglia il raggio di visibilita' prima di tagliare altro.

---

## 6. Diagramma delle classi

```
main.tscn : Node2D  →  main.gd
│  stati: BOOT, VILLAGE, DUNGEON, INVENTORY, DIALOG, SHOP, PAUSE, DEAD, LOADING
│  possiede: WorldRoot, Hud (CanvasLayer 10), MenuPanel (CanvasLayer 20)
│
└── WorldRoot (Node2D)
     ├── floor_painter            Node2D, _draw di pavimento e muri
     ├── Walls  StaticBody2D      un CollisionShape2D per tratto di muro   [layer 1]
     ├── NavigationRegion2D       una sola regione, cotta con agent_radius 12
     ├── Props     RigidBody2D    barili, casse, detriti                   [layer 6]
     ├── GroundItems (Area2D)     bottino                                  [layer 7]
     ├── Interactables (Area2D)   NPC, scale, portale                      [layer 8]
     ├── Zones (Area2D)           stanze, ingresso area                    [layer 9]
     ├── Enemies (Node2D)         container, spawn/despawn per stanza
     ├── Player                   entity.gd
     ├── FogOfWar  Sprite2D       ImageTexture mascherata
     └── Lighting  Node2D         CanvasModulate + PointLight2D + occlusori
```

```
RefCounted ─ Stats (statblock)
RefCounted ─ Item ── Affix
RefCounted ─ Inventory ── Item
RefCounted ─ Equipment ── Item

CharacterBody2D ─ Entity
  ├─ Player          (Stats, Inventory, Equipment, Belt, NavigationAgent2D, camera)
  ├─ Enemy           (Stats, FSM, NavigationAgent2D, loot_table, is_champion)
  │    ├─ Skeleton  Zombie  Bat  Archer  Shaman  Demon
  │    └─ BossBase → GuardianoMarmo, VedovaCenere, BoccaSale, SignoreFornace
StaticBody2D ─ Npc   (Area2D figlia su layer 8)

Area2D ─ Hitbox, Projectile, GroundItem, Interactable, Zone, GroundEffect
Node2D ─ DamageNumber (pool), Fx
```

**Entity** (base comune): `hp`, `max_hp`, `stats`, `take_hit(info: HitInfo) -> void`,
`die()`, `apply_knockback(dir: Vector2, force: float)`, `flash()`, `_spawn_corpse()`.
Chi non eredita da `Entity` (props, NPC) espone comunque `take_hit()` e
`is_hittable()`: i colpi usano duck typing, non `is Entity`.

**FSM dei mostri** (un solo `match` in `_physics_process`, nessun nodo in piu'):

```
IDLE ──(timer)──► PATROL
IDLE/PATROL ──(giocatore entro aggro E in linea di vista)──► CHASE
CHASE ──(distanza < portata)──► ATTACK
CHASE ──(hp < 20% e tipo codardo)──► FLEE
CHASE ──(fuori da 1,5 x aggro per 3 s)──► IDLE
ATTACK ──(fuori portata)──► CHASE
FLEE ──(3 s)──► CHASE
qualsiasi ──(hp <= 0)──► DEAD
```
`STAGGER` non e' uno stato: e' un timer che sospende movimento e attacco, cosi' il
knockback non spezza la FSM.

### Combattimento: la catena di un colpo (fase 2, implementata)

```
input / IA
   └─ Damage.make(quantita', tipo, direzione, contraccolpo, critico)
        └─ Hitbox.spawn(...)    Area2D, vive 0,10-0,12 s, colpisce una volta per bersaglio
             └─ bersaglio.take_hit(dmg)          duck typing: funziona su Entity e su PropBody
                  ├─ hp -= quantita'
                  ├─ contraccolpo: stagger 0,16 s, il movimento lo decide il colpo
                  ├─ lampeggio bianco 0,14 s
                  ├─ EventBus.damage_dealt
                  ├─ DamageNumber.spawn(...)     z_index 70, si libera da solo dopo 0,75 s
                  └─ hp <= 0 -> on_death()
```

Perche' la hitbox interroga `get_overlapping_bodies()` invece di usare `body_entered`:
un bersaglio gia' dentro l'area nel frame in cui nasce non emette il segnale "entered".
Con un colpo che vive 6 frame, quel caso non e' un limite teorico, e' il caso normale.

Numeri della fase 2, tutti verificati dal selftest:

| Grandezza | Valore |
|---|---|
| vita del giocatore | 112 (40 + 12 vitalita' x 6) |
| danno del giocatore | 6 + 0,75 x forza ≈ 15, critico x1,8 con probabilita' 12,8% |
| recupero tra due fendenti | 0,42 s |
| portata del fendente | 34 px, raggio della hitbox 17 px |
| vita dello scheletro | 64 (40 + 4 vitalita' x 6) |
| danno dello scheletro | 6 ogni 1,2 s, portata 30 px |
| inseguimento | 112 px/s, aggro 240 px, linea di vista obbligatoria |
| bottino | 1-4 monete d'oro |

Il mostro non insegue attraverso i muri: `_line_of_sight()` fa un `intersect_ray` sui soli
muri prima di passare a CHASE. E' il controllo che manca quasi sempre nelle FSM scritte in
fretta, e si vede subito in gioco: mostri che si ammucchiano contro una parete.

### Tre verifiche chieste prima della fase 3

Tutte e tre automatiche, tutte verdi. Ognuna ha trovato o chiuso un difetto concreto.

**1. Contraccolpo contro il muro.** Scheletro a 0,5 px dalla faccia del muro, colpito con
forza 400 verso la parete. Misura: distanza minima dal muro **10,0 px** (raggio del corpo),
deriva negli ultimi 30 frame **0,00 px**. La correzione che ha reso possibile il secondo
numero: `Entity.apply_motion` frenava con `speed * 10 * delta`, quindi con `speed = 0`
(mostro in IDLE o in ATTACK) la velocita' residua del contraccolpo non calava mai. Ora la
frenata e' fissa (`FRENATA = 1400 px/s²`): un residuo di 720 px/s si ferma in 0,52 s.
Senza questa correzione il mostro restava a spingere contro il muro con velocita' diversa
da zero, e il test "non vibra" non sarebbe stato onesto.

**2. Quattro scheletri in un corridoio largo una cella.** Corridoio in riga 3, muri sulle
righe 2 e 4 da x=6 a x=20, quindi 32 px di larghezza e solo 8 px di navmesh utile dopo
l'erosione di 12 px. Quattro scheletri in fila a 28 px l'uno dall'altro, giocatore oltre
l'uscita. Misura: percorso minimo **280 px**, frame consecutivi da fermo **0**. L'avoidance
di `NavigationAgent2D` **non e' servita** e non e' attiva: con velocita' uguali i mostri
mantengono la distanza, e il collo di bottiglia vero del corridoio e' la larghezza, non
l'incrocio. Resta un limite dichiarato: se il primo della fila si ferma, quelli dietro si
accodano (non possono passargli accanto) — e' il comportamento voluto, non un incastro.

**3. Tasto sinistro tenuto premuto.** Il comando non e' piu' un evento singolo: `set_hold()`
registra il cursore, `_hold_tick()` rinnova la destinazione ogni 0,15 s e `_try_attack()`
continua a ricalcolare il percorso verso il bersaglio vivo. Misure: **96 danni** inferti
senza mai rilasciare, **98 px** di inseguimento dopo che il bersaglio e' stato spostato di
120 px, **0 danni** dopo il rilascio. La prova ha scoperto un bug della fase 2: fuori
portata `_try_attack()` restituiva `true`, quindi il ramo che segue il percorso non veniva
eseguito e il giocatore restava fermo a guardare il mostro. Ora restituisce `true` solo
quando e' a portata e deve stare fermo.

Tenere premuto e trascinare aggiorna la destinazione senza nuovi clic; WASD ha sempre la
precedenza e annulla l'ordine. Rilasciando si smette di menare ma si finisce di camminare
verso l'ultimo punto: piantarsi a meta' passo sarebbe peggio.

---

## 7. Dati di gioco

**Aree (4 x 4 piani = 16 discese)**
1. Cripta dei Sepolti — scheletri, pipistrelli. Boss: *Il Guardiano di Marmo*.
2. Catacombe di Vellargento — zombi, arcieri d'ossa. Boss: *La Vedova di Cenere*.
3. Caverne di Sale — pipistrelli, sciamani. Boss: *Bocca di Sale*.
4. La Fornace Rossa — demoni, sciamani, arcieri. Boss: *Il Signore della Fornace*.

Borgo base: **Pietrasalda**. Livello 1 → 4 per area, mostri da livello 1 a 16.

**Quest fisse (6)**
1. *Primi passi sotto* — scendi al piano 1 della Cripta (raggiungi).
2. *Le ossa del fabbro* — uccidi 12 scheletri.
3. *Il martello perduto* — recupera il martello al piano 2 (trova oggetto).
4. *L'acqua che brucia* — raggiungi il livello 6 (raggiungi).
5. *Il sigillo spezzato* — uccidi il Guardiano di Marmo.
6. *Cenere nelle vene* — uccidi il Signore della Fornace.

**Quest casuali (pool, 2 per partita)**: *Il dente del pipistrello* (5 denti rari),
*La moneta del morto* (500 oro raccolti), *Il sussurro nelle ossa* (uccidi 8 sciamani).

**Qualita' e colori**: normale `#EDEDED`, magico `#6FA8FF`, raro `#F5D547`, unico `#E08A2E`.

---

## 8. Salvataggio

`user://save_1.json`, campo `version` per migrare. Contenuto: seed della run, classe,
livello, xp, punti assegnati, oro, area/piano, posizione, inventario (lista di oggetti
serializzati), equipaggiamento, cintura, quest, flag del mondo, boss uccisi.
Scrittura atomica: si scrive su `save_1.json.tmp` e si rinomina, per non corrompere il
salvataggio se il gioco viene chiuso a meta'.

---

## 9. Inventario: griglia fissa, nessuna rotazione

Decisione chiusa: **gli oggetti non ruotano**. Ogni oggetto ha una dimensione fissa in celle,
ancorata in alto a sinistra:

| Forma | Celle | Esempi |
|---|---|---|
| 1x1 | 1 | anello, amuleto, gemma, pozione |
| 1x2 | 2 | pugnale, bacchetta |
| 1x3 | 3 | spada corta, mazza |
| 2x2 | 4 | elmo, scudo piccolo, armatura leggera |
| 2x3 | 6 | armatura pesante, arco lungo |
| 2x4 | 8 | spadone, alabarda |

Griglia zaino 10 colonne x 6 righe, cella da 44 px. Cintura: 4 slot, accettano solo 1x1.
Equipaggiamento: slot fissi (arma, scudo, elmo, corazza, guanti, stivali, anello x2, amuleto),
ognuno con la propria forma ammessa.

Perche' senza rotazione, senza giri di parole: la rotazione e' la sorgente del 90% dei bug di
un inventario a griglia (oggetto ruotato che esce dai bordi, rotazione mentre si trascina,
rotazione che rende invalida una posizione gia' valida, salvataggi con orientamento
incoerente). Rinunciarci toglie un verbo al giocatore e toglie un'intera classe di difetti
allo sviluppatore. Con 60 celle e forme fino a 2x4 lo spazio basta: il vincolo reale e' la
cintura, non lo zaino.

Conseguenza sull'implementazione: nessuna matrice di rotazione, nessun ricalcolo di
occupazione dopo una rotazione, un solo `Rect2i` per oggetto e un `Array[bool]` di 60 celle
per la griglia. Il drag & drop diventa: prendi l'oggetto, mostra l'anteprima, verifica che
il `Rect2i` tradotto sia dentro i bordi e che tutte le celle siano libere, piazza.

### Equipaggiamento (fase 3, implementato)

Nove slot in `Equipment`: arma, scudo, elmo, corazza, guanti, stivali, anello x2, amuleto.
L'unica regola di ammissione e' la **categoria** (`ItemBase.Categoria`), e sta in
`Equipment.accetta()`, non nella UI: se stesse nel pannello finirebbe scritta due volte e,
prima o poi, in due modi diversi. Gli anelli sono due slot distinti della stessa categoria.

**Durante il trascinamento l'oggetto non viene mai tolto dal suo contenitore.** Si sposta
solo al rilascio riuscito. E' la decisione che rende impossibile la perdita di un oggetto:
chiudere il pannello a meta' trascinamento, rilasciare fuori dal pannello, rilasciare su
una cella occupata o su uno slot di categoria sbagliata finiscono tutti nello stesso modo,
cioe' l'oggetto dov'era. Ogni spostamento che tocca due contenitori (zaino -> slot con
scambio, slot -> slot, slot -> cintura) e' scritto in modo reversibile: se la seconda meta'
fallisce, la prima viene annullata.

**Effetto sul personaggio.** `Player` somma base e indossato:

| Grandezza | Formula |
|---|---|
| danno del fendente | `6 + forza x 0,75 + danno dell'arma` (forza = base + affissi) |
| difesa | somma delle difese dei pezzi + affissi `DIFESA` |
| vita massima | `40 + vitalita x 6 + affissi VITA` |
| velocita' | `190 + destrezza x 2 + affissi VELOCITA` |
| probabilita' critica | `8% + destrezza x 0,4% + affissi CRITICO x 1%` |

**La difesa riduce il danno davvero**, con una curva a rendimento decrescente in
`Entity.danno_ridotto()`: `riduzione = difesa / (difesa + 50)`, tetto al 75%, minimo un
punto di danno. Misurato dal selftest: con elmo + corazza pesante (difesa 12) un colpo da
20 ne toglie 16. La sottrazione secca, con questi numeri, avrebbe reso il personaggio
immortale: 12 di difesa contro i 6 danni di uno scheletro vuol dire 1 fisso per sempre.
L'armatura ferma solo il danno **fisico**: per fuoco, gelo e veleno ci saranno le
resistenze, che sono un'altra statistica.

### Morte: non si perde mai un oggetto

Regola di progetto, chiusa e non negoziabile:

> Alla morte il giocatore **non perde nessun oggetto**: ne' quelli equipaggiati, ne' quelli
> nello zaino, ne' quelli nella cintura. Gli oggetti che riprende sono **gli stessi**
> (stessi `uid`), non copie.

Penalita' di morte, scelta: **il 5% dell'oro trasportato** (`GameConsts.PENALITA_ORO_MORTE`)
e il piano che si rigenera con tutti i mostri in piedi. Il personaggio riappare al punto di
ritorno: nella stanza di prova e' il punto di partenza, dalla fase 5 sara' il borgo.
Il 5% e' una multa che si sente senza diventare una punizione; la perdita vera e' il piano
da rifare. Niente penalita' di esperienza e niente durabilita' persa: due tasse che
scoraggiano l'unica cosa che un action RPG deve incoraggiare, cioe' riprovare subito.

Implementazione: `Player.esporta_sacca()` / `importa_sacca()` passano `Inventory`,
`Equipment` e oro al corpo nuovo. Sono `RefCounted`: il nodo del vecchio giocatore viene
liberato, i contenitori no. `Main._restart()` applica la penalita' e ricollega il pannello.

---

## 10. Ripartizione in fasi

| Fase | File principali | Risultato verificabile | Stato |
|---|---|---|---|
| 1 | `main.gd`, `main.tscn`, `project.godot`, `autoload/event_bus.gd`, `scripts/core/{constants,rng,art,scene_factory}.gd`, `scripts/combat/stats.gd`, `scripts/entities/{entity,player}.gd`, `scripts/world/{world_root,floor_builder,floor_painter,wall_block,prop_body,test_room}.gd`, `tools/selftest.gd` | stanza con muri, barili fisici, movimento click e WASD, telecamera, occlusione dei muri alti | **fatta**, 11 controlli headless verdi |
| 2 | `scripts/combat/{damage,hitbox}.gd`, `scripts/entities/{entity,enemy}.gd`, `scripts/entities/enemies/skeleton.gd`, `scripts/fx/damage_number.gd`, `scripts/world/gold_pickup.gd` | scheletro con FSM, colpi, numeri, morte, oro, tasto tenuto premuto, contraccolpo su muro, corridoio affollato | **fatta**, 29 controlli headless verdi |
| 3 | `scripts/items/{item_base,affix,item,item_generator,inventory,equipment}.gd`, `scripts/world/ground_item.gd`, `scripts/ui/{inventory_panel,tooltip}.gd` | loot casuale da mostri e barili, oggetti a terra, griglia con drag & drop, manichino, morte senza perdita di oggetti | **fatta**, 56 controlli headless verdi |
| 4 | `dungeon_generator.gd`, `dungeon_floor.gd`, `fog_of_war.gd`, `lighting.gd`, mostri 2-6 | 4 piani della Cripta, scale, nebbia, luce | da fare |
| 5 | `village.gd`, `npc.gd`, `ui/dialog_panel.gd`, `ui/shop_panel.gd`, `equipment.gd` | borgo con 4 NPC, compravendita, riparazione, identificazione | da fare |
| 6 | `quests.gd`, `quest_manager.gd`, `bosses/*`, classi Arciera e Mago, `projectile.gd` | quest attive, boss con pattern, frecce e palle di fuoco | da fare |
| 7 | `ui/hud.gd`, `ui/minimap.gd`, `game_state.gd` (salvataggi), `audio/*`, bilanciamento | HUD completo, F5/F9, audio, curva di difficolta' | da fare |

---

## 11. Limiti noti, dichiarati prima di iniziare

- **Grafica geometrica.** Senza asset esterni il gioco sara' leggibile e coerente, non
  bello come un gioco con sprite disegnati a mano. Forme e colori rendono ogni creatura
  riconoscibile; il dettaglio fine no.
- **Niente TileMap.** Disegno procedurale: niente autotiling, quindi i bordi dei muri
  vanno gestiti a mano (faccia frontale + ombra). Ci sara' un `floor_painter` dedicato.
- **Audio sintetico.** Effetti da `AudioStreamGenerator`: impatti, passi, morte, drone.
  Niente musica composta, niente riverbero da campione.
- **Griglia oggetti.** Costruita con test headless come previsto. Limiti dichiarati della
  fase 3: **nessuno scambio al volo** (rilasciare un oggetto su una cella occupata lo fa
  tornare indietro, non scambia i due pezzi); **nessun ordinamento automatico** dello zaino;
  **niente clic destro** per equipaggiare al volo, si trascina; **niente requisiti** di
  forza o livello sugli slot, l'unico controllo e' la categoria.
- **Oggetti senza effetti speciali.** Gli affissi muovono numeri (forza, difesa, vita,
  velocita', critico): nessun affisso cambia il comportamento del gioco. I danni elementali
  esistono in `Damage.Kind` ma nessuna arma li produce ancora, e le resistenze non ci sono:
  l'armatura ferma solo il fisico.
- **Niente pozioni.** La cintura accetta gli 1x1 ma non c'e' ancora niente da bere: le
  pozioni arrivano col borgo (fase 5), che e' anche dove si comprano.
- **16 piani + 4 boss + 3 classi + 6 quest** e' un volume grande: le fasi 6 e 7 saranno
  le piu' lunghe. Se una fase rischia di sfondare la lunghezza della risposta, la spezzo
  su piu' file completi e ti scrivo CONTINUA.
- **Prestazioni.** Misurato, non stimato: il bake della navigazione di un piano 96x96 con
  80 tratti costa **0,8 ms**. I `NavigationRegion2D` per tratto non sono un'alternativa:
  costavano 867 frame di agente incastrato. Nebbia e luci sono ancora stime (vedi sezione 5)
  e si misurano in fase 4. La cifra "~100 ms di generazione" che avevo scritto prima era
  un'ipotesi senza misura: la tolgo finche' non ho il generatore vero da cronometrare.
- **Y-sort verificabile solo con l'arte alta.** Il test esiste ed e' automatico: il selftest
  mette il giocatore rasente al lato nord del muro in (14,10) e verifica che il rettangolo
  disegnato dal muro contenga quello del personaggio, testa compresa (OK, margine 6 px).
  Se un domani qualcuno abbassa la faccia del muro sotto 86 px, il controllo cade: non e'
  una cosa che si puo' sbagliare in silenzio.
- **Il muro coprente sbiadisce.** Con 92 px di muro il personaggio sparirebbe dietro al muro
  sud: `modulate.a` scende a 0,4 sui muri che lo coprono. Non e' un vezzo grafico, e' la
  condizione perche' i muri alti siano giocabili. Costo: 89 confronti per frame, nessun
  raycast.
- **Combattimento senza difese.** In fase 2 non esistono armatura, resistenze, parata o
  schivata: il danno arriva intero. Le statistiche ci sono gia' tutte, quindi aggiungerle
  e' un cambio di formula, non di struttura.
- **Bilanciamento al primo colpo.** 64 di vita per lo scheletro e 15 di danno per fendente
  sono una scelta iniziale, non un numero calibrato: si tarano quando ci sono le armi
  (fase 3) e i mostri delle altre aree (fase 4).
- **Numeri del danno non in pool.** Un nodo per colpo, liberato da solo. Il selftest
  controlla che sparisca davvero; il pool serve quando i colpi al secondo saliranno.
- **Bottino solo in oro.** Gli oggetti veri, con griglia e affissi, sono la fase 3.
  Lo stato `FLEE` della FSM e' scritto e funzionante ma nessun mostro lo usa ancora:
  servira' ai mostri codardi delle aree successive.
