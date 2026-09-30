extends SceneTree
## Differential checks use simple arrays/sets/BFS, independent of the algorithms.
var checks := 0
var failures := 0
var rng := RandomNumberGenerator.new()

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	rng.seed = 20261001
	_heaps()
	_trees()
	_tries()
	_lct()
	print("Advanced differential tests: %d checks; %d failures." % [checks, failures])
	quit(0 if failures == 0 else 1)

func _heaps() -> void:
	for kind in ["binary_heap", "binomial", "fibonacci"]:
		var model: LabModel = load("res://scripts/models/%s.gd" % ("heaps" if kind == "binary_heap" else "forest_heaps")).new(kind)
		model.recording = false
		var reference: Array = []
		if kind == "binary_heap":
			for item in model.items: reference.append(item.value)
		else:
			for id in model.pool: reference.append(model.pool[id].value)
		for round in 1200:
			var choice := rng.randi_range(0, 4)
			if reference.is_empty() or (choice == 0 and reference.size() < 15):
				var value := rng.randi_range(-50, 50)
				check(model.perform("insert", {"value": value}), kind + " insert")
				reference.append(value)
			elif choice == 1 or kind == "binary_heap":
				reference.sort()
				var expected: int = reference.pop_front()
				check(model.perform("extract", {}), kind + " extract")
				check(model.result == expected, kind + " minimum")
			elif choice == 2 and reference.size() <= 12:
				check(model.perform("merge", {"values": "6,-2,6"}), kind + " union")
				reference.append_array([6, -2, 6])
			else:
				var ids: Array = model.pool.keys()
				var id: int = ids[rng.randi_range(0, ids.size() - 1)]
				var old: int = model.pool[id].value
				reference.erase(old)
				if choice == 3:
					var value := old - rng.randi_range(0, 20)
					check(model.perform("decrease", {"id": id, "value": value}), kind + " decrease")
					reference.append(value)
				else:
					check(model.perform("delete", {"id": id}), kind + " delete")
			check(model.invariant().is_empty(), kind + ": " + model.invariant())
			var actual: Array = []
			if kind == "binary_heap":
				for item in model.items: actual.append(item.value)
			else:
				for id in model.pool: actual.append(model.pool[id].value)
			actual.sort()
			reference.sort()
			check(actual == reference, kind + " multiset preserved")
	for round in 80:
		var model := HeapModel.new("heap_sort")
		model.recording = false
		var values: Array = []
		for i in rng.randi_range(0, 15): values.append(rng.randi_range(-20, 20))
		var text := ",".join(values.map(func(x): return str(x)))
		check(model.perform("build", {"values": text}), "heap sort build")
		check(model.perform("sort", {}), "heap sort execute")
		var actual: Array = []
		for item in model.items: actual.append(item.value)
		values.sort()
		check(actual == values, "heap sort differential")
		check(model.invariant().is_empty(), "heap sort invariant")

func _trees() -> void:
	for kind in ["avl", "treap", "splay", "red_black"]:
		var model: LabModel = load("res://scripts/models/%s.gd" % ("red_black" if kind == "red_black" else "balanced")).new(kind)
		model.recording = false
		var reference: Array = model.keys()
		for round in 2500:
			var key := rng.randi_range(-25, 25)
			var action := rng.randi_range(0, 2)
			if action == 0 and not reference.has(key) and reference.size() < 15:
				check(model.perform("insert", {"value": key}), kind + " insert")
				reference.append(key)
			elif action == 1 and not reference.is_empty():
				key = reference[rng.randi_range(0, reference.size() - 1)]
				check(model.perform("delete", {"value": key}), kind + " delete")
				reference.erase(key)
			else:
				check(model.perform("find", {"value": key}), kind + " find")
				check(model.found == reference.has(key), kind + " membership")
				if kind == "splay" and model.found:
					check(model.pool[model.root].key == key, "splay access reaches root")
			reference.sort()
			check(model.keys() == reference, kind + " ordered set")
			check(model.invariant().is_empty(), kind + ": " + model.invariant())
		# Ascending and descending insertion/deletion stress rotations and NIL repair.
		for descending in [false, true]:
			model.perform("build", {"values": ""})
			var sequence: Array = range(15)
			if descending: sequence.reverse()
			for value in sequence:
				check(model.perform("insert", {"value": value}), kind + " monotonic insert")
				check(model.invariant().is_empty(), kind + " monotonic invariant")
			for value in sequence:
				check(model.perform("delete", {"value": value}), kind + " monotonic delete")
				check(model.invariant().is_empty(), kind + " deletion invariant")
			check(model.pool.is_empty() and model.root == 0, kind + " deletes all")

func _tries() -> void:
	for kind in ["trie", "trie01"]:
		var model := TrieModel.new(kind)
		model.recording = false
		var reference := model.values.duplicate()
		for round in 400:
			var value: Variant = ["a", "ab", "abc", "b", "bc", "cat", "car"][rng.randi_range(0, 6)] if kind == "trie" else rng.randi_range(0, 255)
			if reference.is_empty() or (rng.randf() < 0.5 and reference.size() < 16):
				check(model.perform("insert", {"value": value}), kind + " insert")
				reference.append(value)
			else:
				value = reference[rng.randi_range(0, reference.size() - 1)]
				check(model.perform("delete", {"value": value}), kind + " delete")
				reference.erase(value)
			check(model.invariant().is_empty(), kind + ": " + model.invariant())
			if kind == "trie":
				for prefix in ["a", "ab", "b", "c", "cat"]:
					var expected := 0
					for word in reference:
						if word.begins_with(prefix): expected += 1
					model.perform("prefix", {"value": prefix})
					check(model.result == expected, "trie prefix frequency")
					model.perform("find", {"value": prefix})
					check(model.result == reference.count(prefix), "trie exact frequency")
			elif not reference.is_empty():
				var query := rng.randi_range(0, 255)
				model.perform("xor", {"value": query})
				var expected := -1
				for item in reference: expected = maxi(expected, item ^ query)
				check(model.result == expected and reference.has(model.matched), "01 trie max xor")
	var model := TrieModel.new("persistent_trie")
	model.recording = false
	var histories: Array = [model.values.duplicate()]
	for version in range(1, 6):
		var base := rng.randi_range(0, version - 1)
		model.perform("version", {"version": base})
		var value := rng.randi_range(0, 255)
		check(model.perform("insert", {"value": value}), "persistent insert")
		histories.append(histories[base] + [value])
		check(model.invariant().is_empty(), "persistent trie invariant")
	for version in histories.size():
		model.perform("version", {"version": version})
		for query in 256:
			model.perform("xor", {"value": query})
			var expected := -1
			for value in histories[version]: expected = maxi(expected, value ^ query)
			check(model.result == expected, "persistent trie historical query")

func _bfs(adj: Dictionary, u: int, v: int, weights: Dictionary) -> Variant:
	var pending: Array = [[u, weights[u]]]
	var seen := {u: true}
	while not pending.is_empty():
		var item: Array = pending.pop_front()
		if item[0] == v: return item[1]
		for next in adj[item[0]]:
			if seen.has(next): continue
			seen[next] = true
			pending.append([next, item[1] + weights[next]])
	return null

func _lct() -> void:
	var model := LinkCutModel.new()
	model.recording = false
	var adj := {}
	var weights := {}
	for id in model.pool:
		adj[id] = []
		weights[id] = model.pool[id].value
	for pair in [[1, 2], [2, 3], [4, 5], [5, 6]]:
		adj[pair[0]].append(pair[1])
		adj[pair[1]].append(pair[0])
	for round in 2000:
		var u := rng.randi_range(1, 6)
		var v := rng.randi_range(1, 6)
		var expected: Variant = _bfs(adj, u, v, weights)
		var action := rng.randi_range(0, 5)
		if action == 0 and expected == null:
			check(model.perform("link", {"u": u, "v": v}), "LCT link")
			adj[u].append(v)
			adj[v].append(u)
		elif action == 1 and adj[u].has(v):
			check(model.perform("cut", {"u": u, "v": v}), "LCT cut")
			adj[u].erase(v)
			adj[v].erase(u)
		elif action == 2:
			var value := rng.randi_range(-30, 30)
			check(model.perform("set", {"id": u, "value": value}), "LCT set")
			weights[u] = value
		elif action == 3:
			check(model.perform("makeroot", {"id": u}), "LCT makeroot")
		elif action == 4:
			check(model.perform("access", {"id": u}), "LCT access")
		else:
			check(model.perform("query", {"u": u, "v": v}) == (expected != null), "LCT query reachability")
			if expected != null: check(model.result == expected, "LCT sum vs independent BFS")
		check(model.invariant().is_empty(), "LCT: " + model.invariant())
		# Every operation is followed by a path query, exercising lazy propagation.
		u = rng.randi_range(1, 6)
		v = rng.randi_range(1, 6)
		expected = _bfs(adj, u, v, weights)
		if expected != null:
			check(model.perform("query", {"u": u, "v": v}), "LCT connected query")
			check(model.result == expected, "LCT post-operation path sum")
			check(model.invariant().is_empty(), "LCT post-query invariant")
