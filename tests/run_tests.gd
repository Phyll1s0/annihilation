extends SceneTree

const Puzzle = preload("res://scripts/puzzle.gd")
const Session = preload("res://scripts/session.gd")
const Progress = preload("res://scripts/progress.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Settings = preload("res://scripts/settings.gd")
const UserData = preload("res://scripts/user_data.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func level(rows: Array, tokens: Array = []) -> Dictionary:
	return {"layout": rows, "tokens": tokens, "id": "test", "optimal_moves": 1}

func _run() -> void:
	_test_rules()
	_test_session()
	_test_progress()
	_test_framework()
	_test_user_data_migration()
	_test_catalog()
	print("NULL: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _test_rules() -> void:
	var original := Puzzle.from_level(level(["wb"]))
	var fingerprint := Puzzle.key(original)
	var collision := Puzzle.move(original, 0, "right")
	check(Puzzle.won(collision.state), "Opposite colors disappear")
	check(collision.state.board == [0, -1], "Only the destination floor disappears")
	check(Puzzle.key(original) == fingerprint, "Moves never mutate their input")
	check(Puzzle.move(original, 0, "left").is_empty(), "Cannot leave board bounds")
	check(Puzzle.move(original, 0, "diagonal").is_empty(), "Unknown direction is rejected")
	check(Puzzle.move(original, -1, "right").is_empty(), "No selected piece is rejected")
	check(Puzzle.move(Puzzle.from_level(level(["wwb"])), 0, "right").is_empty(), "Same color blocks")
	check(Puzzle.move(Puzzle.from_level(level(["w#b"])), 0, "right").is_empty(), "Missing floor blocks")
	check(Puzzle.move(Puzzle.from_level(level([".w", "b."])), 1, "right").is_empty(), "Horizontal motion never wraps rows")
	var portal := Puzzle.from_level(level(["wA#A.b"]))
	var travel := Puzzle.move(portal, 0, "right")
	check(travel.target == 3 and travel.teleported and not travel.merged, "Portal performs exactly one teleport")
	check(travel.state.pieces[3] == 1 and travel.state.board == portal.board, "Empty exit preserves both portals")
	var exit_hit := Puzzle.move(Puzzle.from_level(level(["wA#A"], [[3, -1]])), 0, "right")
	check(exit_hit.merged and exit_hit.state.board == [0, 0, -1, -1], "Exit collision removes exit and downgrades entry")
	var entry_hit := Puzzle.move(Puzzle.from_level(level(["wA#A"], [[1, -1]])), 0, "right")
	check(entry_hit.merged and not entry_hit.teleported and entry_hit.state.board == [0, -1, -1, 0], "Occupied entry merges before teleporting")
	check(Puzzle.move(Puzzle.from_level(level(["wA#A"], [[3, 1]])), 0, "right").is_empty(), "Same color at exit blocks")
	check(Puzzle.move(Puzzle.from_level(level(["wA#A"], [[1, -1], [3, 1]])), 0, "right").is_empty(), "Exit validation happens before entry collision, using the portal validation order")
	var adjacent := Puzzle.from_level(level(["AA"], [[0, 1]]))
	var return_trip := Puzzle.move(adjacent, 0, "right")
	check(not return_trip.is_empty() and Puzzle.key(return_trip.state) == Puzzle.key(adjacent), "Adjacent portals may return to source without recursion")
	check(Puzzle.solve(original, 1).status == "limit", "Search limit never certifies a minimum")
	check(Puzzle.solve(Puzzle.from_level(level(["w#b"]))).status == "unsolvable", "Search distinguishes an impossible puzzle")
	var additional_group := Puzzle.from_level(level(["wC#Cb"]))
	check(Puzzle.solve(additional_group).moves == 2, "Portal rules support additional letter groups")
	var trap := Puzzle.from_level(level(["w.bw.b"]))
	trap = Puzzle.move(trap, 3, "left").state
	check(Puzzle.solve(trap).status == "unsolvable", "Destroying the bridge can make a level impossible")

func _test_session() -> void:
	var game = Session.new()
	game.start(level(["wb"]), true)
	game.cycle_selection(true)
	check(game.selected == 1, "Shift Tab selects the last piece from no selection")
	game.selected = 0
	game.play("left")
	check(game.steps == 0 and game.history.is_empty(), "Invalid move costs no steps and adds no history")
	game.play("right")
	check(game.steps == 1 and game.cleared(), "Optimal hard clear succeeds")
	check(game.play("right").is_empty(), "Finished board cannot be moved")
	game.undo()
	check(game.steps == 0 and game.selected == 0 and game.state.board == [0, 0], "Undo restores selection, pieces, floor, and steps after a clear")
	var detour := level(["w..b"])
	detour.optimal_moves = 3
	game.start(detour, true)
	game.selected = 0
	for direction in ["right", "left", "right", "right", "right"]:
		game.play(direction)
	check(Puzzle.won(game.state) and not game.cleared() and game.steps == 5, "Nonminimal hard completion does not pass")
	game.hard_mode = false
	check(game.cleared(), "The same nonminimal completion passes easy mode")
	game.restart()
	check(game.steps == 0 and game.history.is_empty() and game.selected == -1, "Restart fully resets runtime state")
	game.start(level(["wA#A"], [[3, -1]]), true)
	game.selected = 0
	game.play("right")
	game.undo()
	check(game.state.board == [0, 1, -1, 1] and game.state.pieces == [1, 0, 0, -1], "Undo restores a destroyed portal pair")

func _test_progress() -> void:
	var path := "user://test_progress_%d.json" % OS.get_process_id()
	var store = Progress.new(path)
	var definition := level(["w..b"])
	definition.id = "01"
	definition.optimal_moves = 3
	check(store.record_clear(definition, 5, true) == OK, "Progress writes successfully")
	check(store.records["01"].easy and not store.records["01"].hard, "Over-budget hard run awards only easy completion")
	store.record_clear(definition, 3, false)
	check(not store.records["01"].hard, "An easy run does not award hard completion")
	store.record_clear(definition, 3, true)
	store.record_clear(definition, 7, false)
	var reloaded = Progress.new(path)
	check(reloaded.records["01"].hard and reloaded.records["01"].best == 3, "Reload preserves hard medal and minimum personal best")
	check(reloaded.completed(false) == 1 and reloaded.completed(true) == 1, "Completion totals are mode-specific")
	DirAccess.remove_absolute(path)

func _test_framework() -> void:
	var catalog := Catalog.load_campaign()
	check(catalog.errors.is_empty() and catalog.levels.size() == 26, "Catalog validates twenty-six certified levels")
	var definition: Dictionary = catalog.levels[1].duplicate(true)
	var hash_value := Catalog.fingerprint(definition)
	definition.title = "A renamed title"
	check(Catalog.fingerprint(definition) == hash_value, "Copy edits preserve level identity")
	definition.layout = ["w...b"]
	check(Catalog.fingerprint(definition) != hash_value, "Layout changes invalidate old completion hashes")
	check(not Catalog.validate(definition).is_empty(), "Catalog rejects a stale solution after layout changes")
	definition = catalog.levels[0].duplicate(true)
	definition.layout = ["wA.b"]
	check(not Catalog.validate(definition).is_empty(), "Catalog rejects an unpaired portal")
	definition = catalog.levels[0].duplicate(true)
	definition.tokens = [[0, -1]]
	check(not Catalog.validate(definition).is_empty(), "Catalog rejects overlapping pieces")
	var game = Session.new()
	definition = catalog.levels[1]
	game.start(definition, true)
	game.selected = 0
	game.play("right")
	var restored = Session.new()
	check(restored.restore(definition, true, game.actions()), "A valid action checkpoint restores")
	check(Puzzle.key(game.state) == Puzzle.key(restored.state) and restored.steps == 1, "Restored state and step count match")
	restored.undo()
	check(restored.steps == 0 and restored.state.pieces[0] == 1, "Restored history supports undo")
	check(not restored.restore(definition, true, [{"source": 0, "direction": "left"}]), "Illegal checkpoint actions are rejected")
	check(restored.steps == 0 and restored.history.is_empty(), "Rejected checkpoint leaves a clean initial state")
	var path := "user://framework_test_%d.json" % OS.get_process_id()
	var store = Progress.new(path)
	store.checkpoint(game)
	store = Progress.new(path)
	store.bind_catalog(catalog.levels)
	check(store.resume.actions.size() == 1 and store.resume.hard_mode, "Checkpoint persists across process reload")
	store.record_clear(definition, 3, true)
	check(store.resume.is_empty(), "A completed run removes its unfinished checkpoint")
	definition = definition.duplicate(true)
	definition.layout = ["w...b"]
	store.bind_catalog([definition])
	check(store.records.is_empty(), "Old medals cannot survive a changed puzzle")
	var legacy := FileAccess.open(path, FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"version": 1, "records": {"01": {"best": 1, "easy": true, "hard": true}}}))
	legacy.close()
	store = Progress.new(path)
	store.bind_catalog(catalog.levels)
	check(store.records.has("01") and store.records["01"].hard, "First prototype progress migrates using known content hashes")
	check(Catalog.recommended(catalog.levels, store.records, false) == 1, "Continue recommends the first unfinished level")
	var config = Settings.new(path + ".cfg")
	check(config.language == "en", "Missing language preferences default to English")
	config.show_hints = false
	config.reduce_motion = true
	config.hard_mode = true
	config.language = "zh_CN"
	check(config.save() == OK, "Preferences save")
	config = Settings.new(path + ".cfg")
	check(not config.show_hints and config.reduce_motion and config.hard_mode, "Preferences survive reload")
	check(config.language == "zh_CN", "The selected language survives reload")
	var invalid := ConfigFile.new()
	invalid.set_value("preferences", "language", "unsupported")
	invalid.save(path + ".cfg")
	check(Settings.new(path + ".cfg").language == "en", "Unsupported language preferences fall back to English")
	invalid.set_value("preferences", "language", 42)
	invalid.save(path + ".cfg")
	check(Settings.new(path + ".cfg").language == "en", "Invalid language value types fall back to English")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".cfg")

func _test_user_data_migration() -> void:
	var directory := "user://rename_test_%d" % OS.get_process_id()
	var legacy := directory.path_join("GRAY")
	var current := directory.path_join("NULL")
	DirAccess.make_dir_recursive_absolute(legacy)
	var source := legacy.path_join("progress.json")
	var contents := "{\"version\":2,\"records\":{}}"
	var file := FileAccess.open(source, FileAccess.WRITE)
	file.store_string(contents)
	file.close()
	check(UserData.migrate_file("progress.json", current) == OK, "Existing progress migrates to the renamed application directory")
	check(FileAccess.get_file_as_string(current.path_join("progress.json")) == contents, "Migration preserves progress contents")
	check(FileAccess.get_file_as_string(source) == contents, "Migration preserves the original save")
	file = FileAccess.open(current.path_join("progress.json"), FileAccess.WRITE)
	file.store_string("current progress")
	file.close()
	check(UserData.migrate_file("progress.json", current) == OK, "Migration is safe to run repeatedly")
	check(FileAccess.get_file_as_string(current.path_join("progress.json")) == "current progress", "Existing NULL saves are never replaced by older saves")
	var preferences := "[preferences]\nshow_hints=false\n"
	file = FileAccess.open(legacy.path_join("settings.cfg"), FileAccess.WRITE)
	file.store_string(preferences)
	file.close()
	check(UserData.migrate_file("settings.cfg", current) == OK, "Settings migrate alongside progress")
	check(FileAccess.get_file_as_string(current.path_join("settings.cfg")) == preferences, "Migration preserves preferences")
	check(UserData.migrate_file("missing.json", current) == OK and not FileAccess.file_exists(current.path_join("missing.json")), "A missing legacy file needs no migration")
	for base in [legacy, current]:
		for name_value in ["progress.json", "settings.cfg"]:
			DirAccess.remove_absolute(base.path_join(name_value))
		DirAccess.remove_absolute(base)
	DirAccess.remove_absolute(directory)

func _test_catalog() -> void:
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))
	check(catalog.size() >= 12, "Original campaign has at least twelve levels")
	for definition in catalog:
		var state := Puzzle.from_level(definition)
		var solution: Array = definition.solution
		for action in solution:
			var result := Puzzle.move(state, int(action.source), action.direction)
			check(not result.is_empty(), "Stored solution is legal: " + definition.id)
			if result.is_empty():
				break
			state = result.state
		check(Puzzle.won(state), "Stored solution clears: " + definition.id)
		var verified := Puzzle.solve(Puzzle.from_level(definition))
		check(verified.status == "solved" and verified.moves == int(definition.optimal_moves), "Godot BFS agrees with independent Python minimum: " + definition.id)
		print("Verified %s: %d moves, %d states" % [definition.id, verified.get("moves", -1), verified.visited])
