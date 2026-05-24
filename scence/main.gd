extends Node

@onready var mult : Button = $"PanelContainer/node/VBoxContainer/Panel2/倍率"
@onready var chips : Button = $"PanelContainer/node/VBoxContainer/Panel2/筹码"
@onready var total_score : Button = $"PanelContainer/node/VBoxContainer/Panel/总分值"
@onready var money : Button = $"PanelContainer/node/Panel/Button"
@onready var play_times : Button = $"PanelContainer/node/出牌/出牌次数"
@onready var discard_times : Button = $"PanelContainer/node/弃牌/弃牌次数"
@onready var target_score_label : Label = $"PanelContainer/node/VBoxContainer/盲注信息/Panel/目标分数值"
@onready var desk : HBoxContainer = $"牌桌"
@onready var joker_container : HBoxContainer = $"小丑牌桌/小丑"
@onready var game_over_scene = preload("res://scence/GameOver.tscn")

var stats :Dictionary = {}

func _ready() -> void:
	ScoreManager.score_changed.connect(_score_change)
	ScoreManager.mult_changed.connect(_mult_change )
	ScoreManager.chips_changed.connect(_chips_change)
	ScoreManager.totalscore_changed.connect(_totalscore_change)
	MoneyManager.money_changed.connect(_money_change)
	HandManager.plays_changed.connect(_play_change)
	HandManager.discards_changed.connect(_discard_change)
	ScoreManager.target_score_changed.connect(_target_score_change)
	ScoreManager.round_cleared.connect(_on_round_cleared)
	ScoreManager.set_target_score(300)
	HandManager.draw_eight_cards(desk)
	
	# 设置小丑牌容器并创建测试按钮
	JokerManager.joker_container = joker_container
	_create_joker_test_button()
	pass

func _create_joker_test_button() -> void:
	"""在屏幕上方创建一个测试按钮，点击随机生成小丑牌"""
	var btn = Button.new()
	btn.text = "生成小丑"
	btn.position = Vector2(540, 140)
	btn.size = Vector2(100, 40)
	btn.add_theme_color_override("font_color", Color(1, 0.8, 0))
	btn.pressed.connect(_on_generate_joker_pressed)
	add_child(btn)

func _on_generate_joker_pressed() -> void:
	var joker = JokerManager.add_random_joker()
	if joker:
		print("生成小丑: [", joker.joker_id, "] ", joker.joker_name, " — ", joker.description)
	else:
		print("小丑牌栏位已满（上限5个）")

func _score_change(_thescore : int) :
	pass

func _mult_change(total_mult: float):
	mult.text = str(total_mult)
	pass

func _chips_change(total_chips : int):
	chips.text = str(total_chips)
	pass
	
func _totalscore_change(thetotal_score:int):
	total_score.text = str(thetotal_score)

func _on_花色_pressed() -> void:
	HandManager.sort_hand_by_colour()
	pass # Replace with function body.


func _on_点数_pressed() -> void:
	HandManager.sort_hand_by_rank()
	pass # Replace with function body.



func _on_弃牌_pressed() -> void:	
	HandManager.discard_selected_cards()
	pass # Replace with function body.

func _on_出牌_pressed() -> void:
	HandManager.play_selected_cards()
	pass # Replace with function body.
func _money_change(current:int) -> void:
	money.text = str(current)

func _play_change(value:int) ->void:
	play_times.text = str(value)

func _discard_change(value :int) -> void:
	discard_times.text = str(value)

func _target_score_change(value :int) -> void:
	target_score_label.text = str(value)

func _on_round_cleared(won: bool, thetotal_score: int, target_score: int):
	if won:
		print("通关！总分: ", thetotal_score, " >= 目标: ", target_score)

	else:
		print("失败！总分: ", thetotal_score, " < 目标: ", target_score)
	stats = {
		"最佳出牌" : 0,
		"最常用牌型" : ScoreManager.get_mostused(),
		"已使用卡牌" : ScoreManager.total_cards_played,
		"已弃掉卡牌" : ScoreManager.total_cards_discarded,
		"已购买卡牌" : ScoreManager.total_cards_bought,
		"种子": 0 
	}
	trigger_game_over()

func trigger_game_over():
  
# 实例化游戏结束界面
	var game_over = game_over_scene.instantiate()
	game_over.stats = stats
  
# 添加到当前场景
	add_child(game_over)
