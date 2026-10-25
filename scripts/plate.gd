extends Node2D

const PIECE_SCENE := preload("res://scenes/piece.tscn")
const MAX_DENOMINATOR := 24
const PIECE_RADIUS := 130.0

signal clicked(plate)
signal piece_grabbed(plate, piece)
signal piece_released(plate, piece)

@export var can_be_sliced: bool = true
@export var can_give: bool = true

var count: int = 0
var denominator: int = 1
var denominators: Array[int] = []
var has_cut: bool = false
var pieces: Array = []

@onready var pieces_node: Node2D = $Pieces
@onready var fraction_label: Label = $FractionLabel

func set_fraction(p_count: int, p_denominator: int, pile: bool = false) -> void:
	for child in pieces_node.get_children():
		child.queue_free()
	denominators.clear()
	pieces.clear()

	count = p_count
	denominator = p_denominator
	for i in range(count):
		var piece := PIECE_SCENE.instantiate()
		pieces_node.add_child(piece)
		piece.setup(denominator)
		piece.plate = self
		piece.grabbable = can_give
		piece.grabbed.connect(func(p): piece_grabbed.emit(p.plate, p))
		piece.released.connect(func(p): piece_released.emit(p.plate, p))

		if pile:
			var rot := randf_range(0.0, TAU)
			var mid := rot + (TAU / denominator) / 2.0
			piece.rotation = rot
			piece.position = -Vector2.from_angle(mid) * PIECE_RADIUS * 0.35 \
				+ Vector2(randf_range(-35.0, 35.0), randf_range(-35.0, 35.0))
			piece.scale = Vector2(0.6, 0.6)
			create_tween().tween_property(piece, "scale", Vector2.ONE, 0.25) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(i * 0.03)
		else:
			piece.rotation = i * TAU / denominator

		pieces.append(piece)
		denominators.append(denominator)

	_update_label()

func _ready() -> void:
	$KnifeButton.visible = can_be_sliced
	$KnifeButton.pressed.connect(func(): clicked.emit(self))

func _on_drop_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not can_be_sliced:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)

func slice_each(n: int) -> bool:
	if has_cut or denominator * n > MAX_DENOMINATOR:
		return false
	has_cut = true
	$KnifeButton.visible = false
	set_fraction(count * n, denominator * n, true)
	return true

func total() -> Frac:
	return Frac.new(count, denominator)

func can_accept(d: int) -> bool:
	return count == 0 or denominator == d

func _update_label() -> void:
	fraction_label.text = "" if count == 0 else "%d/%d" % [count, denominator]

func remove_piece(piece) -> void:
	pieces.erase(piece)
	count = pieces.size()
	_update_label()

func adopt_piece(piece) -> void:
	piece.reparent(pieces_node)
	piece.plate = self
	piece.grabbable = can_give
	pieces.append(piece)
	count = pieces.size()
	denominator = piece.denominator
	_update_label()

func animate_cut(n: int) -> void:
	var new_den := denominator * n
	var new_count := count * n

	var holder := Node2D.new()
	holder.z_index = 50
	pieces_node.add_child(holder)

	var tween := create_tween()
	for k in range(1, new_count):
		if k % n == 0:
			continue
		var dir := Vector2.from_angle(k * TAU / new_den)
		var line := Line2D.new()
		line.width = 8.0
		line.default_color = Color.WHITE
		line.add_point(Vector2.ZERO)
		line.add_point(Vector2.ZERO)
		holder.add_child(line)
		tween.tween_method(
			func(t: float): line.set_point_position(1, dir * PIECE_RADIUS * t),
			0.0, 1.0, 0.15)
	tween.tween_interval(0.25)

	await tween.finished
	holder.queue_free()

func reset_cut() -> void:
	has_cut = false
	$KnifeButton.visible = can_be_sliced
