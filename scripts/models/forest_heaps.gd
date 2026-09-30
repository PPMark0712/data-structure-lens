class_name ForestHeapModel
extends LabModel

var pool := {}
var roots: Array = []
var minimum := 0
var result := 0

func _init(p_kind: String = "binomial") -> void:
	super(p_kind)
	code.assign(["新树加入根链表 / 合并两条根链表", "提取最小根，将其孩子提升为根",
		"相同度数的根链接：较小键成为父亲", "减键破坏堆序：交换键 / 切断并加入根链表",
		"首次丢失孩子作标记，再次丢失则级联切断", "更新最小根指针"])
	recording = false
	for value in [7, 12, 3, 24, 16, 9, 20, 30]: _insert(value)
	# Start Fibonacci with a consolidated forest so decrease-key can demonstrate cuts.
	if kind == "fibonacci": _consolidate()
	_update_min()
	recording = true

func operations() -> Array:
	return [op("insert", "插入", [field("value", "数值", "5")]),
		op("extract", "提取最小值"),
		op("decrease", "减键", [field("id", "节点编号 #", "8"), field("value", "新值", "1")]),
		op("delete", "删除节点", [field("id", "节点编号 #", "8")]),
		op("merge", "合并另一堆", [field("values", "另一堆的整数（逗号分隔）", "4,18,2", true)])]

func _insert(value: int) -> void:
	var id := uid()
	pool[id] = {"value": value, "parent": 0, "children": [], "mark": false}
	roots.append(id)
	record("单节点树 #%d 加入根链表" % id, [str(id)], 0)
	if kind == "binomial": _consolidate()
	_update_min()

func _update_min() -> void:
	minimum = 0
	for id in roots:
		if minimum == 0 or pool[id].value < pool[minimum].value: minimum = id

func _consolidate() -> void:
	var degrees := {}
	var pending := roots.duplicate()
	for candidate in pending:
		var x: int = candidate
		var degree: int = pool[x].children.size()
		while degrees.has(degree):
			var y: int = degrees[degree]
			degrees.erase(degree)
			if pool[y].value < pool[x].value:
				var temp := x
				x = y
				y = temp
			roots.erase(y)
			pool[y].parent = x
			pool[y].mark = false
			pool[x].children.append(y)
			record("两棵度数 %d 的树链接：#%d → #%d" % [degree, y, x], [str(x), str(y)], 2)
			degree += 1
		degrees[degree] = x
	roots.sort_custom(func(a, b): return pool[a].children.size() < pool[b].children.size())
	_update_min()

func _extract() -> void:
	var id := minimum
	result = pool[id].value
	roots.erase(id)
	for child in pool[id].children:
		pool[child].parent = 0
		pool[child].mark = false
		roots.append(child)
	pool.erase(id)
	minimum = 0
	record("提取最小值 %d；孩子加入根链表" % result, [], 1)
	_consolidate()

func _cut(id: int, parent: int) -> void:
	pool[parent].children.erase(id)
	pool[id].parent = 0
	pool[id].mark = false
	roots.append(id)
	record("切断 #%d 与父亲 #%d；节点回到根链表" % [id, parent], [str(id), str(parent)], 3)

func _cascade(id: int) -> void:
	var parent: int = pool[id].parent
	if parent == 0: return
	calls.append("cascading_cut(#%d)" % id)
	if not pool[id].mark:
		pool[id].mark = true
		record("#%d 首次丢失孩子，设置 mark" % id, [str(id)], 4)
	else:
		_cut(id, parent)
		_cascade(parent)
	calls.pop_back()

func _decrease(id: int, value: int) -> void:
	pool[id].value = value
	record("将 #%d 的键减为 %d" % [id, value], [str(id)], 3)
	var parent: int = pool[id].parent
	if kind == "fibonacci":
		if parent and pool[id].value < pool[parent].value:
			_cut(id, parent)
			_cascade(parent)
	else:
		while parent and pool[id].value < pool[parent].value:
			var temp: int = pool[id].value
			pool[id].value = pool[parent].value
			pool[parent].value = temp
			record("二项堆减键：键与父节点交换，节点编号不变", [str(id), str(parent)], 3)
			id = parent
			parent = pool[id].parent
	_update_min()

func perform(action: String, args: Dictionary) -> bool:
	if action == "insert" and pool.size() >= 20: return fail("最多演示 20 个节点。")
	if action == "extract" and pool.is_empty(): return fail("空堆无法提取。")
	if action in ["decrease", "delete"]:
		if not pool.has(int(args.id)): return fail("节点编号不存在。")
		if action == "decrease" and int(args.value) > pool[int(args.id)].value:
			return fail("新值不能大于原值；此操作是减键。")
	var values: Array = []
	if action == "merge":
		values = integers(args.values, 20)
		if not error.is_empty(): return false
		if pool.size() + values.size() > 20: return fail("合并后最多 20 个节点。")
	begin()
	match action:
		"insert": _insert(int(args.value))
		"extract": _extract()
		"decrease": _decrease(int(args.id), int(args.value))
		"delete":
			_decrease(int(args.id), -1000000000)
			_extract()
		"merge":
			# Build the second heap independently, then union its root list.
			var other := ForestHeapModel.new(kind)
			other.pool.clear()
			other.roots.clear()
			other.minimum = 0
			other.next_id = next_id
			other.recording = false
			for value in values: other._insert(value)
			next_id = other.next_id
			pool.merge(other.pool)
			roots.append_array(other.roots)
			record("连接两堆根链表", [], 0)
			if kind == "binomial": _consolidate()
	_update_min()
	record("最小根为 #%d；操作完成" % minimum if minimum else "堆已空", [str(minimum)], 5)
	return true

func _width(id: int) -> int:
	var width := 0
	for child in pool[id].children: width += _width(child)
	return maxi(width, 1)

func _layout(id: int, left: float, depth: int, nodes: Array, edges: Array) -> void:
	var node: Dictionary = pool[id]
	var width := _width(id)
	nodes.append(vertex(id, node.value, left + width * 48, 80 + depth * 115,
		"#%d · d%d%s" % [id, node.children.size(), " · M" if node.mark else ""],
		"circle", "red" if node.mark else ("green" if id == minimum else "")))
	for child in node.children:
		edges.append(edge(id, child))
		_layout(child, left, depth + 1, nodes, edges)
		left += _width(child) * 96

func view() -> Dictionary:
	var nodes: Array = []
	var edges: Array = []
	var left := 20.0
	for i in roots.size():
		var id: int = roots[i]
		_layout(id, left, 0, nodes, edges)
		left += _width(id) * 96 + 40
		if i: edges.append(edge(roots[i - 1], id, "root", true))
	return {"nodes": nodes, "edges": edges, "stats":
		"节点 %d · 根 %d · min %s · M=已丢失一个孩子" % [pool.size(), roots.size(),
		str(pool[minimum].value) if pool.has(minimum) else "∅"]}

func invariant() -> String:
	var seen := {}
	var pending := roots.duplicate()
	var degrees := {}
	for id in roots:
		if pool[id].parent != 0 or pool[id].mark: return "root parent/mark"
		var degree: int = pool[id].children.size()
		if kind == "binomial" and degrees.has(degree): return "duplicate binomial degrees"
		degrees[degree] = true
	while not pending.is_empty():
		var id: int = pending.pop_back()
		if seen.has(id): return "heap cycle"
		seen[id] = true
		var n: Dictionary = pool[id]
		for i in n.children.size():
			var child: int = n.children[i]
			if pool[child].parent != id or pool[child].value < n.value: return "heap parent/order"
			if kind == "binomial" and pool[child].children.size() != i: return "binomial tree shape"
			pending.append(child)
	if seen.size() != pool.size(): return "unreachable heap node"
	for id in pool:
		if not minimum or pool[id].value < pool[minimum].value: return "minimum pointer"
	return ""
