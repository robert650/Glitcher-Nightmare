extends Area2D

@export var viteza: float = 480.0
@export var range_maxim: float = 550.0
@export var damage: int = 50
@export var viteza_y: float = 0.0

var directie: float = 1.0
var distanta_parcursa: float = 0.0
var timp: float = 0.0
var inamici_loviti: Array = []
var faza_oscilatie: float = 0.0

func _ready():
	add_to_group("ProiectileJucator")
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play("default")
		$AnimatedSprite2D.flip_h = directie < 0
	faza_oscilatie = randf_range(0.0, PI * 2)

func _physics_process(delta):
	timp += delta
	var pas = directie * viteza * delta
	global_position.x += pas
	# Efect de plutire ondulată caracteristic fantomelor + dispersie pe axa Y
	global_position.y += (viteza_y * delta) + sin(timp * 9.0 + faza_oscilatie) * 1.8
	
	distanta_parcursa += abs(pas)
	if distanta_parcursa >= range_maxim:
		set_physics_process(false)
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.15)
		tween.tween_callback(queue_free)

func _on_body_entered(body):
	if body.is_in_group("Inamici") and not body in inamici_loviti:
		inamici_loviti.append(body)
		body.primeste_damage(damage)
		print("Fantomița a lovit inamicul! Daune: ", damage)
