extends Node2D

signal grabbed(piece)
signal released(piece)
signal landed(piece)

enum State { IDLE, DRAGGING, FALLING, RETURNING }

const GRAVITY := 2600.0

var denominator: int = 1
var radius: float = 130.0
var color: Color = Color("f4b942")

var plate = null            # piring pemilik saat ini
var grabbable: bool = false
var state: State = State.IDLE
var velocity := Vector2.ZERO
var floor_y: float = 0.0
var return_after_land: bool = false
var grab_offset := Vector2.ZERO
var home_position := Vector2.ZERO
var home_rotation: float = 0.0

var area: Area2D
var shape: CollisionPolygon2D

static var candidates: Array = []

func _ready() -> void:
	area = Area2D.new()
	shape = CollisionPolygon2D.new()
	area.add_child(shape)
	add_child(area)
	area.input_event.connect(_on_area_input_event)

func setup(p_denominator: int) -> void:
	denominator = p_denominator
	shape.polygon = _wedge_points()
	queue_redraw()

func _wedge_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	if denominator > 1:
		points.append(Vector2.ZERO)
	var steps := 24
	var last := steps if denominator == 1 else steps + 1
	var angle := TAU / denominator
	for i in range(last):
		var a := angle * i / steps
		points.append(Vector2(cos(a), sin(a)) * radius)
	return points

func _draw() -> void:
	if denominator == 1:
		draw_circle(Vector2.ZERO, radius, color)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(0, 0, 0, 0.5), 3.0)
		return

	var angle := TAU / denominator
	var points := PackedVector2Array([Vector2.ZERO])
	var steps := 24
	for i in range(steps + 1):
		var a := angle * i / steps
		points.append(Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(points, color)

	points.append(Vector2.ZERO)
	draw_polyline(points, Color(0, 0, 0, 0.5), 3.0)

func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not grabbable or state != State.IDLE:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		candidates.append(self)
		if candidates.size() == 1:
			_resolve_grab.call_deferred()

func _input(event: InputEvent) -> void:
	if state == State.DRAGGING and event is InputEventMouseButton \
			and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		state = State.IDLE
		released.emit(self)

func _process(delta: float) -> void:
	match state:
		State.DRAGGING:
			global_position = get_global_mouse_position() + grab_offset
		State.FALLING:
			velocity.y += GRAVITY * delta
			global_position += velocity * delta
			if global_position.y >= floor_y:
				global_position.y = floor_y
				if velocity.y > 350.0:
					velocity.y = -velocity.y * 0.3
				else:
					velocity = Vector2.ZERO
					if return_after_land:
						return_home()
					else:
						state = State.IDLE
						z_index = 0
						landed.emit(self)

func fall_to(p_floor_y: float, p_return_after: bool = false) -> void:
	floor_y = p_floor_y
	return_after_land = p_return_after
	velocity = Vector2.ZERO
	state = State.FALLING

func return_home() -> void:
	state = State.RETURNING
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "global_position", home_position, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "rotation", home_rotation, 0.25)
	tw.chain().tween_callback(func():
		state = State.IDLE
		z_index = 0)

func _resolve_grab() -> void:
	var top = null
	for c in candidates:
		if not is_instance_valid(c):
			continue
		if top == null or c.get_index() > top.get_index():
			top = c
	candidates.clear()
	if top != null:
		top._begin_grab()

func _begin_grab() -> void:
	if state != State.IDLE:
		return
	home_position = global_position
	home_rotation = rotation
	grab_offset = global_position - get_global_mouse_position()
	state = State.DRAGGING
	z_index = 100
	grabbed.emit(self)
