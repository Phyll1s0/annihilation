extends SceneTree
const Settings = preload("res://scripts/settings.gd")
const Progress = preload("res://scripts/progress.gd")
const Music = preload("res://scripts/music.gd")
var directory := "user://audio_test_%d" % OS.get_process_id()
var app
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func settle(seconds: float = 0.05) -> void:
	await create_timer(seconds).timeout
	for i in 3: await process_frame

func click(control: Control, fraction: float = 0.5) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = control.get_global_rect().position + control.size * Vector2(fraction,0.5)
		event.pressed = pressed
		Input.parse_input_event(event)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	# Probe the actual mixed signal without playing test sound through the speakers.
	AudioServer.set_bus_mute(0,true)
	AudioServer.add_bus()
	var probe := AudioServer.bus_count - 1
	AudioServer.set_bus_name(probe,"MusicProbe")
	var path := directory.path_join("settings.cfg")
	var legacy := ConfigFile.new()
	legacy.set_value("preferences","language","zh_CN")
	legacy.set_value("preferences","music_volume","loud")
	legacy.save(path)
	var restored := Settings.new(path)
	check(restored.language == "zh_CN" and restored.music_volume == 0.45 and restored.music_enabled, "Legacy settings keep their language and get safe music defaults")
	legacy.set_value("preferences","music_volume",-1.0);legacy.save(path)
	check(Settings.new(path).music_volume == 0.0, "Negative saved volume is clamped")
	legacy.set_value("preferences","music_volume",5.0);legacy.save(path)
	check(Settings.new(path).music_volume == 1.0, "Saved volume cannot exceed full scale")
	legacy.set_value("preferences","music_volume",NAN);legacy.save(path)
	check(Settings.new(path).music_volume == 0.45, "Non-finite saved volume falls back safely")
	app = load("res://scenes/main.tscn").instantiate()
	app.settings = Settings.new(path)
	app.settings.language = "en"
	app.settings.reduce_motion = true
	app.settings.music_enabled = false
	app.settings.music_volume = 0.45
	app.settings.save()
	app.progress = Progress.new(directory.path_join("progress.json"))
	root.size = Vector2i(1280,820)
	root.add_child(app)
	app.music.player.bus = "MusicProbe"
	await settle(0.4)
	check(not app.music.player.has_stream_playback() and app.music.gain == 0.0, "A saved mute does not start a stream")
	check(FileAccess.file_exists("res://assets/audio/CREDITS.txt") and FileAccess.file_exists("res://assets/audio/VSCO-CC0-LICENSE.txt"), "Music credits and sample license ship with the game")
	check(app.music.player.stream.loop and absf(app.music.player.stream.get_length()-96.0) < 0.02, "The real 96-second music asset is configured to loop")
	app._navigate("settings")
	await settle()
	click(app.preferences.audio_button)
	await settle()
	var geometry := {}
	for item in [["start",app.home.continue_button],["settings",app.campaign.settings_button],["audio",app.preferences.audio_button],["music",app.preferences.switches.music_enabled],["volume",app.preferences.volume_slider]]:
		var rect: Rect2 = item[1].get_global_rect()
		geometry[item[0]] = {"x":rect.get_center().x,"y":rect.get_center().y,"left":rect.position.x,"width":rect.size.x}
	var geometry_file := FileAccess.open("res://builds/audio-controls.json",FileAccess.WRITE)
	geometry_file.store_string(JSON.stringify(geometry));geometry_file.close()
	check(app.preferences.audio.visible and not app.preferences.volume_slider.editable, "Audio settings expose music and disable the slider while muted")
	click(app.preferences.switches.music_enabled)
	await settle(0.55)
	check(app.music.player.has_stream_playback() and not app.music.player.stream_paused and absf(app.music.gain-0.45)<0.002, "Enabling music fades in the stream even with reduced motion")
	click(app.preferences.volume_slider,0.28)
	await settle(0.4)
	var volume: float = app.settings.music_volume
	check(volume > 0.2 and volume < 0.36 and absf(app.music.gain-volume)<0.002, "Pointer input on the slider updates the real playback gain")
	check(Settings.new(path).music_enabled and absf(Settings.new(path).music_volume-volume)<0.002, "Music preferences persist")
	await settle(0.7)
	check(AudioServer.get_bus_peak_volume_left_db(probe,0)>-95.0, "Decoded piano audio reaches the mixer")
	var position: float = app.music.player.get_playback_position()
	var instance: int = app.music.player.get_instance_id()
	app.show_screen("home")
	app.show_screen("campaign")
	await settle(0.2)
	check(app.music.player.get_instance_id()==instance and app.music.player.get_playback_position()>position, "Navigation keeps a continuous stream and its playhead")
	app.start_level(1,false)
	await settle(0.9)
	check(absf(app.music.gain-volume*0.72)<0.002, "Gameplay gently lowers the selected music level")
	app.pause_game()
	position = app.music.player.get_playback_position()
	await settle(0.2)
	check(app.music.player.get_playback_position()>position, "The pause menu keeps the music playing")
	app._navigate("settings")
	app.preferences._audio_tab()
	click(app.preferences.switches.music_enabled)
	await settle(0.4)
	check(app.music.gain==0.0 and app.music.player.stream_paused, "Mute fades to silence and pauses decoding")
	position = app.music.player.get_playback_position()
	await settle(0.2)
	check(absf(app.music.player.get_playback_position()-position)<0.04, "The muted playhead stays still")
	click(app.preferences.switches.music_enabled)
	await settle(0.45)
	check(not app.music.player.stream_paused and app.music.player.get_playback_position()>position, "Unmuting resumes instead of restarting the track")
	app.preferences.volume_slider.value = 0
	await settle(0.4)
	check(app.music.gain==0.0 and app.music.player.stream_paused, "Zero volume is silent")
	app.preferences.volume_slider.value = 50
	click(app.preferences.switches.music_enabled)
	click(app.preferences.switches.music_enabled)
	await settle(0.45)
	check(not app.music.player.stream_paused and absf(app.music.gain-0.5)<0.002, "Rapid mute and volume changes cannot leave a stale pause callback")
	app.music.player.seek(app.music.player.stream.get_length()-0.1)
	await settle(0.4)
	check(app.music.player.has_stream_playback() and app.music.player.get_playback_position()<1.0, "The real stream loops through its end")
	var web_music := Music.new()
	web_music.settings = app.settings
	web_music.awaiting_gesture = true
	root.add_child(web_music)
	await settle(0.1)
	check(not web_music.player.has_stream_playback(), "Web startup waits for an interaction")
	web_music.unlock()
	await settle(0.1)
	check(web_music.player.has_stream_playback(), "The first interaction unlocks Web startup")
	web_music.queue_free()
	var saved := Settings.new(path)
	check(saved.music_enabled and saved.music_volume==0.5, "The final music level survives reloading settings")
	app.queue_free()
	await settle()
	remove_tree(directory)
	print("ANNIHILATION audio: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func remove_tree(path: String) -> void:
	var folder := DirAccess.open(path)
	if folder == null: return
	for name in folder.get_files(): DirAccess.remove_absolute(path.path_join(name))
	for name in folder.get_directories(): remove_tree(path.path_join(name))
	DirAccess.remove_absolute(path)
