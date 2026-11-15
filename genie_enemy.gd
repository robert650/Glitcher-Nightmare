extends CharacterBody2D

@export var viata: int = 50                    # Viața duhului
@export var viteza: float = 80.0
@export var range_atac: float = 85.0           # Raza de la care atacă normal
@export var range_detectie: float = 320.0      # Raza de la care te urmărește în zbor
@export var range_spawn: float = 280.0         # Distanța de la care apare din senin

@export var damage_atac: int = 10             # Mereu 10 damage pe atac (mod Easy)
@export var cooldown_atac: float = 0.6        # Pauză între atacuri (secunde)
@export var apare_imediat: bool = false       # Dacă e bifat, se spawnează direct la început

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var e_mort: bool = false
var poate_ataca: bool = false
var este_in_atac: bool = false
var a_aparut: bool = false                    # True dacă a terminat spawn-ul
var in_aparitie: bool = false                 # True pe durata animației de spawn

func _ready():
	add_to_group("Inamici")
	if has_node("BaraViata"):
		$BaraViata.max_value = viata
		$BaraViata.value = viata

	# Încărcare dificultate din salvare și ajustare daune atac
	var config = ConfigFile.new()
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
	print("Inamic Genie configurat pe dificultatea: ", dif, " | Daune atac: ", damage_atac)

	# Duhul începe invizibil și inactiv până când jucătorul se apropie
	if not apare_imediat:
		visible = false
		$CollisionShape2D.disabled = true
	else:
		incepe_aparitie(1)

func _physics_process(delta):
	# 1. Dacă nu a apărut încă, verifică distanța până la jucător pentru a se spawna
	if not a_aparut and not in_aparitie:
		var jucatori = get_tree().get_nodes_in_group("Jucator")
		if jucatori.size() > 0:
			var jucator = jucatori[0]
			if not jucator.e_mort:
				var distanta = global_position.distance_to(jucator.global_position)
				var directie = sign(jucator.global_position.x - global_position.x)
				if distanta <= range_spawn or apare_imediat:
					incepe_aparitie(directie)
		return

	# 2. Cât timp se materializează (animația de spawn)
	if in_aparitie:
		if not is_on_floor():
			velocity.y += gravity * delta
		velocity.x = 0
		move_and_slide()
		return

	# 3. Gravitație
	if not is_on_floor():
		velocity.y += gravity * delta

	# 4. Dacă a murit
	if e_mort:
		velocity.x = move_toward(velocity.x, 0, viteza)
		move_and_slide()
		return

	# 5. Dacă este în mijlocul atacului, nu lăsăm procesul fizic să întrerupă animația
	if este_in_atac:
		velocity.x = move_toward(velocity.x, 0, viteza)
		move_and_slide()
		return

	# 6. Comportament AI: Urmărire și atac normal automat
	var jucatori = get_tree().get_nodes_in_group("Jucator")
	if jucatori.size() > 0:
		var jucator = jucatori[0]
		if not jucator.e_mort:
			var distanta = global_position.distance_to(jucator.global_position)
			var directie = sign(jucator.global_position.x - global_position.x)

			# Orientare automată către jucător
			if directie != 0 and $AnimatedSprite2D.animation != "hurt":
				$AnimatedSprite2D.flip_h = directie < 0

			# Atac automat când jucătorul este în range
			if distanta <= range_atac and poate_ataca:
				executa_atac(jucator, directie)
			# Urmărire în zbor dacă jucătorul este în raza de detecție
			elif distanta < range_detectie and distanta > range_atac and $AnimatedSprite2D.animation != "hurt":
				velocity.x = directie * viteza
				$AnimatedSprite2D.play("flight")
			# Stare de repaus (idle)
			else:
				if $AnimatedSprite2D.animation != "hurt":
					velocity.x = move_toward(velocity.x, 0, viteza)
					$AnimatedSprite2D.play("idle")
		else:
			if $AnimatedSprite2D.animation != "hurt":
				velocity.x = move_toward(velocity.x, 0, viteza)
				$AnimatedSprite2D.play("idle")

	move_and_slide()

func incepe_aparitie(directie):
	in_aparitie = true
	visible = true
	$CollisionShape2D.disabled = false
	velocity = Vector2.ZERO
	if directie != 0:
		$AnimatedSprite2D.flip_h = directie < 0
	$AnimatedSprite2D.play("magic attack") # Animația de spawn / apariție din senin
	print("====================================================")
	print(">>> DUHUL A APĂRUT DE NICĂIERI (SPAWN)! <<<")
	print("====================================================")

func executa_atac(jucator, directie):
	poate_ataca = false
	este_in_atac = true
	velocity.x = 0

	# Se întoarce spre direcția jucătorului
	if directie != 0:
		$AnimatedSprite2D.flip_h = directie < 0

	# Atac normal (mereu 10 damage pe Easy)
	$AnimatedSprite2D.play("attack")
	jucator.primeste_damage(damage_atac)
	print("Duhul a atacat normal! Daune date: ", damage_atac)

func primeste_damage(valoare):
	# Duhul nu poate fi rănit dacă este mort sau în timp ce se spawnează
	if e_mort or in_aparitie:
		return
	viata -= valoare
	if has_node("BaraViata"):
		$BaraViata.value = max(0, viata)
	print("Monstru lovit! Viață rămasă: ", viata)
	if viata <= 0:
		e_mort = true
		poate_ataca = false
		este_in_atac = false
		velocity.x = 0
		if has_node("BaraViata"):
			$BaraViata.visible = false
		$AnimatedSprite2D.play("death")
	else:
		velocity.x = 0
		$AnimatedSprite2D.play("hurt")

func _on_animated_sprite_2d_animation_finished():
	if $AnimatedSprite2D.animation == "magic attack":
		# Animația de apariție s-a terminat, duhul intră în acțiune!
		in_aparitie = false
		a_aparut = true
		$AnimatedSprite2D.play("idle")
		poate_ataca = true
		print("Duhul s-a materializat complet și este gata de luptă!")
	elif $AnimatedSprite2D.animation == "death":
		queue_free()
	elif $AnimatedSprite2D.animation == "hurt":
		este_in_atac = false
		$AnimatedSprite2D.play("idle")
		if not e_mort:
			await get_tree().create_timer(cooldown_atac).timeout
			if not e_mort:
				poate_ataca = true
	elif $AnimatedSprite2D.animation == "attack":
		este_in_atac = false
		$AnimatedSprite2D.play("idle")
		# Cooldown înainte de următorul atac
		if not e_mort:
			await get_tree().create_timer(cooldown_atac).timeout
			if not e_mort:
				poate_ataca = true
