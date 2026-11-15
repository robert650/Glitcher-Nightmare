extends CharacterBody2D

signal boss_hp_changed(current_hp: int, max_hp: int)
signal boss_defeated()

@export var viata_max: int = 450
var viata: int = 450
var e_activ: bool = false
var e_mort: bool = false
var este_in_actiune: bool = false
var faza_enrage: bool = false

# Timpi de acțiune și cooldowns
var timer_actiune: float = 2.0
var cooldown_atac: float = 2.0
var atacuri_succesive: int = 0

# Referințe scene atacuri
var scena_proiectil = preload("res://queen_projectile.tscn")
var scena_val = preload("res://queen_wave.tscn")

var y_baza: float = 0.0
var damage_proiectil: int = 15
var damage_special: int = 22
var viteza_mers: float = 65.0

func _ready() -> void:
	# 1. Daca Boss-ul a fost deja invins in aceasta salvare, nu mai apare
	var config = ConfigFile.new()
	var dif = "medium"
	if config.load("user://salvare_joc.ini") == OK:
		if config.get_value("Save", "queen_defeated", false):
			queue_free()
			return
		dif = config.get_value("Player", "difficulty", "medium")

	add_to_group("Inamici")
	add_to_group("Boss")
	y_baza = position.y
	
	# 2. Ajustare dificultate din salvare
	match dif:
		"easy":
			viata_max = 300
			damage_proiectil = 10
			damage_special = 16
			cooldown_atac = 2.5
			viteza_mers = 55.0
		"medium":
			viata_max = 450
			damage_proiectil = 15
			damage_special = 22
			cooldown_atac = 1.9
			viteza_mers = 70.0
		"hard":
			viata_max = 600
			damage_proiectil = 22
			damage_special = 30
			cooldown_atac = 1.4
			viteza_mers = 90.0
			
	viata = viata_max
	seteaza_animatie("idle")
	print("Boss pixelat initializat! Dificultate: ", dif, " | HP: ", viata_max)

func activeaza_lupta() -> void:
	e_activ = true
	timer_actiune = 1.0
	emit_signal("boss_hp_changed", viata, viata_max)
	print("Lupta cu Boss-ul a inceput!")

func _physics_process(delta: float) -> void:
	if not e_activ or e_mort:
		return

	var jucator = get_tree().get_first_node_in_group("Jucator")
	if jucator and not jucator.e_mort:
		var dir_x = jucator.global_position.x - global_position.x
		if not este_in_actiune and has_node("AnimatedSprite2D"):
			# Orientare către jucător
			$AnimatedSprite2D.flip_h = (dir_x < 0)

		# Mers spre jucător dacă este prea departe și nu e în acțiune
		var dist = abs(dir_x)
		if not este_in_actiune:
			if dist > 140.0:
				velocity.x = sign(dir_x) * viteza_mers
				if $AnimatedSprite2D.animation != "walk":
					$AnimatedSprite2D.play("walk")
			else:
				velocity.x = 0
				if $AnimatedSprite2D.animation != "idle" and $AnimatedSprite2D.animation != "hurt":
					$AnimatedSprite2D.play("idle")
		else:
			velocity.x = 0
	else:
		velocity.x = 0
		if not este_in_actiune and has_node("AnimatedSprite2D"):
			$AnimatedSprite2D.play("idle")

	move_and_slide()

	# Control cicluri de atac
	timer_actiune -= delta
	if timer_actiune <= 0.0 and not este_in_actiune:
		alege_urmatoarea_actiune(jucator)

func alege_urmatoarea_actiune(jucator) -> void:
	if not jucator or jucator.e_mort:
		return

	este_in_actiune = true
	var distanta = global_position.distance_to(jucator.global_position)
	
	# Dacă jucătorul este foarte aproape (sub 90px), atac melee rapid sau teleportare
	if distanta < 95.0:
		if randf() > 0.4:
			executa_atac_melee(jucator)
		else:
			executa_teleportare()
		return

	# Alternează între atacul de proiectile și mișcarea specială
	atacuri_succesive += 1
	if atacuri_succesive >= (2 if faza_enrage else 3):
		atacuri_succesive = 0
		executa_special_wrath()
	else:
		if randf() > 0.35:
			executa_tir_proiectile(jucator)
		else:
			executa_teleportare_si_atac(jucator)

# --- ATAC MELEE CU GHEARELE ---
func executa_atac_melee(jucator) -> void:
	seteaza_animatie("attack")
	await get_tree().create_timer(0.35).timeout
	if e_mort: return
	
	if jucator and is_instance_valid(jucator) and global_position.distance_to(jucator.global_position) < 110.0:
		jucator.primeste_damage(damage_special)

	await get_tree().create_timer(0.3).timeout
	if not e_mort:
		seteaza_animatie("idle")
		este_in_actiune = false
		timer_actiune = cooldown_atac

# --- SPECIAL MOVE 1: TIR CU ORBURI DE MAGIE NEAGRA ---
func executa_tir_proiectile(jucator) -> void:
	seteaza_animatie("attack")
	var tween = create_tween()
	tween.tween_property($AnimatedSprite2D, "modulate", Color(1.8, 0.6, 2.0), 0.25)
	tween.tween_property($AnimatedSprite2D, "modulate", Color.WHITE, 0.15)
	
	await get_tree().create_timer(0.35).timeout
	if e_mort: return

	var directie_baza = (jucator.global_position - global_position).normalized()
	var unghiuri = [-0.25, 0.0, 0.25]
	if faza_enrage:
		unghiuri = [-0.35, -0.15, 0.15, 0.35]

	for unghi in unghiuri:
		var proj = scena_proiectil.instantiate()
		proj.global_position = global_position + Vector2(0, -10)
		proj.damage = damage_proiectil
		var dir_rotit = directie_baza.rotated(unghi)
		proj.set_directie(dir_rotit)
		get_parent().add_child(proj)

	await get_tree().create_timer(0.4).timeout
	if not e_mort:
		seteaza_animatie("idle")
		este_in_actiune = false
		timer_actiune = cooldown_atac

# --- SPECIAL MOVE 2: WRATH OF THE VOID (VALURI LA SOL) ---
func executa_special_wrath() -> void:
	seteaza_animatie("special")
	var tween = create_tween()
	tween.tween_property($AnimatedSprite2D, "modulate", Color(2.5, 0.4, 2.0), 0.35)
	
	await get_tree().create_timer(0.5).timeout
	if e_mort: return

	var val_stanga = scena_val.instantiate()
	val_stanga.global_position = Vector2(global_position.x - 30, y_baza + 15)
	val_stanga.set_directie_x(-1.0)
	val_stanga.damage = damage_special
	get_parent().add_child(val_stanga)

	var val_dreapta = scena_val.instantiate()
	val_dreapta.global_position = Vector2(global_position.x + 30, y_baza + 15)
	val_dreapta.set_directie_x(1.0)
	val_dreapta.damage = damage_special
	get_parent().add_child(val_dreapta)

	await get_tree().create_timer(0.5).timeout
	if not e_mort:
		var tween_back = create_tween()
		tween_back.tween_property($AnimatedSprite2D, "modulate", Color.WHITE, 0.25)
		await tween_back.finished
		seteaza_animatie("idle")
		este_in_actiune = false
		timer_actiune = cooldown_atac * 1.2

# --- TELEPORTARE CU DISSOLVE UMBRE ---
func executa_teleportare() -> void:
	var tween = create_tween()
	tween.tween_property($AnimatedSprite2D, "modulate:a", 0.0, 0.2)
	await tween.finished
	if e_mort: return

	var jucator = get_tree().get_first_node_in_group("Jucator")
	var tinta_x = 4750.0
	if jucator:
		if jucator.global_position.x < 4750:
			tinta_x = randf_range(4900, 5200)
		else:
			tinta_x = randf_range(4250, 4550)
	global_position.x = tinta_x

	var tween_in = create_tween()
	tween_in.tween_property($AnimatedSprite2D, "modulate:a", 1.0, 0.2)
	await tween_in.finished
	este_in_actiune = false
	timer_actiune = 0.4

func executa_teleportare_si_atac(jucator) -> void:
	executa_teleportare()
	await get_tree().create_timer(0.5).timeout
	if not e_mort and jucator:
		executa_tir_proiectile(jucator)

# --- PRIMIRE DAMAGE & ENRAGE ---
func primeste_damage(valoare: int) -> void:
	if e_mort or not e_activ:
		return

	viata -= valoare
	emit_signal("boss_hp_changed", max(0, viata), viata_max)
	print("Boss a primit ", valoare, " damage! HP ramas: ", viata)

	var tween = create_tween()
	tween.tween_property($AnimatedSprite2D, "modulate", Color(2.5, 0.2, 0.2), 0.1)
	tween.tween_property($AnimatedSprite2D, "modulate", Color.WHITE, 0.1)

	if not faza_enrage and viata <= (viata_max / 2):
		faza_enrage = true
		cooldown_atac *= 0.75
		viteza_mers *= 1.25
		print("BOSS A INTRAT IN FAZA ENRAGE!")
		var tw_enrage = create_tween()
		tw_enrage.tween_property($AnimatedSprite2D, "modulate", Color(2.0, 0.3, 1.8), 0.4)
		tw_enrage.tween_property($AnimatedSprite2D, "modulate", Color.WHITE, 0.2)

	if viata <= 0:
		moare()
	elif not este_in_actiune:
		$AnimatedSprite2D.play("hurt")

func moare() -> void:
	e_mort = true
	e_activ = false
	velocity = Vector2.ZERO
	remove_from_group("Inamici")
	remove_from_group("Boss")
	
	var config = ConfigFile.new()
	if config.load("user://salvare_joc.ini") == OK:
		config.set_value("Save", "queen_defeated", true)
		config.save("user://salvare_joc.ini")
	
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
		
	seteaza_animatie("death")
	emit_signal("boss_hp_changed", 0, viata_max)
	emit_signal("boss_defeated")
	
	print("BOSS A FOST INVINS!")

func _on_animated_sprite_2d_animation_finished() -> void:
	if $AnimatedSprite2D.animation == "death":
		var tween = create_tween()
		tween.tween_property($AnimatedSprite2D, "modulate", Color(2.5, 0.5, 2.5), 0.4)
		tween.tween_property($AnimatedSprite2D, "modulate:a", 0.0, 1.0)
		tween.tween_callback(queue_free)
	elif $AnimatedSprite2D.animation == "hurt" and not este_in_actiune:
		$AnimatedSprite2D.play("idle")

func seteaza_animatie(nume: String) -> void:
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play(nume)
