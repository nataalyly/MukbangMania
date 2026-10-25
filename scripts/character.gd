extends Node2D

@onready var body: AnimatedSprite2D = $Body
@onready var base_scale: Vector2 = body.scale

var tween: Tween

func set_expression(anim: StringName, with_bounce: bool = true) -> void:
	if not body.sprite_frames.has_animation(anim):
		push_warning("Animasi tidak ditemukan: %s" % anim)
		return
	body.play(anim)
	if with_bounce:
		bounce()

func bounce() -> void:
	if tween:
		tween.kill()
	body.scale = base_scale
	tween = create_tween()
	tween.tween_property(body, "scale", base_scale * Vector2(1.12, 0.88), 0.08)
	tween.tween_property(body, "scale", base_scale * Vector2(0.94, 1.08), 0.10)
	tween.tween_property(body, "scale", base_scale, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
