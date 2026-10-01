class_name LabModel
extends RefCounted
## Pure algorithm model. Frames contain only value data, never scene objects.

const OperationNotes := preload("res://scripts/core/operation_notes.gd")

var kind: String
var frames: Array[Dictionary] = []
var error := ""
var calls: Array[String] = []
var code: Array[String] = []
var next_id := 1
var recording := true

func _init(p_kind: String = "") -> void:
	kind = p_kind

func uid() -> int:
	var result := next_id
	next_id += 1
	return result

func begin() -> void:
	frames.clear()
	error = ""
	calls.clear()
	record("开始操作")

func fail(message: String) -> bool:
	error = message
	return false

func record(message: String, active: Array = [], line: int = -1) -> void:
	if not recording:
		return
	var frame := view()
	frame["message"] = message
	frame["active"] = active.duplicate()
	frame["line"] = line
	frame["code"] = code.duplicate()
	frame["calls"] = calls.duplicate()
	frames.append(frame.duplicate(true))

func view() -> Dictionary:
	return {"nodes": [], "edges": [], "stats": ""}

func operations() -> Array:
	return []

func perform(_op: String, _args: Dictionary) -> bool:
	return fail("尚未定义此操作")

func op(id: String, title: String, fields: Array = []) -> Dictionary:
	return {"id": id, "title": title, "fields": fields, "note": OperationNotes.describe(kind, id)}

func field(key: String, title: String, initial: String, text: bool = false) -> Dictionary:
	return {"key": key, "title": title, "initial": initial, "text": text}

func vertex(id: Variant, label: Variant, x: float, y: float,
		detail: String = "", shape: String = "circle", tone: String = "") -> Dictionary:
	return {"id": str(id), "label": str(label), "pos": Vector2(x, y),
		"detail": detail, "shape": shape, "tone": tone}

func edge(a: Variant, b: Variant, label: String = "", dashed: bool = false) -> Dictionary:
	return {"from": str(a), "to": str(b), "label": label, "dashed": dashed}

func integers(text: String, limit: int = 16) -> Array:
	error = ""
	var result: Array = []
	var normalized := text.replace("，", ",").replace(" ", ",")
	for part in normalized.split(",", false):
		if not part.is_valid_int():
			fail("请输入以逗号或空格分隔的整数。")
			return []
		var value := int(part)
		if value < -999 or value > 999:
			fail("演示数值范围为 -999 到 999。")
			return []
		result.append(value)
	if result.size() > limit:
		fail("最多允许 %d 个元素。" % limit)
		return []
	return result

func array_view(values: Array, y: float = 130, prefix: String = "a") -> Dictionary:
	var nodes: Array = []
	for i in values.size():
		nodes.append(vertex(prefix + str(i), values[i], 70 + i * 76, y, "[%d]" % [i + 1], "box"))
	return {"nodes": nodes, "edges": [], "stats": "元素数 %d" % values.size()}

func invariant() -> String:
	return ""
