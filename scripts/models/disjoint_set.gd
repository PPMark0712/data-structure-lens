class_name DisjointSetModel
extends LabModel

const MAX_SIZE := 12
const HORIZONTAL_GAP := 112.0
const ROOT_GAP := 56.0

var count := 10
var parent: Array[int] = []
var result := 0
var connected_result := false
var outcome := ""

func _init(p_kind: String = "disjoint_set") -> void:
	super(p_kind)
	code.assign([
		"int find(int x) { return x == fa[x] ? x : fa[x] = find(fa[x]); }",
		"合并：fa[find(a)] = find(b)",
		"连通：find(a) == find(b)",
		"初始化：fa[i] = i"
	])
	_reset(count)
	# Keep short paths in the default forest so find(1) demonstrates compression.
	parent[1] = 2
	parent[2] = 3
	parent[4] = 5
	parent[5] = 6
	parent[7] = 8
	parent[9] = 10

func operations() -> Array:
	return [
		op("find", "查找代表元", [field("x", "元素 x（1–%d）" % count, "1")]),
		op("union", "合并集合", [
			field("a", "元素 a（1–%d）" % count, "1"),
			field("b", "元素 b（1–%d）" % count, "5")
		]),
		op("connected", "判断连通", [
			field("a", "元素 a（1–%d）" % count, "1"),
			field("b", "元素 b（1–%d）" % count, "7")
		]),
		op("build", "重新初始化", [field("size", "元素个数（1–12）", "10")])
	]

func _reset(size: int) -> void:
	count = size
	parent.clear()
	for i in range(count + 1):
		parent.append(i)
	result = 0
	connected_result = false
	outcome = ""

func _valid_element(value: int) -> bool:
	return value >= 1 and value <= count

func _find(x: int) -> int:
	calls.append("find(%d)" % x)
	record("检查 %d 是否为根：fa[%d] = %d" % [x, x, parent[x]], ["d%d" % x], 0)
	if x == parent[x]:
		record("%d == fa[%d]，返回代表元 %d" % [x, x, x], ["d%d" % x], 0)
		calls.pop_back()
		return x
	var old_parent := parent[x]
	record("%d 不是根，递归执行 find(%d)" % [x, old_parent],
		["d%d" % x, "d%d" % old_parent], 0)
	var root := _find(old_parent)
	if parent[x] != root:
		parent[x] = root
		record("递归回溯：fa[%d] = %d，压缩一层路径" % [x, root],
			["d%d" % x, "d%d" % root], 0)
	else:
		record("递归回溯：fa[%d] 已直接指向根 %d" % [x, root],
			["d%d" % x, "d%d" % root], 0)
	calls.pop_back()
	return root

func perform(action: String, args: Dictionary) -> bool:
	if action == "build":
		var size := int(args.get("size", 0))
		if size < 1 or size > MAX_SIZE:
			return fail("元素个数必须在 1 到 %d 之间。" % MAX_SIZE)
		begin()
		_reset(size)
		record("令每个 fa[i] = i，得到 %d 个单元素集合" % count,
			range(1, count + 1).map(func(i): return "d%d" % i), 3)
		return true
	var a := int(args.get("a", args.get("x", 0)))
	var b := int(args.get("b", 0))
	if not _valid_element(a):
		return fail("元素必须在 1 到 %d 之间。" % count)
	if action in ["union", "connected"] and not _valid_element(b):
		return fail("元素 b 必须在 1 到 %d 之间。" % count)
	outcome = ""
	begin()
	match action:
		"find":
			result = _find(a)
			outcome = "find(%d) = %d" % [a, result]
			record("查找完成：%d 的代表元是 %d" % [a, result],
				["d%d" % a, "d%d" % result], 0)
		"union":
			var root_a := _find(a)
			var root_b := _find(b)
			if root_a == root_b:
				outcome = "%d 与 %d 已属于同一集合" % [a, b]
				record(outcome, ["d%d" % root_a], 1)
			else:
				parent[root_a] = root_b
				outcome = "fa[%d] = %d" % [root_a, root_b]
				record("合并：令 fa[%d] = %d；不使用按秩或按大小合并" %
					[root_a, root_b], ["d%d" % root_a, "d%d" % root_b], 1)
		"connected":
			var root_a := _find(a)
			var root_b := _find(b)
			connected_result = root_a == root_b
			outcome = "%d 与 %d%s连通" % [a, b, "" if connected_result else "不"]
			record("%s：代表元分别为 %d 与 %d" % [outcome, root_a, root_b],
				["d%d" % root_a, "d%d" % root_b], 2)
		_:
			return fail("未知操作。")
	return true

func _children() -> Dictionary:
	var children := {}
	for i in range(1, count + 1):
		children[i] = []
	for i in range(1, count + 1):
		if parent[i] != i:
			children[parent[i]].append(i)
	for i in children:
		children[i].sort()
	return children

func _measure(id: int, children: Dictionary, widths: Dictionary) -> float:
	var width := 0.0
	for child in children[id]:
		width += _measure(child, children, widths)
	widths[id] = maxf(1.0, width)
	return widths[id]

func _layout(id: int, depth: int, left: float, children: Dictionary,
		widths: Dictionary, nodes: Array, edges: Array) -> void:
	var span: float = widths[id] * HORIZONTAL_GAP
	var node := vertex("d%d" % id, id, left + span / 2.0, 85 + depth * 105,
		"", "circle", "green" if parent[id] == id else "")
	node["element"] = id
	node["lines"] = [str(id), "ROOT" if parent[id] == id else "fa=%d" % parent[id]]
	nodes.append(node)
	var child_left := left
	for child in children[id]:
		edges.append(edge("d%d" % child, "d%d" % id))
		_layout(child, depth + 1, child_left, children, widths, nodes, edges)
		child_left += widths[child] * HORIZONTAL_GAP

func _component_count() -> int:
	var total := 0
	for i in range(1, count + 1):
		if parent[i] == i:
			total += 1
	return total

func view() -> Dictionary:
	var nodes: Array = []
	var edges: Array = []
	var children := _children()
	var widths := {}
	var left := 45.0
	for i in range(1, count + 1):
		if parent[i] != i:
			continue
		_measure(i, children, widths)
		_layout(i, 0, left, children, widths, nodes, edges)
		left += widths[i] * HORIZONTAL_GAP + ROOT_GAP
	var stats := "元素 %d · 集合 %d · 仅路径压缩" % [count, _component_count()]
	if not outcome.is_empty():
		stats += " · " + outcome
	return {
		"nodes": nodes,
		"edges": edges,
		"annotations": [{"pos": Vector2(45, 28), "text": "箭头：x → fa[x]  ·  绿色：集合代表元"}],
		"parents": parent.duplicate(),
		"stats": stats
	}

func invariant() -> String:
	if parent.size() != count + 1:
		return "parent array size"
	for i in range(1, count + 1):
		if parent[i] < 1 or parent[i] > count:
			return "parent out of range"
	for start in range(1, count + 1):
		var seen := {}
		var current := start
		while parent[current] != current:
			if seen.has(current):
				return "parent cycle"
			seen[current] = true
			current = parent[current]
	return ""
