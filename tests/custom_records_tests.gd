extends SceneTree
const Records = preload("res://scripts/custom_records.gd")
const Model = preload("res://scripts/editor_model.gd")
var failures := 0
var checks := 0
var directory := "user://records_test_%d" % OS.get_process_id()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var model = Model.parse({"layout": ["w..b"], "title": "Orbit"}).model
	var level: Dictionary = model.definition()
	var short: Array = [{"source":0,"direction":"right"},{"source":1,"direction":"right"},{"source":2,"direction":"right"}]
	var long: Array = [{"source":0,"direction":"right"},{"source":1,"direction":"left"}] + short
	var records := Records.new(directory)
	check(records.best(level) == 0, "A fresh map has no record")
	check(records.submit(level, "Alice", long).improved and records.best(level) == 5, "A completed walk establishes a record without searching")
	check(records.submit(level, "Bob", short).improved and records.best(level) == 3, "Another player's shorter walk improves the best known record")
	check(not records.submit(level, "Alice", long).updated, "An equal score is idempotent")
	check(records.submit(level, " alice ", short).updated and records.entries(level).size() == 2, "A name has one personal best regardless of case or padding")
	check(not records.submit(level, "Alice", long).updated, "A worse walk cannot replace a personal best")
	var incomplete := short.slice(0,2)
	check(not records.submit(level, "Incomplete", incomplete).updated, "Unfinished runs cannot enter the leaderboard")
	check(not records.submit(level, "Illegal", [{"source":0,"direction":"up"}]).updated, "Illegal moves cannot enter the leaderboard")
	check(Records.replay(level, short + [{"source":0,"direction":"right"}]).is_empty(), "Actions after completion are rejected")
	check(Records.replay(level, [{"source":INF,"direction":"right"}]).is_empty(), "Invalid source numbers are rejected")
	var merge := records.merge(level, [{"player":"Carol","moves":0,"actions":long}, {"player":"Wrong","actions":[]}, "bad"])
	check(merge.updated == 1 and merge.rejected == 2 and records.entries(level)[2].moves == 5, "Imported move counts come from replay rather than claimed numbers")
	var renamed := level.duplicate(true)
	renamed.title = "Renamed"
	renamed.id = "custom_copy"
	renamed.optimal_moves = 1
	check(records.best(renamed) == 3, "Names, identities, and claimed minima do not change a map's leaderboard")
	var altered := level.duplicate(true)
	altered.layout = ["w...b"]
	check(records.best(altered) == 0, "Changed geometry starts a different leaderboard")
	check(Records.fingerprint({"layout":["wA#Ab"]}) == Records.fingerprint({"layout":["wZ#Zb"]}), "Portal letters do not fragment identical maps")
	check(Records.fingerprint({"layout":["wABABb"]}) != Records.fingerprint({"layout":["wAABBb"]}), "Different portal pairings stay separate")
	var portal := {"layout":["wA#Ab"]}
	check(Records.replay(portal,[{"source":0,"direction":"right"},{"source":3,"direction":"right"}]).size() == 2, "Record replay uses the real portal rules")
	records.set_player("  Guest\n ")
	var reload := Records.new(directory)
	check(reload.player == "Guest" and reload.best(level) == 3 and reload.entries(level).size() == 3, "Player profiles and replayed scores persist across restarting")
	var shared := records.document(model)
	var recipient := Records.new(directory.path_join("recipient"))
	check(recipient.merge(level, JSON.parse_string(JSON.stringify(shared)).records).updated == 3 and recipient.best(level) == 3, "JSON shares merge all personal bests into another library")
	check(recipient.merge(level, shared.records).updated == 0, "Repeated imports do not duplicate rows")
	check(recipient.merge(altered, shared.records).rejected == 3, "Walks from another map cannot populate a changed map")
	var decoded: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(records.path))
	decoded.boards[Records.fingerprint(level)].records[0].actions = []
	var file := FileAccess.open(records.path, FileAccess.WRITE)
	file.store_string(JSON.stringify(decoded)); file.close()
	check(Records.new(directory).entries(level).size() == 2, "Tampered persisted walks are replayed and rejected after reopening")
	var saved_model = Model.parse({"layout":["wAAb"]}).model
	saved_model.paint(1,"white")
	saved_model.paint(1,"clear")
	check(saved_model.board[1] == 1 and saved_model.pieces[1] == 0, "Erase piece keeps the portal underneath")
	saved_model.paint(0,"clear")
	check(saved_model.board[0] == 0 and saved_model.pieces[0] == 0, "Erase piece keeps the floor underneath")
	saved_model.paint(2,"void")
	check(saved_model.board[2] == -1 and saved_model.pieces[2] == 0, "Void removes the entire tile")
	remove_tree(directory)
	print("ANNIHILATION custom records: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func remove_tree(path: String) -> void:
	var folder := DirAccess.open(path)
	if folder == null: return
	for name in folder.get_files(): DirAccess.remove_absolute(path.path_join(name))
	for name in folder.get_directories(): remove_tree(path.path_join(name))
	DirAccess.remove_absolute(path)
