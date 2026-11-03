extends SceneTree
const Puzzle = preload("res://scripts/puzzle.gd")
const Model = preload("res://scripts/editor_model.gd")
const Records = preload("res://scripts/custom_records.gd")
const Session = preload("res://scripts/session.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	for index in 4:
		var glyph: String = Puzzle.FIELD_GLYPHS[index]
		var direction: String = Puzzle.FIELD_DIRECTIONS[index]
		var state := Puzzle.from_level({"layout":["...", "."+glyph+".", "..."], "tokens":[[4,1]]})
		for attempt in Puzzle.DIRECTIONS:
			var result := Puzzle.move(state,4,attempt)
			check(result.is_empty() == (attempt != direction), "A field permits only its own departure direction: " + glyph + " / " + attempt)
			if not result.is_empty():
				check(not result.teleported and result.state.pieces.count(1)==1 and result.state.board==state.board, "Field movement is one normal step and keeps terrain")
	var state := Puzzle.from_level({"layout":["w>>b"]})
	var arrival := Puzzle.move(state,0,"right")
	check(arrival.target==1 and arrival.state.pieces[1]==1, "Arrival stops on the field without forced motion or teleport between matching arrows")
	check(Puzzle.move(arrival.state,1,"left").is_empty(), "A particle cannot retreat against a field")
	check(Puzzle.move(arrival.state,1,"right").target==2, "Repeated arrows are separate ordinary tiles")
	var collision := Puzzle.move(Puzzle.from_level({"layout":["w>>"], "tokens":[[1,-1]]}),0,"right")
	check(collision.merged and collision.state.board==[0,-1,28], "A collision destroys only its field tile; another matching field stays intact")
	var sideways := Puzzle.move(Puzzle.from_level({"layout":["w.","^b"]}),0,"down")
	check(sideways.target==2 and sideways.state.pieces[2]==1, "A field accepts arrival against its arrow")
	var portal := Puzzle.from_level({"layout":[">A#Ab"],"tokens":[[0,1]]})
	var travel := Puzzle.move(portal,0,"right")
	check(travel.teleported and travel.target==3, "An allowed field departure may enter a portal normally")
	check(Puzzle.move(travel.state,3,"left").is_empty(), "Portals never treat a field as their paired exit")
	var black := Puzzle.from_level({"layout":["b>"],"tokens":[[1,1]]})
	check(Puzzle.move(black,0,"right").merged, "Black particles may collide with a white particle standing on a field")
	var session := Session.new()
	session.start({"layout":["w>>b"],"optimal_moves":3},false)
	session.selected=0
	session.play("right")
	session.play("left")
	check(session.steps==1 and session.history.size()==1, "Rejected field departures cost no move or undo entry")
	session.play("right")
	session.play("right")
	check(session.cleared() and session.steps==3, "Field walks use the ordinary completion and move count")
	session.undo()
	check(session.state.board==[0,28,28,0] and session.state.pieces[2]==1 and session.steps==2, "Undo restores a completed field walk")
	var model = Model.parse({"layout":["w>v", "^<b"]}).model
	model.paint(1,"black")
	model.paint(1,"clear")
	check(model.board[1]==28, "Particle painting and erasing preserve the field")
	model.paint(1,"up")
	model.undo()
	check(model.board[1]==28, "Undo restores the previous arrow direction")
	model.redo()
	check(model.board[1]==27, "Redo restores the changed direction")
	model.paint(1,"white")
	var parsed := Model.parse(JSON.parse_string(JSON.stringify(model.document())))
	check(parsed.has("model") and parsed.model.state()==model.state(), "All arrow directions and particles survive JSON round trips")
	model.resize_grid(4,3)
	check(model.board[1]==27 and model.board[4]==27, "Resizing preserves field positions and directions")
	var first := {"layout":["w>AbA"]}
	var relabeled := {"layout":["w>ZbZ"]}
	var changed := {"layout":["w<AbA"]}
	check(Records.fingerprint(first)==Records.fingerprint(relabeled), "Portal relabeling preserves a leaderboard containing fields")
	check(Records.fingerprint(first)!=Records.fingerprint(changed), "Changing field orientation starts a different leaderboard")
	check(Records.fingerprint({"layout":["w>><b"]})!=Records.fingerprint({"layout":["w<>>b"]}), "Arrow orientations are never canonicalized like portal letters")
	var walk := [{"source":0,"direction":"right"},{"source":1,"direction":"right"},{"source":2,"direction":"right"}]
	check(Records.replay({"layout":["w>>b"]},walk).size()==3, "JSON scores replay legal field walks")
	check(Records.replay({"layout":["w><b"]},walk).is_empty(), "A shared score cannot bypass a changed field restriction")
	print("ANNIHILATION one-way fields: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
