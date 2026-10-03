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
	_array_deletes()
	_array_migration()
	_linked_heads()
	_linked_queries_and_reverse()
	_stack_container()
	_hash_layout()
	_disjoint_set()
	_monotonic()
	_sparse_table()
	_segment_intervals()
	_heap_filling()
	_trie_labels()
	_splay()
	_boundaries()
	print("Teaching regressions: %d checks; %d failures." % [checks, failures])
	quit(0 if failures == 0 else 1)

func _positions(frame: Dictionary) -> Dictionary:
	var result := {}
	for node in frame.nodes:
		if str(node.id).is_valid_int(): result[node.id] = node.pos
	return result

func _has_edge(frame: Dictionary, from: String, to: String,
		label: String = "", dashed: bool = false) -> bool:
	for link in frame.edges:
		if link.from == from and link.to == to and link.label == label and link.dashed == dashed:
			return true
	return false

func _stack_container() -> void:
	var model := LinearModel.new("stack")
	var view := model.view()
	check(view.outlines.size() == 1 and view.outlines[0].points.size() == 4,
		"stack has one open-top container")
	var outline: Array = view.outlines[0].points
	check(outline[0].y == outline[-1].y and outline[0].x < outline[-1].x,
		"stack container leaves its top edge open")
	for node in view.nodes:
		check(node.detail_offset.x > 0, "stack index is placed beside its cell")
	var pushed_id := str(model.next_id)
	check(model.perform("push", {"value": 99}), "stack push")
	var entering: Array = model.frames.filter(func(frame): return frame.message.contains("从栈口放入"))
	check(entering.size() == 1, "stack push emits an entry frame")
	var entering_node: Dictionary = entering[0].nodes.filter(func(node): return node.id == pushed_id)[0]
	var settled_node: Dictionary = model.frames[-1].nodes.filter(func(node): return node.id == pushed_id)[0]
	check(entering_node.pos.y == settled_node.pos.y - 68, "pushed value moves down through stack opening")
	check(entering_node.detail == settled_node.detail and settled_node.detail.ends_with("TOP"),
		"moving stack value keeps its logical index and TOP label")
	var before_pop: Vector2 = settled_node.pos
	check(model.perform("pop", {}), "stack pop")
	var leaving: Array = model.frames.filter(func(frame): return frame.message.contains("从栈口取出"))
	check(leaving.size() == 1, "stack pop emits an exit frame")
	var leaving_node: Dictionary = leaving[0].nodes.filter(func(node): return node.id == pushed_id)[0]
	check(leaving_node.pos.y == before_pop.y - 68, "popped value moves up through stack opening")
	check(model.frames[-1].nodes.all(func(node): return node.id != pushed_id),
		"popped value disappears after leaving the container")

func _hash_layout() -> void:
	for kind in ["hash_linear", "hash_quadratic", "hash_chain"]:
		var model := HashModel.new(kind)
		var view := model.view()
		var slots: Array = view.nodes.filter(func(node): return node.id.begins_with("slot"))
		check(slots.size() == HashModel.SIZE, kind + " renders every hash slot")
		for i in HashModel.SIZE:
			var slot: Dictionary = slots.filter(func(node): return node.id == "slot%d" % i)[0]
			check(slot.pos == Vector2(70 + i * 74, 115), kind + " slots form one horizontal row")
			check(slot.detail == "[%d]" % i and slot.detail_offset.y < 0,
				kind + " shows an unobstructed 0-based index")
		check(model.code[0] == "h = ((key % 11) + 11) % 11",
			kind + " hash formula is 0-based")
		check(model.operations()[0].note.contains("0–10"), kind + " operation note states 0-based buckets")
		if kind == "hash_chain":
			for value in [12, 23, 7, 34]:
				var key: Dictionary = view.nodes.filter(func(node): return node.id == "key%d" % value)[0]
				var bucket: Dictionary = slots.filter(
					func(node): return node.id == "slot%d" % model._hash(value))[0]
				check(key.pos.x == bucket.pos.x and key.pos.y > bucket.pos.y,
					"hash chains extend downward from their bucket")
		check(model.perform("insert", {"value": 45}), kind + " insert for index narration")
		check(model.frames[1].message == "h(45) = 1", kind + " hash narration uses 0-based index")

func _disjoint_set() -> void:
	var model := DisjointSetModel.new()
	check(model.parent == [0, 2, 3, 3, 5, 6, 6, 8, 8, 10, 10],
		"disjoint set default forest uses short paths worth compressing")
	check(DisjointSetModel.HORIZONTAL_GAP == 112.0 and DisjointSetModel.ROOT_GAP == 56.0,
		"disjoint set reserves readable horizontal spacing")
	var initial := model.view()
	check(initial.nodes.size() == 10 and initial.edges.size() == 6,
		"disjoint set forest renders every element and non-root parent")
	check(initial.nodes.filter(func(node): return node.tone == "green").size() == 4,
		"disjoint set roots are visibly distinct")
	for node in initial.nodes:
		check(node.detail.is_empty() and node.lines.size() == 2,
			"disjoint set keeps parent labels inside nodes")
	check(initial.edges.all(func(link): return link.label.is_empty()),
		"disjoint set arrows do not duplicate parent labels")
	check(model.code[1] == "路径压缩开启时：fa[x] = find(fa[x])",
		"disjoint set presents the path-compression assignment")
	check(model.perform("build", {"size": 6}), "prepare a long path for compression")
	model.parent[1] = 2
	model.parent[2] = 3
	model.parent[3] = 4
	check(model.perform("find", {"x": 1}), "disjoint set find")
	check(model.result == 4 and model.parent.slice(1, 5) == [4, 4, 4, 4],
		"find compresses the full path to its representative")
	var changed: Array = []
	var previous: Array = model.frames[0].parents
	for frame in model.frames.slice(1):
		var current: Array = frame.parents
		var differences: Array = []
		for i in range(1, current.size()):
			if current[i] != previous[i]:
				differences.append([i, current[i]])
		check(differences.size() <= 1, "path compression rewrites one fa entry per frame")
		changed.append_array(differences)
		previous = current
	check(changed == [[2, 4], [1, 4]], "path compression rewrites parents during recursion unwind")
	var deepest: Array = model.frames.map(func(frame): return frame.calls.size())
	check(deepest.max() == 4, "find exposes the complete recursive call stack")
	check(model.perform("build", {
		"size": 6, "path_compression": false, "union_strategy": "none"
	}), "disable path compression")
	model.parent[1] = 2
	model.parent[2] = 3
	model.parent[3] = 4
	check(model.perform("find", {"x": 1}), "find without path compression")
	check(model.parent.slice(1, 5) == [2, 3, 4, 4],
		"disabled path compression preserves the full path")
	check(model.frames.any(func(frame): return frame.message.contains("路径压缩关闭")),
		"disabled path compression is explicit in the animation")
	model = DisjointSetModel.new()
	check(model.perform("union", {"a": 1, "b": 8}), "disjoint set union")
	check(model.parent[3] == 8, "union attaches find(a) directly below find(b)")
	check(model.frames[-1].message.contains("未启用合并启发式"),
		"union animation states that no heuristic is enabled")
	check(model.perform("connected", {"a": 1, "b": 8}) and model.connected_result,
		"connected uses compressed representatives")
	check(model.perform("build", {
		"size": 6, "path_compression": true, "union_strategy": "rank"
	}), "enable union by rank")
	check(model.perform("union", {"a": 1, "b": 2}), "rank union first pair")
	check(model.perform("union", {"a": 3, "b": 2}), "rank union keeps taller root")
	check(model.parent[1] == 2 and model.parent[3] == 2 and model.rank[2] == 1,
		"rank union attaches the shallower tree")
	check(model.perform("build", {
		"size": 6, "path_compression": true, "union_strategy": "size"
	}), "enable union by size")
	check(model.perform("union", {"a": 1, "b": 2}), "size union first pair")
	check(model.perform("union", {"a": 1, "b": 3}), "size union keeps larger root")
	check(model.parent[3] == 2 and model.size[2] == 3,
		"size union attaches the smaller component")
	check(model.perform("build", {"size": 12}), "disjoint set rebuild")
	for i in range(1, 13):
		check(model.parent[i] == i, "rebuild starts each element as its own representative")
	check(not model.perform("find", {"x": 0}), "disjoint set rejects zero")
	check(not model.perform("build", {"size": 13}), "disjoint set enforces teaching limit")
	var weighted := DisjointSetModel.new("weighted_disjoint_set")
	check(weighted.view().nodes.all(func(node): return node.lines.size() == 3),
		"weighted disjoint set shows parent and edge weight inside every node")
	check(weighted.perform("query", {"a": 1, "b": 3}),
		"weighted disjoint set queries an existing relation")
	check(weighted.has_result and weighted.result == 1,
		"weighted query returns value[3] - value[1]")
	check(weighted.parent[1] == 3 and weighted.weight[1] == -1,
		"weighted path compression preserves accumulated potential")
	check(weighted.perform("relation", {"a": 1, "b": 4, "delta": 7}),
		"weighted disjoint set joins two components")
	check(weighted.perform("query", {"a": 1, "b": 4}) and weighted.result == 7,
		"weighted union preserves the requested difference")
	var weighted_before := weighted.parent.duplicate()
	check(not weighted.perform("relation", {"a": 1, "b": 4, "delta": 8}),
		"weighted disjoint set rejects a contradictory relation")
	check(weighted.parent == weighted_before,
		"contradictory weighted relation leaves the forest unchanged")
	var rollback := DisjointSetModel.new("rollback_disjoint_set")
	check(rollback.merge_history.size() == 4,
		"rollback disjoint set default example has visible history")
	var rollback_parent := rollback.parent.duplicate()
	var rollback_size := rollback.size.duplicate()
	check(rollback.perform("union", {"a": 7, "b": 8}),
		"rollback disjoint set records a merge")
	check(rollback.parent[8] == 7 and rollback.merge_history.size() == 5,
		"rollback union uses size and pushes history")
	check(rollback.perform("rollback", {"steps": 1}),
		"rollback disjoint set restores the latest merge")
	check(rollback.parent == rollback_parent and rollback.size == rollback_size,
		"rollback restores parent and size exactly")
	var before_find := rollback.parent.duplicate()
	check(rollback.perform("connected", {"a": 2, "b": 4}) and rollback.connected_result,
		"rollback disjoint set answers connectivity")
	check(rollback.parent == before_find,
		"rollback disjoint set never compresses paths")

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
					if now.has(id) and now[id].x != previous[id].x:
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

func _array_deletes() -> void:
	for kind in ["array", "dynamic_array"]:
		for index in range(1, 5):
			var model := LinearModel.new(kind)
			var old_items := model.items.duplicate(true)
			check(model.perform("delete", {"index": index}), kind + " delete")
			var moved_ids: Array = []
			var previous := _positions(model.frames[0])
			for frame in model.frames.slice(1):
				var now := _positions(frame)
				var moved: Array = []
				for id in previous:
					if now.has(id) and now[id].x != previous[id].x:
						moved.append(id)
						check(now[id] - previous[id] == Vector2(-78, 0), "one slot left")
				check(moved.size() <= 1, "only one deletion shift per frame")
				moved_ids.append_array(moved)
				previous = now
			var expected: Array = []
			for i in range(index, old_items.size()):
				expected.append(str(old_items[i].id))
			check(moved_ids == expected, "left shifts start after deletion and proceed to tail")
			check(model.frames.any(func(frame): return frame.message.contains("左移")),
				"array deletion explains left shifts")
			check(model.frames.all(func(frame): return not frame.message.contains("重接")),
				"array deletion does not use linked-list wording")

func _array_migration() -> void:
	var model := LinearModel.new("dynamic_array")
	check(model.perform("build", {"values": "4,4,-2,7,9,1,3,6,8"}), "build through two expansions")
	var expansions: Array = []
	var previous: Dictionary = {}
	var last_copied := 0
	for frame in model.frames:
		var memory: Dictionary = frame.get("memory", {})
		if memory.is_empty():
			previous = frame
			continue
		var original := _positions(frame)
		if memory.phase == "lift":
			expansions.append(memory.old_capacity)
			last_copied = 0
			var before := _positions(previous)
			for id in original:
				check(original[id] - before[id] == Vector2(0, -100), "old array lifts as a block")
		check(memory.new_capacity == memory.old_capacity * 2, "new memory doubles capacity")
		var old_nodes: Array = frame.nodes.filter(func(n): return str(n.id).begins_with("old_memory_"))
		var lower: Array = frame.nodes.filter(func(n): return n.pos.y == 320)
		if memory.phase == "lift":
			check(lower.is_empty(), "old array lifts before allocation")
		else:
			check(lower.size() == memory.new_capacity, "new allocation has twice as many slots")
			check(old_nodes.size() == (0 if memory.phase == "release" else memory.old_capacity),
				"source memory stays until explicit release")
			var copies: Array = lower.filter(func(n): return str(n.id).is_valid_int())
			copies.sort_custom(func(a, b): return a.pos.x < b.pos.x)
			check(copies.size() == memory.copied, "copied prefix fills destination")
			for i in copies.size():
				check(copies[i].label == str([4, 4, -2, 7, 9, 1, 3, 6][i]), "copy preserves values and order")
				check(copies[i].pos.x == 75 + i * 78, "copy stays in same column")
			if memory.copied > last_copied:
				check(memory.copied == last_copied + 1, "one copy per frame")
				var before := _positions(previous)
				var moved := 0
				for id in original:
					if original[id] != before[id]:
						moved += 1
						check(original[id] - before[id] == Vector2(0, 220), "element travels downward")
				check(moved == 1, "only current element travels during copy")
			if memory.phase in ["switch", "release"]:
				check(memory.copied == memory.old_capacity, "switch/release only after complete copy")
			for old in old_nodes:
				check(old.pos.y == 100, "old copy remains in upper allocation")
		last_copied = memory.copied
		previous = frame
	check(expansions == [4, 8], "construction animates 4 to 8 and 8 to 16")
	check(model.capacity == 16 and model.migration.is_empty(), "migration finishes without transient state")
	check(model.items.map(func(item): return item.value) == [4, 4, -2, 7, 9, 1, 3, 6, 8],
		"expansion preserves logical contents")
	check(model.perform("push", {"value": 10}), "append within available capacity")
	check(model.frames.all(func(frame): return not frame.has("memory")), "spare capacity skips migration")
	for index in [1, 3, 5]:
		model = LinearModel.new("dynamic_array")
		var before := model.items.map(func(item): return item.id)
		check(model.perform("insert", {"index": index, "value": 99}), "insert following migration")
		var after := model.items.map(func(item): return item.id)
		after.remove_at(index - 1)
		check(after == before, "stable element IDs survive copying and insertion")
		check(model.items[index - 1].value == 99 and model.invariant().is_empty(),
			"insertion uses expanded allocation")

func _linked_heads() -> void:
	for kind in ["linked", "doubly"]:
		var model := LinearModel.new(kind)
		var initial := model.view()
		var marker_ids := ["head_marker", "tail_marker", "next_null"]
		if kind == "doubly":
			marker_ids.append("prev_null")
		var markers: Array = initial.nodes.filter(func(node): return node.id in marker_ids)
		var head_node: Dictionary = initial.nodes.filter(
			func(node): return node.id == str(model.head))[0]
		var tail_node: Dictionary = initial.nodes.filter(
			func(node): return node.id == str(model.tail))[0]
		check(markers.size() == marker_ids.size() and markers.all(
			func(node): return node.shape == "label" and not node.pickable),
			kind + " renders non-interactive pointer labels")
		check(initial.nodes.filter(func(node): return node.id == "head_marker")[0].pos.y < head_node.pos.y
			and initial.nodes.filter(func(node): return node.id == "tail_marker")[0].pos.y < tail_node.pos.y,
			kind + " places HEAD and TAIL above their nodes")
		check(_has_edge(initial, "head_marker", str(model.head))
			and _has_edge(initial, "tail_marker", str(model.tail)),
			kind + " points HEAD and TAIL down to the endpoint nodes")
		var next_null: Dictionary = initial.nodes.filter(func(node): return node.id == "next_null")[0]
		check(next_null.pos.x > tail_node.pos.x
			and _has_edge(initial, str(model.tail), "next_null", "next"),
			kind + " tail next points right to NULL")
		if kind == "doubly":
			var prev_null: Dictionary = initial.nodes.filter(func(node): return node.id == "prev_null")[0]
			check(prev_null.pos.x < head_node.pos.x
				and _has_edge(initial, str(model.head), "prev_null", "prev", true),
				"head prev points left to NULL")
			check(model._by_id(model.head).prev == 0 and model._by_id(model.tail).next == 0,
				"rendered NULL pointers match the stored endpoints")
		else:
			check(initial.nodes.all(func(node): return node.id != "prev_null"),
				"singly linked list does not render a prev pointer")
			var operation_ids: Array = model.operations().map(func(operation): return operation.id)
			check(operation_ids.slice(0, 2) == ["insert_head", "insert_tail"]
				and not operation_ids.has("insert"),
				"singly linked list exposes only head and tail insertion")
			var deletion := LinearModel.new("linked")
			var predecessor_id := str(deletion.items[1].id)
			var target_id := str(deletion.items[2].id)
			var successor_id: int = deletion.items[3].id
			check(deletion.perform("delete", {"index": 3}), "singly linked middle deletion")
			var visits: Array = deletion.frames.filter(
				func(frame): return frame.message.begins_with("沿 next"))
			check(visits.size() == 2 and visits[-1].active == [predecessor_id],
				"singly linked deletion traverses only through the predecessor")
			var unlink: Array = deletion.frames.filter(
				func(frame): return frame.message.contains("删除 next"))
			check(unlink.size() == 1 and unlink[0].active == [predecessor_id, target_id],
				"singly linked deletion removes the predecessor's next node")
			check(deletion._by_id(int(predecessor_id)).next == successor_id
				and deletion.items.map(func(item): return item.value) == [12, 7, 16],
				"singly linked deletion reconnects next to the target successor")
			check(deletion.frames[-1].message == "前驱 next 改指向目标的后继，长度减一",
				"singly linked middle deletion does not claim to update TAIL")
			check(deletion.perform("delete", {"index": 3}), "singly linked tail deletion")
			check(deletion.tail == int(predecessor_id) and deletion._by_id(deletion.tail).next == 0
				and deletion.frames[-1].message.contains("TAIL 改为前驱"),
				"singly linked tail deletion updates TAIL and terminates next")
		var old_head := model.head
		var head_action := "insert_head" if kind == "linked" else "insert"
		check(model.perform(head_action, {"index": 1, "value": 99}), "head insert accepted")
		check(model._by_id(model.head).value == 99, "head points at new element")
		check(model._by_id(model.head).next == old_head, "head connects to former head")
		var tail_action := "insert_tail" if kind == "linked" else "insert"
		check(model.perform(tail_action, {
			"index": model.items.size() + 1, "value": 88
		}), "tail insert")
		check(model._by_id(model.tail).value == 88, "tail updated")
		check(model.invariant().is_empty(), "head/tail/prev/next preserved")
		while not model.items.is_empty():
			check(model.perform("delete", {"index": 1}), "delete head")
			check(model.invariant().is_empty(), "head deletion invariant")
		check(model.head == 0 and model.tail == 0, "empty list pointers")
		if kind == "linked":
			check(model.frames[-1].message.contains("HEAD 和 TAIL 均指向 NULL"),
				"singly linked singleton deletion clears both endpoint pointers")
		check(model.perform(head_action, {"index": 1, "value": 7}), "empty head insertion")
		check(model.head == model.tail and model.invariant().is_empty(), "singleton pointers")
		if kind == "linked":
			check(model.frames[-1].message.contains("HEAD 和 TAIL 均指向它"),
				"singly linked empty insertion sets both endpoint pointers")
		var singleton := model.view()
		var head_marker: Dictionary = singleton.nodes.filter(
			func(node): return node.id == "head_marker")[0]
		var tail_marker: Dictionary = singleton.nodes.filter(
			func(node): return node.id == "tail_marker")[0]
		check(head_marker.pos.x < tail_marker.pos.x,
			kind + " singleton HEAD and TAIL labels do not overlap")
		if kind == "linked":
			check(not model.perform("insert", {"index": 2, "value": 7}),
				"singly linked list rejects arbitrary insertion")
		else:
			check(not model.perform("insert", {"index": 0, "value": 7}), "zero position rejected")

func _linked_queries_and_reverse() -> void:
	for kind in ["linked", "doubly"]:
		var model := LinearModel.new(kind)
		var ids: Array = model.items.map(func(item): return str(item.id))
		var operations: Array = model.operations()
		var operation_ids: Array = operations.map(func(operation): return operation.id)
		check(not operation_ids.has("update"), kind + " removes value update")
		check(operation_ids.has("get") and operation_ids.has("get_from_end"),
			kind + " exposes both kth queries")
		check(operations.filter(func(operation): return operation.id == "get")[0].title
			== "查询第 k 个", kind + " names forward kth query")
		check(model.perform("get", {"index": 3}), kind + " queries kth node")
		check(model.frames[-1].active == [ids[2]]
			and model.frames[-1].message.contains("24"),
			kind + " forward kth query returns the visited node")
		check(model.perform("get_from_end", {"index": 2}), kind + " queries kth node from end")
		var fast_steps: Array = model.frames.filter(
			func(frame): return frame.message.begins_with("fast 沿 next 前进第"))
		var tandem_steps: Array = model.frames.filter(
			func(frame): return frame.message == "fast 与 slow 同步沿 next 前进")
		check(fast_steps.size() == 2 and tandem_steps.size() == 2,
			kind + " kth-from-end uses the two-pointer distance")
		check(model.frames[-1].active == [ids[2]]
			and model.frames[-1].message.contains("24"),
			kind + " kth-from-end returns the slow pointer node")
		var values: Array = model.items.map(func(item): return item.value)
		check(not model.perform("update", {"index": 2, "value": 99})
			and model.items.map(func(item): return item.value) == values,
			kind + " rejects hidden value updates")
		check(not model.perform("get_from_end", {"index": 0}), kind + " rejects k = 0")
		check(not model.perform("get", {"index": 5}), kind + " rejects k beyond length")

	var middle := LinearModel.new("linked")
	var original_ids: Array = middle.items.map(func(item): return str(item.id))
	check(middle.perform("reverse_range", {"l": 2, "r": 4}), "reverse linked suffix")
	check(middle.items.map(func(item): return item.value) == [12, 16, 24, 7]
		and middle.invariant().is_empty(), "reverse linked suffix preserves structure")
	var reverse_frames: Array = middle.frames.filter(
		func(frame): return frame.get("reversal", {}).get("phase", "") == "reverse")
	check(reverse_frames.size() == 3, "each reversed node gets one lower-row frame")
	for i in reverse_frames.size():
		var positions := _positions(reverse_frames[i])
		for processed_id in reverse_frames[i].reversal.processed:
			check(positions[str(processed_id)].y == 410,
				"processed reversal node is moved to the lower row")
	var complete_lower: Dictionary = reverse_frames[-1]
	check(_has_edge(complete_lower, original_ids[3], original_ids[2], "next")
		and _has_edge(complete_lower, original_ids[2], original_ids[1], "next"),
		"lower row forms the reversed next chain")
	check(complete_lower.nodes.any(func(node): return node.id == "reverse_pre")
		and _has_edge(complete_lower, "reverse_pre", original_ids[0]),
		"reversal keeps a visible pre pointer")
	var link_pre: Array = middle.frames.filter(
		func(frame): return frame.get("reversal", {}).get("phase", "") == "link_pre")
	check(link_pre.size() == 1
		and _has_edge(link_pre[0], original_ids[0], original_ids[3], "next"),
		"pre.next reconnects to the reversed head")
	var link_after: Array = middle.frames.filter(
		func(frame): return frame.get("reversal", {}).get("phase", "") == "link_after")
	check(link_after.size() == 1
		and _has_edge(link_after[0], original_ids[1], "next_null", "next")
		and _has_edge(link_after[0], "tail_marker", original_ids[1]),
		"reversed suffix reconnects NULL and updates TAIL")
	check(_positions(middle.frames[-1])[original_ids[3]].y == 200,
		"reconnected reversed nodes return to the main row")

	var prefix := LinearModel.new("linked")
	var prefix_ids: Array = prefix.items.map(func(item): return str(item.id))
	check(prefix.perform("reverse_range", {"l": 1, "r": 3}), "reverse linked prefix")
	check(prefix.items.map(func(item): return item.value) == [24, 7, 12, 16]
		and prefix.head == int(prefix_ids[2]), "prefix reversal updates HEAD")
	var prefix_link: Array = prefix.frames.filter(
		func(frame): return frame.get("reversal", {}).get("phase", "") == "link_after")
	check(prefix_link.size() == 1
		and _has_edge(prefix_link[0], prefix_ids[0], prefix_ids[3], "next"),
		"reversed prefix reconnects to its saved successor")
	check(prefix.frames.any(func(frame): return frame.get("reversal", {}).get(
		"phase", "") == "save" and frame.nodes.any(
			func(node): return node.id == "reverse_pre" and node.label == "pre = NULL")),
		"reversal from HEAD records a NULL pre")

	var whole := LinearModel.new("linked")
	check(whole.perform("reverse_range", {"l": 1, "r": 4}), "reverse entire linked list")
	check(whole.items.map(func(item): return item.value) == [16, 24, 7, 12]
		and whole.head == whole.items[0].id and whole.tail == whole.items[-1].id
		and whole.invariant().is_empty(), "whole reversal updates both endpoints")
	var singleton := LinearModel.new("linked")
	var singleton_ids: Array = singleton.items.map(func(item): return item.id)
	check(singleton.perform("reverse_range", {"l": 2, "r": 2}),
		"single-node range reversal")
	check(singleton.items.map(func(item): return item.id) == singleton_ids
		and singleton.invariant().is_empty(), "single-node reversal is structurally neutral")
	check(not singleton.perform("reverse_range", {"l": 3, "r": 2}),
		"reverse rejects i greater than j")

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
	check(model.data.size() == 16 and model.table.size() == 5, "ST uses 16 elements and five levels")
	for l in range(1, 17):
		for r in range(l, 17):
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
		check(bar.size.x == (r - l + 1) * RangeModel.ST_CELL_WIDTH, "bar width matches interval")
		check(bar.pos.x - bar.size.x / 2 == 40 + (l - 1) * RangeModel.ST_CELL_WIDTH,
			"bar starts above left boundary")
		check(bar.pos.x + bar.size.x / 2 == 40 + r * RangeModel.ST_CELL_WIDTH,
			"bar ends above right boundary")
		if not lanes.has(k): lanes[k] = {}
		lanes[k][bar.pos.y] = true
		for other in bars:
			if bar.id == other.id or bar.pos.y != other.pos.y: continue
			check(not Rect2(bar.pos - bar.size / 2 + Vector2.ONE * 0.1, bar.size - Vector2.ONE * 0.2).intersects(
				Rect2(other.pos - other.size / 2, other.size)), "bars in same lane do not overlap")
	check(lanes[0].size() == 1 and lanes[1].size() == 2 and lanes[2].size() == 4 and
		lanes[3].size() == 8 and lanes[4].size() == 1, "ST uses 1/2/4/8/1 staggered lanes")
	check(not model.perform("query", {"l": 0, "r": 16}), "ST rejects zero index")

func _segment_intervals() -> void:
	var model := SegmentModel.new()
	check(model.domain == 16 and model.data.size() == 16, "segment tree uses range [1,16]")
	for node in model.view().nodes:
		check(node.shape == "box", "segment tree uses rectangles")
		if node.has("range"):
			check(node.size.x == (node.range[1] - node.range[0] + 1) *
				SegmentModel.INTERVAL_CELL_WIDTH, "interval width")
			check(node.pos.x - node.size.x / 2 ==
				40 + (node.range[0] - 1) * SegmentModel.INTERVAL_CELL_WIDTH,
				"aligned left boundary")
			check(node.pos.x + node.size.x / 2 ==
				40 + node.range[1] * SegmentModel.INTERVAL_CELL_WIDTH,
				"aligned right boundary")
	check(model.perform("add", {"l": 2, "r": 6, "value": 5}), "range add")
	check(model.data == [3, 6, 9, 6, 10, 14, 2, 6, 5, 3, 5, 8, 9, 7, 9, 3],
		"source array updates exactly once")
	check(model.perform("query", {"l": 2, "r": 6}) and model.result == 45, "range sum after add")
	var final: Dictionary = model.frames.back()
	var pieces: Array = []
	for node in final.nodes:
		if node.has("range") and node.tone == "green": pieces.append(node.range)
	check(pieces == [[2, 2], [3, 4], [5, 6]], "final frame retains exact disjoint cover")
	check(final.nodes.any(func(n): return n.tone == "blue"), "visited ancestors remain blue")
	check(final.annotations.back().text.contains("[2,2] + [3,4] + [5,6]"), "persistent decomposition explanation")
	check(model.perform("add", {"l": 1, "r": 16, "value": -2}), "whole range lazy update")
	check(model.used == [model.root], "new operation clears previous cover")
	var expected := model.data.duplicate()
	check(model.perform("query", {"l": 3, "r": 5}) and model.result == 19, "subset query pushes pending lazy")
	check(model.data == expected and model.invariant().is_empty(), "lazy push preserves source data and sums")
	for kind in ["dynamic_segment", "persistent_segment"]:
		var other := SegmentModel.new(kind)
		check(other.view().nodes.all(func(n): return n.shape == "circle"), "other segment trees retain circles")
		check(not other.view().edges.is_empty(), "other segment trees retain edges")
	var persistent := SegmentModel.new("persistent_segment")
	var persistent_note: String = persistent.operations()[0].note
	check(persistent_note.contains("节点间连线关系与区间为准"), "persistent layout caveat is documented")
	for node in persistent.view().nodes:
		var interval := "[%d,%d]" % [persistent.pool[int(node.id)].l, persistent.pool[int(node.id)].r]
		check(node.detail.is_empty() and node.lines.has(interval),
			"persistent intervals are rendered inside circles")

func _heap_filling() -> void:
	for action in ["build", "sort"]:
		var model := HeapModel.new()
		check(model.perform(action, {"values": "4,-2,4,9,0"}), "heap accepts duplicate and negative input")
		var fill_frames: Array = model.frames.filter(func(f): return f.get("filling", false))
		check(fill_frames.size() == 6, "empty tree plus one frame per inserted element")
		var original_ids := _positions(fill_frames[0]).keys()
		for i in fill_frames.size():
			var frame: Dictionary = fill_frames[i]
			var tree_nodes: Array = frame.nodes.filter(func(n): return n.shape == "circle")
			check(tree_nodes.size() == i, "complete tree grows one node at a time")
			check(tree_nodes.map(func(n): return int(n.label)) == [4, -2, 4, 9, 0].slice(0, i),
				"input order preserved until filling completes")
			check(_positions(frame).keys() == original_ids, "same IDs move from source to tree")
			check(frame.nodes.filter(func(n): return str(n.id).begins_with("array")).size() == 5,
				"entire source array remains visible")
		check(model.invariant().is_empty(), "heap invariant after build or sort")
		if action == "sort":
			check(model.items.map(func(n): return n.value) == [-2, 0, 4, 4, 9], "ascending heap sort")
			check(model.perform("insert", {"value": -5}) and model.invariant().is_empty(), "insert after sort")
			check(model.perform("extract", {}) and model.result == -5 and model.invariant().is_empty(),
				"extract after sort and insert")
			check(model.perform("sort", {}) and model.items.map(func(n): return n.value) == [-2, 0, 4, 4, 9],
				"repeat sort preserves multiset")
		while not model.items.is_empty(): check(model.perform("extract", {}), "extract to empty")
		check(model.perform("sort", {}) and model.items.is_empty(), "sort empty current heap")

func _trie_labels() -> void:
	for kind in ["trie", "trie01", "persistent_trie"]:
		var model := TrieModel.new(kind)
		check(model.perform("insert", {"value": "cat" if kind == "trie" else 5}), "Trie repeated key")
		for node in model.view().nodes:
			var id := int(node.id)
			check(node.detail.is_empty() and node.lines == ["#%d" % id,
				"%d/%d" % [model.pool[id].count, model.pool[id].end]], "node contains only index and counts")
		for link in model.view().edges:
			check(link.label.length() == 1, "edge contains a single character")
		check(model.invariant().is_empty(), "Trie counts preserved")
		if kind == "persistent_trie":
			check(model.view().annotations.size() == 2, "version labels remain outside roots")

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
