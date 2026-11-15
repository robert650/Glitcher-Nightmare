extends Node2D

var cale_salvare = "user://salvare_joc.ini"
var jucator_in_zona = false

# Sistem Dialog Boss
var dialog_inceput: bool = false
var in_dialog: bool = false
var dialog_index: int = 0

var dialog_lines: Array = [
	{
		"speaker": "HERO",
		"text": "The Undead Executioner... Death itself stands before me. Let's finish this!",
		"side": "left",
		"portrait": "res://prototype_portraits/Prototype/Aggression.png"
	}
]

func _ready() -> void:
	# 1. Textul de bun venit ("WELCOME TO THE GAME!") dispare automat după un scurt timp
	if has_node("Label"):
		var tween = create_tween()
		tween.tween_interval(2.5) # Rămâne pe ecran 2.5 secunde
		tween.tween_property($Label, "modulate:a", 0.0, 1.0) # Se estompează lin în 1 secundă
		tween.tween_callback($Label.hide)

	# 2. Asigură că bara de viață a boss-ului este ASCUNSĂ la începutul nivelului
	if has_node("CanvasLayer/BossHealthBarUI"):
		$CanvasLayer/BossHealthBarUI.hide()

	# 3. Inițializare portrete dialog la pornire
	if has_node("CanvasLayer/DialogueUI/DialoguePanel/LeftPortrait"):
		$CanvasLayer/DialogueUI/DialoguePanel/LeftPortrait.texture = load("res://prototype_portraits/Prototype/Calm.png")
	if has_node("CanvasLayer/DialogueUI/DialoguePanel/RightPortrait"):
		$CanvasLayer/DialogueUI/DialoguePanel/RightPortrait.texture = load("res://dark_elf_queen/Queen/Calm.png")

func _unhandled_input(event: InputEvent) -> void:
	# Control tastatură pentru BannerVictorie dacă este deschis
	if has_node("CanvasLayer/BannerVictorie") and $CanvasLayer/BannerVictorie.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE] or event.keycode in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
				_on_buton_go_to_menu_pressed()
				get_viewport().set_input_as_handled()
				return

	# Control tastatură pentru PopupSalvare dacă este deschis
	if has_node("CanvasLayer/PopupSalvare") and $CanvasLayer/PopupSalvare.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode in [KEY_Y, KEY_SPACE, KEY_ENTER] or event.keycode in [KEY_Y, KEY_SPACE, KEY_ENTER]:
				_on_buton_save_yes_pressed()
				get_viewport().set_input_as_handled()
				return
			elif event.physical_keycode in [KEY_N, KEY_ESCAPE] or event.keycode in [KEY_N, KEY_ESCAPE]:
				_on_buton_save_no_pressed()
				get_viewport().set_input_as_handled()
				return

	# Avansare dialog dacă este activ
	if in_dialog and event.is_pressed() and not event.is_echo():
		if event is InputEventKey:
			if event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_E] or event.keycode in [KEY_SPACE, KEY_ENTER, KEY_E]:
				avanseaza_dialog()
				return
		elif event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				avanseaza_dialog()
				return

	# Când jucătorul este lângă fântână și apasă tasta E
	if jucator_in_zona and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E or event.keycode == KEY_E:
			interactioneaza_cu_fantana()

# ==================== SISTEM DIALOG & BOSS ====================

func _on_trigger_boss_zone_body_entered(body: Node2D) -> void:
	if (body.is_in_group("Jucator") or body.name == "Player") and not dialog_inceput:
		var queen = get_tree().get_first_node_in_group("Boss")
		if queen and is_instance_valid(queen) and not queen.e_mort:
			porneste_dialog_boss()

func porneste_dialog_boss() -> void:
	dialog_inceput = true
	in_dialog = true
	dialog_index = 0
	opreste_jucator(true)
	
	if has_node("CanvasLayer/DialogueUI"):
		$CanvasLayer/DialogueUI.show()
		afiseaza_linie_curenta()

func avanseaza_dialog() -> void:
	dialog_index += 1
	if dialog_index < dialog_lines.size():
		afiseaza_linie_curenta()
	else:
		incheie_dialog()

func afiseaza_linie_curenta() -> void:
	var linie = dialog_lines[dialog_index]
	var panel = $CanvasLayer/DialogueUI/DialoguePanel
	var lbl_speaker = panel.get_node("LabelSpeaker")
	var lbl_text = panel.get_node("LabelText")
	var p_left = panel.get_node("LeftPortrait")
	var p_right = panel.get_node("RightPortrait")
	
	lbl_speaker.text = linie["speaker"]
	lbl_text.text = linie["text"]
	
	if p_right:
		p_right.hide()
	
	if p_left:
		p_left.show()
		p_left.texture = load(linie["portrait"])
		p_left.modulate = Color(1.0, 1.0, 1.0, 1.0)
	lbl_speaker.set("theme_override_colors/font_color", Color(0.25, 0.85, 1.0, 1.0))

func incheie_dialog() -> void:
	in_dialog = false
	opreste_jucator(false)
	
	if has_node("CanvasLayer/DialogueUI"):
		$CanvasLayer/DialogueUI.hide()
	
	# Activează bara lungă de viață jos pe ecran
	if has_node("CanvasLayer/BossHealthBarUI"):
		$CanvasLayer/BossHealthBarUI.show()
		$CanvasLayer/BossHealthBarUI.modulate.a = 0.0
		var tw = create_tween()
		tw.tween_property($CanvasLayer/BossHealthBarUI, "modulate:a", 1.0, 0.6)
		
	# Declanșează lupta cu Undead Executioner
	var boss = get_tree().get_first_node_in_group("Boss")
	if boss and boss.has_method("activeaza_lupta"):
		boss.activeaza_lupta()

func opreste_jucator(oprit: bool) -> void:
	var player = get_tree().get_first_node_in_group("Jucator")
	if player:
		player.set_physics_process(not oprit)
		if oprit:
			player.velocity = Vector2.ZERO
			if player.has_node("AnimatedSprite2D"):
				player.get_node("AnimatedSprite2D").play("idle")

func _on_button_next_pressed() -> void:
	if in_dialog:
		avanseaza_dialog()

func arata_bara_boss() -> void:
	if has_node("CanvasLayer/BossHealthBarUI"):
		var ui = $CanvasLayer/BossHealthBarUI
		ui.visible = true
		ui.modulate.a = 1.0

func _process(_delta: float) -> void:
	var player = get_tree().get_first_node_in_group("Jucator")
	var boss = get_tree().get_first_node_in_group("Boss")
	if player and boss and is_instance_valid(boss) and not boss.e_mort:
		var dist = boss.global_position.distance_to(player.global_position)
		# Bara de viață apare DOAR când te apropii de el (când începi să-l vezi: X >= 4250 sau distanță <= 550px)
		if player.global_position.x >= 4250.0 or dist <= 550.0:
			arata_bara_boss()
			if not boss.lupta_activa and boss.has_method("activeaza_lupta"):
				boss.activeaza_lupta()
		elif not boss.lupta_activa:
			# Dacă ești departe (la fântână sau început de hartă), bara este garantat ascunsă!
			if has_node("CanvasLayer/BossHealthBarUI") and $CanvasLayer/BossHealthBarUI.visible:
				$CanvasLayer/BossHealthBarUI.hide()

func _on_boss_hp_changed(current_hp: int, max_hp: int) -> void:
	var player = get_tree().get_first_node_in_group("Jucator")
	var boss = get_tree().get_first_node_in_group("Boss")
	if boss and is_instance_valid(boss) and not boss.e_mort:
		if boss.lupta_activa or (player and player.global_position.x >= 4250.0):
			arata_bara_boss()

	if has_node("CanvasLayer/BossHealthBarUI/ProgressBar"):
		var bar = $CanvasLayer/BossHealthBarUI/ProgressBar
		bar.max_value = max_hp
		var tween = create_tween()
		tween.tween_property(bar, "value", float(current_hp), 0.25)
		if bar.has_node("LabelHpText"):
			bar.get_node("LabelHpText").text = str(current_hp) + " / " + str(max_hp) + " HP"

func _on_boss_defeated() -> void:
	if has_node("CanvasLayer/BossHealthBarUI"):
		var tween_bar = create_tween()
		tween_bar.tween_property($CanvasLayer/BossHealthBarUI, "modulate:a", 0.0, 0.8)
		tween_bar.tween_callback($CanvasLayer/BossHealthBarUI.hide)
		
	if has_node("CanvasLayer/BannerVictorie"):
		$CanvasLayer/BannerVictorie.show()
		$CanvasLayer/BannerVictorie.modulate.a = 0.0
		var tween_v = create_tween()
		tween_v.tween_property($CanvasLayer/BannerVictorie, "modulate:a", 1.0, 0.8)
		if has_node("CanvasLayer/BannerVictorie/ButonGoToMenu") and $CanvasLayer/BannerVictorie/ButonGoToMenu.is_inside_tree():
			$CanvasLayer/BannerVictorie/ButonGoToMenu.grab_focus()

func _on_buton_go_to_menu_pressed() -> void:
	print("Tranziție către Meniu...")
	get_tree().change_scene_to_file("res://Desktop.tscn")

func _on_undead_executioner_boss_hp_changed(current_hp: int, max_hp: int) -> void:
	_on_boss_hp_changed(current_hp, max_hp)

func _on_undead_executioner_boss_defeated() -> void:
	_on_boss_defeated()

func _on_queen_boss_boss_hp_changed(current_hp: int, max_hp: int) -> void:
	_on_boss_hp_changed(current_hp, max_hp)

func _on_queen_boss_boss_defeated() -> void:
	_on_boss_defeated()

# ==================== FÂNTÂNĂ & SALVARE ====================

func _on_park_zone_tileset_fountain_4_body_entered(body: Node2D) -> void:
	if body.is_in_group("Jucator") or body.name == "Player":
		jucator_in_zona = true
		if has_node("ParkZoneTilesetFountain4/Label"):
			$ParkZoneTilesetFountain4/Label.text = "[E] DRINK & HEAL"
			$ParkZoneTilesetFountain4/Label.show()

func _on_park_zone_tileset_fountain_4_body_exited(body: Node2D) -> void:
	if body.is_in_group("Jucator") or body.name == "Player":
		jucator_in_zona = false
		if has_node("ParkZoneTilesetFountain4/Label"):
			$ParkZoneTilesetFountain4/Label.hide()
		if has_node("CanvasLayer/PopupSalvare"):
			$CanvasLayer/PopupSalvare.hide()
		if has_node("CanvasLayer/BannerAvertisment"):
			$CanvasLayer/BannerAvertisment.hide()

func interactioneaza_cu_fantana() -> void:
	# Verificare dacă Meduza este încă în viață
	var meduza_in_viata = false
	var meduze = get_tree().get_nodes_in_group("Meduza")
	for m in meduze:
		if is_instance_valid(m) and not m.e_mort:
			meduza_in_viata = true
			break

	# Dacă Meduza nu a fost încă bătută, nu ai voie să salvezi!
	if meduza_in_viata:
		print("Meduza trăiește! Salvarea este blocată până la înfrângerea ei.")
		afiseaza_avertisment("YOU NEED TO DEFEAT ALL THE ENEMIES!")
		return

	# Dacă Meduza a fost învinsă:
	# 1. Regenerare lină a vieții jucătorului până la 100 HP
	var player = get_tree().get_first_node_in_group("Jucator")
	if player and not player.e_mort:
		var start_hp = float(player.viata_jucator)
		var tween = create_tween()
		tween.tween_method(func(val: float):
			player.viata_jucator = int(val)
			if player.has_node("UI/BaraViata"):
				player.get_node("UI/BaraViata").value = int(val)
		, start_hp, 100.0, 0.6)
		print("Viața jucătorului a fost regenerată la fântână!")

	# 2. Deschide mini ecranul cu întrebarea de salvare
	if has_node("CanvasLayer/PopupSalvare"):
		$CanvasLayer/PopupSalvare/LabelQuestion.text = "DO YOU WANT TO SAVE?"
		$CanvasLayer/PopupSalvare/ButonSaveYes.show()
		$CanvasLayer/PopupSalvare/ButonSaveNo.show()
		$CanvasLayer/PopupSalvare.show()
		$CanvasLayer/PopupSalvare/ButonSaveYes.grab_focus()

func afiseaza_avertisment(mesaj: String) -> void:
	if has_node("ParkZoneTilesetFountain4/Label"):
		$ParkZoneTilesetFountain4/Label.text = mesaj

	if has_node("CanvasLayer/BannerAvertisment"):
		$CanvasLayer/BannerAvertisment/LabelAvertisment.text = mesaj
		$CanvasLayer/BannerAvertisment.show()
		$CanvasLayer/BannerAvertisment.modulate.a = 1.0

		var tween = create_tween()
		tween.tween_interval(2.2)
		tween.tween_property($CanvasLayer/BannerAvertisment, "modulate:a", 0.0, 0.5)
		tween.tween_callback($CanvasLayer/BannerAvertisment.hide)

	# Resetează textul de pe fântână după câteva secunde dacă jucătorul e încă în zonă
	await get_tree().create_timer(2.7).timeout
	if jucator_in_zona and has_node("ParkZoneTilesetFountain4/Label"):
		$ParkZoneTilesetFountain4/Label.text = "[E] DRINK & HEAL"

func _on_buton_save_yes_pressed() -> void:
	var config = ConfigFile.new()
	config.load(cale_salvare)
	config.set_value("Save", "has_save", true)
	config.set_value("Save", "medusa_defeated", true)
	config.set_value("Player", "scene", "res://level_1.tscn")
	
	var player = get_tree().get_first_node_in_group("Jucator")
	if player:
		config.set_value("Player", "pos_x", player.global_position.x)
		config.set_value("Player", "pos_y", player.global_position.y)
	
	config.save(cale_salvare)
	print("Joc salvat cu succes la poziția: ", player.global_position if player else Vector2.ZERO)

	if has_node("CanvasLayer/PopupSalvare"):
		$CanvasLayer/PopupSalvare/LabelQuestion.text = "GAME SAVED!"
		$CanvasLayer/PopupSalvare/ButonSaveYes.hide()
		$CanvasLayer/PopupSalvare/ButonSaveNo.hide()
		await get_tree().create_timer(0.9).timeout
		$CanvasLayer/PopupSalvare.hide()

func _on_buton_save_no_pressed() -> void:
	if has_node("CanvasLayer/PopupSalvare"):
		$CanvasLayer/PopupSalvare.hide()
