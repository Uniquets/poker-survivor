extends Resource
class_name ShapeEffectSpec
## 牌型表 **效果规格** 基类：**`PlayShapeEntry.effect_spec`** 指向本类子资源时，由 **`PlayShapeEffectAssembler`** 转为 **`PlayEffectCommand`**。
##
## **子类**：一种 **`PlayEffectCommand`** 工厂语义对应一个 **`Resource`** 脚本，便于检查器只显示本类型相关字段（方案 A · 做法 1）。
