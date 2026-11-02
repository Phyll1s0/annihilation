class_name NullSettings
extends RefCounted
const UserData = preload("res://scripts/user_data.gd")
const LANGUAGES := ["en", "zh_CN"]

var path: String
var reduce_motion := false
var show_hints := true
var fullscreen := false
var hard_mode := false
var developer_mode := false
var language := "en"
var music_enabled := true
var music_volume := 0.45

func _init(config_path: String = "user://settings.cfg") -> void:
	path = config_path
	if config_path == "user://settings.cfg":
		var error := UserData.migrate_file("settings.cfg")
		if error != OK:
			push_warning("NULL: could not migrate existing settings (error %d)." % error)
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	for property in ["reduce_motion", "show_hints", "fullscreen", "hard_mode", "developer_mode", "music_enabled"]:
		var value = config.get_value("preferences", property, get(property))
		if value is bool:
			set(property, value)
	var volume = config.get_value("preferences", "music_volume", music_volume)
	if (volume is int or volume is float) and is_finite(volume): music_volume = clampf(volume, 0.0, 1.0)
	var saved_language = config.get_value("preferences", "language", "en")
	if saved_language is String and saved_language in LANGUAGES:
		language = saved_language

func save() -> Error:
	var config := ConfigFile.new()
	for property in ["reduce_motion", "show_hints", "fullscreen", "hard_mode", "developer_mode", "music_enabled"]:
		config.set_value("preferences", property, get(property))
	config.set_value("preferences", "language", language)
	config.set_value("preferences", "music_volume", music_volume)
	var error := config.save(path)
	if error == OK and OS.has_feature("web"): JavaScriptBridge.force_fs_sync()
	return error

func apply_language() -> void:
	TranslationServer.set_locale(language if language in LANGUAGES else "en")

func apply_window() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
