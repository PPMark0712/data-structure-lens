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
			check(ui.operation_note.text == "操作说明\n" + ui.selected_op.note, entry[1] + " selected operation note")
			check(ui.operation_note.get_parent().get_index() == ui.execute_button.get_index() + 1,
				entry[1] + " note immediately below execute")
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
	ui._select(LabCatalog.ENTRIES[2]) # Linked head picking uses position 1.
	ui._pick_node(str(ui.model.head))
	check(ui.editors.index.text == "1", "linked head picks position 1")
	ui.editors.value.text = "99"
	ui.execute_button.pressed.emit()
	check(ui.model.items[0].value == 99, "linked form inserts before head")
	ui._undo()
	check(ui.model.items[0].value == 12, "linked head insertion undo")
	ui._select(LabCatalog.ENTRIES[16]) # 2D segment
	ui._pick_node("a1_4")
	check(ui.editors.x.text == "1" and ui.editors.y.text == "4", "2D segment uses 1-based cells")
	ui._select(LabCatalog.ENTRIES[13]) # ST bar endpoints
	check(ui.code_label.get_parsed_text().contains("st[i][0] = a[i]"), "literal indices survive text rendering")
	ui._pick_node("s2_1")
	check(ui.editors.l.text == "2" and ui.editors.r.text == "5", "ST bar fills covered interval")
	ui.canvas.fit()
	var bar: Dictionary = ui.canvas.current.nodes.filter(func(node): return node.id == "s3_0")[0]
	var point: Vector2 = (bar.pos + Vector2(bar.size.x / 2 - 5, 0)) * ui.canvas.zoom + ui.canvas.offset
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = point
	mouse.pressed = true
	ui.canvas._gui_input(mouse)
	mouse.pressed = false
	ui.canvas._gui_input(mouse)
	check(ui.editors.l.text == "1" and ui.editors.r.text == "8", "long bar edge is clickable")
	for node in ui.canvas.current.nodes:
		var left: Vector2 = (node.pos - node.size / 2) * ui.canvas.zoom + ui.canvas.offset
		var right: Vector2 = (node.pos + node.size / 2) * ui.canvas.zoom + ui.canvas.offset
		check(Rect2(Vector2.ZERO, ui.canvas.size).has_point(left) and
			Rect2(Vector2.ZERO, ui.canvas.size).has_point(right), "ST fit contains entire bar")
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
