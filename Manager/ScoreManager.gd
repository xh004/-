# score_manager.gd（AutoLoad）
extends Node

signal score_changed(current_score: int)
signal totalscore_changed(total_score :int)
signal chips_changed(value: int)
signal mult_changed(value: float)
signal hand_leveled_up(hand_type: String, level: int)
signal target_score_changed(value: int)
signal round_cleared(won: bool, total_score: int, target_score: int)

var current_chips: int = 0      # 当前筹码（小丑牌效果等）
var current_mult: float = 1.0   # 当前倍率（小丑牌效果等）
var round_score: int = 0        # 本回合当前得分
var game_total_score: int = 0   # 游戏累计总分

var base_chips: int = 0         # 牌型基础分
var base_mult: float = 1.0      # 牌型基础倍率

var target_score: int = 300     # 当前回合目标分数

var hand_type_counts: Dictionary = {}   # 各牌型使用次数 {牌型名: 次数}
var total_cards_played: int = 0         # 累计打出牌数
var total_cards_discarded: int = 0      # 累计弃掉牌数
var total_cards_bought: int = 0        # 累计购买牌数

const RANK_ORDER = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]

func _rank_value(rank: String) -> int:
	"""将牌面点数转换为数值（A=14, 2=2）"""
	match rank:
		"A": return 14
		"K": return 13
		"Q": return 12
		"J": return 11
		"10": return 10
		"9": return 9
		"8": return 8
		"7": return 7
		"6": return 6
		"5": return 5
		"4": return 4
		"3": return 3
		"2": return 2
		_: return 0

# 全局手牌类型分数表（Balatro 标准数值）
# 格式: { 手牌名: { base_chips, base_mult, chip_increase, mult_increase } }
const HAND_DATA: Dictionary = {
	"High Card":        { "base_chips": 5,   "base_mult": 1,  "chip_increase": 10, "mult_increase": 1 },
	"Pair":             { "base_chips": 10,  "base_mult": 2,  "chip_increase": 15, "mult_increase": 1 },
	"Two Pair":         { "base_chips": 20,  "base_mult": 2,  "chip_increase": 20, "mult_increase": 1 },
	"Three of a Kind":  { "base_chips": 30,  "base_mult": 3,  "chip_increase": 20, "mult_increase": 2 },
	"Straight":         { "base_chips": 30,  "base_mult": 4,  "chip_increase": 30, "mult_increase": 3 },
	"Flush":            { "base_chips": 35,  "base_mult": 4,  "chip_increase": 15, "mult_increase": 2 },
	"Full House":       { "base_chips": 40,  "base_mult": 4,  "chip_increase": 25, "mult_increase": 2 },
	"Four of a Kind":   { "base_chips": 60,  "base_mult": 7,  "chip_increase": 30, "mult_increase": 3 },
	"Straight Flush":   { "base_chips": 100, "base_mult": 8,  "chip_increase": 40, "mult_increase": 4 },
	"Five of a Kind":   { "base_chips": 120, "base_mult": 12, "chip_increase": 35, "mult_increase": 3 },
	"Flush House":      { "base_chips": 140, "base_mult": 14, "chip_increase": 40, "mult_increase": 4 },
	"Flush Five":       { "base_chips": 160, "base_mult": 16, "chip_increase": 50, "mult_increase": 3 },
}

# 各手牌类型的当前等级（默认 1 级）
var hand_levels: Dictionary = {}

func _ready():
	"""节点就绪时重置所有手牌等级"""
	reset_all_hand_levels()

func reset_round():
	"""每回合重置动态分数"""
	current_chips = 0
	current_mult = 0
	round_score = 0
	game_total_score = 0
	base_chips = 0
	base_mult = 1.0
	chips_changed.emit(0)
	mult_changed.emit(1.0)
	score_changed.emit(0)
	totalscore_changed.emit(0)

func reset_stats():
	"""重置所有统计"""
	hand_type_counts.clear()
	total_cards_played = 0
	total_cards_discarded = 0
	total_cards_bought = 0

func record_hand_type(hand_type: String):
	"""记录牌型使用次数"""
	hand_type_counts[hand_type] = hand_type_counts.get(hand_type, 0) + 1

func record_cards_played(count: int):
	"""记录打出牌数"""
	total_cards_played += count

func record_cards_discarded(count: int):
	"""记录弃掉牌数"""
	total_cards_discarded += count

func record_cards_bought(count: int):
	"""记录购买牌数"""
	total_cards_bought += count

func set_target_score(value: int):
	"""设置目标分数"""
	target_score = value
	target_score_changed.emit(value)

func check_round_end() -> bool:
	"""检查是否通关，并发出信号"""
	var won = game_total_score >= target_score
	round_cleared.emit(won, game_total_score, target_score)
	return won

func reset_all_hand_levels():
	"""重置所有手牌等级为 1"""
	hand_levels.clear()
	for hand_name in HAND_DATA.keys():
		hand_levels[hand_name] = 1

func get_hand_level(hand_type: String) -> int:
	"""获取指定手牌类型的当前等级"""
	return hand_levels.get(hand_type, 1)

func get_hand_base_score(hand_type: String) -> Dictionary:
	"""获取手牌的基础数据（不含等级加成）"""
	if not HAND_DATA.has(hand_type):
		return { "chips": 0, "mult": 0 }
	var data = HAND_DATA[hand_type]
	return { "chips": data["base_chips"], "mult": data["base_mult"] }

func get_hand_score(hand_type: String) -> Dictionary:
	"""获取指定手牌类型在当前等级下的筹码和倍率"""
	if not HAND_DATA.has(hand_type):
		return { "chips": 0, "mult": 0 }
	
	var data = HAND_DATA[hand_type]
	var level = hand_levels.get(hand_type, 1)
	var chips = data["base_chips"] + (level - 1) * data["chip_increase"]
	var mult = data["base_mult"] + (level - 1) * data["mult_increase"]
	return { "chips": chips, "mult": mult }

func level_up_hand(hand_type: String, amount: int = 1) -> bool:
	"""升级指定手牌类型，返回是否成功"""
	if not HAND_DATA.has(hand_type):
		return false
	
	hand_levels[hand_type] = get_hand_level(hand_type) + amount
	hand_leveled_up.emit(hand_type, hand_levels[hand_type])
	return true

func set_hand_type(hand_type: String):
	"""设置当前出牌的手牌类型，更新 base_chips / base_mult"""
	var score = get_hand_score(hand_type)
	current_chips = score["chips"]
	current_mult = score["mult"]
	chips_changed.emit(current_chips)
	mult_changed.emit(current_mult)

func add_chips(amount: int):
	"""添加筹码（小丑牌效果）"""
	current_chips += amount
	chips_changed.emit( current_chips)

func add_mult(amount: float):
	"""添加倍率（小丑牌效果）"""
	current_mult += amount
	mult_changed.emit( current_mult)

func multiply_mult(factor: float):
	"""倍率乘法（小丑牌效果）"""
	current_mult *= factor
	mult_changed.emit(current_mult)

func recalculate():
	"""重新计算本回合得分"""
	var chips = current_chips
	var mult = current_mult
	round_score = int(chips * mult)
	score_changed.emit(round_score)
	add_round_score_to_total()
	totalscore_changed.emit(game_total_score)

func add_round_score_to_total():
	"""将本回合得分累加到总分"""
	game_total_score += round_score
	totalscore_changed.emit(game_total_score)

func reset_chips():
	"""重置临时筹码和基础牌型分（出牌后调用）"""
	current_chips = 0
	base_chips = 0
	base_mult = 1.0
	round_score = 0
	chips_changed.emit(0)
	mult_changed.emit(1.0)
	score_changed.emit(0)

func submit_score() -> int:
	"""提交最终分数"""
	add_round_score_to_total()
	var final = round_score
	reset_round()
	return final

func get_scoring_cards(cards: Array, hand_type: String) -> Array:
	"""获取参与计分的卡牌(Balatro 规则)"""
	if cards.is_empty():
		return []
	
	# 统计 rank 频率
	var rank_counts: Dictionary = {}
	for card in cards:
		var r = card.get_rank()
		rank_counts[r] = rank_counts.get(r, 0) + 1
	
	match hand_type:
		"High Card":
			# 最大点数的那张牌
			var max_val = -1
			var max_rank = ""
			for r in rank_counts.keys():
				var v = _rank_value(r)
				if v > max_val:
					max_val = v
					max_rank = r
			return cards.filter(func(c): return c.get_rank() == max_rank)
		
		"Pair":
			var pair_rank = ""
			for r in rank_counts.keys():
				if rank_counts[r] == 2:
					pair_rank = r
					break
			return cards.filter(func(c): return c.get_rank() == pair_rank)
		
		"Two Pair":
			var pair_ranks: Array[String] = []
			for r in rank_counts.keys():
				if rank_counts[r] == 2:
					pair_ranks.append(r)
			return cards.filter(func(c): return c.get_rank() in pair_ranks)
		
		"Three of a Kind":
			var three_rank = ""
			for r in rank_counts.keys():
				if rank_counts[r] == 3:
					three_rank = r
					break
			return cards.filter(func(c): return c.get_rank() == three_rank)
		
		"Straight", "Flush", "Straight Flush", "Full House", "Five of a Kind", "Flush House", "Flush Five":
			# 全部卡牌都计分
			return cards.duplicate()
		
		"Four of a Kind":
			var four_rank = ""
			for r in rank_counts.keys():
				if rank_counts[r] == 4:
					four_rank = r
					break
			return cards.filter(func(c): return c.get_rank() == four_rank)
	
	return cards.duplicate()

func evaluate_hand(cards: Array) -> String:
	"""判断牌型，返回牌型名称字符串"""
	if cards.is_empty():
		return "None"
	if cards.size() == 1:
		return "High Card"
	
	var ranks: Array[String] = []
	var suits: Array[String] = []
	var values: Array[int] = []
	
	for card in cards:
		ranks.append(card.get_rank())
		suits.append(card.get_suit())
		values.append(_rank_value(card.get_rank()))

	# 统计 rank 频率
	var rank_counts: Dictionary = {}
	for r in ranks:
		rank_counts[r] = rank_counts.get(r, 0) + 1
	var counts = rank_counts.values()
	counts.sort()
	counts.reverse()
	
	var is_flush = suits.all(func(s): return s == suits[0])
	var is_straight = _is_straight(values)
	
	# 5张牌特有的牌型（同花、顺子相关）
	if cards.size() == 5:
		if counts == [5] and is_flush:
			return "Flush Five"
		if counts == [3, 2] and is_flush:
			return "Flush House"
		if is_straight and is_flush:
			return "Straight Flush"
		if is_flush:
			return "Flush"
		if is_straight:
			return "Straight"
		if counts == [3, 2]:
			return "Full House"
		if counts == [2, 2, 1]:
			return "Two Pair"
	
	# 2-5张通用的牌型（按牌面大小判断）
	if counts == [5]:
		return "Five of a Kind"
	if counts[0] == 4:
		return "Four of a Kind"
	if counts[0] == 3:
		return "Three of a Kind"
	if cards.size() == 4 and counts == [2, 2]:
		return "Two Pair"
	if counts[0] == 2:
		return "Pair"
	
	return "High Card"


func _is_straight(values: Array[int]) -> bool:
	"""判断给定数值数组是否构成顺子（支持A当1或14）"""
	if values.size() < 5:
		return false
	var unique = values.duplicate()
	unique.sort()
	if _is_consecutive(unique):
		return true
	if unique.has(14):
		var low_ace = unique.duplicate()
		low_ace.erase(14)
		low_ace.append(1)
		low_ace.sort()
		if _is_consecutive(low_ace):
			return true
	return false

func _is_consecutive(values: Array[int]) -> bool:
	"""判断数组中的数值是否连续递增"""
	for i in range(1, values.size()):
		if values[i] != values[i - 1] + 1:
			return false
	return true

func get_mostused() -> String:
	var  mostused : String 
	var value :int
	for hand_type in hand_type_counts:
		if hand_type_counts[hand_type] > value :
			mostused = hand_type
	return mostused