extends Node2D

var cale_salvare = "user://salvare_joc.ini"

func _ready() -> void:
	incarca_volum()

# ----------------- BUTOANE DESKTOP & TASKBAR -----------------

func _on_button_pressed() -> void:
	# Butonul de ShutDown de pe bara desktop-ului (închide aplicația complet)
	get_tree().quit()

func _on_texture_button_pressed() -> void:
	pass

func _on_x_pressed() -> void:
	# Butonul X din bara de sus a ferestrei jocului
	inchide_fereastra_meniu()

func _on_buton_taskbar_pressed() -> void:
	if %Meniu.visible:
		%Meniu.hide()
	else:
		%Meniu.show()
		%ButonTaskbar.show()

# ----------------- MENIU PRINCIPAL -----------------

func _on_buton_new_game_pressed() -> void:
	var config = ConfigFile.new()
	var err = config.load(cale_salvare)
	var are_salvare = (err == OK and config.get_value("Save", "has_save", false) == true)
	
	if are_salvare:
		# Dacă există deja o salvare, întrebăm jucătorul în engleză dacă vrea să o șteargă și să înceapă un joc nou
		ascunde_toate_submeniurile()
		%PopupOverwriteSave.show()
	else:
		# Dacă nu există nicio salvare anterioară, intrăm direct în alegerea dificultății
		ascunde_toate_submeniurile()
		%GrupDificultate.show()

func _on_buton_overwrite_yes_pressed() -> void:
	# Jucătorul a ales YES: merge mai departe la selectarea dificultății
	ascunde_toate_submeniurile()
	%GrupDificultate.show()

func _on_buton_overwrite_no_pressed() -> void:
	# Jucătorul a ales NO: îl trimite înapoi la meniul principal
	ascunde_toate_submeniurile()
	%GrupPrincipal.show()

func _on_back_pressed() -> void:
	ascunde_toate_submeniurile()
	%GrupPrincipal.show()

func _on_buton_load_pressed() -> void:
	var config = ConfigFile.new()
	var err = config.load(cale_salvare)
	var are_salvare = (err == OK and config.get_value("Save", "has_save", false) == true)
	
	if are_salvare:
		print("Salvare găsită! Se încarcă nivelul...")
		get_tree().change_scene_to_file("res://level_1.tscn")
	else:
		# Dacă nu există nicio salvare până acum, afișează mesajul "NO SAVED GAME EXISTS"
		ascunde_toate_submeniurile()
		%PopupFaraSalvare.show()

func _on_back_1_pressed() -> void:
	ascunde_toate_submeniurile()
	%GrupPrincipal.show()

func _on_buton_options_pressed() -> void:
	ascunde_toate_submeniurile()
	%GrupOptiuni.show()

func _on_back_options_pressed() -> void:
	ascunde_toate_submeniurile()
	%GrupPrincipal.show()

func _on_buton_extras_pressed() -> void:
	ascunde_toate_submeniurile()
	%GrupExtras.show()

func _on_back_extras_pressed() -> void:
	ascunde_toate_submeniurile()
	%GrupPrincipal.show()

# ----------------- POPUP QUIT -----------------

func _on_buton_quit_pressed() -> void:
	ascunde_toate_submeniurile()
	%PopupQuit.show()

func _on_buton_quit_no_pressed() -> void:
	# Apasă NO: revine la meniul principal
	ascunde_toate_submeniurile()
	%GrupPrincipal.show()

func _on_buton_quit_yes_pressed() -> void:
	# Apasă YES: îl trimite înapoi pe desktop-ul creat (închide fereastra ferestrei Meniu)
	inchide_fereastra_meniu()

# ----------------- DIFICULTATE -----------------

func _on_easy_pressed() -> void:
	incepe_joc_cu_dificultate("easy")

func _on_medium_pressed() -> void:
	incepe_joc_cu_dificultate("medium")

func _on_hard_pressed() -> void:
	incepe_joc_cu_dificultate("hard")

func incepe_joc_cu_dificultate(dificultate: String) -> void:
	var config = ConfigFile.new()
	config.load(cale_salvare)
	config.set_value("Player", "difficulty", dificultate)
	# Fiind un joc nou (START NEW GAME), resetăm salvarea anterioară
	config.set_value("Save", "has_save", false)
	config.set_value("Save", "medusa_defeated", false)
	config.set_value("Save", "executioner_defeated", false)
	if config.has_section("Player"):
		config.erase_section_key("Player", "pos_x")
		config.erase_section_key("Player", "pos_y")
	config.save(cale_salvare)
	get_tree().change_scene_to_file("res://level_1.tscn")

# ----------------- SETĂRI AUDIO / VOLUM -----------------

func _on_volume_slider_value_changed(value: float) -> void:
	var master_bus_idx = AudioServer.get_bus_index("Master")
	if value <= 0.0:
		AudioServer.set_bus_mute(master_bus_idx, true)
	else:
		AudioServer.set_bus_mute(master_bus_idx, false)
		var db = linear_to_db(value / 100.0)
		AudioServer.set_bus_volume_db(master_bus_idx, db)
	
	if has_node("%VolumePercentLabel"):
		%VolumePercentLabel.text = str(int(value)) + "%"

func incarca_volum() -> void:
	var master_bus_idx = AudioServer.get_bus_index("Master")
	var val = 80.0
	if AudioServer.is_bus_mute(master_bus_idx):
		val = 0.0
	else:
		var current_db = AudioServer.get_bus_volume_db(master_bus_idx)
		val = clamp(round(db_to_linear(current_db) * 100.0), 0.0, 100.0)
	
	if has_node("%VolumeSlider"):
		%VolumeSlider.value = val
	if has_node("%VolumePercentLabel"):
		%VolumePercentLabel.text = str(int(val)) + "%"

# ----------------- METODE AJUTĂTOARE -----------------

func inchide_fereastra_meniu() -> void:
	%Meniu.hide()
	%ButonTaskbar.hide()
	ascunde_toate_submeniurile()
	%GrupPrincipal.show()

func ascunde_toate_submeniurile() -> void:
	%GrupPrincipal.hide()
	%GrupDificultate.hide()
	%PopupFaraSalvare.hide()
	%GrupOptiuni.hide()
	if has_node("%GrupExtras"):
		%GrupExtras.hide()
	if has_node("%PopupQuit"):
		%PopupQuit.hide()
	if has_node("%PopupOverwriteSave"):
		%PopupOverwriteSave.hide()
