extends SceneTree
const Settings = preload("res://scripts/settings.gd")
const Progress = preload("res://scripts/progress.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Model = preload("res://scripts/editor_model.gd")
var directory := "user://progression_test_%d" % OS.get_process_id()
var viewport: SubViewport
var app
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in 4: await process_frame

func click(control: Control) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = control.get_global_rect().get_center()
		viewport.push_input(event,true)

func make_app() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	app.settings = Settings.new(directory.path_join("settings.cfg"))
	app.settings.music_enabled = false
	app.settings.reduce_motion = true
	app.progress = Progress.new(directory.path_join("progress.json"))
	app.editor_directory = directory.path_join("editor")
	viewport.add_child(app)

func complete(index: int, hard: bool) -> void:
	check(app.start_level(index,hard), "An unlocked level starts")
	for action in app.levels[index].solution:
		app.game.session.selected = int(action.source)
		app.game._try_move(action.direction)
	check(app.game.session.cleared(), "A saved legal solution completes the level")

func developer(enabled: bool) -> void:
	app._navigate("settings")
	app.preferences._developer_tab()
	await settle()
	if app.settings.developer_mode != enabled: click(app.preferences.switches.developer_mode)
	await settle()

func capture(name_value: String) -> void:
	if DisplayServer.get_name() == "headless": return
	redraw(viewport)
	await process_frame
	RenderingServer.force_draw()
	viewport.get_texture().get_image().save_png("res://builds/"+name_value+".png")

func redraw(node: Node) -> void:
	if node is CanvasItem: node.queue_redraw()
	for child in node.get_children(): redraw(child)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,820)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	make_app()
	await settle()
	var levels: Array = app.levels
	var chapters: Array = Catalog.chapters(levels)
	check(not app.settings.developer_mode and app.progress.unlocked_chapters(levels)==[chapters[0]], "Only the first chapter is open to a new player")
	click(app.home.continue_button)
	await settle()
	check(app.screen=="campaign" and app.campaign.cards.all(func(card):return not card.disabled), "Start opens the available first chapter")
	app.campaign._shift(1)
	await settle()
	check(app.campaign.cards.all(func(card):return card.disabled) and not app.campaign.detail.text.is_empty(), "Later chapters show disabled cards and the unlocking condition")
	click(app.campaign.cards[0])
	check(app.screen=="campaign", "Locked cards cannot start a game")
	check(not app.start_level(3,false) and not app.start_level(-1,false) and not app.start_level(levels.size(),false), "Application-level guards reject locked and invalid level indices")
	check(app.progress.resume.is_empty(), "Rejected navigation never overwrites a checkpoint")
	await capture("chapter-locked-1280")
	complete(2,false)
	check(app.game.next_button.disabled, "The final level's Next is locked while another Easy remains unfinished")
	app.game._next()
	check(app.screen=="campaign" and app.game.current==2, "The Next route cannot bypass a chapter lock")
	complete(0,true)
	check(app.progress.records["01"].hard and app.progress.records["01"].easy, "Hard completion automatically records Easy completion")
	check(not app.progress.level_unlocked(levels,3), "Partial Easy completion cannot unlock the next chapter")
	complete(1,false)
	check(app.progress.level_unlocked(levels,3) and not app.progress.level_unlocked(levels,7), "All Easy clears unlock precisely the next chapter")
	var reload := Progress.new(app.progress.path)
	reload.bind_catalog(levels)
	check(reload.chapter_complete(levels,chapters[0]) and reload.level_unlocked(levels,3), "Chapter progression survives restarting")
	complete(2,false)
	check(not app.game.next_button.disabled, "The boundary Next becomes available after all Easy clears")
	app.game._next()
	check(app.game.current==3, "An unlocked boundary advances to the next chapter")
	var genuine: Dictionary = app.progress.records.duplicate(true)
	await developer(true)
	check(app.progress.unlocked_chapters(levels,true).size()==chapters.size() and not app.preferences.editor_button.disabled, "Developer mode unlocks every chapter and the editor")
	check(app.start_level(29,true), "Developer mode can jump directly to the final level")
	var checkpoint := FileAccess.get_file_as_string(app.progress.path)
	app.pause_game()
	await developer(false)
	app._navigate("back")
	await settle()
	check(app.screen=="campaign" and not app.campaign.resume_button.visible, "Disabling Developer mode leaves a locked run and hides Continue")
	app._navigate("continue")
	check(app.screen=="campaign" and not app.start_level(29,false), "Continue and direct start cannot bypass a restored lock")
	check(FileAccess.get_file_as_string(app.progress.path)==checkpoint and app.progress.records==genuine, "Toggling Developer mode preserves the checkpoint and never fabricates completion")
	await developer(true)
	app._navigate("continue")
	check(app.screen=="game" and app.game.current==29, "Re-enabling Developer mode can resume the preserved run")
	await developer(true)
	click(app.preferences.editor_button)
	await settle()
	check(app.screen=="editor", "Enabled Developer mode opens level creation")
	app.editor._replace(Model.parse({"layout":["wb"],"title":"Orbit"}).model)
	app.editor._save()
	app.editor._playtest()
	await settle()
	app.pause_game()
	await developer(false)
	app._navigate("back")
	await settle()
	check(app.screen=="my_levels" and not app.my_levels.create_button.visible and not app.my_levels.rows[0].edit.visible, "Disabling Developer mode exits authoring and hides Create and Edit")
	app._navigate("editor")
	app.my_levels.edit_requested.emit(app.custom_library.list_levels()[0].path)
	check(app.screen=="my_levels", "Editor routes and edit signals enforce Developer mode")
	click(app.my_levels.rows[0].play)
	await settle()
	check(app.screen=="editor_test" and app.test_game.custom_return=="my_levels", "Saved custom levels remain playable without authoring permissions")
	app._navigate("my_levels")
	await developer(true)
	app._navigate("back")
	check(app.my_levels.create_button.visible and app.my_levels.rows[0].edit.visible, "Re-enabling Developer mode restores creation controls")
	viewport.remove_child(app)
	app.queue_free()
	await settle()
	make_app()
	check(app.settings.developer_mode and app.progress.level_unlocked(levels,29,true), "Developer access persists after restarting")
	var legacy_path := directory.path_join("legacy.json")
	var file := FileAccess.open(legacy_path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":2,"records":{"01":{"best":1,"easy":false,"hard":true,"content_hash":Catalog.fingerprint(levels[0])}}}));file.close()
	var legacy := Progress.new(legacy_path)
	legacy.bind_catalog(levels)
	check(legacy.records["01"].easy and legacy.completed(false)==1, "Older Hard-only records also count as Easy")
	var stages := Progress.new(directory.path_join("stages.json"))
	for i in chapters.size():
		check(stages.unlocked_chapters(levels).size()==i+1, "Each chapter opens only after its predecessors")
		for level in levels:
			if level.chapter==chapters[i]: stages.record_clear(level,level.optimal_moves,true)
		check(stages.chapter_complete(levels,chapters[i]), "Hard clears satisfy a whole chapter's Easy requirement")
	var skipped := Progress.new(directory.path_join("skipped.json"))
	for level in levels:
		if level.chapter==chapters[-2]: skipped.record_clear(level,level.optimal_moves,true)
	check(skipped.unlocked_chapters(levels)==[chapters[0]], "Out-of-order developer clears cannot bypass an unfinished earlier chapter")
	viewport.queue_free()
	await settle()
	remove_tree(directory)
	print("ANNIHILATION progression: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func remove_tree(path: String) -> void:
	var folder := DirAccess.open(path)
	if folder==null:return
	for name in folder.get_files():DirAccess.remove_absolute(path.path_join(name))
	for name in folder.get_directories():remove_tree(path.path_join(name))
	DirAccess.remove_absolute(path)
