extends Node
## One continuous stream for the entire application; navigation never restarts it.
const TRACK = preload("res://assets/audio/still-orbit.ogg")
var settings
var player: AudioStreamPlayer
var fade: Tween
var page := "home"
var awaiting_gesture := OS.has_feature("web")
var target_gain := -1.0
var gain := 0.0:
	set(value):
		gain = clampf(value, 0.0, 1.0)
		if player != null:
			player.volume_db = linear_to_db(gain) if gain > 0.00001 else -80.0

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.stream = TRACK
	player.stream.loop = true
	player.volume_db = -80.0
	# Stream playback preserves fades and loop behavior on desktop and Web.
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(player)
	apply_settings(4.0)

func unlock() -> void:
	if not awaiting_gesture: return
	awaiting_gesture = false
	apply_settings(4.0)

func set_page(destination: String) -> void:
	if page == destination: return
	page = destination
	apply_settings(0.8)

func apply_settings(seconds: float = 0.3) -> void:
	var target: float = settings.music_volume * (0.72 if page in ["game", "editor_test"] else 1.0)
	if not settings.music_enabled or awaiting_gesture: target = 0.0
	if is_equal_approx(target, target_gain): return
	target_gain = target
	if fade != null and fade.is_running(): fade.kill()
	if target > 0.0:
		if not player.has_stream_playback(): player.play()
		player.stream_paused = false
	if seconds <= 0.0:
		gain = target
		player.stream_paused = target == 0.0
		return
	fade = create_tween()
	fade.tween_property(self, "gain", target, seconds).set_trans(Tween.TRANS_SINE)
	if target == 0.0: fade.tween_callback(func(): player.stream_paused = true)

func _input(event: InputEvent) -> void:
	if not awaiting_gesture: return
	if (event is InputEventMouseButton or event is InputEventKey or event is InputEventScreenTouch) and event.is_pressed():
		unlock()
