extends Resource
class_name EnemyDropEntry
## 单条死亡掉落：**`pickup_scene`** 实例化后挂战场；**`drop_probability`** 为 **[0,1]** 独立掷骰一次，命中则生成一条


## 拾取物预制（根节点一般为 **`BattlePickup`**，由 **`PickupCollector`** 驱动收集）
@export var pickup_scene: PackedScene
## 掉落概率；**`1.0`** 为必掉，**`0.1`** 为 10% 独立一次
@export_range(0.0, 1.0, 0.001) var drop_probability: float = 1.0
