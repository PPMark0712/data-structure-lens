extends Control

const CanvasScript := preload("res://scripts/ui/canvas.gd")
const BG := Color("#fdf6e3")
const PANEL := Color("#eee8d5")
const INK := Color("#252a2b")
var model: LabModel
var selected_entry: Array
var canvas: LabCanvas
var sidebar: VBoxContainer
var operation_box: VBoxContainer
var fields_box: VBoxContainer
var operation_picker: OptionButton
var editors := {}
var selected_op: Dictionary
var timeline: HSlider
var play_button: Button
var execute_button: Button
var operation_note: Label
var status: Label
var heading: Label
var subtitle: Label
var stats: Label
var explanation: RichTextLabel
var stack_label: RichTextLabel
var code_label: RichTextLabel
var counter: Label
var speed_picker: OptionButton
var search: LineEdit
var trace: Array[Dictionary] = []
var cursor := 0
var playing := false
var elapsed := 0.0
var speed := 1.0
var syncing := false
var history: Array[Dictionary] = []
var undo_button: Button
var pick_second := false

func _ready() -> void:
	_build_theme()
	_build_ui()
	_show_menu("")
	_select(LabCatalog.ENTRIES[0])
	# Smoke checks and browser automation can choose a module without private engine APIs.
	var initial := OS.get_environment("LAB_MODULE")
	for entry in LabCatalog.ENTRIES:
		if entry[1] == initial:
			_select(entry)
			break

func _build_theme() -> void:
	var skin := Theme.new()
	skin.default_font_size = 17
	if ResourceLoader.exists("res://assets/NotoSansSC.ttf"):
		skin.default_font = load("res://assets/NotoSansSC.ttf")
	for type in ["Label", "Button", "LineEdit", "OptionButton", "CheckButton", "RichTextLabel", "PopupMenu"]:
		skin.set_color("font_color", type, INK)
		skin.set_color("font_hover_color", type, INK)
		skin.set_color("font_pressed_color", type, INK)
		skin.set_color("font_hover_pressed_color", type, INK)
		skin.set_color("font_focus_color", type, INK)
		skin.set_color("font_disabled_color", type, Color("#8b887f"))
	skin.set_color("default_color", "RichTextLabel", INK)
	skin.set_color("font_placeholder_color", "LineEdit", Color("#777367"))
	skin.set_color("caret_color", "LineEdit", INK)
	skin.set_color("selection_color", "LineEdit", Color("#bce1ef"))
	for type in ["Button", "OptionButton", "LineEdit"]:
		for state in ["normal", "hover", "pressed", "focus", "disabled", "read_only"]:
			var box := StyleBoxFlat.new()
			box.bg_color = Color("#cce4eb") if state in ["hover", "pressed"] else BG
			box.border_color = Color("#a5a091") if state == "disabled" else INK
			box.set_border_width_all(1)
			box.set_corner_radius_all(4)
			box.content_margin_left = 12
			box.content_margin_right = 12
			box.content_margin_top = 9
			box.content_margin_bottom = 9
			skin.set_stylebox(state, type, box)
	var popup := StyleBoxFlat.new()
	popup.bg_color = BG
	popup.border_color = INK
	popup.set_border_width_all(1)
	popup.set_corner_radius_all(4)
	for side in ["left", "right", "top", "bottom"]:
		popup.set("content_margin_" + side, 8)
	skin.set_stylebox("panel", "PopupMenu", popup)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color("#cce4eb")
	skin.set_stylebox("hover", "PopupMenu", hover)
	theme = skin

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)
	var top := HBoxContainer.new()
	root.add_child(top)
	var brand := _label("数据结构实验室", 25)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(brand)
	top.add_child(_label("30 个实验  /  小规模 · 看见每一步", 15))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	root.add_child(body)
	var nav := VBoxContainer.new()
	nav.custom_minimum_size.x = 215
	body.add_child(nav)
	search = LineEdit.new()
	search.placeholder_text = "搜索结构…"
	search.text_changed.connect(_show_menu)
	nav.add_child(search)
	var nav_scroll := ScrollContainer.new()
	nav_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	nav.add_child(nav_scroll)
	sidebar = VBoxContainer.new()
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_scroll.add_child(sidebar)
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(center)
	heading = _label("", 25)
	center.add_child(heading)
	subtitle = _label("", 15)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(subtitle)
	var tools := HBoxContainer.new()
	center.add_child(tools)
	stats = _label("", 15)
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(stats)
	tools.add_child(_button("−", func(): canvas.magnify(1.0 / 1.2)))
	tools.add_child(_button("+", func(): canvas.magnify(1.2)))
	tools.add_child(_button("适应", func(): canvas.fit()))
	canvas = CanvasScript.new()
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.picked.connect(_pick_node)
	center.add_child(canvas)
	center.add_child(_label("滚轮缩放 · 拖拽平移 · 点击节点填入位置 / 编号", 13))
	timeline = HSlider.new()
	timeline.step = 1
	timeline.value_changed.connect(_seek)
	center.add_child(timeline)
	var controls := HBoxContainer.new()
	center.add_child(controls)
	controls.add_child(_button("首步", func(): _go(0)))
	controls.add_child(_button("上一步", func(): _go(cursor - 1)))
	play_button = _button("播放", _toggle_play)
	controls.add_child(play_button)
	controls.add_child(_button("下一步", func(): _go(cursor + 1)))
	controls.add_child(_button("末步", func(): _go(trace.size() - 1)))
	counter = _label("", 14)
	counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(counter)
	speed_picker = OptionButton.new()
	for text in ["0.5×", "1×", "2×", "4×"]:
		speed_picker.add_item(text)
	speed_picker.selected = 1
	speed_picker.item_selected.connect(func(i): speed = [0.5, 1.0, 2.0, 4.0][i])
	controls.add_child(speed_picker)
	var right_scroll := ScrollContainer.new()
	right_scroll.custom_minimum_size.x = 315
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(right_scroll)
	operation_box = VBoxContainer.new()
	operation_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	operation_box.add_theme_constant_override("separation", 10)
	right_scroll.add_child(operation_box)
	operation_box.add_child(_label("操作", 20))
	operation_picker = OptionButton.new()
	operation_picker.item_selected.connect(_choose_operation)
	operation_box.add_child(operation_picker)
	fields_box = VBoxContainer.new()
	operation_box.add_child(fields_box)
	execute_button = _button("执行操作", _execute)
	operation_box.add_child(execute_button)
	var note_panel := PanelContainer.new()
	var note_style := StyleBoxFlat.new()
	note_style.bg_color = PANEL
	note_style.set_corner_radius_all(4)
	for side in ["left", "right", "top", "bottom"]:
		note_style.set("content_margin_" + side, 10)
	note_panel.add_theme_stylebox_override("panel", note_style)
	operation_box.add_child(note_panel)
	operation_note = _label("", 14)
	operation_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_panel.add_child(operation_note)
	var reset_row := HBoxContainer.new()
	operation_box.add_child(reset_row)
	reset_row.add_child(_button("恢复默认", func(): _select(selected_entry)))
	undo_button = _button("撤销操作", _undo)
	reset_row.add_child(undo_button)
	status = _label("", 14)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	operation_box.add_child(status)
	operation_box.add_child(HSeparator.new())
	operation_box.add_child(_label("当前步骤", 20))
	explanation = _rich(90)
	operation_box.add_child(explanation)
	operation_box.add_child(_label("算法步骤", 18))
	code_label = _rich(150)
	operation_box.add_child(code_label)
	operation_box.add_child(_label("调用栈 / 路径", 18))
	stack_label = _rich(130)
	operation_box.add_child(stack_label)
	root.add_child(_label("DATA STRUCTURE LAB    ·    Godot / GDScript    ·    米黄纸上的算法", 13))

func _label(text: String, font_size: int = 17) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	return button

func _rich(height: float) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = false
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size = Vector2(290, height)
	label.selection_enabled = true
	return label

func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _show_menu(filter: String) -> void:
	_clear(sidebar)
	var group := ""
	for entry in LabCatalog.ENTRIES:
		if not filter.is_empty() and not (entry[2] + entry[1]).to_lower().contains(filter.to_lower()):
			continue
		if group != entry[0]:
			group = entry[0]
			sidebar.add_child(_label(group, 14))
		var button := _button(entry[2], func(): _select(entry))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = entry[3]
		button.disabled = not ResourceLoader.exists("res://scripts/models/%s.gd" % entry[4])
		sidebar.add_child(button)

func _select(entry: Array) -> void:
	var next := LabCatalog.create(entry)
	if next == null: return
	model = next
	selected_entry = entry
	history.clear()
	playing = false
	heading.text = entry[2]
	subtitle.text = entry[3]
	status.text = "选择操作，输入参数后执行。"
	status.remove_theme_color_override("font_color")
	operation_picker.clear()
	for operation in model.operations():
		operation_picker.add_item(operation.title)
	_choose_operation(0)
	model.frames.clear()
	model.record("默认示例已就绪。可修改参数，观察完整变化过程。")
	trace = model.frames.duplicate(true)
	_show_frame(0, false)
	canvas.call_deferred("fit")

func _choose_operation(index: int) -> void:
	_clear(fields_box)
	editors.clear()
	selected_op = model.operations()[index]
	operation_note.text = "操作说明\n" + selected_op.note
	pick_second = false
	for spec in selected_op.fields:
		fields_box.add_child(_label(spec.title, 14))
		var editor := LineEdit.new()
		editor.text = spec.initial
		editor.placeholder_text = spec.title
		editor.text_submitted.connect(func(_text): _execute())
		fields_box.add_child(editor)
		editors[spec.key] = editor

func _execute() -> void:
	if playing or cursor < trace.size() - 1:
		_error("请先播放到末尾或点击「末步」，再执行新操作。")
		return
	var args := {}
	for spec in selected_op.fields:
		var text: String = editors[spec.key].text.strip_edges()
		if not spec.text:
			if not text.is_valid_int():
				_error("%s 必须是整数。" % spec.title)
				return
			if absi(int(text)) > 9999:
				_error("演示参数绝对值不能超过 9999。")
				return
			args[spec.key] = int(text)
		else:
			args[spec.key] = text
	# Capture a value-only copy for transactional failure and undo.
	var saved := _save_model()
	if not model.perform(selected_op.id, args):
		var reason := model.error
		_restore_model(saved)
		_error(reason)
		return
	var broken := model.invariant()
	if not broken.is_empty():
		_restore_model(saved)
		_error("校验失败，操作已回滚：" + broken)
		return
	history.append(saved)
	if history.size() > 30: history.pop_front()
	trace = model.frames.duplicate(true)
	if trace.is_empty():
		model.record("操作完成")
		trace = model.frames.duplicate(true)
	status.text = "操作已生成 %d 步，可暂停或拖动进度。" % trace.size()
	status.remove_theme_color_override("font_color")
	_show_frame(0, false)
	canvas.fit_frames(trace)
	playing = trace.size() > 1
	elapsed = 0
	_update_controls()

func _save_model() -> Dictionary:
	var saved := {}
	for property in model.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = model.get(property.name)
			if value is Array or value is Dictionary:
				value = value.duplicate(true)
			saved[property.name] = value
	return saved

func _restore_model(saved: Dictionary) -> void:
	for key in saved: model.set(key, saved[key])

func _undo() -> void:
	if history.is_empty(): return
	playing = false
	_restore_model(history.pop_back())
	model.frames.clear()
	model.record("已撤销上一次操作")
	trace = model.frames.duplicate(true)
	_show_frame(0, false)
	status.text = "已恢复上一次操作前的数据。"

func _error(message: String) -> void:
	status.text = message
	status.add_theme_color_override("font_color", Color("#ad3c26"))

func _process(delta: float) -> void:
	if not playing: return
	elapsed += delta * speed
	if elapsed >= 0.85:
		elapsed = 0
		if cursor + 1 < trace.size():
			_show_frame(cursor + 1, true)
		else:
			playing = false
			_update_controls()

func _toggle_play() -> void:
	if trace.size() < 2: return
	if not playing and cursor == trace.size() - 1 and canvas.progress >= 1.0:
		_show_frame(0, false)
	playing = not playing
	canvas.pause_animation(not playing)
	elapsed = 0
	_update_controls()

func _go(index: int) -> void:
	playing = false
	_show_frame(clampi(index, 0, trace.size() - 1), true)

func _seek(value: float) -> void:
	if syncing: return
	playing = false
	_show_frame(int(value), false)

func _show_frame(index: int, animate: bool) -> void:
	cursor = index
	var frame := trace[cursor]
	canvas.display(frame, animate, 0.5 / speed)
	stats.text = frame.get("stats", "")
	explanation.text = frame.get("message", "")
	var lines := ""
	var source: Array = frame.get("code", [])
	for i in source.size():
		var prefix := "▶ " if i == frame.get("line", -1) else "   "
		lines += "%s%d  %s\n" % [prefix, i + 1, source[i]]
	code_label.text = lines
	stack_label.text = "\n".join(frame.get("calls", []))
	if stack_label.text.is_empty(): stack_label.text = "—"
	syncing = true
	timeline.max_value = maxi(0, trace.size() - 1)
	timeline.value = cursor
	syncing = false
	counter.text = "%d / %d" % [cursor + 1, trace.size()]
	_update_controls()

func _update_controls() -> void:
	play_button.text = "暂停" if playing else "播放"
	execute_button.disabled = playing or cursor < trace.size() - 1
	undo_button.disabled = history.is_empty()

func _pick_node(id: String) -> void:
	for node in canvas.current.get("nodes", []):
		if str(node.id) != id: continue
		var fill := {}
		var detail: String = node.get("detail", "")
		var index := -1
		if detail.begins_with("[") and detail.get_slice("]", 0).trim_prefix("[").is_valid_int():
			index = int(detail.get_slice("]", 0).trim_prefix("["))
		if model.kind == "fenwick":
			index = int(id.substr(1)) + (1 if id.begins_with("a") else 0)
		if model.kind == "sparse_table" and node.has("range"):
			fill["l"] = node.range[0]
			fill["r"] = node.range[1]
			index = -1
		if index >= 1:
			fill["index"] = index
			if editors.has("l"):
				fill["r" if pick_second else "l"] = index
				pick_second = not pick_second
		if model.kind in ["segment", "dynamic_segment", "persistent_segment"] and id.is_valid_int():
			var part: Dictionary = model.pool[int(id)]
			fill["l"] = part.l
			fill["r"] = part.r
			fill["index"] = part.l
		if model.kind in ["fenwick2", "segment2"] and id.begins_with("a"):
			var x := int(id.substr(1).get_slice("_", 0))
			var y := int(id.get_slice("_", 1))
			fill["x"] = x
			fill["y"] = y
			if editors.has("x1"):
				fill["x2" if pick_second else "x1"] = x
				fill["y2" if pick_second else "y1"] = y
				pick_second = not pick_second
		if model.kind == "segment2" and id.begins_with("x"): fill["node"] = int(id.substr(1))
		if id.is_valid_int(): fill["id"] = int(id)
		if model.kind == "lct":
			fill["id"] = int(id.substr(1))
			if editors.has("u"):
				fill["v" if pick_second else "u"] = int(id.substr(1))
				pick_second = not pick_second
		# Numeric labels are keys only in these structures, not interval aggregates.
		if model.kind in ["array", "dynamic_array", "linked", "doubly", "stack", "queue",
				"mono_stack", "mono_queue", "hash_linear", "hash_quadratic", "hash_chain",
				"binary_heap", "heap_sort", "binomial", "fibonacci", "avl", "treap", "splay", "red_black"]:
			if str(node.label).is_valid_int(): fill["value"] = int(node.label)
		var assigned: Array[String] = []
		for key in fill:
			if editors.has(key):
				editors[key].text = str(fill[key])
				assigned.append("%s=%s" % [key, fill[key]])
		status.remove_theme_color_override("font_color")
		status.text = "已填入：" + "，".join(assigned) if not assigned.is_empty() else "已选择：%s  %s" % [node.label, detail]
		return
