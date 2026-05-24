# my_Balatro 项目指南

> 本项目是一个使用 Godot 4.6 开发的 Balatro 克隆版卡牌游戏。本文档面向 AI 编码助手，帮助快速理解项目结构、技术栈与开发规范。

---

## 项目概述

- **引擎**: Godot 4.6（Mobile 渲染后端，Windows 使用 D3D12，物理引擎 Jolt）
- **语言**: GDScript
- **类型**: 2D 卡牌 Roguelike（Balatro 克隆）
- **分辨率**: 1280×720
- **主要语言**: 中文（UI 文本、注释、部分文件名使用中文）

项目通过 5 个 AutoLoad 单例管理器驱动游戏状态，包含完整的扑克牌型判定、计分系统、小丑牌被动效果、蜡封/增强系统，以及卡牌拖拽排序功能。

---

## 目录结构

```
├── project.godot              # Godot 项目主配置（5 个 AutoLoad）
├── Manager/                   # AutoLoad 单例管理器
│   ├── DeckManager.gd         # 牌堆初始化、抽牌、洗牌
│   ├── HandManager.gd         # 手牌管理（选牌、出牌、弃牌、补牌、拖拽排序）
│   ├── ScoreManager.gd        # 计分系统、牌型判定、等级成长、回合结算
│   ├── MoneyManager.gd        # 金钱系统
│   └── JokerManager.gd        # 小丑牌管理（持有、触发、拖拽换位）
├── card/                      # 卡牌相关
│   ├── Playingcard.gd         # 单张卡牌的自定义 Control 类（含蜡封/增强纹理）
│   └── Poker_card.tscn        # 卡牌场景（含浮动 Shader）
├── joker/                     # 小丑牌相关
│   ├── JokerCard.gd           # 小丑牌基类（id 驱动效果，含拖拽逻辑）
│   └── Joker_card.tscn        # 小丑牌场景
├── scence/                    # 主场景（注意：目录名拼写为 scence）
│   ├── main.tscn              # 游戏主场景
│   ├── main.gd                # 主场景脚本（UI 绑定、信号连接、游戏结束流程）
│   ├── main_menu.tscn         # 主菜单场景
│   ├── main_menu.gd           # 主菜单脚本（按钮事件）
│   ├── background.tscn        # 动态背景场景
│   ├── background.gd          # 背景着色器参数驱动
│   ├── GameOver.tscn          # 游戏结束界面
│   ├── game_over.gd           # 结算统计展示
│   └── levelchose.tscn        # 关卡选择场景（WIP）
├── resources/                 # 资源文件
│   ├── fonts/                 # 多语言字体（Noto Sans CJK 系列 + 像素字体）
│   ├── shaders/               # 视觉特效（cardfloat.gdshader + 大量 .fs 片段着色器）
│   ├── myshader/              # 自定义着色器（Background.gdshader — 漩涡颜料背景）
│   ├── sounds/                # 音效（出牌、硬币、UI 等 .ogg 文件）
│   ├── textures/              # 贴图精灵表（1x / 2x，含 8BitDeck.png、Enhancers.png、Jokers.png）
│   └── gamecontrollerdb.txt   # 手柄数据库
├── Balatro OST/               # BGM 音乐文件（5 首 .mp3 + Cover.jpg）
├── joker.gd                   # 空桩脚本（extends Control，未使用）
└── .godot/                    # Godot 编辑器缓存（已加入 .gitignore）
```

---

## 技术栈与架构

### AutoLoad 单例（project.godot 注册）

| 名称 | 路径 | 职责 |
|------|------|------|
| `DeckManager` | UID 引用 | 牌堆初始化、抽牌、洗牌、测试牌堆 |
| `HandManager` | UID 引用 | 手牌区管理、出牌/弃牌流程、拖拽排序 |
| `ScoreManager` | UID 引用 | 牌型判定、等级系统、计分、回合结算 |
| `MoneyManager` | `res://Manager/MoneyManager.gd` | 金钱增减 |
| `JokerManager` | `res://Manager/JokerManager.gd` | 小丑牌持有/触发/拖拽 |

### 核心设计模式
- **AutoLoad 单例**: 5 个管理器作为全局单例，通过 `project.godot` 的 `[autoload]` 节注册。
- **信号驱动**: 管理器之间通过 `signal` 解耦。例如 `ScoreManager.score_changed` → `main.gd` 更新分数标签；`ScoreManager.round_cleared` → `main.gd` 触发游戏结束。
- **状态机**: `PlayingCard` 使用 `CardState` 枚举管理 6 种状态（NORMAL / HOVER / SELECTED / DRAGGING / PLAYED / DISCARDED）。
- **Panel 卡槽布局**: 手牌区和小丑区使用 `HBoxContainer` + `Panel` 卡槽模式，每张卡/小丑放入一个透明 Panel 中，再添加到容器。手动排列时通过 Panel 的 index 控制顺序。

### 关键数据流

1. **初始化**: `DeckManager` 创建 52 张标准扑克牌（测试模式下附加 15% 概率的随机蜡封/增强）并洗牌。
2. **发牌**: `main.gd` → `HandManager.draw_eight_cards(desk)` → 连续抽取 8 张，每张包装为 Panel+卡牌实例。
3. **出牌流程**:
   - 玩家选中卡牌（点击切换 SELECTED/NORMAL）
   - 点击"出牌"按钮 → `HandManager.play_selected_cards()`
   - JokerManager 依次触发 INDEPENDENT → ON_HAND_PLAYED → ON_CARD_SCORED
   - 计分牌执行 `score_jump()` 跳跃动画
   - 蜡封（金色加钱、红色重计分）和增强（奖励牌 +30 筹码、倍率牌 +4 倍率）逐张生效
   - `ScoreManager.recalculate()` → `chips × mult` 计入总分
   - 销毁已打出卡牌，补牌，重置临时筹码
   - 检查通关/失败条件
4. **弃牌流程**: 类似出牌但跳过计分，触发 ON_DISCARD 小丑效果后销毁并补牌。
5. **回合结算**: `ScoreManager.check_round_end()` 判定 `game_total_score >= target_score`，发出 `round_cleared` 信号 → `main.gd` 收集统计数据 → 实例化 `GameOver.tscn`。
6. **拖拽排序**: 卡牌/小丑拖入另一个 Panel 卡槽时，`try_drop_card()` / `try_drop_joker()` 将 source Panel 移动到 target Panel 的 HBoxContainer 索引位置，所有卡牌动画平滑滑入新位置。

### 牌型与计分规则

- 支持 12 种牌型（按 Balatro 标准数值）：High Card、Pair、Two Pair、Three of a Kind、Straight、Flush、Full House、Four of a Kind、Straight Flush、Five of a Kind、Flush House、Flush Five。
- 每种牌型有基础筹码/倍率和每次升级的成长值（`ScoreManager.HAND_DATA`）。
- 牌型支持等级成长：`level_up_hand()` 增加等级，`get_hand_score()` 根据等级计算最终筹码/倍率。
- 计分仅对"参与计分的牌"生效（`get_scoring_cards()` 根据牌型筛选）。
- 顺子判定支持 A 当 1 或 14 两种场景。

### 蜡封与增强系统

**蜡封**（`seal` 字段，存储在 `card_data`，作用于出牌流程）:
- `金色蜡封`: 计分时 +2 金币
- `红色蜡封`: 该牌再次计分（chips 即时 flush 后重复一次 score_jump + add_chips）
- `紫色蜡封` / `蓝色蜡封`: 贴图已配置，逻辑待实现

**增强**（`enhancement` 字段，存储在 `card_data`，作用于出牌流程）:
- `奖励牌`: +30 筹码
- `倍率牌`: +4 倍率
- `石头牌` / `黄金牌` / `万能牌` / `玻璃牌` / `幸运牌` / `钢铁牌`: 贴图已配置，逻辑待实现

### 小丑牌系统

- `JokerCard` 是 id 驱动的基类，所有效果通过 `_setup_by_id(id)` 配置，`on_trigger()` 根据 id 和 `TriggerType` 执行。
- 触发时机枚举：`INDEPENDENT`（持续）、`ON_HAND_PLAYED`（出牌时）、`ON_CARD_SCORED`（单张计分时）、`ON_DISCARD`（弃牌时）、`ON_ROUND_END`、`ON_BLIND_SELECTED`。
- `JokerManager.trigger_all()` 遍历所有持有小丑，汇总效果并应用到 ScoreManager/MoneyManager。
- 当前已实现 10 张小丑牌（id 0-9），id 10-159 为 `_` 默认（未知小丑）。
- 小丑牌上限 5 张（`MAX_JOKERS`），超出 `push_warning`。
- 主场景有"生成小丑"测试按钮（`main.gd`），随机生成 id 0-9 的小丑牌。
- 小丑牌支持拖拽换位（`try_drop_joker()`），与卡牌拖拽逻辑一致。

### 卡牌渲染

- 使用 `AtlasTexture` 从精灵表中裁切：
  - **卡牌正面**: `resources/textures/2x/8BitDeck.png`（每行 14 列，每张 142×190 像素）
  - **蜡封/增强贴纸**: `resources/textures/2x/Enhancers.png`
  - **小丑牌**: `resources/textures/2x/Jokers.png`
- 花色行顺序：Heart(0) → Club(1) → Diamond(2) → Spade(3)
- 卡牌场景挂载 `cardfloat.gdshader`，实现呼吸缩放与轻微晃动效果。
- 背景使用 `resources/myshader/Background.gdshader`，由 `background.gd` 驱动 `time` / `spin_time` 参数实现动态漩涡颜料效果。

---

## 开发规范

### 命名风格
- **类名**: PascalCase（如 `PlayingCard`、`ScoreManager`、`JokerCard`）
- **函数/变量**: snake_case（如 `draw_cards()`, `current_chips`）
- **常量**: 全大写 snake_case（如 `CARD_WIDTH`, `SELECTED_OFFSET`）
- **信号**: snake_case，描述事件（如 `cards_played`, `round_cleared`）
- **中文使用**: UI 节点名、注释、部分文件名使用中文；GDScript 标识符保持英文。

### 代码注释习惯
- 关键函数顶部使用三引号 `"""描述"""` 风格的注释。
- 状态切换、牌型判定等逻辑旁有中文行注释。
- 部分旧代码残留英文注释或空 `pass` 桩。

### 场景与脚本组织
- `.tscn` 场景文件与驱动脚本同目录或就近放置。
- `project.godot` 中 `DeckManager`、`HandManager`、`ScoreManager` 使用 UID 引用，`MoneyManager`、`JokerManager` 使用 `res://` 路径引用。

---

## 构建与运行

### 环境要求
- Godot 4.6+（推荐官方稳定版）
- 无需额外编译步骤；GDScript 为解释执行。

### 运行方式
1. 在 Godot 编辑器中打开项目根目录。
2. 直接按 F5 或点击"运行项目"按钮即可启动。
3. 主场景为 `scence/main.tscn`（`run/main_scene` 在 `project.godot` 中通过 UID 指定）。

### 导出与部署
- 项目当前没有配置 CI/CD 或自动导出脚本。
- 导出需通过 Godot 编辑器的"项目 > 导出"菜单手动配置导出模板。
- Android 导出目录 `android/` 已加入 `.gitignore`。

---

## 测试说明

- 本项目**没有配置单元测试框架**（如 GUT）。
- 核心逻辑（牌型判定、计分）目前通过运行时 `print()` 输出到编辑器控制台进行人工验证。
- 如需添加自动化测试，推荐引入 [GUT (Godot Unit Test)](https://github.com/bitwes/Gut) 插件，并对以下模块优先覆盖：
  - `ScoreManager.evaluate_hand()` 的各种边界情况
  - `ScoreManager.get_scoring_cards()` 的计分牌筛选
  - `JokerCard.on_trigger()` 各 id 的效果正确性
  - `PlayingCard._calculate_value()` 与花色映射

---

## 已知问题与注意事项

1. **目录拼写**: `scence/` 应为 `scene/`，修改会影响 `project.godot` 中的路径与引用，需谨慎处理。
2. **部分蜡封/增强未实现逻辑**: 紫色蜡封、蓝色蜡封、以及大部分增强（石头牌、黄金牌、万能牌等）贴图已配置但效果代码为空，仅在 `_update_seal_texture()` 中设置了纹理区域。
3. **小丑牌 id 范围未填充**: 当前仅 id 0-9 有实际效果，id 10-159 为默认"未知小丑"（无效果）。随机生成目前限定 id 0-9。
4. **音效未接入**: `resources/sounds/` 与 `Balatro OST/` 目录已存在大量音频资源，但代码中尚未播放这些音效。
5. **手柄支持**: 存在 `gamecontrollerdb.txt`，但代码中未见手柄输入处理逻辑。
6. **Settings / Stats 按钮**: 主菜单中 Settings 和 Stats 按钮仅 `print("S")` / `print("A")`，功能未实现。
7. **levelchose.tscn**: 关卡选择场景存在但无对应的 .gd 驱动脚本。
8. **joker.gd**: 根目录下的 `joker.gd` 是仅含 `extends Control` 的空桩，未被任何场景引用。
9. **HandTypeManager 已移除**: 原 `HandTypeManager.gd` 中的牌型判定逻辑与 `ScoreManager.gd` 重复，已删除，统一由 `ScoreManager` 处理。
10. **手牌.gd 已移除**: 原 `手牌.gd` 中的空按钮回调已整合到 `main.gd` 中，文件不再存在。
11. **版本控制**: `.godot/` 目录已加入 `.gitignore`，但工作区中仍有该目录，不影响提交。

---

## 扩展建议

- **音效层**: 在 `HandManager` 的出牌/弃牌/补牌流程以及 `JokerManager` 触发时加入 AudioStreamPlayer 调用。
- **更多小丑牌**: 在 `JokerCard._setup_by_id()` 和 `on_trigger()` 中按现有模式扩展 id 10+。
- **蜡封/增强完善**: 在 `HandManager._get_enhancement_bonus()` / `_apply_seal_effect()` 中补全紫色蜡封、蓝色蜡封以及各类增强的实际效果。
- **盲注与关卡**: `ScoreManager` 已有 `target_score` 和 `round_cleared` 信号，`levelchose.tscn` 也已存在，可配置多轮盲注关卡递进。
- **商店系统**: `MoneyManager` 已有完整收支接口，可配合 `ScoreManager.record_cards_bought()` 实现购买卡牌/小丑牌功能。
- **多语言**: 字体库已覆盖中日韩，若后续需要英文/其他语言 UI，只需替换 Label 文本即可。
