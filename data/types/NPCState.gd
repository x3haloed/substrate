extends Resource
class_name NPCState

## NPC emotional state vector and agency
@export var id: String = ""
@export var mood: String = "neutral"
@export var bond_with_player: float = 0.5
@export var assertiveness: float = 0.1  # 0.0 = reactive, 1.0 = proactive
@export var conviction: float = 0.5
@export var goals: Array[String] = []
@export var triggers: Dictionary = {}  # {"on_low_health_ally": "cast_heal"}
@export var flags: Dictionary = {}

