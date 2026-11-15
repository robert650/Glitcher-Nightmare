extends CharacterBody2D

const SPEED = 250.0
const JUMP_VELOCITY = -350.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var stare_actuala = "om" 
var viata_jucator = 100
var e_mort = false

# Dificultate și daune dinamice
var damage_normal: int = 25
var damage_special: int = 110

# Sistem Ultimate [F]
var ult_curenta: float = 0.0
const ULT_MAX: float = 100.0
var invulnerabil_ult: bool = false
var tasta_f_apasata_anterior: bool = false
var tween_feedback_ult: Tween = null

var a_facut_primul_summon: bool = false      # Devine true după prima transformare (summon)
var inamici_loviti_in_acest_atac: Array = []  # Asigură lovirea o singură dată per atac

@export var limita_void: float = 720.0       # Coordonata Y sub care se consideră cădere în void
@export var restart_scena_la_void: bool = true # True: reîncarcă nivelul; False: teleportează la început
var pozitie_start: Vector2 = Vector2.ZERO

const GHOST_PROJECTILE_SCENE = preload("res://ghost_projectile.tscn")

func _ready():
	add_to_group("Jucator")
	
	# SETARE HUD: Conectează bara de viață și bara de ult la pornirea jocului
	if has_node("UI/BaraViata"):
		$UI/BaraViata.max_value = viata_jucator
		$UI/BaraViata.value = viata_jucator

	actualizeaza_hud_ult()

	# Încărcare dificultate din salvare și ajustare daune jucător
	incarca_dificultate()

	# Dacă există salvare activă, respawnează jucătorul la punctul salvat
	aplica_salvare_pozitie()

func aplica_salvare_pozitie() -> void:
	var config = ConfigFile.new()
	if config.load("user://salvare_joc.ini") == OK:
		var are_salvare = config.get_value("Save", "has_save", false)
		if are_salvare and config.has_section_key("Player", "pos_x") and config.has_section_key("Player", "pos_y"):
			var salvat_x = config.get_value("Player", "pos_x")
			var salvat_y = config.get_value("Player", "pos_y")
			global_position = Vector2(salvat_x, salvat_y)
			pozitie_start = global_position
			a_facut_primul_summon = true
			if has_node("Camera2D"):
				$Camera2D.reset_smoothing()
			print("Jucător încărcat la poziția salvată: ", global_position)
			return

	pozitie_start = global_position

func incarca_dificultate() -> void:
	var config = ConfigFile.new()
	var dif = "easy"
	if config.load("user://salvare_joc.ini") == OK:
		dif = config.get_value("Player", "difficulty", "easy")

	match dif:
		"easy":
			damage_normal = 25
			damage_special = 110
		"medium":
			damage_normal = 18
			damage_special = 85
		"hard":
			damage_normal = 12
			damage_special = 70
	print("Player configurat pe dificultatea: ", dif, " | Dmg normal: ", damage_normal, " | Dmg special OP: ", damage_special)

func adauga_ult(val: float) -> void:
	if ult_curenta >= ULT_MAX:
		return
	var era_sub_max = ult_curenta < ULT_MAX
	ult_curenta = clamp(ult_curenta + val, 0.0, ULT_MAX)
	actualizeaza_hud_ult()
	if ult_curenta >= ULT_MAX and era_sub_max:
		print("ULTIMATE GATA DE FOLOSIRE! [F]")
		flash_ready_ult()

func actualizeaza_hud_ult() -> void:
	if not has_node("UI/BaraUlt"):
		return
	var bar = $UI/BaraUlt
	bar.value = ult_curenta
	if bar.has_node("LabelUlt"):
		var lbl = bar.get_node("LabelUlt")
		if ult_curenta >= ULT_MAX:
			lbl.text = "READY [F]"
			lbl.set("theme_override_colors/font_color", Color(1.0, 0.9, 0.15, 1.0))
		else:
			lbl.text = "ULT: " + str(int(ult_curenta)) + "% [F]"
			lbl.set("theme_override_colors/font_color", Color(0.85, 0.95, 1.0, 0.95))

func flash_ready_ult() -> void:
	if not has_node("UI/BaraUlt"):
		return
	var bar = $UI/BaraUlt
	var tween = create_tween()
	tween.tween_property(bar, "scale", Vector2(1.06, 1.15), 0.12)
	tween.tween_property(bar, "scale", Vector2(1.0, 1.0), 0.15)

func feedback_ult_neincarcata() -> void:
	if not has_node("UI/BaraUlt/LabelUlt"):
		return
	var lbl = $UI/BaraUlt/LabelUlt
	if tween_feedback_ult and tween_feedback_ult.is_valid():
		tween_feedback_ult.kill()
	
	lbl.text = "NOT READY! (" + str(int(ult_curenta)) + "%)"
	lbl.set("theme_override_colors/font_color", Color(1.0, 0.3, 0.3, 1.0))
	
	tween_feedback_ult = create_tween()
	var bar = $UI/BaraUlt
	var orig_left = 20.0
	tween_feedback_ult.tween_property(bar, "offset_left", orig_left - 4.0, 0.05)
	tween_feedback_ult.tween_property(bar, "offset_left", orig_left + 4.0, 0.05)
	tween_feedback_ult.tween_property(bar, "offset_left", orig_left, 0.05)
	tween_feedback_ult.tween_interval(0.4)
	tween_feedback_ult.tween_callback(actualizeaza_hud_ult)

func aplica_screen_shake(durata: float = 0.35, intensitate: float = 6.0) -> void:
	if not has_node("Camera2D"):
		return
	var cam = $Camera2D
	var offset_initial = cam.offset
	var tween = create_tween()
	var pasi = 8
	var dt = durata / float(pasi)
	for i in range(pasi):
		var factor = 1.0 - (float(i) / float(pasi))
		var dx = randf_range(-intensitate, intensitate) * factor
		var dy = randf_range(-intensitate, intensitate) * factor
		tween.tween_property(cam, "offset", offset_initial + Vector2(dx, dy), dt)
	tween.tween_property(cam, "offset", offset_initial, dt)

func flash_aura_ult() -> void:
	var sprite = $AnimatedSprite2D
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(0.2, 1.5, 2.2, 1.0), 0.12)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)

func _physics_process(delta):
	# Verificare cădere în void (sub nivelul podelei)
	if global_position.y > limita_void:
		cade_in_void()
		return

	if not is_on_floor():
		velocity.y += gravity * delta
		
	if e_mort:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		move_and_slide()
		return

	if stare_actuala in ["se_transforma", "atac", "se_incarca", "speciala"]:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		if stare_actuala in ["atac", "speciala"]:
			aplica_damage(damage_special if stare_actuala == "speciala" else damage_normal)
		move_and_slide()
		return

	# Atac normal cu click stânga
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and is_on_floor():
		stare_actuala = "atac"
		inamici_loviti_in_acest_atac.clear()
		$AnimatedSprite2D.play("attack")
		# Hitbox generos orientat în fața direcției curente
		$ZonaAtac.position.x = -60 if $AnimatedSprite2D.flip_h else 60
		aplica_damage(damage_normal)
		move_and_slide()
		return

	# Verificare apăsare tasta F pentru atac special (ULT)
	var f_apasat_acum = Input.is_physical_key_pressed(KEY_F)
	var f_tocmai_apasat = f_apasat_acum and not tasta_f_apasata_anterior
	tasta_f_apasata_anterior = f_apasat_acum

	# Atac special cu tasta F - doar când bara de ult este 100% plină!
	if f_tocmai_apasat and is_on_floor():
		if ult_curenta >= ULT_MAX:
			ult_curenta = 0.0
			actualizeaza_hud_ult()
			invulnerabil_ult = true
			stare_actuala = "se_incarca"
			$AnimatedSprite2D.play("charge")
			aplica_screen_shake(0.25, 4.0)
			flash_aura_ult()
			move_and_slide()
			return
		else:
			feedback_ult_neincarcata()

	# Săritură
	if Input.is_action_just_pressed("ui_up") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		$AnimatedSprite2D.play("jump")
		stare_actuala = "suflet" 
		a_facut_primul_summon = true

	var direction = Input.get_axis("ui_left", "ui_right")
	if direction:
		# Orientare și poziționare hitbox
		if direction < 0: # Când mergi în stânga
			$AnimatedSprite2D.flip_h = true
			$ZonaAtac.position.x = -60
		else: # Când mergi în dreapta
			$AnimatedSprite2D.flip_h = false
			$ZonaAtac.position.x = 60
			
		# Doar prima oară la începutul jocului se face animația de summon
		if not a_facut_primul_summon:
			if is_on_floor():
				stare_actuala = "se_transforma"
				$AnimatedSprite2D.play("summon")
		else:
			# Ulterior, ești direct fantomă și alergi (run) fără animația de summon!
			stare_actuala = "suflet"
			velocity.x = direction * SPEED
			if is_on_floor():
				$AnimatedSprite2D.play("run") 
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		if is_on_floor():
			# Când te oprești, te faci om (idle)
			stare_actuala = "om"
			$AnimatedSprite2D.play("idle")

	move_and_slide()

func lanseaza_fantomite():
	var directie = -1.0 if $AnimatedSprite2D.flip_h else 1.0
	# Baraj devastator de 6 fantomițe spectrale răspândite în evantai OP
	var config_proiectile = [
		{"offset": Vector2(40 * directie, -36), "vy": -45.0, "viteza": 520.0},
		{"offset": Vector2(55 * directie, -20), "vy": -20.0, "viteza": 560.0},
		{"offset": Vector2(70 * directie, -5),  "vy": -5.0,  "viteza": 600.0},
		{"offset": Vector2(70 * directie, 10),  "vy": 5.0,   "viteza": 600.0},
		{"offset": Vector2(55 * directie, 25),  "vy": 20.0,  "viteza": 560.0},
		{"offset": Vector2(40 * directie, 40),  "vy": 45.0,  "viteza": 520.0}
	]
	var dmg_proiectil = int(damage_special * 0.65)
	for cfg in config_proiectile:
		var fantomita = GHOST_PROJECTILE_SCENE.instantiate()
		fantomita.global_position = global_position + cfg["offset"]
		fantomita.directie = directie
		fantomita.damage = dmg_proiectil
		fantomita.viteza = cfg["viteza"]
		fantomita.viteza_y = cfg["vy"]
		fantomita.range_maxim = 700.0
		fantomita.scale = Vector2(1.7, 1.7)
		get_parent().add_child(fantomita)

func aplica_damage(valoare_dmg):
	var a_lovit_inamic = false
	var corpuri_lovite = $ZonaAtac.get_overlapping_bodies()
	for corp in corpuri_lovite:
		if corp.is_in_group("Inamici") and not corp in inamici_loviti_in_acest_atac:
			inamici_loviti_in_acest_atac.append(corp)
			corp.primeste_damage(valoare_dmg)
			print("Jucătorul a lovit inamicul (overlap): ", corp.name, " cu daune: ", valoare_dmg)
			if stare_actuala == "atac":
				a_lovit_inamic = true

	# Verificare suplimentară de proximitate pentru lovituri sigure când jucătorul este în fața inamicului
	var dir_x = -1.0 if $AnimatedSprite2D.flip_h else 1.0
	for inamic in get_tree().get_nodes_in_group("Inamici"):
		if is_instance_valid(inamic) and not inamic in inamici_loviti_in_acest_atac and not inamic.e_mort:
			var delta_x = inamic.global_position.x - global_position.x
			var dist = global_position.distance_to(inamic.global_position)
			if dist <= 125.0 and (sign(delta_x) == dir_x or dist <= 45.0):
				inamici_loviti_in_acest_atac.append(inamic)
				inamic.primeste_damage(valoare_dmg)
				print("Jucătorul a lovit inamicul (proximitate): ", inamic.name, " cu daune: ", valoare_dmg)
				if stare_actuala == "atac":
					a_lovit_inamic = true

	if a_lovit_inamic:
		adauga_ult(20.0) # 5 lovituri normale = 100% Ult plină

func _on_zona_atac_body_entered(body):
	if stare_actuala in ["atac", "speciala"] and body.is_in_group("Inamici"):
		if not body in inamici_loviti_in_acest_atac:
			inamici_loviti_in_acest_atac.append(body)
			var dmg = damage_special if stare_actuala == "speciala" else damage_normal
			body.primeste_damage(dmg)
			if stare_actuala == "atac":
				adauga_ult(20.0)

func primeste_damage(valoare):
	if e_mort: return
	if invulnerabil_ult:
		print("Jucătorul este invulnerabil în timpul atacului special OP!")
		return
	viata_jucator -= valoare
	adauga_ult(6.0) # Bonus de încărcare Ult când iei damage
	
	# SETARE HUD: Actualizează bara de viață de pe ecran când iei damage
	if has_node("UI/BaraViata"):
		$UI/BaraViata.value = max(0, viata_jucator)
	print("Viață rămasă jucător: ", viata_jucator)
	
	if viata_jucator <= 0:
		moare()

func moare():
	if e_mort: return
	e_mort = true
	invulnerabil_ult = false
	velocity.x = 0
	# Redă animația de moarte (dead)
	if $AnimatedSprite2D.sprite_frames.has_animation("dead"):
		$AnimatedSprite2D.play("dead")
	elif $AnimatedSprite2D.sprite_frames.has_animation("death"):
		$AnimatedSprite2D.play("death")
	print("Personajul a murit! Se redă animația de moarte...")

func cade_in_void():
	print("Jucătorul a căzut în void! Se duce la început...")
	invulnerabil_ult = false
	if restart_scena_la_void:
		get_tree().reload_current_scene()
	else:
		global_position = pozitie_start
		velocity = Vector2.ZERO
		stare_actuala = "om"
		$AnimatedSprite2D.play("idle")
		if has_node("Camera2D"):
			$Camera2D.reset_smoothing()

func _on_animated_sprite_2d_animation_finished():
	if $AnimatedSprite2D.animation in ["dead", "death"]:
		# S-a terminat animația de moarte, așteptăm puțin și reîncărcăm nivelul
		await get_tree().create_timer(0.6).timeout
		get_tree().reload_current_scene()
	elif $AnimatedSprite2D.animation == "summon":
		a_facut_primul_summon = true
		stare_actuala = "suflet"
	elif $AnimatedSprite2D.animation == "attack":
		stare_actuala = "om" 
	elif $AnimatedSprite2D.animation == "charge":
		stare_actuala = "speciala" 
		inamici_loviti_in_acest_atac.clear()
		$AnimatedSprite2D.play("special move")
		$ZonaAtac.position.x = -60 if $AnimatedSprite2D.flip_h else 60
		aplica_screen_shake(0.4, 7.0) # Impact puternic la eliberarea specialei
		flash_aura_ult()
		aplica_damage(damage_special) 
		lanseaza_fantomite() # Lansează barajul OP de 6 fantomițe!
	elif $AnimatedSprite2D.animation == "special move":
		stare_actuala = "om"
		invulnerabil_ult = false
