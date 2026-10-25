extends Node2D

const ZONE_HALF_WIDTH := 170.0

const LEVELS := [
	{ "left": [1, 4], "right": [2, 4], "options": [2, 3, 4] },
	{ "left": [1, 2], "right": [1, 4], "options": [2, 3, 4] },
	{ "left": [2, 3], "right": [1, 4], "options": [2, 3, 4] },
	{ "left": [2, 5], "right": [1, 3], "options": [3, 4, 5] },
]
const HAPPY_LINES := ["Yummy!", "Enak banget!", "Hmm, lezat!"]
const WRONG_LINES := ["Duh, sakit perut.."] 

var selected_plate = null
var level_index: int = 0
var level_options: Array = [2, 3, 4]
var expected: Frac
var in_flight: int = 0

func _ready() -> void:
	$PlateLeft.clicked.connect(_on_plate_clicked)
	$PlateRight.clicked.connect(_on_plate_clicked)
	$PlateLeft.piece_released.connect(_on_piece_released)
	$PlateRight.piece_released.connect(_on_piece_released)
	$UI/SlicePanel.slice_chosen.connect(_on_slice_chosen)
	$UI/SlicePanel.cancelled.connect(_on_slice_cancelled)
	$UI/BtnCheck.pressed.connect(_on_check_pressed)
	$UI/BtnReset.pressed.connect(func(): load_level(level_index))
	$UI/ResultPopup/VBox/Buttons/BtnRetry.pressed.connect(func(): load_level(level_index))
	$UI/ResultPopup/VBox/Buttons/BtnNext.pressed.connect(_on_next_pressed)
	load_level(0)

func load_level(index: int) -> void:
	level_index = index
	var lv: Dictionary = LEVELS[index]
	var l: Array = lv["left"]
	var r: Array = lv["right"]
	level_options = lv["options"]
	expected = Frac.new(l[0], l[1]).plus(Frac.new(r[0], r[1]))

	$PlateLeft.reset_cut()
	$PlateRight.reset_cut()
	$PlateLeft.set_fraction(l[0], l[1])
	$PlateRight.set_fraction(r[0], r[1])
	$PlateCenter.set_fraction(0, 1)

	var bubble: Control = $Character/SpeechBubble
	$Character/SpeechBubble/QuestionLabel.text = "%d/%d + %d/%d = ?" % [l[0], l[1], r[0], r[1]]
	$Character.set_expression(&"idle", false)
	$UI/ResultPopup.visible = false
	$UI/SlicePanel.visible = false
	$UI/InputBlocker.visible = false
	in_flight = 0
	_pop_bubble(bubble, true)

func _on_plate_clicked(plate) -> void:
	if $UI/SlicePanel.visible:
		return
	selected_plate = plate
	$UI/SlicePanel.open_for(plate, level_options)

func _on_slice_chosen(n: int) -> void:
	selected_plate.slice_each(n)
	$UI/SlicePanel.visible = false

func _on_slice_cancelled() -> void:
	$UI/SlicePanel.visible = false

func _on_piece_released(_plate, piece) -> void:
	var target = $PlateCenter
	var landing_y: float = target.get_node("LandingPoint").global_position.y

	var over_zone: bool = abs(piece.global_position.x - target.global_position.x) < ZONE_HALF_WIDTH \
		and piece.global_position.y < landing_y

	if over_zone and target.can_accept(piece.denominator):
		in_flight += 1
		piece.landed.connect(_on_piece_landed, CONNECT_ONE_SHOT)
		piece.fall_to(landing_y + randf_range(-15.0, 5.0))
	elif over_zone:
		print("Ukurannya beda, samakan dulu ya!")
		piece.return_home()
	else:
		piece.fall_to(landing_y, true)

func _on_piece_landed(piece) -> void:
	in_flight -= 1
	piece.plate.remove_piece(piece)
	$PlateCenter.adopt_piece(piece)

func _on_check_pressed() -> void:
	if in_flight > 0 or $UI/SlicePanel.visible or $UI/InputBlocker.visible:
		return
	var center = $PlateCenter
	if center.count == 0:
		print("Isi piring tengah dulu ya!")
		return

	$UI/InputBlocker.visible = true

	var total: Frac = center.total()
	var diff: int = total.n * expected.d - expected.n * total.d
	var ex := expected.simplified()

	var msg: Label = $UI/ResultPopup/VBox/MessageLabel
	var detail: Label = $UI/ResultPopup/VBox/DetailLabel

	if diff == 0:
		msg.text = ["Perfect!", "Delicious!"].pick_random()
		detail.text = "Jawabannya %d/%d" % [ex.n, ex.d]
	else:
		msg.text = "I'm full.."
		var hint := "Porsinya masih kurang." if diff < 0 else "Porsinya kebanyakan."
		detail.text = "%s Jawaban yang benar: %d/%d" % [hint, ex.n, ex.d]

	$UI/ResultPopup/VBox/Buttons/BtnNext.visible = (diff == 0)
	$UI/ResultPopup/VBox/Buttons/BtnRetry.visible = (diff != 0)

	await _play_reaction(diff == 0)
	_show_popup()

func _on_next_pressed() -> void:
	if level_index + 1 < LEVELS.size():
		load_level(level_index + 1)
	else:
		print("Semua level selesai!")

func _show_popup() -> void:
	var popup: Control = $UI/ResultPopup
	popup.visible = true
	popup.pivot_offset = popup.size / 2
	popup.scale = Vector2(0.5, 0.5)
	create_tween().tween_property(popup, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _play_reaction(correct: bool) -> void:
	var bubble: Control = $Character/SpeechBubble
	var label: Label = $Character/SpeechBubble/QuestionLabel

	await _pop_bubble(bubble, false)

	label.text = (HAPPY_LINES if correct else WRONG_LINES).pick_random()
	$Character.set_expression(&"happy" if correct else &"full")
	await _pop_bubble(bubble, true)

	await get_tree().create_timer(1.4).timeout

func _pop_bubble(bubble: Control, appear: bool) -> void:
	bubble.pivot_offset = bubble.size / 2
	var tw := create_tween()
	if appear:
		bubble.visible = true
		bubble.scale = Vector2.ZERO
		tw.tween_property(bubble, "scale", Vector2.ONE, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(bubble, "scale", Vector2.ZERO, 0.2) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tw.finished
	if not appear:
		bubble.visible = false
