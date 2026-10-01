extends RefCounted
## Explanations belong to the operation contract, so every selector uses the same text.

static func describe(kind: String, action: String) -> String:
	var notes := {}
	match kind:
		"array", "dynamic_array", "linked", "doubly":
			var linked := kind in ["linked", "doubly"]
			notes = {
				"insert": "在指定位置之前插入。位置 1 是头插，n+1 是尾插。" +
					("先连接新节点与后继，再重接前驱；头插更新 HEAD。" if linked else "从末尾向前，将后续元素逐个右移，再写入新值。"),
				"delete": "删除指定位置的元素；" + ("重接前驱与后继，并更新 HEAD / TAIL。" if linked else "后续元素左移以填补空位。"),
				"update": ("沿 next 走到指定节点" if linked else "按下标定位元素") + "，将原值替换为新值，长度不变。",
				"get": ("从 HEAD 沿 next 访问第 i 个节点，返回数值，耗时 O(n)。" if linked else "直接读取第 i 个位置的值，耗时 O(1)。"),
				"find": "从位置 1 开始逐个比较，返回第一个匹配值的位置；找不到则给出提示。",
				"push": "把新值追加到末尾。容量不足时旧数组上移，下方申请两倍内存，逐个向下复制，最后释放旧内存。追加均摊 O(1)。",
				"build": "清空当前结构，按输入顺序加入各元素。" + ("同时建立 next / prev 连接。" if linked else "静态数组最多 8 项；动态数组容量不足时倍增。")
			}
			if kind == "dynamic_array":
				notes.insert = "容量不足时先申请两倍内存，向下逐个复制并释放旧内存；再将插入点后的元素逐个右移，写入新值。位置 1 是头插，n+1 是尾插。"
				notes.build = "清空数组并按输入顺序加入元素；容量不足时，旧数组上移，下方申请两倍内存，逐个复制完成后释放旧内存。"
		"stack", "queue":
			var stack := kind == "stack"
			notes = {
				"push": "将新值放入栈顶 TOP，后加入的元素先弹出。" if stack else "将新值加入队尾 TAIL，先加入的元素先出队。",
				"pop": "移除并展示栈顶元素，更新 TOP。" if stack else "移除并展示队首元素，更新 HEAD。",
				"peek": "读取栈顶 TOP 的值，不改变栈。" if stack else "读取队首 HEAD 的值，不改变队列。",
				"build": "按输入顺序依次入栈；最后一个值位于栈顶。" if stack else "按输入顺序依次入队；第一个值位于队首。"
			}
		"mono_stack", "mono_queue":
			var logic := "弹出栈顶所有 ≤ 当前值的下标；余下栈顶即左侧最近严格更大值的下标，空栈则无，最后压入当前下标。" if kind == "mono_stack" else "移除过期队首，弹出值更小的队尾，再加入当前下标；完整窗口的最大值下标在队首，相等时取最左。"
			notes = {
				"step": "处理原数组的下一个元素。" + logic,
				"run": "继续扫描剩余数组，为每个元素／完整窗口计算答案。" + logic,
				"reset": "保留原数组与窗口长度，清空候选下标和答案，从下标 1 重新演示。",
				"build": "设置 1–16 个整数并清空进度。" + ("可设置窗口长度 1–n。默认用约 10 个值演示。" if kind == "mono_queue" else "默认用约 10 个值演示；相等值不算严格更大。")
			}
		"hash_linear", "hash_quadratic", "hash_chain":
			var route := "按偏移 0,1,2,… 依次探测" if kind == "hash_linear" else ("按平方偏移 0,1,4,9,… 探测" if kind == "hash_quadratic" else "沿对应桶的链表访问")
			notes = {
				"insert": "计算 0–10 范围的哈希桶；" + route + "，在可用位置插入互异键。",
				"find": route + "并比较键。" + ("链尾仍未匹配则不存在。" if kind == "hash_chain" else "遇空槽可停止；遇 DEL 必须继续。"),
				"delete": route + "定位键；" + ("断开链表中的目标节点。" if kind == "hash_chain" else "将槽标为 DEL，以免中断其他键的探测路径。"),
				"clear": "删除所有键、冲突链与 DEL 标记，恢复空表。"
			}
		"fenwick", "fenwick2":
			notes = {
				"add": "给原数组单点增加 Δ，沿 i += lowbit(i) 更新包含该点的区间。" if kind == "fenwick" else "给矩阵单点增加 Δ；行、列各自沿 lowbit 向上跳转，更新所有覆盖块。",
				"query": "沿 i -= lowbit(i) 累加前缀和，再用 prefix(r)−prefix(l−1) 求闭区间和。" if kind == "fenwick" else "分别计算四个二维前缀和，按容斥求出含两端点的矩形和。",
				"build": "设置 8 个整数，清空树状数组，再逐个加入各元素的贡献。"
			}
		"sparse_table":
			notes = {
				"build": "第 0 层保存单个值；第 k 层合并两个长度 2^(k−1) 的区间。长条覆盖原数组，下标从 1 起，各层长度依次为 1、2、4、8、16。",
				"query": "取 k=floor(log2(r−l+1))，读取从 l 开始、在 r 结束的两段长度 2^k 的最小值，再取 min；两段可以重叠。"
			}
		"segment", "dynamic_segment", "persistent_segment":
			notes = {
				"add": "完全覆盖时更新 sum 与 lazy；部分覆盖时下传标记、递归更新，再合并子区间和。",
				"query": "查询闭区间 [l,r]：完全覆盖直接返回区间和；部分覆盖继续访问子区间并合并。",
				"version": "切换到指定历史根（首个版本为 V1）；共享节点保持不变，可从该版本继续分支。"
			}
			if kind == "dynamic_segment": notes.add = "在范围 [1,32] 内给单点增加 Δ，只沿根到叶的路径按需创建节点，再回溯更新区间和。"
			if kind == "persistent_segment":
				notes.add = "从当前版本复制根到目标叶子的路径，给单点增加 Δ；其他子树共享，旧版本保持不变。为优化排版，显示的左右子节点相对位置不一定正确，请以节点间连线关系与区间为准。"
			if kind == "segment":
				notes.add += "浅蓝保留访问路径，绿色标记直接更新区间；结束后保留与原数组对应的区间拆分。"
				notes.query += "绿色区间直接贡献答案，浅蓝记录递归访问；结束后仍可查看区间拆分与原数组对应关系。"
		"segment2":
			notes = {
				"add": "定位目标行与列；更新原矩阵单点，并更新行树沿途每个节点对应的列树。",
				"query": "先用行树拆分查询行区间，再在各覆盖节点的列树查询列区间，累加各矩形块的和。",
				"inspect": "选择左侧行树节点，右侧展开它的列树；列树保存该行区间内各列区间的总和。"
			}
		"binary_heap":
			notes = {
				"build": "从空树开始，按数组下标逐个填入完全二叉树；全部放入后，从最后一个非叶节点开始下沉，建立最小堆。",
				"insert": "新值放到末尾，反复与父节点比较；更小时交换并上浮，直到满足最小堆序。",
				"extract": "取走最小值，用末尾元素补到根，选择较小的子节点逐层下沉。",
				"sort": "输入数组逐个填入空树，再调整为大顶堆；反复交换堆顶与未排序末尾、缩小堆并下沉，得到升序数组。之后可继续最小堆操作。"
			}
		"binomial", "fibonacci":
			var fib := kind == "fibonacci"
			notes = {
				"insert": "新节点加入根链表并更新最小值；暂不合并同度树。" if fib else "加入一棵零度树，反复合并同度树，将较大根挂到较小根下。",
				"extract": "移除最小根，将其孩子提升为根；按度数合并同度树，重新寻找最小根。",
				"decrease": "减小指定节点的值；破坏堆序时切到根链表，父节点已标记则继续级联切断。" if fib else "减小指定节点的值，若小于父节点则交换键并向上调整，恢复堆序。",
				"delete": "先把目标键降到全堆最小值以下，再执行提取最小值。",
				"merge": "把另一堆的根链表接入当前堆，只更新最小值，合并推迟到提取时。" if fib else "合并两堆的根集合，再按度链接同度树，如二进制进位。"
			}
		"trie", "trie01", "persistent_trie":
			notes = {
				"insert": "逐字符／从高到低逐位沿边，缺失时创建分支；增加沿途计数与终止计数。",
				"delete": "删除一次出现：沿路径减少计数，回溯移除计数为零的分支，保留仍被其他键使用的节点。",
				"find": "按字符走到单词末尾，返回终止计数；路径缺失时词频为 0。",
				"prefix": "沿前缀走到对应节点，返回经过计数，即包含该前缀的单词总次数。",
				"xor": "从最高位到最低位，优先走相反位以获得异或位 1；否则走同位，返回最大异或值与匹配的键。",
				"version": "切换到指定历史根（首个版本 V1），之后的查询与插入基于该版本；旧版本保持不变。"
			}
			if kind == "persistent_trie": notes.insert = "从当前版本复制插入路径、更新计数，未经过的分支共享；保存新版本根，旧版本不变。"
		"avl", "treap", "splay", "red_black":
			var repair: String = {
				"avl": "回溯更新高度，失衡时执行单旋或双旋。",
				"treap": "通过旋转维持随机优先级的最小堆序。",
				"splay": "用 Zig、Zig-Zig 或 Zig-Zag 将访问节点伸展到根。",
				"red_black": "通过染色与旋转恢复红黑约束和各路径黑高。"
			}[kind]
			notes = {
				"insert": "沿 BST 键序寻找空位，插入互异键。" + repair,
				"delete": "定位并删除键，重接剩余子树。" + repair,
				"find": "从根逐个比较，向左或向右寻找目标键。" + ("找到后伸展到根；未找到则伸展最后访问节点。" if kind == "splay" else "返回是否找到，不改变键集合。"),
				"build": "清空当前树，按输入顺序逐个插入互异键。" + repair
			}
			if kind == "splay": notes.delete = "把目标伸展到根并移除；将左子树最大节点伸展为新根，再接上右子树。"
		"lct":
			notes = {
				"link": "将 u 换根后，若 u、v 不连通则建立路径父亲连接；已连通时拒绝，避免形成环。",
				"cut": "将 u 换根并暴露 u 到 v 的路径，确认两点之间存在直接边后断开。",
				"query": "将 u 换根、access(v) 并伸展 v；辅助树中的聚合值就是 u 到 v 的路径和。",
				"set": "access 并伸展指定节点，替换其权值，再更新辅助树聚合值。",
				"access": "沿路径父亲向上访问，逐次替换右孩子，使当前根到目标节点的路径成为首选路径。",
				"makeroot": "先 access 并伸展节点，再翻转首选路径的左右方向，将该节点设为表示树的根。",
				"add": "创建一个带给定权值的孤立节点；之后可用连接操作加入森林。"
			}
	return notes.get(action, "")
