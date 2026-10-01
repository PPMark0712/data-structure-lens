class_name BalancedModel
extends LabModel

var pool := {}
var root := 0
var rng_state := 1729
var found := false

func _init(p_kind: String = "avl") -> void:
	super(p_kind)
	code.assign(["按 BST 键序比较，沿左 / 右孩子下降", "插入叶子 / 删除并重接子树",
		"AVL：更新高度，检查平衡因子 ±2", "旋转：重接父子指针",
		"Treap：维护最小优先级堆序", "Splay：Zig / Zig-Zig / Zig-Zag 伸展到根"])
	recording = false
	for key in [30, 15, 45, 8, 22, 38, 50]: _insert(key)
	recording = true

func operations() -> Array:
	return [op("insert", "插入", [field("value", "键（不重复）", "20")]),
		op("delete", "删除", [field("value", "键", "15")]),
		op("find", "查找", [field("value", "键", "22")]),
		op("build", "重新构建", [field("values", "整数序列（最多 15 个）", "30,15,45,8,22,38,50", true)])]

func _new(key: int) -> int:
	var id := uid()
	rng_state = (rng_state * 48271) % 2147483647
	pool[id] = {"key": key, "left": 0, "right": 0, "parent": 0, "height": 1,
		"priority": rng_state % 1000, "red": true}
	return id

func _height(id: int) -> int:
	return pool[id].height if id else 0

func _pull(id: int) -> void:
	if id: pool[id].height = 1 + maxi(_height(pool[id].left), _height(pool[id].right))

func _refresh(id: int) -> void:
	if not id: return
	_refresh(pool[id].left)
	_refresh(pool[id].right)
	_pull(id)

func _balance(id: int) -> int:
	return _height(pool[id].left) - _height(pool[id].right)

func _replace(old: int, replacement: int) -> void:
	var parent: int = pool[old].parent
	if not parent: root = replacement
	else: pool[parent]["left" if pool[parent].left == old else "right"] = replacement
	if replacement: pool[replacement].parent = parent

func _rotate(x: int, left: bool) -> int:
	var side := "right" if left else "left"
	var opposite := "left" if left else "right"
	var y: int = pool[x][side]
	var middle: int = pool[y][opposite]
	_replace(x, y)
	pool[y][opposite] = x
	pool[x].parent = y
	pool[x][side] = middle
	if middle: pool[middle].parent = x
	_pull(x)
	_pull(y)
	record("%s旋 #%d：提升 #%d，重接中间子树" % ["左" if left else "右", x, y], [str(x), str(y)], 3)
	return y

func _lookup(key: int) -> int:
	var id := root
	var last := 0
	while id:
		last = id
		calls.append("compare %d with %d" % [key, pool[id].key])
		record("比较 %d 与 %d" % [key, pool[id].key], [str(id)], 0)
		if key == pool[id].key: break
		id = pool[id]["left" if key < pool[id].key else "right"]
	calls.clear()
	if kind == "splay" and last: _splay(last)
	return id

func _insert(key: int) -> void:
	var parent := 0
	var current := root
	while current:
		parent = current
		record("比较键 %d，选择子树" % key, [str(current)], 0)
		current = pool[current]["left" if key < pool[current].key else "right"]
	var id := _new(key)
	pool[id].parent = parent
	if parent: pool[parent]["left" if key < pool[parent].key else "right"] = id
	else: root = id
	record("插入叶子 #%d" % id, [str(id)], 1)
	match kind:
		"avl": _avl(parent)
		"treap":
			while pool[id].parent and pool[id].priority < pool[pool[id].parent].priority:
				parent = pool[id].parent
				record("子节点优先级更小，需要提升", [str(id), str(parent)], 4)
				_rotate(parent, pool[parent].right == id)
		"splay": _splay(id)
	_refresh(root)

func _avl(id: int) -> void:
	while id:
		_pull(id)
		record("回溯 #%d：height=%d，BF=%d" % [id, pool[id].height, _balance(id)], [str(id)], 2)
		if _balance(id) > 1:
			if _balance(pool[id].left) < 0: _rotate(pool[id].left, true)
			id = _rotate(id, false)
		elif _balance(id) < -1:
			if _balance(pool[id].right) > 0: _rotate(pool[id].right, false)
			id = _rotate(id, true)
		id = pool[id].parent

func _splay(id: int) -> void:
	while pool[id].parent:
		var p: int = pool[id].parent
		var g: int = pool[p].parent
		if not g:
			record("Zig：父节点就是根，旋转一次", [str(id), str(p)], 5)
			_rotate(p, pool[p].right == id)
		elif (pool[p].left == id) == (pool[g].left == p):
			record("Zig-Zig：同侧；先绕祖父 #%d %s旋提升父亲，再绕父亲 #%d 同向旋转提升当前节点" %
				[g, "左" if pool[g].right == p else "右", p], [str(id), str(p), str(g)], 5)
			_rotate(g, pool[g].right == p)
			_rotate(p, pool[p].right == id)
		else:
			record("Zig-Zag：异侧；先绕父亲 #%d %s旋，再绕祖父 #%d 反向旋转，两次提升当前节点" %
				[p, "左" if pool[p].right == id else "右", g], [str(id), str(p), str(g)], 5)
			_rotate(p, pool[p].right == id)
			_rotate(g, pool[g].right == id)

func _delete(id: int) -> void:
	if kind == "splay":
		_splay(id)
		var left: int = pool[id].left
		var right: int = pool[id].right
		if left: pool[left].parent = 0
		if right: pool[right].parent = 0
		pool.erase(id)
		root = left
		if left:
			var largest := left
			while pool[largest].right: largest = pool[largest].right
			_splay(largest)
			pool[root].right = right
			if right: pool[right].parent = root
		else: root = right
	elif kind == "treap":
		while pool[id].left or pool[id].right:
			var l: int = pool[id].left
			var r: int = pool[id].right
			_rotate(id, not l or (r != 0 and pool[r].priority < pool[l].priority))
		_replace(id, 0)
		pool.erase(id)
	else:
		if pool[id].left and pool[id].right:
			var successor: int = pool[id].right
			while pool[successor].left: successor = pool[successor].left
			pool[id].key = pool[successor].key
			record("用中序后继替换键，再删除后继节点", [str(id), str(successor)], 1)
			id = successor
		var parent: int = pool[id].parent
		_replace(id, pool[id].left if pool[id].left else pool[id].right)
		pool.erase(id)
		_avl(parent)
	_refresh(root)
	record("删除完成，重接子树", [], 1)

func keys() -> Array:
	var result: Array = []
	for id in pool: result.append(pool[id].key)
	result.sort()
	return result

func perform(action: String, args: Dictionary) -> bool:
	if action == "build":
		var values := integers(args.values, 15)
		if not error.is_empty(): return false
		var distinct := {}
		for key in values: distinct[key] = true
		if distinct.size() != values.size(): return fail("平衡树示例使用互异键，请移除重复值。")
		begin()
		pool.clear()
		root = 0
		rng_state = 1729
		for key in values: _insert(key)
	else:
		var key := int(args.value)
		if action == "insert":
			if keys().has(key): return fail("键已存在；本实验不保存重复键。")
			if pool.size() >= 15: return fail("最多演示 15 个节点。")
		if action == "delete" and not keys().has(key): return fail("键不存在，无法删除。")
		begin()
		if action == "insert": _insert(key)
		else:
			var id := _lookup(key)
			found = id != 0
			if action == "delete": _delete(id)
			else: record("找到键 %d" % key if found else "键 %d 不存在" % key,
				[str(id)] if found else [], 0)
	record("操作完成；根 = %s" % (str(pool[root].key) if root else "∅"))
	return true

func _layout(id: int, depth: int, order: Array, nodes: Array, edges: Array) -> void:
	if not id: return
	var n: Dictionary = pool[id]
	_layout(n.left, depth + 1, order, nodes, edges)
	var x := 60 + order.size() * 85
	order.append(id)
	var detail := "#%d" % id
	var tone := ""
	if kind == "avl": detail += " h%d b%d" % [n.height, _balance(id)]
	if kind == "treap": detail += " p%d" % n.priority
	if kind == "red_black": tone = "red" if n.red else "black"
	nodes.append(vertex(id, n.key, x, 60 + depth * 110, detail, "circle", tone))
	for child in [n.left, n.right]:
		if child: edges.append(edge(id, child))
	_layout(n.right, depth + 1, order, nodes, edges)

func view() -> Dictionary:
	var nodes: Array = []
	var edges: Array = []
	_layout(root, 0, [], nodes, edges)
	return {"nodes": nodes, "edges": edges, "stats": "节点 %d · 根 #%d · 互异键 BST" % [pool.size(), root]}

func invariant() -> String:
	if root and pool[root].parent: return "root parent"
	var visited := {}
	var pending: Array = [[root, -10000000000, 10000000000]]
	while not pending.is_empty():
		var item: Array = pending.pop_back()
		var id: int = item[0]
		if not id: continue
		if visited.has(id): return "BST cycle"
		visited[id] = true
		var n: Dictionary = pool[id]
		if n.key <= item[1] or n.key >= item[2]: return "BST order"
		if kind == "avl" and (absi(_balance(id)) > 1 or n.height != 1 + maxi(_height(n.left), _height(n.right))):
			return "AVL height/balance"
		for child in [n.left, n.right]:
			if child and pool[child].parent != id: return "BST parent"
			if kind == "treap" and child and pool[child].priority < n.priority: return "treap priority"
		pending.append([n.left, item[1], n.key])
		pending.append([n.right, n.key, item[2]])
	if visited.size() != pool.size(): return "unreachable BST node"
	return ""
