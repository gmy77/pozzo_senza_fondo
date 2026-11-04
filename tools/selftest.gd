# res://tools/selftest.gd
# Scopo: verifica automatica della fase 1 senza finestra. Controlla mondo, muri (un pezzo per
#        cella), collisioni, props, navmesh, click-to-move, blocco dei muri e spinta dei barili.
# Uso:   POZZO_SELFTEST=1 godot --headless --path . --quit-after 1200
# Dipendenze: main.gd, world_root.gd, floor_builder.gd, prop_body.gd, constants.gd
class_name Selftest
extends RefCounted

static func run(main: Main) -> void:
	var world: WorldRoot = main.world
	var tree: SceneTree = main.get_tree()
	var failures: int = 0
	var notes := PackedStringArray()

	failures += _check(world != null and world.player != null, "mondo e giocatore creati", notes)
	if world == null or world.player == null:
		_report(failures, notes)
		tree.quit(1)
		return

	var player: Player = world.player
	var grid: Array = world.floor_info["grid"]

	var expected_walls := _count_value(grid, GameConsts.CELL_MURO)
	var blocks := tree.get_nodes_in_group("wall_block").size()
	failures += _check(blocks == expected_walls, "un pezzo di muro per cella (%d)" % expected_walls, notes)

	var walls: StaticBody2D = world.floor_info["walls"]
	failures += _check(walls.get_child_count() > 0, "collisioni dei muri unite per tratto (%d)" % walls.get_child_count(), notes)

	var prop_count := tree.get_nodes_in_group("prop").size()
	failures += _check(prop_count == 8, "barili e casse presenti (%d)" % prop_count, notes)

	# La mappa di navigazione si sincronizza nei frame fisici: senza attesa la ricerca
	# del percorso risponde vuoto (verificato a mano, non e' un caso limite teorico).
	for i in 12:
		await tree.physics_frame

	var map: RID = player.get_world_2d().navigation_map
	var far_cell := FloorBuilder.cell_center(Vector2i(20, 12))
	var path := NavigationServer2D.map_get_path(map, player.global_position, far_cell, true)
	var reached := path.size() > 0 and path[path.size() - 1].distance_to(far_cell) < 20.0
	failures += _check(reached, "navmesh attraversa la stanza (%d punti)" % path.size(), notes)

	var start := player.global_position
	player.set_move_target(start + Vector2(120.0, 0.0))
	for i in 50:
		await tree.physics_frame
	var moved := player.global_position.x - start.x
	failures += _check(moved > 70.0, "click-to-move sposta il giocatore (%.0f px)" % moved, notes)

	player.set_move_target(Vector2(60.0 * float(GameConsts.CELL), player.global_position.y))
	for i in 120:
		await tree.physics_frame
	var wall_x := float((TestRoom.LARGHEZZA - 1) * GameConsts.CELL)
	var inside := player.global_position.x < wall_x - 4.0
	failures += _check(inside, "il muro ferma il giocatore (x=%.0f, muro a %.0f)" % [player.global_position.x, wall_x], notes)

	# Occlusione: rasente al lato nord del muro in (14,10) la faccia deve coprire tutto il
	# personaggio, testa compresa. Rettangoli calcolati, non guardati a occhio.
	var wall_origin := FloorBuilder.cell_bottom(Vector2i(14, 10))
	var wall_block: WallBlock = null
	for node in tree.get_nodes_in_group("wall_block"):
		var candidate := node as WallBlock
		if candidate != null and candidate.global_position.distance_to(wall_origin) < 1.0:
			wall_block = candidate
			break
	failures += _check(wall_block != null, "muro di prova trovato in (14,10)", notes)
	if wall_block != null:
		player.global_position = Vector2(
			wall_origin.x,
			wall_origin.y - float(GameConsts.CELL) - Player.RADIO_CORPO
		)
		player.velocity = Vector2.ZERO
		player.stop()
		var local := wall_block.drawn_rect()
		var wall_world := Rect2(wall_block.global_position + local.position, local.size)
		var body_world := Rect2(
			player.global_position - Vector2(Player.LARGHEZZA_DISEGNO * 0.5, Player.ALTEZZA_DISEGNO),
			Vector2(Player.LARGHEZZA_DISEGNO, Player.ALTEZZA_DISEGNO)
		)
		failures += _check(wall_world.encloses(body_world), "la faccia del muro copre il personaggio fino alla testa", notes)
		for i in 24:
			await tree.process_frame
		failures += _check(wall_block.modulate.a < 0.9, "il muro che copre sbiadisce (alpha %.2f)" % wall_block.modulate.a, notes)

	var barrel := _nearest_prop(world.props, FloorBuilder.cell_center(Vector2i(11, 8)))
	if barrel != null:
		# Allineati al centro del barile (che sta 13 px sopra la sua base), non ai piedi:
		# altrimenti il contatto e' di striscio e la prova misura il caso sbagliato.
		player.global_position = barrel.global_position + Vector2(-50.0, -PropBody.RADIO_BARILE)
		player.velocity = Vector2.ZERO
		var before := barrel.global_position
		player.set_move_target(barrel.global_position + Vector2(120.0, 0.0))
		for i in 70:
			await tree.physics_frame
		var pushed := barrel.global_position.distance_to(before)
		failures += _check(pushed > 25.0, "il barile viene spinto (%.1f px)" % pushed, notes)
	else:
		failures += _check(false, "barile disponibile per la prova di spinta", notes)

	# --- Fase 2: combattimento ---
	failures += _check(world.enemies.size() == 3, "tre mostri nella stanza (%d)" % world.enemies.size(), notes)

	player.global_position = FloorBuilder.cell_center(Vector2i(11, 8))
	player.velocity = Vector2.ZERO
	player.stop()
	var skeleton: Enemy = world.enemies[0]
	skeleton.global_position = player.global_position + Vector2(26.0, 0.0)
	skeleton.velocity = Vector2.ZERO
	for i in 6:
		await tree.physics_frame

	var hp_before: int = skeleton.hp
	Hitbox.spawn(
		world,
		skeleton.global_position,
		Player.RAGGIO_COLPO,
		GameConsts.L_COLPI_GIOCATORE,
		GameConsts.L_NEMICI | GameConsts.L_PROPS,
		Damage.make(9, Damage.Kind.FISICO, Vector2.RIGHT, 0.0, false),
		0.2
	)
	for i in 8:
		await tree.physics_frame
	failures += _check(skeleton.hp <= hp_before - 9, "la hitbox toglie vita al mostro (%d -> %d)" % [hp_before, skeleton.hp], notes)
	failures += _check(tree.get_nodes_in_group("damage_number").size() > 0, "numero del danno creato", notes)

	# Attacco vero del giocatore: bersaglio a portata, deve partire il fendente.
	# Non basta provare la hitbox da sola: qui si prova la catena bersaglio -> cooldown -> colpo.
	skeleton.global_position = player.global_position + Vector2(24.0, 0.0)
	skeleton.velocity = Vector2.ZERO
	var hp_attack := skeleton.hp
	player.attack_target = skeleton
	for i in 30:
		await tree.physics_frame
	player.attack_target = null
	failures += _check(skeleton.hp < hp_attack, "il giocatore attacca il mostro a portata (%d -> %d)" % [hp_attack, skeleton.hp], notes)

	# Inseguimento: mostro a 150 px, in vista. Deve avvicinarsi, non restare fermo.
	skeleton.global_position = player.global_position + Vector2(150.0, 0.0)
	skeleton.velocity = Vector2.ZERO
	for i in 6:
		await tree.physics_frame
	var distance_before := skeleton.global_position.distance_to(player.global_position)
	for i in 60:
		await tree.physics_frame
	var distance_after := skeleton.global_position.distance_to(player.global_position)
	failures += _check(distance_after < distance_before - 20.0, "lo scheletro insegue (%.0f -> %.0f px)" % [distance_before, distance_after], notes)

	# Attacco: entro qualche secondo il giocatore deve perdere vita.
	var hp_player_before := player.hp
	var attacked := false
	for i in 120:
		await tree.physics_frame
		if player.hp < hp_player_before:
			attacked = true
			break
	failures += _check(attacked, "lo scheletro colpisce il giocatore (%d/%d)" % [player.hp, player.max_hp], notes)

	# Morte e bottino.
	var loot_before := tree.get_nodes_in_group("loot").size()
	skeleton.take_hit(Damage.make(999, Damage.Kind.FISICO, Vector2.RIGHT, 0.0, false))
	for i in 6:
		await tree.physics_frame
	failures += _check(tree.get_nodes_in_group("enemy").size() == 2, "lo scheletro muore e sparisce", notes)
	failures += _check(tree.get_nodes_in_group("loot").size() > loot_before, "lascia oro a terra", notes)

	if tree.get_nodes_in_group("loot").size() > 0:
		var coin := tree.get_nodes_in_group("loot")[0] as Node2D
		player.global_position = coin.global_position
		player.stop()
		for i in 12:
			await tree.physics_frame
		failures += _check(player.gold > 0, "il giocatore raccoglie l'oro (%d)" % player.gold, notes)
	else:
		failures += _check(false, "oro raccoglibile presente", notes)

	# Il numero del danno deve sparire da solo: un nodo che resta e' una perdita di memoria.
	var number := DamageNumber.spawn(world, Vector2(900.0, 900.0), 5, false)
	for i in 55:
		await tree.physics_frame
	failures += _check(not is_instance_valid(number), "il numero del danno si elimina da solo", notes)

	# =====================================================================
	# Verifiche chieste prima della fase 3
	# =====================================================================

	player.hp = player.max_hp

	# --- Attacco tenendo premuto: il comando e' continuo, il bersaglio viene inseguito e
	# colpito piu' volte; al rilascio si smette. ---
	var dummy: Enemy = world.enemies[1]
	dummy.stand_down()
	dummy.max_hp = 9999
	dummy.hp = 9999
	dummy.global_position = FloorBuilder.cell_center(Vector2i(17, 8))
	# Il terzo scheletro va tolto di mezzo: altrimenti entra nel combattimento e falsa la
	# misura (colpisce il giocatore mentre questo insegue il bersaglio).
	var bystander: Enemy = world.enemies[2]
	bystander.stand_down()
	bystander.global_position = FloorBuilder.cell_center(Vector2i(3, 14))
	player.global_position = FloorBuilder.cell_center(Vector2i(11, 8))
	player.stop()
	for i in 6:
		await tree.physics_frame

	player.set_hold(true, dummy.global_position)
	for i in 120:
		await tree.physics_frame
	var held_hits := 9999 - dummy.hp
	var approach := player.global_position.distance_to(dummy.global_position)
	failures += _check(held_hits >= 30, "tenendo premuto il tasto il giocatore continua a colpire (%d danni)" % held_hits, notes)
	failures += _check(approach < 60.0, "tenendo premuto il tasto il giocatore raggiunge il bersaglio (%.0f px)" % approach, notes)

	# Il bersaglio si sposta: senza un nuovo clic il giocatore deve seguirlo.
	dummy.global_position += Vector2(120.0, 0.0)
	var player_before_follow := player.global_position
	for i in 90:
		await tree.physics_frame
	var followed := player.global_position.x - player_before_follow.x
	failures += _check(followed > 40.0, "il giocatore insegue il bersaglio che si sposta (%.0f px)" % followed, notes)

	player.set_hold(false, Vector2.ZERO)
	for i in 10:
		await tree.physics_frame
	var hp_after_release := dummy.hp
	for i in 60:
		await tree.physics_frame
	failures += _check(dummy.hp == hp_after_release, "rilasciando il tasto il giocatore smette di colpire", notes)
	dummy.stand_down()
	dummy.global_position = FloorBuilder.cell_center(Vector2i(2, 14))

	# --- Contraccolpo contro il muro: non entra e non vibra. ---
	player.global_position = FloorBuilder.cell_center(Vector2i(11, 12))
	player.stop()
	var wall_face := float(GameConsts.CELL)
	bystander.stand_down()
	bystander.global_position = Vector2(wall_face + 10.0 + 0.5, FloorBuilder.cell_center(Vector2i(2, 8)).y)
	bystander.velocity = Vector2.ZERO
	for i in 4:
		await tree.physics_frame
	bystander.take_hit(Damage.make(1, Damage.Kind.FISICO, Vector2.LEFT, 400.0, false))
	var min_clearance := INF
	for i in 60:
		await tree.physics_frame
		min_clearance = minf(min_clearance, bystander.global_position.x - wall_face)
	var settled := bystander.global_position
	for i in 30:
		await tree.physics_frame
	var drift := bystander.global_position.distance_to(settled)
	failures += _check(min_clearance >= 9.0, "il contraccolpo non fa entrare lo scheletro nel muro (%.1f px dal muro)" % min_clearance, notes)
	failures += _check(drift < 1.5, "lo scheletro contro il muro non vibra (%.2f px in 30 frame)" % drift, notes)

	# --- Quattro scheletri in un corridoio largo una cella. ---
	player.hp = player.max_hp
	player.global_position = FloorBuilder.cell_center(Vector2i(22, 3))
	player.stop()
	var walkers: Array[Enemy] = []
	var start_line := FloorBuilder.cell_center(Vector2i(8, 3))
	for i in 4:
		var walker := world.spawn_skeleton(Vector2i(8, 3))
		walker.global_position = start_line + Vector2(float(i) * 28.0, 0.0)
		walker.velocity = Vector2.ZERO
		walkers.append(walker)
	for i in 4:
		await tree.physics_frame
	for walker in walkers:
		walker.alert()

	var starts: Array[Vector2] = []
	var lasts: Array[Vector2] = []
	var still_frames: Array[int] = [0, 0, 0, 0]
	var worst_still := 0
	for walker in walkers:
		starts.append(walker.global_position)
		lasts.append(walker.global_position)
	for f in 150:
		await tree.physics_frame
		for idx in walkers.size():
			var walker: Enemy = walkers[idx]
			if walker.global_position.distance_to(lasts[idx]) < 0.4:
				still_frames[idx] += 1
				worst_still = maxi(worst_still, still_frames[idx])
			else:
				still_frames[idx] = 0
			lasts[idx] = walker.global_position

	var moved_min := INF
	for idx in walkers.size():
		moved_min = minf(moved_min, walkers[idx].global_position.distance_to(starts[idx]))
	failures += _check(moved_min > 100.0, "quattro scheletri percorrono il corridoio (minimo %.0f px)" % moved_min, notes)
	failures += _check(worst_still <= 60, "nessuno resta fermo piu' di un secondo (max %d frame)" % worst_still, notes)
	for walker in walkers:
		world.enemies.erase(walker)
		walker.queue_free()

	# =====================================================================
	# Fase 3: oggetti, inventario, equipaggiamento, morte senza perdite
	# =====================================================================

	var avvisi: Array[String] = []
	EventBus.notice.connect(func(testo: String) -> void: avvisi.append(testo))

	# --- Generatore: forme ammesse, affissi coerenti, nome e valore sempre presenti ---
	var rng_prova := Rng.new(987654)
	var forme_ammesse: Array[Vector2i] = [
		Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3),
		Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4),
	]
	var forme_ok := true
	var affissi_ok := true
	var dati_ok := true
	for i in 150:
		var generato := ItemGenerator.roll(rng_prova, 1 + i % 12)
		if not forme_ammesse.has(generato.size()):
			forme_ok = false
		if generato.valore() <= 0 or generato.nome().is_empty():
			dati_ok = false
		var quanti_affissi := generato.affissi.size()
		match generato.rarita:
			Item.Rarita.NORMALE:
				if quanti_affissi != 0:
					affissi_ok = false
			Item.Rarita.MAGICO:
				if quanti_affissi < 1 or quanti_affissi > 2:
					affissi_ok = false
			Item.Rarita.RARO:
				if quanti_affissi < 2 or quanti_affissi > 3:
					affissi_ok = false
	failures += _check(forme_ok, "150 oggetti generati hanno solo forme ammesse", notes)
	failures += _check(affissi_ok, "numero di affissi coerente con la rarita'", notes)
	failures += _check(dati_ok, "ogni oggetto generato ha nome e valore", notes)

	# --- Griglia e pannello: si parte da uno stato noto ---
	var panel: InventoryPanel = main.inventory_panel
	var inv: Inventory = player.inventory
	inv.oggetti.clear()
	for s in player.equipment.numero_slot():
		player.equipment.togli(s)
	panel.collega(player)
	panel.apri()

	var spadone := Item.new(ItemBase.per_id("spadone"))
	failures += _check(inv.aggiungi_a(spadone, Vector2i(0, 0)), "lo spadone 2x4 entra in (0,0)", notes)

	# Fuori griglia: 2x4 appoggiato in (9,4) sborda a destra e in basso.
	panel.prendi(spadone)
	var fuori := panel.rilascia(panel.punto_cella(Vector2i(9, 4)))
	failures += _check(
		not fuori and spadone.pos == Vector2i(0, 0) and inv.oggetti.has(spadone),
		"oggetto fuori griglia rifiutato e rimesso a posto",
		notes
	)

	var elmo := Item.new(ItemBase.per_id("elmo"))
	failures += _check(inv.aggiungi_a(elmo, Vector2i(5, 0)), "l'elmo 2x2 entra in (5,0)", notes)
	panel.prendi(elmo)
	var sovrapposto := panel.rilascia(panel.punto_cella(Vector2i(1, 1)))
	failures += _check(
		not sovrapposto and elmo.pos == Vector2i(5, 0) and spadone.pos == Vector2i(0, 0),
		"oggetto su oggetto rifiutato, nessuna sovrapposizione",
		notes
	)

	panel.prendi(elmo)
	var spostato := panel.rilascia(panel.punto_cella(Vector2i(5, 3)))
	failures += _check(spostato and elmo.pos == Vector2i(5, 3), "spostamento valido eseguito", notes)

	# --- Chiusura del pannello mentre si trascina ---
	panel.prendi(elmo)
	panel.chiudi()
	failures += _check(
		panel.trascinato() == null and inv.oggetti.has(elmo) and elmo.pos == Vector2i(5, 3),
		"chiudere il pannello durante il trascinamento non perde l'oggetto",
		notes
	)
	panel.apri()

	# --- Equipaggiamento: categoria sbagliata rifiutata, giusta accettata ---
	panel.prendi(spadone)
	var in_corazza := panel.rilascia(panel.punto_slot(Equipment.Slot.CORAZZA))
	failures += _check(
		not in_corazza and player.equipment.oggetto(Equipment.Slot.CORAZZA) == null and inv.oggetti.has(spadone),
		"arma rifiutata dallo slot della corazza e rimessa nello zaino",
		notes
	)
	panel.prendi(spadone)
	var in_arma := panel.rilascia(panel.punto_slot(Equipment.Slot.ARMA))
	failures += _check(
		in_arma and player.equipment.oggetto(Equipment.Slot.ARMA) == spadone and not inv.oggetti.has(spadone),
		"arma equipaggiata nello slot dell'arma",
		notes
	)
	panel.prendi(spadone)
	var tolto := panel.rilascia(panel.punto_cella(Vector2i(0, 0)))
	failures += _check(
		tolto and player.equipment.oggetto(Equipment.Slot.ARMA) == null and inv.oggetti.has(spadone),
		"l'arma si toglie trascinandola nello zaino",
		notes
	)

	# --- Danno e difesa cambiano davvero ---
	var danno_nudo := player.danno_fendente()
	panel.prendi(spadone)
	panel.rilascia(panel.punto_slot(Equipment.Slot.ARMA))
	var danno_armato := player.danno_fendente()
	failures += _check(danno_armato > danno_nudo, "l'arma aumenta il danno (%d -> %d)" % [danno_nudo, danno_armato], notes)

	var colpo := Damage.make(20, Damage.Kind.FISICO, Vector2.RIGHT, 0.0, false)
	var subito_nudo := player.danno_ridotto(colpo)
	player.equipment.equipaggia(Equipment.Slot.CORAZZA, Item.new(ItemBase.per_id("corazza_pesante")))
	player.equipment.equipaggia(Equipment.Slot.ELMO, Item.new(ItemBase.per_id("elmo")))
	var subito_armato := player.danno_ridotto(colpo)
	failures += _check(
		subito_armato < subito_nudo,
		"la difesa riduce il danno ricevuto (%d -> %d su 20, difesa %d)" % [subito_nudo, subito_armato, player.difesa()],
		notes
	)
	player.hp = player.max_hp
	var hp_prima_colpo := player.hp
	player.take_hit(colpo)
	failures += _check(
		hp_prima_colpo - player.hp == subito_armato,
		"il colpo toglie il danno ridotto, non quello pieno (%d)" % (hp_prima_colpo - player.hp),
		notes
	)
	# --- Cintura: accetta solo 1x1, e il rifiuto non smonta l'equipaggiamento ---
	var anello := Item.new(ItemBase.per_id("anello"))
	failures += _check(inv.aggiungi(anello), "l'anello 1x1 entra nello zaino", notes)
	panel.prendi(anello)
	var in_cintura := panel.rilascia(panel.punto_cintura(1))
	failures += _check(in_cintura and anello.cintura == 1, "l'anello si mette nella cintura", notes)
	panel.prendi(spadone)
	var spadone_in_cintura := panel.rilascia(panel.punto_cintura(2))
	failures += _check(
		not spadone_in_cintura and player.equipment.oggetto(Equipment.Slot.ARMA) == spadone,
		"lo spadone non entra nella cintura e resta equipaggiato",
		notes
	)

	# --- Tooltip: nome, rarita' e proprieta' leggibili ---
	var suggerimento := Tooltip.new()
	main.add_child(suggerimento)
	suggerimento.mostra(spadone, Vector2(10.0, 10.0))
	failures += _check(
		suggerimento.visible and suggerimento.size.x > 100.0 and spadone.righe().size() >= 3,
		"il tooltip si apre con nome e proprieta' (%d righe)" % spadone.righe().size(),
		notes
	)
	suggerimento.queue_free()
	panel.chiudi()

	# --- I barili lasciano oggetti, non solo monete ---
	for nodo in tree.get_nodes_in_group("ground_item"):
		nodo.queue_free()
	await tree.physics_frame
	for i in 18:
		var barile := PropBody.new()
		barile.setup(PropBody.Kind.BARILE, 0.0)
		barile.rng = rng_prova
		world.add_child(barile)
		barile.global_position = FloorBuilder.cell_center(Vector2i(2 + i % 18, 1))
		barile.take_hit(Damage.make(99, Damage.Kind.FISICO, Vector2.RIGHT, 0.0, false))
	await tree.physics_frame
	var da_barili := tree.get_nodes_in_group("ground_item").size()
	failures += _check(da_barili > 0, "i barili rotti lasciano oggetti (%d su 18)" % da_barili, notes)
	for nodo in tree.get_nodes_in_group("ground_item"):
		nodo.queue_free()
	await tree.physics_frame

	# --- Zaino pieno: l'oggetto resta a terra ---
	inv.oggetti.clear()
	for i in Inventory.COLONNE * Inventory.RIGHE:
		inv.aggiungi(Item.new(ItemBase.per_id("anello")))
	failures += _check(inv.pieno() and inv.quantita() == 60, "zaino riempito (60 celle su 60)", notes)
	player.global_position = FloorBuilder.cell_center(Vector2i(11, 8))
	player.stop()
	avvisi.clear()
	var caduto := GroundItem.spawn(world, player.global_position, Item.new(ItemBase.per_id("mazza")))
	for i in 10:
		await tree.physics_frame
	failures += _check(
		is_instance_valid(caduto) and inv.quantita() == 60 and avvisi.has("Zaino pieno"),
		"a zaino pieno l'oggetto resta a terra e il gioco lo dice",
		notes
	)
	caduto.queue_free()

	# --- Morte: stessi oggetti, stessi uid, solo l'oro paga ---
	player.gold = 100
	var uid_prima: Array[int] = []
	for item in inv.oggetti:
		uid_prima.append(item.uid)
	for item in player.equipment.tutti():
		uid_prima.append(item.uid)
	uid_prima.sort()
	var indossati_prima := player.equipment.quantita()

	player.take_hit(Damage.make(9999, Damage.Kind.FISICO, Vector2.ZERO, 0.0, false))
	failures += _check(main.state == Main.AppState.DEAD, "il giocatore muore", notes)
	await main._restart()
	await tree.physics_frame

	var rinato: Player = world.player
	var uid_dopo: Array[int] = []
	for item in rinato.inventory.oggetti:
		uid_dopo.append(item.uid)
	for item in rinato.equipment.tutti():
		uid_dopo.append(item.uid)
	uid_dopo.sort()
	failures += _check(
		uid_dopo == uid_prima,
		"dopo la morte gli oggetti sono gli stessi (%d uid, %d indossati)" % [uid_dopo.size(), indossati_prima],
		notes
	)
	failures += _check(
		rinato.equipment.quantita() == indossati_prima,
		"l'equipaggiamento resta indossato dopo la rinascita",
		notes
	)
	failures += _check(rinato.gold == 95, "penalita' di morte: solo il 5 per cento dell'oro (100 -> %d)" % rinato.gold, notes)
	failures += _check(rinato.alive and rinato.hp == rinato.max_hp, "si rinasce vivi e con la vita piena (%d/%d)" % [rinato.hp, rinato.max_hp], notes)

	_report(failures, notes)
	tree.quit(0 if failures == 0 else 1)

static func _check(condition: bool, label: String, notes: PackedStringArray) -> int:
	notes.append(("OK    " if condition else "FALLITO ") + label)
	return 0 if condition else 1

static func _report(failures: int, notes: PackedStringArray) -> void:
	for note in notes:
		print("  ", note)
	if failures == 0:
		print("SELFTEST OK (fallimenti: 0)")
	else:
		print("SELFTEST FALLITO (fallimenti: %d)" % failures)

static func _count_value(grid: Array, value: int) -> int:
	var total := 0
	for row in grid:
		var cells: PackedByteArray = row
		for cell in cells:
			if cell == value:
				total += 1
	return total

static func _nearest_prop(props: Array[PropBody], point: Vector2) -> PropBody:
	var best: PropBody = null
	var best_distance := INF
	for prop in props:
		var distance := prop.global_position.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = prop
	return best
