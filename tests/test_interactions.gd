extends SceneTree
## Scene-level checks for playback, parameter picking, rollback and undo.
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	var ui: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	for entry in LabCatalog.ENTRIES:
		ui._select(entry)
		for i in ui.model.operations().size():
			ui._select(entry)
			ui._choose_operation(i)
			var before: Dictionary = ui.model.view().duplicate(true)
			ui.execute_button.pressed.emit()
			check(ui.history.size() == 1, entry[1] + " executes from form")
			check(ui.trace.size() > 0, entry[1] + " creates timeline")
			ui._go(ui.trace.size() - 1)
			check(not ui.execute_button.disabled, entry[1] + " enables next operation")
			ui._undo()
			check(ui.model.view() == before, entry[1] + " undo restores exact model view")
			check(ui.model.invariant().is_empty(), entry[1] + " undo invariant")
			check(ui.history.is_empty(), entry[1] + " undo history consumed")
	# Parse error and model validation leave both state and history untouched.
	ui._select(LabCatalog.ENTRIES[0])
	var before: Dictionary = ui.model.view().duplicate(true)
	ui.editors.index.text = "invalid"
	ui.execute_button.pressed.emit()
	check(ui.status.text.contains("整数"), "invalid numeric input is visible")
	check(ui.model.view() == before and ui.history.is_empty(), "parse error is transactional")
	ui.editors.index.text = "99"
	ui.execute_button.pressed.emit()
	check(ui.status.text.contains("位置"), "out of range error is visible")
	check(ui.model.view() == before and ui.history.is_empty(), "model failure rolls back")
	# Real Tween must freeze with playback and resume from the same point.
	ui.editors.index.text = "1"
	ui.execute_button.pressed.emit()
	ui._show_frame(1, true)
	await process_frame
	ui._toggle_play()
	var progress: float = ui.canvas.progress
	for i in 5: await process_frame
	check(not ui.playing and ui.canvas.progress == progress, "pause freezes Tween")
	ui._toggle_play()
	check(ui.playing, "play resumes")
	ui._go(ui.trace.size() - 1)
	check(not ui.playing and ui.cursor == ui.trace.size() - 1, "jump finishes playback")
	# Clicking coordinate/ID nodes fills the intended fields.
	ui._select(LabCatalog.ENTRIES[11]) # Fenwick
	ui._pick_node("a2")
	check(ui.editors.index.text == "3" and ui.editors.value.text == "5", "Fenwick click index preserves delta")
	ui._choose_operation(1)
	ui._pick_node("a1")
	ui._pick_node("a5")
	check(ui.editors.l.text == "2" and ui.editors.r.text == "6", "range endpoints alternate")
	ui._select(LabCatalog.ENTRIES[12]) # 2D Fenwick
	ui._pick_node("a2_3")
	check(ui.editors.x.text == "2" and ui.editors.y.text == "3", "matrix coordinate picking")
	ui._select(LabCatalog.ENTRIES[21]) # Fibonacci
	ui._choose_operation(2)
	ui._pick_node("8")
	check(ui.editors.id.text == "8", "heap node ID picking")
	ui._select(LabCatalog.ENTRIES[29]) # LCT
	ui._pick_node("v2")
	ui._pick_node("a5")
	check(ui.editors.u.text == "2" and ui.editors.v.text == "5", "LCT endpoints alternate")
	ui._select(LabCatalog.ENTRIES[26]) # Treap deterministic RNG through undo
	ui.execute_button.pressed.emit()
	var first: Dictionary = ui.model.view().duplicate(true)
	ui._undo()
	ui.execute_button.pressed.emit()
	check(ui.model.view() == first, "undo restores Treap RNG and node IDs")
	print("Scene interaction tests: %d checks; %d failures." % [checks, failures])
	ui.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
