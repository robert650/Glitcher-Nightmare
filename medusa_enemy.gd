extends CharacterBody2D

@export var viata: int = 70
@export var viteza: float = 75.0
@export var range_atac: float = 80.0
@export var range_detectie: float = 340.0
@export var damage_atac: int = 10
@export var cooldown_atac: float = 0.8

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var e_mort: bool = false
var poate_ataca: bool = true
var este_in_atac: bool = false

func _ready() -> void:
	# 1. Dacă Meduza a fost deja învinsă în această salvare, nu mai apare
	var config = ConfigFile.new()
	if config.load("user://salvare_joc.ini") == OK:
		if config.get_value("Save", "medusa_defeated", false):
			queue_free()
			return

	add_to_group("Inamici")
	add_to_group("Meduza")

	if has_node("BaraViata"):
		$BaraViata.max_value = viata
		$BaraViata.value = viata

	# Medusa privește inițial spre stânga, către direcția din care vine jucătorul
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.flip_h = true
	if has_node("CollisionShape2D"):
		$CollisionShape2D.position.x = -10

	# 2. Încărcare dificultate și ajustare daune Meduză
	var dif = "easy"
	if config.load("user://salvare_joc.ini") == OK:
		dif = config.get_value("Player", "difficulty", "easy")
	
	match dif:
		"easy":
			damage_atac = 10
		"medium":
			damage_atac = 15
		"hard":
			damage_atac = 22
	print("Meduza initializata pe dificultate: ", dif, " | Dmg atac: ", damage_atac)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	if e_mort:
		velocity.x = move_toward(velocity.x, 0, viteza)
		move_and_slide()
		return

	if este_in_atac:
		velocity.x = 0
		move_and_slide()
		return

	# Căutare jucător
	var jucatori = get_tree().get_nodes_in_group("Jucator")
	if jucatori.size() > 0:
		var jucator = jucatori[0]
		if not jucator.e_mort:
			var distanta = global_position.distance_to(jucator.global_position)
			var directie = sign(jucator.global_position.x - global_position.x)

			if distanta <= range_detectie:
				# Orientare spre jucător: directie < 0 înseamnă că jucătorul e în stânga
				if directie != 0:
					$AnimatedSprite2D.flip_h = (directie < 0)
					if has_node("CollisionShape2D"):
						$CollisionShape2D.position.x = -10 if (directie < 0) else 10

				# Atac sau urmărire
				if distanta <= range_atac and poate_ataca:
					executa_atac(jucator)
				elif distanta > range_atac:
					velocity.x = directie * viteza
					if $AnimatedSprite2D.animation != "hurt":
						$AnimatedSprite2D.play("walk")
			else:
				velocity.x = move_toward(velocity.x, 0, viteza)
				if $AnimatedSprite2D.animation != "hurt":
					$AnimatedSprite2D.play("idle")
		else:
			velocity.x = move_toward(velocity.x, 0, viteza)
			$AnimatedSprite2D.play("idle")
	else:
		velocity.x = move_toward(velocity.x, 0, viteza)
		$AnimatedSprite2D.play("idle")

	move_and_slide()

func executa_atac(jucator) -> void:
	poate_ataca = false
	este_in_atac = true
	
	# Asigură orientarea către jucător în momentul declanșării atacului
	var directie = sign(jucator.global_position.x - global_position.x)
	if directie != 0:
		$AnimatedSprite2D.flip_h = (directie < 0)
		if has_node("CollisionShape2D"):
			$CollisionShape2D.position.x = -10 if (directie < 0) else 10
	
	# Alternează între atacul normal și atacul cu privirea de piatră
	var anim = "stone" if randf() > 0.5 else "attack"
	$AnimatedSprite2D.play(anim)
	
	# Daune aplicate jucătorului
	jucator.primeste_damage(damage_atac)
	print("Meduza a atacat cu ", anim, "! Daune provocate: ", damage_atac)

func primeste_damage(valoare: int) -> void:
	if e_mort: return
	viata -= valoare

	if has_node("BaraViata"):
		$BaraViata.value = max(0, viata)

	print("Meduza a fost lovită! Viață rămasă: ", viata)

	if viata <= 0:
		moare()
	elif not este_in_atac:
		$AnimatedSprite2D.play("hurt")

func moare() -> void:
	e_mort = true
	remove_from_group("Inamici")
	remove_from_group("Meduza")
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	if has_node("BaraViata"):
		$BaraViata.hide()
	$AnimatedSprite2D.play("death")
	print("Meduza a fost învinsă! Acum fântâna este descuiată pentru salvare.")

func _on_animated_sprite_2d_animation_finished() -> void:
	if $AnimatedSprite2D.animation == "death":
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.8)
		tween.tween_callback(queue_free)
	elif $AnimatedSprite2D.animation in ["attack", "stone"]:
		este_in_atac = false
		$AnimatedSprite2D.play("idle")
		await get_tree().create_timer(cooldown_atac).timeout
		poate_ataca = true
	elif $AnimatedSprite2D.animation == "hurt":
		$AnimatedSprite2D.play("idle")
