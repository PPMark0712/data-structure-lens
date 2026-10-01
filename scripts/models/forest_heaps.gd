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
	pool[id] = {"value": value, "handle": id, "parent": 0, "children": [], "mark": false}
	roots.append(id)
	record("单节点树 #%d 加入根链表" % id, [str(pool[id].handle)], 0)
	if kind == "binomial": _consolidate()
	_update_min()

func node_for_handle(handle: int) -> int:
	for id in pool:
		if pool[id].handle == handle:
			return id
	return 0

func _visible_id(id: int) -> String:
	return str(pool[id].handle)

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
			record("两棵度数 %d 的树链接：#%d → #%d" %
				[degree, pool[y].handle, pool[x].handle],
				[_visible_id(x), _visible_id(y)], 2)
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
	record("切断 #%d 与父亲 #%d；节点回到根链表" %
		[pool[id].handle, pool[parent].handle], [_visible_id(id), _visible_id(parent)], 3)

func _cascade(id: int) -> void:
	var parent: int = pool[id].parent
	if parent == 0: return
	calls.append("cascading_cut(#%d)" % pool[id].handle)
	if not pool[id].mark:
		pool[id].mark = true
		record("#%d 首次丢失孩子，设置 mark" % pool[id].handle, [_visible_id(id)], 4)
	else:
		_cut(id, parent)
		_cascade(parent)
	calls.pop_back()

func _decrease(id: int, value: int) -> void:
	pool[id].value = value
	record("将 #%d 的键减为 %d" % [pool[id].handle, value], [_visible_id(id)], 3)
	var parent: int = pool[id].parent
	if kind == "fibonacci":
		if parent and pool[id].value < pool[parent].value:
			_cut(id, parent)
			_cascade(parent)
	else:
		while parent and pool[id].value < pool[parent].value:
			var child_handle: int = pool[id].handle
			var parent_handle: int = pool[parent].handle
			var temp: int = pool[id].value
			pool[id].value = pool[parent].value
			pool[parent].value = temp
			pool[id].handle = parent_handle
			pool[parent].handle = child_handle
			record("二项堆减键：元素 #%d 与父元素 #%d 交换位置" %
				[child_handle, parent_handle], [_visible_id(id), _visible_id(parent)], 3)
			id = parent
			parent = pool[id].parent
	_update_min()

func perform(action: String, args: Dictionary) -> bool:
	if action == "insert" and pool.size() >= 20: return fail("最多演示 20 个节点。")
	if action == "extract" and pool.is_empty(): return fail("空堆无法提取。")
	var target := 0
	if action in ["decrease", "delete"]:
		target = node_for_handle(int(args.id))
		if target == 0: return fail("节点编号不存在。")
		if action == "decrease" and int(args.value) > pool[target].value:
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
		"decrease": _decrease(target, int(args.value))
		"delete":
			_decrease(target, -1000000000)
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
	record("最小根为 #%d；操作完成" % pool[minimum].handle if minimum else "堆已空",
		[_visible_id(minimum)] if minimum else [], 5)
	return true

func _width(id: int) -> int:
	var width := 0
	for child in pool[id].children: width += _width(child)
	return maxi(width, 1)

func _layout(id: int, left: float, depth: int, nodes: Array, edges: Array) -> void:
	var node: Dictionary = pool[id]
	var width := _width(id)
	nodes.append(vertex(node.handle, node.value, left + width * 48, 80 + depth * 115,
		"#%d · d%d%s" % [node.handle, node.children.size(), " · M" if node.mark else ""],
		"circle", "red" if node.mark else ("green" if id == minimum else "")))
	for child in node.children:
		edges.append(edge(node.handle, pool[child].handle))
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
		if i: edges.append(edge(pool[roots[i - 1]].handle, pool[id].handle, "root", true))
	return {"nodes": nodes, "edges": edges, "stats":
		"节点 %d · 根 %d · min %s · M=已丢失一个孩子" % [pool.size(), roots.size(),
		str(pool[minimum].value) if pool.has(minimum) else "∅"]}

func invariant() -> String:
	var seen := {}
	var handles := {}
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
		if handles.has(n.handle): return "duplicate heap handle"
		handles[n.handle] = true
		for i in n.children.size():
			var child: int = n.children[i]
			if pool[child].parent != id or pool[child].value < n.value: return "heap parent/order"
			if kind == "binomial" and pool[child].children.size() != i: return "binomial tree shape"
			pending.append(child)
	if seen.size() != pool.size(): return "unreachable heap node"
	for id in pool:
		if not minimum or pool[id].value < pool[minimum].value: return "minimum pointer"
	return ""
