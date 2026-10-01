class_name MonotonicModel
extends LabModel
## Store source offsets internally; answers and all visible indices start at 1.

var data: Array = [6, 3, 8, 5, 5, 7, 2, 9, 4, 1]
var frontier: Array[int] = []
var answers: Array = []
var processed := 0
var visiting := -1
var window := 3

func _init(p_kind: String = "mono_stack") -> void:
	super(p_kind)
	if kind == "mono_stack":
		code.assign(["从左到右读取 a[i]", "弹出栈顶所有 ≤ a[i] 的下标",
			"栈顶即左侧最近严格更大值的下标；空栈则无", "将 i 压入栈顶（向右）"])
	else:
		code.assign(["读取 a[i]；移除下标 < i-w+1 的队首",
			"弹出队尾所有 < a[i] 的下标（相等保留）",
			"将 i 加到队尾（向右）", "窗口完整时，队首即最左最大值的下标"])
	_reset()

func operations() -> Array:
	var fields: Array = [field("values", "整数数组（1–16 个）", "6,3,8,5,5,7,2,9,4,1", true)]
	if kind == "mono_queue": fields.append(field("window", "固定窗口长度", "3"))
	return [op("step", "处理下一个元素"), op("run", "处理剩余数组"),
		op("reset", "从头演示"), op("build", "设置数组", fields)]

func _reset() -> void:
	frontier.clear()
	answers.clear()
	answers.resize(data.size())
	processed = 0
	visiting = -1

func perform(action: String, args: Dictionary) -> bool:
	if action == "build":
		var values := integers(str(args.values))
		if not error.is_empty(): return false
		if values.is_empty(): return fail("数组至少需要 1 个整数。")
		var width := int(args.get("window", window))
		if kind == "mono_queue" and (width < 1 or width > values.size()):
			return fail("窗口长度必须在 1 到数组长度之间。")
		begin()
		data = values
		window = width
		_reset()
		record("数组已设置；从下标 1 开始逐个处理。", [], 0)
		return true
	if action == "reset":
		begin()
		_reset()
		record("清空候选下标及答案，从数组下标 1 重新开始。", [], 0)
		return true
	if processed == data.size(): return fail("数组已全部处理；可选择「从头演示」。")
	begin()
	var count := 1 if action == "step" else data.size() - processed
	for unused in count: _advance()
	record("已处理 %d / %d 个元素" % [processed, data.size()], [], 3)
	return true

func _advance() -> void:
	var i := processed
	visiting = i
	record("读取 a[%d]=%d" % [i + 1, data[i]], ["a%d" % i], 0)
	if kind == "mono_queue":
		while not frontier.is_empty() and frontier.front() < i - window + 1:
			var expired: int = frontier.front()
			record("下标 %d 已离开窗口 [%d,%d]，准备移除队首" % [expired + 1, maxi(1, i - window + 2), i + 1],
				["q%d" % expired], 0)
			frontier.pop_front()
			record("移除过期队首 %d" % [expired + 1], [], 0)
	while not frontier.is_empty():
		var top: int = frontier.back()
		record("比较 a[%d]=%d 与 a[%d]=%d" % [top + 1, data[top], i + 1, data[i]],
			["q%d" % top, "a%d" % i], 1)
		var remove: bool = data[top] <= data[i] if kind == "mono_stack" else data[top] < data[i]
		if not remove: break
		frontier.pop_back()
		record("弹出下标 %d：%s" % [top + 1,
			"它不严格大于当前值" if kind == "mono_stack" else "当前值更大，且更晚离开窗口"], ["a%d" % top], 1)
	if kind == "mono_stack":
		answers[i] = 0 if frontier.is_empty() else frontier.back() + 1
		record("a[%d] 左侧最近严格更大值的下标：%s" % [i + 1, "无" if answers[i] == 0 else str(answers[i])],
			["r%d" % i] + ([] if frontier.is_empty() else ["q%d" % frontier.back()]), 2)
	frontier.append(i)
	record("将下标 %d 加入%s的右端" % [i + 1, "栈顶" if kind == "mono_stack" else "队尾"], ["q%d" % i], 3 if kind == "mono_stack" else 2)
	if kind == "mono_queue" and i >= window - 1:
		answers[i] = frontier.front() + 1
		record("窗口 [%d,%d] 最大值为 %d，下标为 %d（相等时取最左）" %
			[i - window + 2, i + 1, data[frontier.front()], answers[i]], ["q%d" % frontier.front(), "r%d" % i], 3)
	processed += 1
	visiting = -1

func view() -> Dictionary:
	var nodes: Array = []
	var current_index := visiting if visiting >= 0 else processed - 1
	for i in data.size():
		var tone := "green" if kind == "mono_queue" and i <= current_index and i > current_index - window else ""
		if i == visiting: tone = "blue"
		nodes.append(vertex("a%d" % i, data[i], 70 + i * 78, 90, "[%d]" % [i + 1], "box", tone))
		var answer := "·" if answers[i] == null else ("无" if answers[i] == 0 else str(answers[i]))
		if kind == "mono_queue" and i < window - 1: answer = "—"
		var detail := "[%d]" % [i + 1] if kind == "mono_stack" else ("未满" if i < window - 1 else "[%d,%d]" % [i - window + 2, i + 1])
		nodes.append(vertex("r%d" % i, answer, 70 + i * 78, 370, detail, "box", "green" if answers[i] != null else "muted"))
	for j in frontier.size():
		var index := frontier[j]
		var detail := "值 %d" % data[index]
		if j == frontier.size() - 1: detail += " TOP" if kind == "mono_stack" else " TAIL"
		if j == 0 and kind == "mono_queue": detail += " HEAD"
		nodes.append(vertex("q%d" % index, index + 1, 70 + j * 78, 230, detail, "box"))
	return {"nodes": nodes, "edges": [], "annotations": [
		{"pos": Vector2(40, 35), "text": "原数组 a  ·  从左到右扫描"},
		{"pos": Vector2(40, 175), "text": "候选下标  ·  栈底 → 栈顶" if kind == "mono_stack" else "候选下标  ·  队首 → 队尾"},
		{"pos": Vector2(40, 315), "text": "答案：左侧最近严格更大值的下标" if kind == "mono_stack" else "答案：各完整窗口最大值的下标（最左）"}],
		"stats": "已处理 %d / %d%s  ·  下标从 1 开始" % [processed, data.size(), "  ·  窗口 %d" % window if kind == "mono_queue" else ""]}

func invariant() -> String:
	for j in frontier.size():
		var i := frontier[j]
		if i < 0 or i >= processed: return "frontier index"
		if kind == "mono_queue" and i < processed - window: return "expired queue index"
		if j > 0:
			if frontier[j - 1] >= i: return "frontier index order"
			if data[frontier[j - 1]] < data[i]: return "frontier value order"
			if kind == "mono_stack" and data[frontier[j - 1]] == data[i]: return "stack must be strictly decreasing"
	return ""
