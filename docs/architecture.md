# 数据结构实验室：实现约定

## 技术与范围

- Godot 4.7.2，Compatibility 渲染，GDScript，单线程 Web 导出。
- 全部计算在客户端执行；GitHub Pages 与本地 HTTP 服务均不需要后端。
- 原始需求见 `plan.md`。其中 ACL 按 AVL 实现；动态树选 Link-Cut Tree。
- 教育用小数据集，各结构明确限制容量、索引范围和操作语义。
- 米黄底 `#fdf6e3`、黑色字与连线；临时访问高亮浅蓝色。
- 中文字体为 Noto Sans SC 的静态 400 字重实例；许可证 `assets/OFL.txt`。

## 模型与快照

`scripts/core/model.gd` 中的 `LabModel` 继承 `RefCounted`，不引用场景节点。

- `operations()` 返回操作与字段定义；字段含 key、title、initial、text。
- `perform(action, args)` 验证参数，执行算法；失败返回 false 并设置 error。
- `begin()` 清空轨迹、记录操作前状态。
- `record(message, active_ids, code_line)` 深复制 `view()`，记录算法行号和调用栈。
- `view()` 返回 nodes、edges、stats；节点含稳定 id、label、pos、detail、shape、tone。
- `invariant()` 返回空字符串表示成立，否则返回错误说明。
- 算法每次改变逻辑关系后显式记录关键步骤，保证访问、比较、旋转、下传与回溯可见。
- `recording=false` 用于快速差分验证，不能影响算法结果。

快照只含值类型、数组和字典，不持有可变对象引用。算法可以先算完；画面由快照逐步追赶。图中的瞬时位置不参与算法计算。

## 播放与交互

`scripts/main.gd` 负责结构目录、动态参数表、严格整数验证、模型校验、操作级撤销和轨迹播放。

`scripts/ui/canvas.gd` 按稳定 ID 在快照间插值位置、淡入淡出节点与连边；支持缩放、平移、适应视图和节点选择。读取动画帧独立于模型当前状态。

- 播放过程中或停在历史步骤时，修改操作禁用；跳到末尾后可继续修改。
- 单步、进度条和回放只改变视觉游标；撤销恢复操作前模型。
- 无效输入显示具体错误，不静默失败。
- 模型操作失败或不变量失败时，界面恢复执行前保存的状态。
- 每个模块提供默认示例；恢复默认会清除历史。
- 递归调用栈是算法主动记录的教学轨迹，并非引擎调试堆栈。
- 暂停同时冻结 Tween；红黑树的节点颜色在访问时保持，用蓝色外圈高亮。
- 执行操作后适应整条轨迹的范围，避免新增节点落在画布之外。
- 点击支持数组位置、区间节点、矩形两角、堆节点编号与 LCT 两个端点；区间增量不会被聚合值覆盖。

## 算法实现

- 线性表：数组移动、倍增容量；链表保存稳定编号和真实 next/prev；单调队列维护长度 3 的窗口。
- 哈希：11 槽位，开放寻址含删除标记；二次探测明确拒绝探测序列已满的插入。
- 区间结构：一维/二维 Fenwick、静态 RMQ、lazy 下传、动态开点、二维行树与列树、路径复制版本。
- 二叉堆与原地堆排序：上浮/下沉；二项堆按度链接；斐波那契堆延迟合并、mark 与级联切断。
- Trie：经过与终止频次；8 位最大异或；可持久化 Trie 允许从任意已有版本继续分支。
- AVL：高度和单双旋；Treap：固定种子最小优先级堆；Splay：Zig/Zig-Zig/Zig-Zag。
- 红黑树：插入修复与完整删除修复，NIL 隐式为黑色；校验红红相邻与黑高。
- LCT：辅助 Splay、路径父亲、access、makeroot、rev 下传、link/cut 和路径求和。实际森林用无向边，辅助树用实线孩子与虚线路径父亲。
- 所有可变状态均是值类型、数组、字典；Treap 的 RNG 状态也是整数，保证撤销后可复现。

## 验证

`tests/test_models.gd` 是无额外插件的 GDScript headless runner：

1. 各目录模块的默认状态、默认操作及轨迹完整性。
2. 每帧 ID 唯一、坐标有效、连边端点存在。
3. 固定种子随机操作，对照数组、集合或暴力求和。
4. 各模型的结构不变量；可持久化结构旧版本保持不变。

运行：

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/test_models.gd
godot --headless --path . --script tests/test_advanced.gd
godot --headless --path . --script tests/test_interactions.gd
```

高级测试用数组多重集/有序集合/逐元素异或/独立 BFS 对照，不以被测模型的查询结果作为参考答案。覆盖随机交错操作、单调序列插删、空结构、重复键、跨版本分支与 LCT 翻转后聚合。场景测试覆盖全部默认操作的输入表单、播放、撤销以及错误回滚。

隔离环境可复制 Godot 可执行文件到 `.tools/godot`，并在同目录创建 `_sc_` 以保存编辑器配置。`--log-file` 必须传入项目内的**绝对路径**，防止编辑器将相对日志路径解释为 `user://`。

## 版本策略

使用本仓库 Git 配置的 PPMark0712 / 939051420@qq.com。每个通过验证的功能阶段独立提交，不自动推送到远端。`.godot`、`.tools`、导出产物与测试截图不提交。
