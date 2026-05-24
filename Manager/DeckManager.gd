extends Node

var deck: Array[Dictionary] = []

const SUITS = ["Heart", "Club", "Diamond", "Spade"]
const RANKS = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]



func _ready():
	"""节点就绪时初始化牌堆"""
	init_test_deck()

func init_deck():
	"""创建52张标准扑克牌并洗牌"""
	deck.clear()
	for suit in SUITS:
		for rank in RANKS:
			deck.append({"suit": suit, "rank": rank,"seal": "无","enhancement": "无"})
	deck.shuffle()
	print("牌堆初始化: ", deck.size(), "张")

func draw_card() -> Dictionary:
	"""从牌堆顶部抽取一张牌，牌堆为空时返回空字典"""
	if deck.is_empty():
		return {}
	return deck.pop_back()

func get_remaining() -> int:
	"""返回牌堆剩余卡牌数量"""
	return deck.size()


func add_card(suit: String, rank: String, seal: String = "无", enhancement: String = "无") -> void:
	"""向牌堆中添加一张新卡牌"""
	deck.append({"suit": suit, "rank": rank, "seal": seal, "enhancement": enhancement})

func shuffle_deck() -> void:
	"""重新打乱牌堆顺序"""
	deck.shuffle()


func init_test_deck() -> void:
	"""创建测试牌堆：每张牌有概率随机附带金色蜡封/红色蜡封/奖励牌/倍率牌"""
	const TEST_SEALS = ["金色蜡封", "红色蜡封"]
	const TEST_ENHANCEMENTS = ["奖励牌", "倍率牌"]
	const SEAL_CHANCE = 0.15     # 15% 概率获得蜡封
	const ENHANCEMENT_CHANCE = 0.15  # 15% 概率获得增强
	
	deck.clear()
	for suit in SUITS:
		for rank in RANKS:
			var card_data = {"suit": suit, "rank": rank, "seal": "无", "enhancement": "无"}
			if randf() < SEAL_CHANCE:
				card_data["seal"] = TEST_SEALS[randi() % TEST_SEALS.size()]
			if randf() < ENHANCEMENT_CHANCE:
				card_data["enhancement"] = TEST_ENHANCEMENTS[randi() % TEST_ENHANCEMENTS.size()]
			deck.append(card_data)
	deck.shuffle()
	print("测试牌堆初始化: ", deck.size(), "张")
