# Layer di collisione — Il Pozzo Senza Fondo

Documento di riferimento unico. Se un numero qui non corrisponde a `GameConsts`, vince
`GameConsts` e questo file va corretto: e' gia' successo una volta e non deve ripetersi.

Bit 1 = valore 1, bit 2 = 2, ... bit 10 = 512. In Godot un bit corrisponde a `1 << (n-1)`.

---

## 1. Tabella ufficiale

| Bit | Valore | Nome in `GameConsts` | Nome progetto | Contenuto |
|---|---|---|---|---|
| 1 | 1 | `L_MONDO` | `Mondo` | muri statici, roccia, edifici del borgo |
| 2 | 2 | `L_GIOCATORE` | `Giocatore` | corpo del giocatore |
| 3 | 4 | `L_NEMICI` | `Nemici` | corpi dei mostri, boss |
| 4 | 8 | `L_COLPI_GIOCATORE` | `Colpi giocatore` | hitbox melee e proiettili del giocatore |
| 5 | 16 | `L_COLPI_NEMICI` | `Colpi nemici` | hitbox e proiettili dei mostri |
| 6 | 32 | `L_PROPS` | `Props fisici` | barili e casse interi (`RigidBody2D`) |
| 7 | 64 | `L_BOTTINO` | `Bottino` | oggetti a terra, oro |
| 8 | 128 | `L_INTERAGIBILI` | `Interagibili` | NPC, scale, portale, bauli |
| 9 | 256 | `L_ZONE` | `Zone` | trigger di stanza, ingresso area, nebbia |
| 10 | 512 | `L_EFFETTI_TERRA` | `Effetti terra` | chiazze di fuoco, aura dei campioni, terreno dannoso |
| 11 | 1024 | `L_DETRITI` | `Detriti` | schegge di barili e casse: rotolano, non fermano nessuno |
| 12-32 | — | — | liberi | riservati |

I nomi della colonna "Nome progetto" sono quelli scritti in `project.godot` sotto
`[layer_names]`, quindi sono visibili nell'editor. I nomi di `GameConsts` sono quelli usati
nel codice.

---

## 2. Matrice layer / maschera

| Nodo | Layer | Maschera | Valore maschera | Note |
|---|---|---|---|---|
| Corpo giocatore | 2 | 1, 3, 6 | 37 | urta muri, mostri, props |
| Corpo nemico | 3 | 1, 2, 3, 6 | 39 | i mostri non si sovrappongono tra loro |
| Corpo NPC | 1 | 0 | 0 | statico, blocca il passo |
| Prop (barile/cassa) | 6 | 1, 2, 3, 6 | 39 | spinto da corpi, si rompe coi colpi |
| Detrito (scheggia) | 11 | 1, 11 | 1025 | urta muri e altri detriti, nient'altro |
| Hitbox giocatore | 4 | 3, 6 | 36 | colpisce mostri e props |
| Hitbox nemico | 5 | 2, 6 | 34 | colpisce giocatore e props |
| Proiettile giocatore | 4 | 1, 3, 6 | 37 | si ferma sui muri |
| Proiettile nemico | 5 | 1, 2, 6 | 35 | si ferma sui muri |
| Oggetto a terra | 7 | 2 | 2 | rileva il giocatore (Area2D) |
| Interagibile | 8 | 2 | 2 | rileva il giocatore (Area2D) |
| Zona / trigger | 9 | 2 | 2 | rileva il giocatore (Area2D) |
| Effetto a terra | 10 | 2, 3 | 6 | danneggia chi sta dentro (Area2D) |

Maschere gia' pronte in `GameConsts`:

```
M_GIOCATORE = L_MONDO | L_NEMICI | L_PROPS               = 37
M_NEMICO    = L_MONDO | L_GIOCATORE | L_NEMICI | L_PROPS = 39
M_PROPS     = L_MONDO | L_GIOCATORE | L_NEMICI | L_PROPS = 39
M_DETRITI   = L_MONDO | L_DETRITI                        = 1025
```

Le altre si scrivono a mano nell'oggetto che le usa: sono poche e ognuna ha un motivo
diverso, quindi una costante unica diventerebbe un contenitore di tutto.

---

## 3. Regole che non si negoziano

1. **Chi disegna un colpo non lo subisce.** I layer 4 e 5 non compaiono mai in una maschera
   che appartenga a un colpo: le hitbox non si urtano tra loro.
2. **Le zone non bloccano.** Layer 9 sempre con maschera 2 e corpo `Area2D`: se una zona
   fosse `StaticBody2D` il giocatore si fermerebbe sull'ingresso della stanza.
3. **Il bottino non e' un ostacolo.** Layer 7, `Area2D`, maschera 2. Gli oggetti a terra non
   devono fermare nessuno, altrimenti un martello caduto in un corridoio largo una cella
   blocca il passaggio.
4. **I detriti non sono props.** Stanno sul layer 11 con maschera 1025: urtano i muri (non
   li attraversano rotolando) ma non fermano giocatore e mostri, e nessuna hitbox li
   bersaglia. Correzione del 2026-11-04, con due difetti misurati alle spalle: con i
   detriti sul layer 6 il giocatore che ne aveva tre intorno avanzava a **0,4 px per frame**
   invece di 3,6 — restava inchiodato dove aveva appena rotto un barile — e ogni fendente
   che ne colpiva uno ne generava altri tre, a cascata senza fine.
5. **Un solo layer per corpo.** Un nodo con due layer attivi (per esempio giocatore + nemico)
   rompe la matrice in modo silenzioso: nessun errore, solo collisioni che non si spiegano.

---

## 4. Differenza tra collisione e navigazione

La collisione fisica e il navmesh derivano dalla stessa griglia, ma non sono la stessa cosa:

- la collisione e' **fusa per tratto di riga** (39 `CollisionShape2D` per la stanza di prova);
- il disegno dei muri e' **un nodo per cella** (89 `WallBlock`), perche' serve all'y-sort;
- la navigazione e' **una sola `NavigationRegion2D` per piano**, cotta con
  `bake_from_source_geometry_data` e `agent_radius = 12`.

Le regioni costruite a mano, una per rettangolo, ignorano il raggio dell'agente: i percorsi
passano a 0 px dal muro e un agente in un corridoio largo una cella si incastra. Misurato:
867 frame contro i muri e mai arrivato, contro 15,6 px di distanza minima e agente arrivato
con il bake. Il motivo per cui serve il bake e' nel documento di architettura, sezione 1.

---

## 5. Come verificare che non sia cambiato

Il selftest headless controlla gia' i punti che possono rompersi in silenzio:

```
$env:POZZO_SELFTEST="1"
godot --headless --path . --quit-after 20000
```

Deve stampare `SELFTEST OK (fallimenti: 0)`. I controlli che riguardano i layer sono
"un pezzo di muro per cella", "il muro ferma il giocatore" e "il barile viene spinto":
se qualcuno cambia una maschera, uno dei tre cade.
