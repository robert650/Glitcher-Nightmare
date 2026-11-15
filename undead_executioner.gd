extends CharacterBody2D

signal boss_hp_changed(current_hp: int, max_hp: int)
signal boss_defeated()

@export var viata_max: int = 750
var viata_curenta: int = 750

@export var viteza_plutire: float = 95.0
@export var damage_melee: int = 22
@export var damage_val_ult: int = 32
@export var damage_pietre: int = 20

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var lupta_activa: bool = false
var e_mort: bool = false
var este_in_actiune: bool = false
var lovit_deja_in_atac: bool = false

# Praguri speciale (la fiecare ~25% viață pierdută)
var prag_special_pct: float = 0.75 # 75%, 50%, 25%
var special_in_asteptare: bool = false

# Timere atac
var timer_atac: float = 0.4
var timer_pietre_automat: float = 7.0
var y_baza: float = 0.0

@onready var sprite = $AnimatedSprite2D
@onready var melee_area = $MeleeArea

var scena_val = preload("res://executioner_wave.tscn")
var scena_spike = preload("res://falling_spike.tscn")

func _ready() -> void:
	# Verificare salvare
	var config = ConfigFile.new()
	if config.load("user://salvare_joc.ini") == OK:
		if config.get_value("Save", "executioner_defeated", false):
			queue_free()
			return

	add_to_group("Inamici")
	add_to_group("Boss")
	y_baza = position.y

	# Dificultate din salvare
	var dif = "medium"
	if config.load("user://salvare_joc.ini") == OK:
		dif = config.get_value("Player", "difficulty", "medium")

	match dif:
		"easy":
			viata_max = 500
			damage_melee = 16
			damage_val_ult = 24
			damage_pietre = 15
		"medium":
			viata_max = 750
			damage_melee = 22
			damage_val_ult = 32
			damage_pietre = 20
		"hard":
			viata_max = 1000
			damage_melee = 30
			damage_val_ult = 42
			damage_pietre = 28

	viata_curenta = viata_max
	boss_hp_changed.emit(viata_curenta, viata_max)

	# Privește spre stânga către jucător
	if sprite:
		sprite.flip_h = true
		sprite.play("idle")
	actualizeaza_offset_melee(true)

func activeaza_lupta() -> void:
	if lupta_activa: return
	lupta_activa = true
	timer_atac = 0.4 # Atacă rapid după trezire
	boss_hp_changed.emit(viata_curenta, viata_max)
	
	var parent_lvl = get_parent()
	if parent_lvl and parent_lvl.has_method("arata_bara_boss"):
		parent_lvl.arata_bara_boss()
		
	print(">>> UNDEAD EXECUTIONER S-A TREZIT SI ATACA! Viață: ", viata_curenta, " / ", viata_max, " <<<")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	if e_mort:
		velocity.x = move_toward(velocity.x, 0, viteza_plutire)
		move_and_slide()
		return

	var jucatori = get_tree().get_nodes_in_group("Jucator")
	if jucatori.size() == 0:
		velocity.x = 0
		move_and_slide()
		return

	var jucator = jucatori[0]
	if jucator.e_mort:
		velocity.x = 0
		if sprite.animation != "idle":
			sprite.play("idle")
		move_and_slide()
		return

	var distanta = global_position.distance_to(jucator.global_position)
	var directie = sign(jucator.global_position.x - global_position.x)

	# Auto-activare doar când jucătorul este aproape (< 550px) sau pe platforma boss-ului (X >= 4250)
	if not lupta_activa:
		if distanta <= 550.0 or jucator.global_position.x >= 4250.0:
			activeaza_lupta()
		else:
			velocity.x = 0
			move_and_slide()
			return

	# Orientare către jucător
	if directie != 0:
		var spre_stanga = (directie < 0)
		sprite.flip_h = spre_stanga
		actualizeaza_offset_melee(spre_stanga)

	# Dacă execută o acțiune / animație de atac, stă pe loc
	if este_in_actiune:
		velocity.x = move_toward(velocity.x, 0, viteza_plutire * 2)
		move_and_slide()
		return

	# Verificare prag special (25%)
	if special_in_asteptare:
		special_in_asteptare = false
		executa_miscare_speciala(jucator, directie)
		return

	# Timere acțiuni
	timer_atac -= delta
	timer_pietre_automat -= delta

	# Ploaie periodică de pietre din cer
	if timer_pietre_automat <= 0.0:
		timer_pietre_automat = randf_range(7.0, 10.0)
		lanseaza_ploaie_pietre(jucator)
		return

	# Atac corp la corp când este aproape
	if distanta <= 115.0:
		if timer_atac <= 0.0:
			executa_atac_melee(jucator)
		else:
			velocity.x = move_toward(velocity.x, 0, viteza_plutire)
			if sprite.animation != "idle":
				sprite.play("idle")
	elif distanta > 115.0:
		velocity.x = directie * viteza_plutire
		if sprite.animation != "idle":
			sprite.play("idle")

	move_and_slide()

func actualizeaza_offset_melee(spre_stanga: bool) -> void:
	if melee_area:
		melee_area.position.x = -50 if spre_stanga else 50

# ==================== ATACURI ====================

func executa_atac_melee(jucator) -> void:
	este_in_actiune = true
	lovit_deja_in_atac = false
	timer_atac = randf_range(1.2, 1.8)
	velocity.x = 0
	sprite.play("attack")
	print("Undead Executioner declanșează lovitura de coasă!")

func executa_miscare_speciala(jucator, directie: float) -> void:
	este_in_actiune = true
	velocity.x = 0
	print(">>> EXECUTIONER ACTIVEAZA MISCAREA SPECIALA (ULTIMATE)! <<<")
	
	# Animația 'skill'
	sprite.play("skill")
	
	# Efect vizual pulsare
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(2.0, 0.3, 0.5, 1.0), 0.25)
	tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.25)
	
	await get_tree().create_timer(0.4).timeout
	if e_mort: return
	lanseaza_unda_la_sol(directie, jucator)
	
	await get_tree().create_timer(0.35).timeout
	if e_mort: return
	lanseaza_ploaie_pietre(jucator)

func lanseaza_unda_la_sol(directie: float, jucator) -> void:
	var dir = directie if directie != 0 else (-1.0 if sprite.flip_h else 1.0)
	var val = scena_val.instantiate()
	var spawn_y = jucator.global_position.y + 10.0 if jucator else (global_position.y + 20.0)
	val.global_position = Vector2(global_position.x + (dir * 45.0), spawn_y)
	val.damage = damage_val_ult
	val.set_directie_x(dir)
	get_parent().add_child(val)
	print("Undead Executioner a lansat Unda Morții! (Sari peste ea!)")

func lanseaza_ploaie_pietre(jucator) -> void:
	este_in_actiune = true
	sprite.play("summon")
	print("Undead Executioner cheamă pietrele/țepușele din cer!")

	var ground_y = jucator.global_position.y + 18.0 if jucator else (global_position.y + 35.0)
	var player_x = jucator.global_position.x if jucator else global_position.x
	
	var offsets = [-160.0, -80.0, 0.0, 80.0, 160.0]
	offsets.shuffle()

	for i in range(offsets.size()):
		if e_mort: return
		var target_x = player_x + offsets[i] + randf_range(-15, 15)
		spawneaza_piatra(target_x, ground_y)
		await get_tree().create_timer(0.25).timeout

	if sprite.animation == "summon" and not e_mort:
		sprite.play("idle")
	este_in_actiune = false

func spawneaza_piatra(x_pos: float, ground_y: float) -> void:
	var spike = scena_spike.instantiate()
	spike.global_position = Vector2(x_pos, ground_y - 450.0)
	spike.tinta_ground_y = ground_y
	spike.damage = damage_pietre
	get_parent().add_child(spike)

# ==================== DAMAGE & VIAȚĂ ====================

func primeste_damage(valoare: int) -> void:
	if e_mort: return

	# Trezire instantanee dacă este lovit
	if not lupta_activa:
		activeaza_lupta()

	viata_curenta -= valoare
	boss_hp_changed.emit(viata_curenta, viata_max)
	print("Undead Executioner lovit! HP: ", viata_curenta, " / ", viata_max)

	# Flash alb/roșu
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(2.0, 0.2, 0.2, 1.0), 0.08)
	tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.08)

	# Verificare praguri speciale 25% (75%, 50%, 25%)
	var procent_curent = float(viata_curenta) / float(viata_max)
	if procent_curent <= prag_special_pct and prag_special_pct > 0.05:
		special_in_asteptare = true
		prag_special_pct -= 0.25
		print(">>> Prag 25% atins! Pregatire atac special! <<<")

	if viata_curenta <= 0:
		moare()

func moare() -> void:
	e_mort = true
	lupta_activa = false
	este_in_actiune = true
	velocity = Vector2.ZERO
	remove_from_group("Inamici")
	remove_from_group("Boss")
	
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	if melee_area and melee_area.has_node("CollisionShape2D"):
		melee_area.get_node("CollisionShape2D").set_deferred("disabled", true)

	sprite.play("death")
	boss_defeated.emit()

	var config = ConfigFile.new()
	config.load("user://salvare_joc.ini")
	config.set_value("Save", "executioner_defeated", true)
	config.save("user://salvare_joc.ini")
	print(">>> UNDEAD EXECUTIONER A FOST ÎNVINS! <<<")

# ==================== EVENIMENTE ANIMAȚIE ====================

func _on_animated_sprite_2d_frame_changed() -> void:
	if sprite.animation == "attack" and sprite.frame in [6, 7, 8, 9]:
		aplica_damage_melee()

func aplica_damage_melee() -> void:
	if lovit_deja_in_atac: return
	
	var jucatori = get_tree().get_nodes_in_group("Jucator")
	if jucatori.size() > 0:
		var jucator = jucatori[0]
		if is_instance_valid(jucator) and not jucator.e_mort:
			var d = global_position.distance_to(jucator.global_position)
			if d <= 135.0:
				lovit_deja_in_atac = true
				jucator.primeste_damage(damage_melee)
				print("Lovitură de coasă a nimerit jucătorul! Daune: ", damage_melee)
				return

	if melee_area:
		for b in melee_area.get_overlapping_bodies():
			if b.is_in_group("Jucator") or b.name == "Player":
				lovit_deja_in_atac = true
				if b.has_method("primeste_damage"):
					b.primeste_damage(damage_melee)
				break

func _on_animated_sprite_2d_animation_finished() -> void:
	if sprite.animation == "death":
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 1.2)
		tween.tween_callback(queue_free)
	elif sprite.animation in ["attack", "skill", "summon"]:
		este_in_actiune = false
		if not e_mort:
			sprite.play("idle")
