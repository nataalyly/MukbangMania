extends Panel

signal slice_chosen(n)
signal cancelled

const PLATE_SCENE := preload("res://scenes/plate.tscn")

var current_options: Array = [2, 3, 4]
var previews: Array = []
var busy: bool = false
var current_preview: Node2D = null

func _ready() -> void:
	for i in range(3):
		var btn: Button = get_node("Options/Option%d/Btn" % i)
		btn.pressed.connect(_on_option_pressed.bind(i))
	$BtnCancel.pressed.connect(func():
		if not busy:
			cancelled.emit())

func open_for(plate, options: Array = [2, 3, 4]) -> void:
	current_options = options

	for p in previews:
		p.queue_free()
	previews.clear()

	current_preview = _add_preview($CurrentSlot, plate.count, plate.denominator, 0.8)
	$CurrentInfo.text = "%d/%d" % [plate.count, plate.denominator]

	for i in range(3):
		var n: int = options[i]
		var option: Node = get_node("Options/Option%d" % i)
		var new_count: int = plate.count * n
		var new_den: int = plate.denominator * n
		var ok: bool = new_den <= plate.MAX_DENOMINATOR

		option.get_node("Btn").text = str(n)
		option.get_node("Btn").disabled = not ok
		option.get_node("Info").text = ("%d/%d" % [new_count, new_den]) if ok else ""
		if ok:
			_add_preview(option.get_node("Slot"), new_count, new_den, 0.5)

	$Options.modulate.a = 1.0
	visible = true

func _add_preview(slot: Control, count: int, denominator: int, s: float) -> Node2D:
	var p := PLATE_SCENE.instantiate()
	p.can_be_sliced = false
	p.can_give = false
	p.scale = Vector2(s, s)
	slot.add_child(p)
	p.position = slot.custom_minimum_size / 2
	p.get_node("FractionLabel").visible = false
	p.set_fraction(count, denominator)
	previews.append(p)
	return p

func _on_option_pressed(i: int) -> void:
	if busy:
		return
	busy = true
	var n: int = current_options[i]
	create_tween().tween_property($Options, "modulate:a", 0.25, 0.2)
	await current_preview.animate_cut(n)
	busy = false
	slice_chosen.emit(n)
