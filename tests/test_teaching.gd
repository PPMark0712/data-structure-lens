extends SceneTree
## Teaching behavior: verify observable frame transitions and independent answers.
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	_array_moves()
	_linked_heads()
	_monotonic()
	_sparse_table()
	_splay()
	_boundaries()
	print("Teaching regressions: %d checks; %d failures." % [checks, failures])
	quit(0 if failures == 0 else 1)

func _positions(frame: Dictionary) -> Dictionary:
	var result := {}
	for node in frame.nodes:
		if str(node.id).is_valid_int(): result[node.id] = node.pos
	return result

func _array_moves() -> void:
	for kind in ["array", "dynamic_array"]:
		for index in range(1, 6):
			var model := LinearModel.new(kind)
			var old_items := model.items.duplicate(true)
			check(model.perform("insert", {"index": index, "value": 99}), kind + " insert")
			var moved_ids: Array = []
			var previous := _positions(model.frames[0])
			for frame in model.frames.slice(1):
				var now := _positions(frame)
				var moved: Array = []
				for id in previous:
					if now.has(id) and now[id] != previous[id]:
						moved.append(id)
						check(now[id] - previous[id] == Vector2(78, 0), "one slot right")
				check(moved.size() <= 1, "only one element moves in each frame")
				moved_ids.append_array(moved)
				previous = now
			var expected: Array = []
			for i in range(3, index - 2, -1): expected.append(str(old_items[i].id))
			check(moved_ids == expected, "right shifts start at tail and end at insertion slot")
			check(model.items[index - 1].value == 99, "new value occupies requested position")
			check(model.visual_slots.is_empty(), "transient positions cleared")

func _linked_heads() -> void:
	for kind in ["linked", "doubly"]:
		var model := LinearModel.new(kind)
		var old_head := model.head
		check(model.perform("insert", {"index": 1, "value": 99}), "head insert accepted")
		check(model._by_id(model.head).value == 99, "head points at new element")
		check(model._by_id(model.head).next == old_head, "head connects to former head")
		check(model.perform("insert", {"index": model.items.size() + 1, "value": 88}), "tail insert")
		check(model._by_id(model.tail).value == 88, "tail updated")
		check(model.invariant().is_empty(), "head/tail/prev/next preserved")
		while not model.items.is_empty():
			check(model.perform("delete", {"index": 1}), "delete head")
			check(model.invariant().is_empty(), "head deletion invariant")
		check(model.head == 0 and model.tail == 0, "empty list pointers")
		check(model.perform("insert", {"index": 1, "value": 7}), "empty head insertion")
		check(model.head == model.tail and model.invariant().is_empty(), "singleton pointers")
		check(not model.perform("insert", {"index": 0, "value": 7}), "zero position rejected")

func _monotonic() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2810
	var samples: Array = [[6, 3, 8, 5, 5, 7, 2, 9, 4, 1], [5, 5, 5, 5],
		[1, 2, 3, 4], [4, 3, 2, 1], [9]]
	for sample in 40:
		var values: Array = []
		for i in rng.randi_range(1, 16): values.append(rng.randi_range(-5, 5))
		samples.append(values)
	for kind in ["mono_stack", "mono_queue"]:
		for values in samples:
			for width in ([1] if kind == "mono_stack" else [1, mini(3, values.size()), values.size()]):
				var model := MonotonicModel.new(kind)
				model.recording = false
				check(model.perform("build", {"values": ",".join(values.map(func(x): return str(x))), "window": width}), "set algorithm input")
				for i in values.size():
					check(model.perform("step", {}), "scan next element")
					var expected: Variant = null
					if kind == "mono_stack":
						expected = 0
						for j in range(i - 1, -1, -1):
							if values[j] > values[i]:
								expected = j + 1
								break
					elif i >= width - 1:
						var best: int = i - width + 1
						for j in range(best + 1, i + 1):
							if values[j] > values[best]: best = j
						expected = best + 1
					check(model.answers[i] == expected, "answer matches independent brute force")
					check(model.invariant().is_empty(), "frontier order and expiry")
				var answers := model.answers.duplicate()
				check(not model.perform("step", {}), "completed scan has explicit feedback")
				check(model.perform("reset", {}), "reset algorithm")
				check(model.perform("run", {}), "scan all remaining")
				check(model.answers == answers, "run and step agree")
				var last_x := -INF
				for node in model.view().nodes:
					if str(node.id).begins_with("q"):
						check(node.pos.y == 230 and node.pos.x > last_x, "frontier points right")
						last_x = node.pos.x
	var queue := MonotonicModel.new("mono_queue")
	check(not queue.perform("build", {"values": "1,2", "window": 3}), "reject oversized window")
	check(not queue.perform("build", {"values": "1,2", "window": 0}), "reject zero window")
	check(not queue.perform("build", {"values": "", "window": 1}), "reject empty array")

func _sparse_table() -> void:
	var model := RangeModel.new("sparse_table")
	for l in range(1, 9):
		for r in range(l, 9):
			check(model.perform("query", {"l": l, "r": r}), "ST 1-based query")
			var expected: int = model.data[l - 1]
			for i in range(l - 1, r): expected = mini(expected, model.data[i])
			check(model.result == expected, "ST query vs brute")
	var bars: Array = model.view().nodes
	var lanes := {}
	for bar in bars:
		var k := int(str(bar.id).get_slice("_", 0).substr(1))
		var l: int = bar.range[0]
		var r: int = bar.range[1]
		check(bar.size.x == (r - l + 1) * 90, "bar width matches interval")
		check(bar.pos.x - bar.size.x / 2 == 40 + (l - 1) * 90, "bar starts above left boundary")
		check(bar.pos.x + bar.size.x / 2 == 40 + r * 90, "bar ends above right boundary")
		if not lanes.has(k): lanes[k] = {}
		lanes[k][bar.pos.y] = true
		for other in bars:
			if bar.id == other.id or bar.pos.y != other.pos.y: continue
			check(not Rect2(bar.pos - bar.size / 2 + Vector2.ONE * 0.1, bar.size - Vector2.ONE * 0.2).intersects(
				Rect2(other.pos - other.size / 2, other.size)), "bars in same lane do not overlap")
	check(lanes[0].size() == 1 and lanes[1].size() == 2 and lanes[2].size() == 4, "ST uses 1/2/4 staggered lanes")
	check(not model.perform("query", {"l": 0, "r": 8}), "ST rejects zero index")

func _splay() -> void:
	# Golden trees include all seven nodes, so lost/reversed middle subtrees fail.
	var expected := {
		1: [[0, 2, 0], [0, 4, 1], [0, 0, 4], [3, 6, 2], [0, 0, 6], [5, 7, 4], [0, 0, 6]],
		7: [[0, 0, 2], [1, 3, 4], [0, 0, 2], [2, 5, 6], [0, 0, 4], [4, 0, 7], [6, 0, 0]],
		3: [[0, 0, 2], [1, 0, 3], [2, 4, 0], [0, 6, 3], [0, 0, 6], [5, 7, 4], [0, 0, 6]],
		5: [[0, 0, 2], [1, 3, 4], [0, 0, 2], [2, 0, 5], [4, 6, 0], [0, 7, 5], [0, 0, 6]]
	}
	for target in expected:
		var tree := BalancedModel.new("splay")
		tree.pool.clear()
		tree.next_id = 1
		for key in range(1, 8): tree._new(key * 10)
		tree.root = 4
		for link in [[4, 2, 6], [2, 1, 3], [6, 5, 7]]:
			tree.pool[link[0]].left = link[1]
			tree.pool[link[0]].right = link[2]
			tree.pool[link[1]].parent = link[0]
			tree.pool[link[2]].parent = link[0]
		tree.begin()
		tree._splay(target)
		check(tree.root == target, "double rotation target becomes root")
		for id in range(1, 8):
			var n: Dictionary = tree.pool[id]
			check([n.left, n.right, n.parent] == expected[target][id - 1], "LL/RR/LR/RL exact topology")
		check(tree.invariant().is_empty(), "Splay BST and parents intact")
		var rotations: Array = tree.frames.filter(func(frame): return frame.message.contains("重接中间子树"))
		check(rotations.size() == 2, "double rotation emits two separate rotation frames")

func _boundaries() -> void:
	for kind in ["segment", "dynamic_segment", "persistent_segment"]:
		var model := SegmentModel.new(kind)
		check(model.pool[model.root].l == 1 and model.pool[model.root].r == model.domain, "segment domain")
		for index in [1, model.domain]:
			var before: int = model.data[index - 1]
			check(model.perform("add", {"index": index, "value": 9}), "segment endpoint update")
			check(model.perform("query", {"l": index, "r": index}), "segment endpoint query")
			check(model.result == before + 9, "segment endpoint value")
		check(not model.perform("query", {"l": 0, "r": 1}), "segment rejects zero")
		if kind == "persistent_segment":
			check(not model.perform("version", {"version": 0}), "versions start at 1")
			check(model.perform("version", {"version": 1}), "V1 accessible")
			check(model.perform("query", {"l": 1, "r": 8}) and model.result == 31, "V1 preserved")
	for entry in LabCatalog.ENTRIES:
		var model := LabCatalog.create(entry)
		for operation in model.operations():
			check(operation.note.length() >= 15, "%s.%s has substantive note" % [entry[1], operation.id])
