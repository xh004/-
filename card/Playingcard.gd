class_name PlayingCard extends Control

enum CardState {
	NORMAL,     # 静止/手牌中
	HOVER,      # 鼠标悬停
	SELECTED,   # 被选中（上移）
	DRAGGING,   # 拖拽中
	PLAYED,     # 已打出
	DISCARDED,  # 已弃牌
}

var state: CardState = CardState.NORMAL

signal clicked(card: PlayingCard)
signal state_changed(new_state: CardState, card: PlayingCard)
signal play_value_revealed(value: int)

# 卡牌属性
@export var suit: String    # 花色: Spade(黑桃), Heart(红心), Diamond(方块), Club(梅花)
@export var rank: String      # 点数: A, 2-10, J, Q, K
@export var value: int          # 牌面数值（用于计算）
@export var seal: String = ""           # 蜡封: Gold, Red, Blue, Purple,None
@export var enhancement: String = ""    # 增强: Bonus, Mult, Wild, Glass, Steel, Stone, Gold, Lucky，None

var original_pos: Vector2         # 卡牌原始位置（未选中时）
var drag_offset: Vector2          # 鼠标相对于卡牌左上角的偏移
var original_z_index: int         # 原始层级
var is_held: bool = false         # 鼠标是否正按住这张牌
var has_dragged: bool = false     # 本次按下是否已触发拖拽
var drag_start_mouse_pos: Vector2 # 按下时的鼠标位置（用于判断点击还是拖拽）

const SELECTED_OFFSET = Vector2(0, -30)
const DRAG_THRESHOLD = 5.0

@onready var button: Button = $Button
@onready var texture_rect: TextureRect = $TextureRect
@onready var seal_rect: TextureRect = $TextureRect2
@onready var enhancement_rect: TextureRect = $TextureRect3

# 卡牌纹理配置
const CARD_TEXTURE_PATH = "res://resources/textures/2x/8BitDeck.png"
const CARD_ENHANCEMENT_PATH = "res://resources/textures/2x/Enhancers.png"
const CARDS_PER_ROW = 14     # 每行14张（13张牌+1个额外图案）
const CARD_WIDTH = 142       # 每张卡牌宽度
const CARD_HEIGHT = 190      # 每张卡牌高度

func _ready():
	# 连接按钮信号（Button 处理鼠标事件更稳定）
	button.pressed.connect(_on_button_pressed)
	button.button_down.connect(_on_button_down)
	button.button_up.connect(_on_button_up)
	button.mouse_entered.connect(_on_mouse_entered)
	button.mouse_exited.connect(_on_mouse_exited)
	original_z_index = z_index
	# 加载卡牌纹理
	_update_card_texture()
	_update_seal_texture()
	value = _calculate_value(get_rank())

func _process(_delta):
	if is_held and state != CardState.DRAGGING:
		var mouse_pos = get_global_mouse_position()
		if mouse_pos.distance_to(drag_start_mouse_pos) > DRAG_THRESHOLD:
			state = CardState.DRAGGING
			has_dragged = true
			z_index = 100
			var parent = get_parent()
			if parent:
				drag_offset = (mouse_pos - parent.global_position) - position
			else:
				drag_offset = mouse_pos - global_position

	if state == CardState.DRAGGING:
		var parent = get_parent()
		if parent:
			position = (get_global_mouse_position() - parent.global_position) - drag_offset
		else:
			global_position = get_global_mouse_position() - drag_offset

func _on_button_pressed():
	print("按钮被按下！")
	toggle_select()
	clicked.emit(self)

func toggle_select():
	if has_dragged:
		return

	match state:
		CardState.NORMAL, CardState.HOVER:
			original_pos = position
			state = CardState.SELECTED
			position = original_pos + SELECTED_OFFSET
			z_index = 100
			_scale_card(1.05)
			modulate = Color(1, 1, 1)

		CardState.SELECTED:
			state = CardState.NORMAL
			position = original_pos
			z_index = original_z_index
			_scale_card(1.0)

		CardState.DRAGGING:
			pass

	state_changed.emit(state, self)

func _on_button_down():
	is_held = true
	has_dragged = false
	drag_start_mouse_pos = get_global_mouse_position()
	if state != CardState.SELECTED:
		original_pos = position

func _on_button_up():
	is_held = false

	if state == CardState.DRAGGING:
		var dropped = HandManager.try_drop_card(self)
		if not dropped:
			return_to_slot()

func _on_mouse_entered():
	if state == CardState.NORMAL:
		state = CardState.HOVER
		# 悬停效果：稍微抬起
		_scale_card(1.05)
		modulate = Color(1.1, 1.1, 1.1)  # 稍微变亮

func _on_mouse_exited():
	if state == CardState.HOVER:
		state = CardState.NORMAL
		_scale_card(1.0)
		modulate = Color(1, 1, 1)  # 恢复原色

func _scale_card(scale_factor: float):
	# 平滑缩放动画
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "scale", Vector2(scale_factor, scale_factor), 0.15)

# 公共方法：设置卡牌数据
func set_card_data(new_suit: String, new_rank: String, new_seal: String = "", new_enhancement: String = ""):
	suit = new_suit
	rank = new_rank
	seal = new_seal
	enhancement = new_enhancement
	value = _calculate_value(new_rank)
	_update_card_texture()

# 更新卡牌纹理显示
func _update_card_texture():
	if texture_rect == null:
		return
	var atlas_texture = AtlasTexture.new()
	atlas_texture.atlas = load(CARD_TEXTURE_PATH)
	atlas_texture.region = _get_card_region()
	texture_rect.texture = atlas_texture

# 获取卡牌在精灵表中的区域
func _get_card_region() -> Rect2:
	var row = _get_suit_row()
	var col = _get_rank_column()
	return Rect2(col * CARD_WIDTH, row * CARD_HEIGHT, CARD_WIDTH, CARD_HEIGHT)

# 获取花色所在行
func _get_suit_row() -> int:
	match suit:
		"Heart": return 0    # 第一行：红心
		"Club": return 1     # 第二行：梅花
		"Diamond": return 2  # 第三行：方块
		"Spade": return 3    # 第四行：黑桃
		_: return 0

# 获取点数所在列
func _get_rank_column() -> int:
	# 列顺序: A,2,3,4,5,6,7,8,9,10,J,Q,K
	match rank:
		"A": return 12
		"2": return 0
		"3": return 1
		"4": return 2
		"5": return 3
		"6": return 4
		"7": return 5
		"8": return 6
		"9": return 7
		"10": return 8
		"J": return 9
		"Q": return 10
		"K": return 11
		_: return 0

# 获取卡牌完整名称
func get_card_name() -> String:
	return suit + rank

# 获取花色
func get_suit() -> String:
	return suit

# 获取点数
func get_rank() -> String:
	return rank

# 获取数值
func get_value() -> int:
	return value

# 获取蜡封
func get_seal() -> String:
	return seal

# 获取增强
func get_enhancement() -> String:
	return enhancement

# 设置蜡封
func set_seal(new_seal: String) -> void:
	seal = new_seal

# 设置增强
func set_enhancement(new_enhancement: String) -> void:
	enhancement = new_enhancement

# 获取花色颜色
func get_suit_color() -> Color:
	match suit:
		"Heart", "Diamond":
			return Color.RED
		_:
			return Color.BLACK


# 内部方法：计算数值
func _calculate_value(r: String) -> int:
	match r:
		"A": return 14
		"J": return 11
		"Q": return 12
		"K": return 13
		_:
			return r.to_int() if r.is_valid_int() else 0

# 公共方法：获取卡牌当前是否在拖拽
func is_dragging() -> bool:
	return state == CardState.DRAGGING

# 公共方法：强制返回原位（可用于非法放置时）
func return_to_start():
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "position", original_pos, 0.3)
	state = CardState.NORMAL
	z_index = original_z_index
	_scale_card(1.0)
	state_changed.emit(state, self)

func return_to_slot():
	return_to_start()

func mark_as_played():
	state = CardState.PLAYED
	z_index = original_z_index
	_scale_card(1.0)
	state_changed.emit(state, self)

func score_jump() -> Tween:
	var tween = create_tween()
	var start_pos = global_position
	var jump_up = start_pos + Vector2(0, -80)
	var jump_down = start_pos + Vector2(0, 30)

	# 第一阶段：向上冲
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "global_position", jump_up, 0.15)

	# 飞到最高点时发出 value 信号
	tween.step_finished.connect(func(idx: int):
		if idx == 0:
			self.play_value_revealed.emit(value)
	)

	# 第二阶段：向下弹跳
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property(self, "global_position", jump_down, 0.35)

	return tween

func mark_as_discarded():
	state = CardState.DISCARDED
	z_index = original_z_index
	_scale_card(1.0)
	state_changed.emit(state, self)

func discard_fade() -> Tween:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.parallel()
	tween.tween_property(self, "global_position", global_position + Vector2(0, 120), 0.3)
	tween.parallel()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.3)
	return tween

func _update_seal_texture() -> void:
	var seal_texture = AtlasTexture.new()
	var enhancement_texture = AtlasTexture.new()
	seal_texture.atlas = load(CARD_ENHANCEMENT_PATH)
	enhancement_texture.atlas = load(CARD_ENHANCEMENT_PATH)
	var have_seal : bool  = true
	match seal :
		"无":
			have_seal = false
		"金色蜡封" :
			seal_texture.region = get_enhancement_randc(1,3)
		"紫色蜡封":
			seal_texture.region = get_enhancement_randc(5,5)
		"红色蜡封" :
			seal_texture.region = get_enhancement_randc(5,6)
		"蓝色蜡封":
			seal_texture.region = get_enhancement_randc(5,7)
	match enhancement:
		"无":
			enhancement_texture.region = get_enhancement_randc(1,2)
		"石头牌":
			enhancement_texture.region = get_enhancement_randc(1,6)
		"黄金牌":
			enhancement_texture.region = get_enhancement_randc(1,7)
		"奖励牌":
			enhancement_texture.region = get_enhancement_randc(2,2)
		"倍率牌":
			enhancement_texture.region = get_enhancement_randc(2,3)
		"万能牌":
			enhancement_texture.region = get_enhancement_randc(2,4)
		"玻璃牌":
			enhancement_texture.region = get_enhancement_randc(2,6)
		"幸运牌":
			enhancement_texture.region = get_enhancement_randc(2,5)
		"钢铁牌":
			enhancement_texture.region = get_enhancement_randc(2,7)
	if(have_seal):
		seal_rect.texture = seal_texture
	enhancement_rect.texture = 	enhancement_texture




func get_enhancement_randc (row:int,col:int) -> Rect2:
	var cell_width = 142  # 142
	var cell_height = 190 # 190
	var x = (col-1) * cell_width
	var y = (row-1) * cell_height
	return Rect2(x, y, cell_width, cell_height)


func _on_button_mouse_exited() -> void:
	pass # Replace with function body.


func _on_button_button_down() -> void:
	pass # Replace with function body.


func _on_button_button_up() -> void:
	pass # Replace with function body.
