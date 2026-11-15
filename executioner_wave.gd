extends Area2D

@export var viteza: float = 270.0
@export var damage: int = 25
var directie_x: float = -1.0
var durata: float = 4.0

func _ready() -> void:
	add_to_group("ProiectileInamici")
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play("default")
		$AnimatedSprite2D.flip_h = (directie_x > 0)

func set_directie_x(dir: float) -> void:
	directie_x = sign(dir)
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.flip_h = (directie_x > 0)

func _physics_process(delta: float) -> void:
	position.x += directie_x * viteza * delta
	durata -= delta
	if durata <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Jucator") or body.name == "Player":
		if body.has_method("primeste_damage"):
			body.primeste_damage(damage)
		queue_free()
