# Il Pozzo Senza Fondo

> **Prototipo/test giocabile — non è un gioco finito.**

Action RPG 2D top-down realizzato con Godot 4.7 e GDScript 2.0. Il progetto serve a
verificare combattimento, movimento, inventario, equipaggiamento, bottino e salvataggi
prima di costruire il dungeon completo.

## Stato attuale

È presente una sola **stanza di prova** con:

- tre scheletri e combattimento melee;
- movimento esclusivamente con **WASD**;
- clic sul mostro per attaccare, senza inseguimento automatico;
- barili e casse rompibili;
- oro e oggetti casuali con affissi;
- inventario 10x6 senza rotazione, cintura e manichino;
- equipaggiamento che modifica danno, difesa, vita e velocità;
- morte senza perdita degli oggetti, con penalità del 5% sull’oro;
- menu iniziale, pausa e salvataggio JSON.

## Cosa manca

Non sono ancora implementati il borgo, il dungeon generato con 16 piani, scale, nebbia di
guerra, NPC, negozi, quest, boss, classi aggiuntive, esperienza, audio e minimappa.
Il bilanciamento è provvisorio e la grafica è interamente procedurale.

## Avvio rapido

### Versione Windows pronta

Scarica l’ultima release, estrai lo zip e fai doppio clic su:

```text
PozzoSenzaFondo.exe
```

Dal menu scegli **NUOVA PARTITA**.

### Da sorgenti

Serve Godot 4.7 o superiore:

```powershell
git clone https://github.com/gmy77/pozzo_senza_fondo.git
cd pozzo_senza_fondo
godot --path .
```

In alternativa, apri `project.godot` nell’editor Godot e premi F6/F5.

## Comandi

| Tasto | Azione |
|---|---|
| WASD | Muove il giocatore |
| Clic sinistro sul mostro | Attacca se è a portata |
| Clic sinistro tenuto | Continua ad attaccare, non insegue |
| I | Apre inventario ed equipaggiamento |
| ESC | Menu di pausa |
| R | Ricomincia dopo la morte |

## Test automatici

Il progetto include 75 controlli headless:

```powershell
$env:POZZO_SELFTEST="1"
godot --headless --path . --quit-after 20000
Remove-Item Env:\POZZO_SELFTEST
```

Il risultato atteso è:

```text
SELFTEST OK (fallimenti: 0)
```

## Licenza e stato

Questo repository è un progetto personale/prototipo. Non contiene asset esterni. Le regole
architetturali, i limiti dichiarati e le decisioni tecniche sono in `docs/ARCHITETTURA.md`.
