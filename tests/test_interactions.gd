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

func _entry(kind: String) -> Array:
	for entry in LabCatalog.ENTRIES:
		if entry[1] == kind:
			return entry
	return []

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
	ui._select(_entry("array"))
	var before: Dictionary = ui.model.view().duplicate(true)
	ui.editors.index.text = "invalid"
	ui.execute_button.pressed.emit()
	check(ui.status.text.contains("整数"), "invalid numeric input is visible")
	check(ui.model.view() == before and ui.history.is_empty(), "parse error is transactional")
	ui.editors.index.text = "-9223372036854775808"
	ui.execute_button.pressed.emit()
	check(ui.status.text.contains("9999"), "minimum int64 cannot bypass scalar limits")
	check(ui.model.view() == before and ui.history.is_empty(), "extreme numeric input is transactional")
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
	ui._set_speed(3)
	check(ui.speed == 4.0 and ui.canvas.animation_speed == 4.0,
		"speed change updates timeline and active Tween clock together")
	ui._go(ui.trace.size() - 1)
	check(not ui.playing and ui.cursor == ui.trace.size() - 1, "jump finishes playback")
	ui.editors.index.text = "99"
	ui.execute_button.pressed.emit()
	check(ui.status.has_theme_color_override("font_color"), "operation error uses error color")
	ui._undo()
	check(not ui.status.has_theme_color_override("font_color"), "successful undo clears error color")
	ui.canvas.previous = {"nodes": [{"id": "moving", "pos": Vector2(0, 0)}], "edges": []}
	ui.canvas.current = {"nodes": [{"id": "moving", "pos": Vector2(100, 0)}], "edges": []}
	ui.canvas.progress = 0.25
	check(ui.canvas._interpolated_positions().moving == Vector2(25, 0),
		"click hit testing shares the current interpolated node position")
	# Clicking coordinate/ID nodes fills the intended fields.
	ui._select(_entry("fenwick"))
	ui._pick_node("a2")
	check(ui.editors.index.text == "3" and ui.editors.value.text == "5", "Fenwick click index preserves delta")
	ui._choose_operation(1)
	ui._pick_node("a1")
	ui._pick_node("a5")
	check(ui.editors.l.text == "2" and ui.editors.r.text == "6", "range endpoints alternate")
	ui._select(_entry("fenwick2"))
	ui._pick_node("a2_3")
	check(ui.editors.x.text == "2" and ui.editors.y.text == "3", "matrix coordinate picking")
	ui._select(_entry("linked"))
	check(ui.model.operations()[0].title == "头插" and ui.model.operations()[1].title == "尾插",
		"singly linked list exposes dedicated endpoint insertion controls")
	check(not ui.model.operations().map(func(operation): return operation.id).has("update"),
		"singly linked list removes value update")
	ui.editors.value.text = "99"
	ui.execute_button.pressed.emit()
	check(ui.model.items[0].value == 99, "linked form inserts before head")
	ui._undo()
	check(ui.model.items[0].value == 12, "linked head insertion undo")
	ui._choose_operation(2)
	ui._pick_node(str(ui.model.items[2].id))
	check(ui.editors.index.text == "3", "linked delete target picks its position")
	ui.execute_button.pressed.emit()
	check(ui.model.items.map(func(item): return item.value) == [12, 7, 16],
		"linked form deletes through the target predecessor")
	ui._undo()
	ui._choose_operation(5)
	ui._pick_node(str(ui.model.items[1].id))
	ui._pick_node(str(ui.model.items[3].id))
	check(ui.editors.l.text == "2" and ui.editors.r.text == "4",
		"linked node picks fill both reversal endpoints")
	ui.execute_button.pressed.emit()
	ui._go(ui.trace.size() - 1)
	check(ui.model.items.map(func(item): return item.value) == [12, 16, 24, 7],
		"linked reversal executes from the form")
	ui._undo()
	ui._select(_entry("doubly"))
	check(not ui.model.operations().map(func(operation): return operation.id).has("update")
		and ui.model.operations().map(func(operation): return operation.id).has("get_from_end"),
		"doubly linked form removes update and adds kth-from-end")
	ui._select(_entry("segment2"))
	ui._pick_node("a1_4")
	check(ui.editors.x.text == "1" and ui.editors.y.text == "4", "2D segment uses 1-based cells")
	ui._select(_entry("sparse_table"))
	check(ui.code_label.get_parsed_text().contains("st[i][0] = a[i]"), "literal indices survive text rendering")
	ui._pick_node("s2_1")
	check(ui.editors.l.text == "2" and ui.editors.r.text == "5", "ST bar fills covered interval")
	ui.canvas.fit()
	var bar: Dictionary = ui.canvas.current.nodes.filter(func(node): return node.id == "s4_0")[0]
	var point: Vector2 = (bar.pos + Vector2(bar.size.x / 2 - 5, 0)) * ui.canvas.zoom + ui.canvas.offset
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = point
	mouse.pressed = true
	ui.canvas._gui_input(mouse)
	mouse.pressed = false
	ui.canvas._gui_input(mouse)
	check(ui.editors.l.text == "1" and ui.editors.r.text == "16", "long bar edge is clickable")
	for node in ui.canvas.current.nodes:
		var left: Vector2 = (node.pos - node.size / 2) * ui.canvas.zoom + ui.canvas.offset
		var right: Vector2 = (node.pos + node.size / 2) * ui.canvas.zoom + ui.canvas.offset
		check(Rect2(Vector2.ZERO, ui.canvas.size).has_point(left) and
			Rect2(Vector2.ZERO, ui.canvas.size).has_point(right), "ST fit contains entire bar")
	ui._select(_entry("segment")) # Segment interval/source picking and retained highlights.
	ui._pick_node("a2")
	ui._pick_node("a6")
	check(ui.editors.l.text == "2" and ui.editors.r.text == "6" and ui.editors.value.text == "5",
		"segment source cells select endpoints without changing delta")
	ui.execute_button.pressed.emit()
	ui._go(ui.trace.size() - 1)
	var retained: Dictionary = ui.model.view().duplicate(true)
	var interval: Dictionary = retained.nodes.filter(func(n): return n.get("range", []) == [3, 4])[0]
	ui._pick_node(interval.id)
	check(ui.editors.l.text == "3" and ui.editors.r.text == "4", "segment bar selects covered interval")
	ui._choose_operation(1)
	ui.execute_button.pressed.emit()
	ui._go(ui.trace.size() - 1)
	ui._undo()
	check(ui.model.view() == retained, "undo restores previous range highlights and source array")
	ui._select(_entry("fibonacci"))
	ui._choose_operation(2)
	ui._pick_node("8")
	check(ui.editors.id.text == "8", "heap node ID picking")
	ui._select(_entry("lct"))
	ui._pick_node("v2")
	ui._pick_node("a5")
	check(ui.editors.u.text == "2" and ui.editors.v.text == "5", "LCT endpoints alternate")
	ui._select(_entry("disjoint_set"))
	ui._choose_operation(1)
	check(ui.editors.path_compression is CheckButton and
		ui.editors.union_strategy is OptionButton,
		"disjoint-set settings use toggle and option controls")
	ui.editors.path_compression.button_pressed = false
	ui.editors.union_strategy.selected = 2
	ui._pick_node("d1")
	ui._pick_node("d5")
	check(ui.editors.a.text == "1" and ui.editors.b.text == "5",
		"disjoint-set endpoints alternate")
	var disjoint_before: Dictionary = ui.model.view().duplicate(true)
	ui.execute_button.pressed.emit()
	ui._go(ui.trace.size() - 1)
	check(ui.model.parent[3] == 6 and not ui.model.path_compression and
		ui.model.union_strategy == "size",
		"disjoint-set form applies size union and compression toggle")
	ui._undo()
	check(ui.model.view() == disjoint_before, "disjoint-set undo restores exact forest")
	ui._choose_operation(0)
	ui._pick_node("d3")
	check(ui.editors.x.text == "3", "disjoint-set node fills find argument")
	ui._select(_entry("weighted_disjoint_set"))
	ui._choose_operation(1)
	ui._pick_node("d1")
	ui._pick_node("d3")
	check(ui.editors.a.text == "1" and ui.editors.b.text == "3",
		"weighted disjoint-set endpoints alternate")
	ui._select(_entry("rollback_disjoint_set"))
	ui._pick_node("d7")
	ui._pick_node("d8")
	check(ui.editors.a.text == "7" and ui.editors.b.text == "8",
		"rollback disjoint-set endpoints alternate")
	ui._select(_entry("treap")) # Treap deterministic RNG through undo
	ui.execute_button.pressed.emit()
	var first: Dictionary = ui.model.view().duplicate(true)
	ui._undo()
	ui.execute_button.pressed.emit()
	check(ui.model.view() == first, "undo restores Treap RNG and node IDs")
	print("Scene interaction tests: %d checks; %d failures." % [checks, failures])
	ui.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
