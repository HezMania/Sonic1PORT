extends Node

# Shared player registry used by the ported objects.
var players: Array[Node] = []

func register_player(player: Node) -> void:
	if not players.has(player):
		players.append(player)

func unregister_player(player: Node) -> void:
	players.erase(player)
