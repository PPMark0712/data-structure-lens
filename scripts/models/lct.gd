class_name LinkCutModel
extends LabModel

var pool := {}
var links: Array = []
var result := 0

func _init(p_kind: String = "lct") -> void:
	super(p_kind)
	code.assign(["access(x)：逐段伸展，替换右孩子为上一段首选路径",
		"splay(x)：下传翻转标记，再旋转到辅助树根", "makeroot(x)：access 后翻转路径",
		"link(u,v)：换根后设置路径父亲", "cut(u,v)：暴露路径，切开直接相连的边",
		"split(u,v)：makeroot(u); access(v)，读取路径 sum"])
	recording = false
	for value in [2, 4, 6, 3, 5, 7]: _new(value)
	for pair in [[1, 2], [2, 3], [4, 5], [5, 6]]:
		_make_root(pair[0])
		pool[pair[0]].parent = pair[1]
		links.append(pair)
	recording = true

func operations() -> Array:
	return [op("link", "连接两棵树", [field("u", "节点 u", "3"), field("v", "节点 v", "4")]),
		op("cut", "断开一条边", [field("u", "节点 u", "2"), field("v", "节点 v", "3")]),
		op("query", "路径求和", [field("u", "起点 u", "1"), field("v", "终点 v", "3")]),
		op("set", "修改节点权值", [field("id", "节点编号", "3"), field("value", "新权值", "10")]),
		op("access", "暴露首选路径", [field("id", "节点编号", "2")]),
		op("makeroot", "换根", [field("id", "节点编号", "2")]),
		op("add", "添加孤立节点", [field("value", "节点权值", "8")])]

func _new(value: int) -> int:
	var id := uid()
	pool[id] = {"value": value, "sum": value, "left": 0, "right": 0, "parent": 0, "rev": false}
	return id

func _aux_root(id: int) -> bool:
	var p: int = pool[id].parent
	return p == 0 or (pool[p].left != id and pool[p].right != id)

func _sum(id: int) -> int:
	return pool[id].sum if id else 0

func _pull(id: int) -> void:
	pool[id].sum = pool[id].value + _sum(pool[id].left) + _sum(pool[id].right)

func _flip(id: int) -> void:
	if not id: return
	var old: int = pool[id].left
	pool[id].left = pool[id].right
	pool[id].right = old
	pool[id].rev = not pool[id].rev

func _push(id: int) -> void:
	if pool[id].rev:
		_flip(pool[id].left)
		_flip(pool[id].right)
		pool[id].rev = false
		record("下传 #%d 的路径翻转标记" % id, ["a%d" % id], 1)

func _rotate(id: int) -> void:
	var p: int = pool[id].parent
	var g: int = pool[p].parent
	var right: bool = pool[p].right == id
	var side := "right" if right else "left"
	var opposite := "left" if right else "right"
	var middle: int = pool[id][opposite]
	if not _aux_root(p): pool[g]["left" if pool[g].left == p else "right"] = id
	pool[id].parent = g
	pool[id][opposite] = p
	pool[p].parent = id
	pool[p][side] = middle
	if middle: pool[middle].parent = p
	_pull(p)
	_pull(id)
	record("辅助树旋转：#%d 提升到 #%d 上方" % [id, p], ["a%d" % id, "a%d" % p], 1)

func _splay(id: int) -> void:
	var ancestors: Array = [id]
	var x := id
	while not _aux_root(x):
		x = pool[x].parent
		ancestors.append(x)
	ancestors.reverse()
	for item in ancestors: _push(item)
	while not _aux_root(id):
		var p: int = pool[id].parent
		var g: int = pool[p].parent
		if not _aux_root(p):
			if (pool[p].left == id) == (pool[g].left == p): _rotate(p)
			else: _rotate(id)
		_rotate(id)

func _access(id: int) -> void:
	var last := 0
	var x := id
	while x:
		calls.append("access: splay(#%d), right ← #%d" % [x, last])
		_splay(x)
		pool[x].right = last
		if last: pool[last].parent = x
		_pull(x)
		record("替换 #%d 的右孩子；旧右子树转为虚边连接" % x, ["a%d" % x], 0)
		last = x
		x = pool[x].parent
		calls.pop_back()
	_splay(id)

func _make_root(id: int) -> void:
	_access(id)
	_flip(id)
	record("翻转根到 #%d 的首选路径；该点成为实际树根" % id, ["a%d" % id], 2)

func connected(u: int, v: int) -> bool:
	return not path(u, v).is_empty()

func path(u: int, v: int) -> Array:
	var pending: Array = [[u]]
	var seen := {u: true}
	while not pending.is_empty():
		var route: Array = pending.pop_front()
		var last: int = route.back()
		if last == v: return route
		for pair in links:
			var next: int = pair[1] if pair[0] == last else (pair[0] if pair[1] == last else 0)
			if next and not seen.has(next):
				seen[next] = true
				pending.append(route + [next])
	return []

func perform(action: String, args: Dictionary) -> bool:
	var u := int(args.get("u", args.get("id", 0)))
	var v := int(args.get("v", 0))
	if action != "add" and not pool.has(u): return fail("节点编号不存在。")
	if action in ["link", "cut", "query"] and not pool.has(v): return fail("节点 v 不存在。")
	if action == "link" and connected(u, v): return fail("两点已经连通，连边会形成环。")
	var edge_index := -1
	for i in links.size():
		if links[i] == [u, v] or links[i] == [v, u]: edge_index = i
	if action == "cut" and edge_index < 0: return fail("这两点之间没有直接相连的边。")
	if action == "query" and not connected(u, v): return fail("两点不连通，不存在路径。")
	if action == "add" and pool.size() >= 12: return fail("最多演示 12 个节点。")
	begin()
	match action:
		"add":
			var id := _new(int(args.value))
			record("添加孤立节点 #%d" % id, ["v%d" % id], 3)
		"link":
			_make_root(u)
			pool[u].parent = v
			links.append([u, v])
			record("连接 #%d 与 #%d，设置路径父亲" % [u, v], ["v%d" % u, "v%d" % v], 3)
		"cut":
			_make_root(u)
			_access(v)
			pool[v].left = 0
			pool[u].parent = 0
			_pull(v)
			links.remove_at(edge_index)
			record("暴露路径后，切开 #%d—#%d" % [u, v], ["v%d" % u, "v%d" % v], 4)
		"query":
			_make_root(u)
			_access(v)
			result = pool[v].sum
			record("路径 #%d → #%d 的节点权值和 = %d" % [u, v, result], ["a%d" % v], 5)
		"set":
			_access(u)
			pool[u].value = int(args.value)
			_pull(u)
			record("更新权值并维护辅助树聚合", ["a%d" % u], 5)
		"access": _access(u)
		"makeroot": _make_root(u)
	if action != "query":
		record("操作完成 · 实线=辅助树孩子，虚线=路径父亲", [], 5)
	return true

func _layout(id: int, depth: int, column: Array, nodes: Array, edges: Array) -> void:
	if not id: return
	var n: Dictionary = pool[id]
	_layout(n.left, depth + 1, column, nodes, edges)
	nodes.append(vertex("a%d" % id, "#%d" % id, 70 + column.size() * 115, 400 + depth * 110,
		"Σ%d%s" % [n.sum, " rev" if n.rev else ""], "circle", "blue" if n.rev else ""))
	column.append(id)
	for child in [n.left, n.right]:
		if child: edges.append(edge("a%d" % id, "a%d" % child))
	_layout(n.right, depth + 1, column, nodes, edges)

func view() -> Dictionary:
	var nodes: Array = []
	var edges: Array = []
	for id in pool:
		nodes.append(vertex("v%d" % id, pool[id].value, 70 + (id - 1) * 110,
			70 + (id % 2) * 65, "实际节点 #%d" % id, "circle", "green"))
	for pair in links:
		var connection := edge("v%d" % pair[0], "v%d" % pair[1])
		connection["directed"] = false
		edges.append(connection)
	var column: Array = []
	for id in pool:
		if _aux_root(id): _layout(id, 0, column, nodes, edges)
	for id in pool:
		if _aux_root(id) and pool[id].parent:
			edges.append(edge("a%d" % id, "a%d" % pool[id].parent, "path", true))
	return {"nodes": nodes, "edges": edges, "stats": "上：实际森林 · 下：辅助 Splay · %d 节点 / %d 边" % [pool.size(), links.size()]}

func invariant() -> String:
	var seen := {}
	var pending: Array = []
	for id in pool:
		if _aux_root(id): pending.append(id)
	while not pending.is_empty():
		var id: int = pending.pop_back()
		if seen.has(id): return "LCT auxiliary cycle"
		seen[id] = true
		var n: Dictionary = pool[id]
		if n.sum != n.value + _sum(n.left) + _sum(n.right): return "LCT aggregate"
		for child in [n.left, n.right]:
			if child:
				if pool[child].parent != id: return "LCT auxiliary parent"
				pending.append(child)
	if seen.size() != pool.size(): return "LCT unreachable"
	return ""
