class_name RedBlackModel
extends BalancedModel

func _init(p_kind: String = "red_black") -> void:
	super(p_kind)
	code.assign(["按 BST 规则定位 / 插入红色叶子", "父叔均红：变黑，上移祖父",
		"叔黑：内侧先转为外侧，再旋转祖父并换色", "旋转并重接父子指针",
		"删除黑节点：兄弟红 / 双黑孩子 / 近红远黑 / 远红", "根与 NIL 恒黑，保持各路径黑高相等"])

func _red(id: int) -> bool:
	return bool(pool[id].red) if id else false

func _color(id: int, red: bool) -> void:
	if id: pool[id].red = red

func _child(id: int, side: String) -> int:
	return pool[id][side] if id else 0

func _insert(key: int) -> void:
	super._insert(key)
	var id := next_id - 1
	while id != root and _red(pool[id].parent):
		var p: int = pool[id].parent
		var g: int = pool[p].parent
		var p_left: bool = pool[g].left == p
		var uncle: int = pool[g].right if p_left else pool[g].left
		if _red(uncle):
			_color(p, false)
			_color(uncle, false)
			_color(g, true)
			record("父叔均红：父叔变黑，祖父变红，继续向上", [str(p), str(uncle), str(g)], 1)
			id = g
		else:
			if (pool[p].right == id) == p_left:
				id = p
				_rotate(id, p_left)
				p = pool[id].parent
				g = pool[p].parent
			_color(p, false)
			_color(g, true)
			record("叔为黑：父变黑、祖父变红，旋转祖父", [str(p), str(g)], 2)
			_rotate(g, not p_left)
	_color(root, false)
	_refresh(root)
	record("根变黑，插入修复完成", [str(root)], 5)

func _delete(id: int) -> void:
	if pool[id].left and pool[id].right:
		var successor: int = pool[id].right
		while pool[successor].left: successor = pool[successor].left
		pool[id].key = pool[successor].key
		record("以后继键替换，再删除至多有一个孩子的后继", [str(id), str(successor)], 0)
		id = successor
	var was_red := _red(id)
	var replacement: int = pool[id].left if pool[id].left else pool[id].right
	var parent: int = pool[id].parent
	_replace(id, replacement)
	pool.erase(id)
	record("删除%s节点，接回子树" % ("红" if was_red else "黑"), [str(replacement)], 4)
	if not was_red: _fix_delete(replacement, parent)
	_color(root, false)
	_refresh(root)
	record("删除修复完成，各根到 NIL 路径黑高相等", [str(root)], 5)

func _fix_delete(x: int, parent: int) -> void:
	while x != root and not _red(x):
		if parent == 0: break
		var left_side: bool = pool[parent].left == x
		var near := "left" if left_side else "right"
		var far := "right" if left_side else "left"
		var sibling: int = pool[parent][far]
		if _red(sibling):
			_color(sibling, false)
			_color(parent, true)
			record("兄弟红：兄弟变黑、父变红，旋转父节点", [str(sibling), str(parent)], 4)
			_rotate(parent, left_side)
			sibling = pool[parent][far]
		if not _red(_child(sibling, near)) and not _red(_child(sibling, far)):
			_color(sibling, true)
			record("兄弟的两个孩子均黑：兄弟变红，额外黑色向父传播", [str(sibling), str(parent)], 4)
			x = parent
			parent = pool[x].parent
		else:
			if not _red(_child(sibling, far)):
				_color(_child(sibling, near), false)
				_color(sibling, true)
				record("近侄红、远侄黑：旋转兄弟，转为远侄红", [str(sibling)], 4)
				_rotate(sibling, not left_side)
				sibling = pool[parent][far]
			_color(sibling, _red(parent))
			_color(parent, false)
			_color(_child(sibling, far), false)
			record("远侄红：兄弟继承父颜色，父与远侄变黑，旋转父", [str(sibling), str(parent)], 4)
			_rotate(parent, left_side)
			x = root
			parent = 0
	_color(x, false)

func _black_height(id: int) -> int:
	if not id: return 1
	var n: Dictionary = pool[id]
	if n.red and (_red(n.left) or _red(n.right)): return -1
	var left := _black_height(n.left)
	var right := _black_height(n.right)
	if left < 0 or right < 0 or left != right: return -1
	return left + (0 if n.red else 1)

func invariant() -> String:
	var base := super.invariant()
	if not base.is_empty(): return base
	if _red(root): return "red root"
	if _black_height(root) < 0: return "red adjacency / unequal black height"
	return ""
