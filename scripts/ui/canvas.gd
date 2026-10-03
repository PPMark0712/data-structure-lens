class_name LabCanvas
extends Control
## Snapshot interpolation. The algorithm never observes these transient positions.
signal picked(id: String)

const INK := Color("#252a2b")
const BLUE := Color("#bce1ef")
const PAPER := Color("#fdf6e3")
var current: Dictionary = {"nodes": [], "edges": []}
var previous: Dictionary = {"nodes": [], "edges": []}
var progress := 1.0
var animation_speed := 1.0
var zoom := 1.0
var offset := Vector2(25, 25)
var active_tween: Tween
var font: Font
var dragging := false
var drag_origin := Vector2.ZERO
var moved := false

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(400, 380)
	font = get_theme_default_font()
	resized.connect(queue_redraw)

func display(frame: Dictionary, animate: bool = true, duration: float = 0.5) -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	previous = current
	current = frame
	progress = 0.0 if animate else 1.0
	if animate:
		active_tween = create_tween()
		active_tween.tween_method(_set_progress, 0.0, 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		active_tween.set_speed_scale(animation_speed)
	queue_redraw()

func _set_progress(value: float) -> void:
	progress = value
	queue_redraw()

func pause_animation(paused: bool) -> void:
	if active_tween and active_tween.is_valid():
		if paused: active_tween.pause()
		else: active_tween.play()

func set_animation_speed(value: float) -> void:
	animation_speed = value
	if active_tween and active_tween.is_valid():
		active_tween.set_speed_scale(animation_speed)

func _interpolated_positions() -> Dictionary:
	var old := {}
	var positions := {}
	for node in previous.get("nodes", []):
		old[str(node.id)] = node
	for node in current.get("nodes", []):
		var id := str(node.id)
		var start: Vector2 = old[id].pos if old.has(id) else node.pos
		positions[id] = start.lerp(node.pos, progress)
	for id in old:
		if not positions.has(id):
			positions[id] = old[id].pos
	return positions

func fit() -> void:
	fit_frames([current])

func fit_frames(frames: Array) -> void:
	var nodes: Array = []
	for frame in frames: nodes.append_array(frame.get("nodes", []))
	var bounds := Rect2()
	var has_bounds := false
	for node in nodes:
		var half: Vector2 = node.get("size", Vector2(90, 60)) / 2
		var top_left: Vector2 = node.pos - half - Vector2(20, 20)
		var bottom_right: Vector2 = node.pos + half + Vector2(20, 32)
		if not has_bounds:
			bounds = Rect2(top_left, Vector2.ZERO)
			has_bounds = true
		bounds = bounds.expand(top_left).expand(bottom_right)
		var detail := str(node.get("detail", ""))
		if not detail.is_empty():
			var detail_offset: Vector2 = node.get("detail_offset", Vector2(0, 46))
			var detail_width := font.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			var baseline: Vector2 = node.pos + detail_offset
			bounds = bounds.expand(baseline + Vector2(-detail_width / 2, -14))
			bounds = bounds.expand(baseline + Vector2(detail_width / 2, 4))
	for frame in frames:
		for outline in frame.get("outlines", []):
			for point: Vector2 in outline.get("points", []):
				if not has_bounds:
					bounds = Rect2(point, Vector2.ZERO)
					has_bounds = true
				bounds = bounds.expand(point - Vector2(4, 4)).expand(point + Vector2(4, 4))
		for annotation in frame.get("annotations", []):
			if not has_bounds:
				bounds = Rect2(annotation.pos, Vector2.ZERO)
				has_bounds = true
			bounds = bounds.expand(annotation.pos - Vector2(0, 20))
			bounds = bounds.expand(annotation.pos + Vector2(font.get_string_size(annotation.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x, 4))
	if not has_bounds:
		zoom = 1.0
		offset = Vector2(25, 25)
		return
	zoom = clampf(minf((size.x - 60) / bounds.size.x, (size.y - 60) / bounds.size.y), 0.18, 1.4)
	offset = (size - bounds.size * zoom) / 2 - bounds.position * zoom
	queue_redraw()

func magnify(factor: float, pivot: Vector2 = Vector2(-1, -1)) -> void:
	if pivot.x < 0:
		pivot = size / 2
	var world := (pivot - offset) / zoom
	zoom = clampf(zoom * factor, 0.15, 3.0)
	offset = pivot - world * zoom
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			magnify(1.12, event.position)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			magnify(1.0 / 1.12, event.position)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_origin = event.position
				moved = false
			else:
				if dragging and not moved:
					var point: Vector2 = (event.position - offset) / zoom
					var positions := _interpolated_positions()
					for node in current.get("nodes", []):
						if not node.get("pickable", true):
							continue
						var node_size: Vector2 = node.get("size", Vector2(68, 68))
						var position: Vector2 = positions[str(node.id)]
						if Rect2(position - node_size / 2, node_size).has_point(point):
							picked.emit(str(node.id))
							break
				dragging = false
	elif event is InputEventMouseMotion and dragging:
		if event.position.distance_to(drag_origin) > 4:
			moved = true
		if moved:
			offset += event.relative
			queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	if font == null:
		return
	var old := {}
	var new := {}
	for node in previous.get("nodes", []): old[str(node.id)] = node
	for node in current.get("nodes", []): new[str(node.id)] = node
	var positions := _interpolated_positions()
	draw_set_transform(offset, 0, Vector2.ONE * zoom)
	for outline in current.get("outlines", []):
		_draw_outline(outline)
	# Old edges fade out; new edges attach to interpolated node positions.
	for e in previous.get("edges", []):
		_draw_edge(e, positions, 1 - progress)
	for e in current.get("edges", []):
		_draw_edge(e, positions, progress)
	for id in old:
		if not new.has(id):
			_draw_vertex(old[id], positions[id], 1 - progress, false)
	for id in new:
		var opacity := 1.0 if old.has(id) else progress
		_draw_vertex(new[id], positions[id], opacity, current.get("active", []).has(id))
	for annotation in current.get("annotations", []):
		draw_string(font, annotation.pos, annotation.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK)
	draw_set_transform(Vector2.ZERO)
	if new.is_empty():
		draw_string(font, Vector2(36, 65), "结构为空 · 使用操作面板加入元素", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK)

func _draw_outline(outline: Dictionary) -> void:
	var points := PackedVector2Array(outline.get("points", []))
	if points.size() < 2:
		return
	draw_polyline(points, outline.get("color", INK), outline.get("width", 2.5), true)

func _draw_edge(e: Dictionary, positions: Dictionary, alpha: float) -> void:
	if alpha <= 0.001 or not positions.has(str(e.from)) or not positions.has(str(e.to)):
		return
	var a: Vector2 = positions[str(e.from)]
	var b: Vector2 = positions[str(e.to)]
	var direction := (b - a).normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	var shift := perpendicular * (11.0 if e.get("dashed", false) else 0.0)
	a += direction * 28 + shift
	b -= direction * 30 - shift
	var color := Color(INK, alpha)
	if e.get("dashed", false):
		draw_dashed_line(a, b, color, 1.5, 7)
	else:
		draw_line(a, b, color, 1.7, true)
	if e.get("directed", true):
		draw_colored_polygon(PackedVector2Array([b, b - direction * 9 + perpendicular * 4,
			b - direction * 9 - perpendicular * 4]), color)
	if not str(e.get("label", "")).is_empty():
		draw_string(font, (a + b) / 2 + perpendicular * 14, str(e.label),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)

func _draw_vertex(node: Dictionary, position: Vector2, alpha: float, active: bool) -> void:
	if alpha <= 0.001:
		return
	var fill := BLUE if active else PAPER
	var ink := INK
	match node.get("tone", ""):
		"red": fill = Color("#f3b8a8")
		"blue": fill = BLUE
		"green": fill = Color("#d1e8bf")
		"muted": ink = Color("#999485")
		"black": fill = INK; ink = PAPER
	if active and node.get("tone", "") not in ["red", "black"]:
		fill = BLUE
		ink = INK
	fill.a = alpha
	ink.a = alpha
	var outline := Color(INK, alpha)
	var shape := str(node.get("shape", "circle"))
	if shape != "label" and active and node.get("tone", "") in ["red", "black"]:
		draw_arc(position, 32, 0, TAU, 48, Color("#268bd2", alpha), 3, true)
	if shape == "box":
		var node_size: Vector2 = node.get("size", Vector2(58, 48))
		var rect := Rect2(position - node_size / 2, node_size)
		draw_rect(rect, fill)
		draw_rect(rect, outline, false, 2 if active else 1.5)
	elif shape == "circle":
		draw_circle(position, 27, fill)
		draw_arc(position, 27, 0, TAU, 48, outline, 2 if active else 1.5, true)
	var lines: Array = node.get("lines", [str(node.label)])
	for i in lines.size():
		var text := str(lines[i])
		var text_size := 13 if lines.size() > 1 or text.length() >= 6 else 17
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
		var baseline := 5.0 + (i - (lines.size() - 1) / 2.0) * 17
		draw_string(font, position + Vector2(-width / 2, baseline), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, ink)
	var detail := str(node.get("detail", ""))
	var width := font.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var detail_offset: Vector2 = node.get("detail_offset", Vector2(0, 46))
	draw_string(font, position + detail_offset - Vector2(width / 2, 0), detail,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(INK, alpha))
