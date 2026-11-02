class_name GraySession
extends RefCounted

const Puzzle = preload("res://scripts/puzzle.gd")

var level: Dictionary
var state: Dictionary
var steps := 0
var selected := -1
var history: Array = []
var hard_mode := false

func start(definition: Dictionary, hard: bool = false) -> void:
	level = definition
	hard_mode = hard
	restart()

func restart() -> void:
	state = Puzzle.from_level(level)
	steps = 0
	selected = -1
	history.clear()

func play(direction: String) -> Dictionary:
	if Puzzle.won(state):
		return {}
	var result := Puzzle.move(state, selected, direction)
	if result.is_empty():
		return {}
	history.append({"state": state, "selected": selected, "steps": steps,
		"action": {"source": selected, "direction": direction}})
	state = result.state
	steps += 1
	selected = -1 if result.merged else int(result.target)
	return result

func undo() -> bool:
	if history.is_empty():
		return false
	var previous: Dictionary = history.pop_back()
	state = previous.state
	selected = previous.selected
	steps = previous.steps
	return true

func cleared() -> bool:
	return Puzzle.won(state) and (not hard_mode or steps == int(level.optimal_moves))

func actions() -> Array:
	var result: Array = []
	for entry in history:
		result.append(entry.action.duplicate())
	return result

func restore(definition: Dictionary, hard: bool, saved_actions: Array) -> bool:
	start(definition, hard)
	if saved_actions.size() > 10000:
		return false
	for action in saved_actions:
		if not action is Dictionary or not action.get("direction") is String:
			restart()
			return false
		var source = action.get("source")
		if not (source is int or source is float) or not is_finite(source) or source != floor(source) or source < 0 or source >= state.pieces.size():
			restart()
			return false
		selected = int(source)
		if play(action.direction).is_empty():
			restart()
			return false
	return true

func cycle_selection(backwards: bool = false) -> void:
	var selectable: Array[int] = []
	for i in state.pieces.size():
		if state.pieces[i] != 0:
			selectable.append(i)
	if selectable.is_empty():
		selected = -1
		return
	var offset := -1 if backwards else 1
	var index := selectable.find(selected)
	if index < 0:
		selected = selectable[-1] if backwards else selectable[0]
		return
	selected = selectable[posmod(index + offset, selectable.size())]
