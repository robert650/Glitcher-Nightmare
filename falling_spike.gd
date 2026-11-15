extends Area2D

@export var damage: int = 18
@export var viteza_cadere: float = 650.0

var tinta_ground_y: float = 460.0
var in_cadere: bool = false
var avertizare_activa: bool = true
var timp_avertizare: float = 0.65
var a_lovit: bool = false

@onready var sprite = $Sprite2D
@onready var indicator = $IndicatorSol

func _ready() -> void:
	add_to_group("ProiectileInamici")
	# Indicatorul de la sol arată punctul exact unde va pica piatra
	if indicator:
		indicator.top_level = true
		indicator.global_position = Vector2(global_position.x, tinta_ground_y)
		indicator.show()
		
		# Animație de pulsare / avertizare pe sol
		var tween = create_tween().set_loops()
		tween.tween_property(indicator, "modulate:a", 1.0, 0.15)
		tween.tween_property(indicator, "modulate:a", 0.4, 0.15)

	# Țepușa este inițial invizibilă sau sus în cer
	if sprite:
		sprite.modulate.a = 0.0

func _physics_process(delta: float) -> void:
	if avertizare_activa:
		timp_avertizare -= delta
		if timp_avertizare <= 0.0:
			avertizare_activa = false
			in_cadere = true
			if sprite:
				sprite.modulate.a = 1.0
			if indicator and is_instance_valid(indicator):
				indicator.queue_free()
		return

	if in_cadere and not a_lovit:
		position.y += viteza_cadere * delta
		if position.y >= tinta_ground_y:
			impact_sol()

func impact_sol() -> void:
	if a_lovit: return
	a_lovit = true
	in_cadere = false
	creeaza_particule_sfaramare()
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if a_lovit: return
	if body.is_in_group("Jucator") or body.name == "Player":
		a_lovit = true
		if body.has_method("primeste_damage"):
			body.primeste_damage(damage)
		creeaza_particule_sfaramare()
		queue_free()

func creeaza_particule_sfaramare() -> void:
	var parent_scene = get_parent()
	if not parent_scene: return
	
	# Creează 5 cioburi mici de piatră care sar în lateral și dispar
	for i in range(5):
		var ciob = ColorRect.new()
		ciob.size = Vector2(randf_range(4, 8), randf_range(4, 8))
		ciob.color = Color(0.4, 0.35, 0.45, 1.0) if i % 2 == 0 else Color(0.7, 0.2, 0.9, 0.9)
		ciob.position = Vector2(global_position.x + randf_range(-6, 6), tinta_ground_y - 6)
		parent_scene.add_child(ciob)
		
		var dir_x = randf_range(-70, 70)
		var dir_y = randf_range(-90, -30)
		var tween = ciob.create_tween()
		tween.set_parallel(true)
		tween.tween_property(ciob, "position", ciob.position + Vector2(dir_x, dir_y), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.chain().tween_property(ciob, "position:y", tinta_ground_y, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.chain().tween_property(ciob, "modulate:a", 0.0, 0.2)
		tween.chain().tween_callback(ciob.queue_free)
