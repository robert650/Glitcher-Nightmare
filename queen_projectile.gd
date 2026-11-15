extends Area2D

@export var viteza: float = 280.0
@export var damage: int = 15
var directie: Vector2 = Vector2.LEFT
var viata_proiectil: float = 5.0

func _ready() -> void:
	add_to_group("ProiectileInamici")
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play("default")
	rotation = directie.angle()

func set_directie(dir: Vector2) -> void:
	directie = dir.normalized()
	rotation = directie.angle()

func _physics_process(delta: float) -> void:
	position += directie * viteza * delta
	viata_proiectil -= delta
	if viata_proiectil <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Jucator"):
		if body.has_method("primeste_damage"):
			body.primeste_damage(damage)
		queue_free()
	elif body is TileMap or body is StaticBody2D:
		queue_free()
