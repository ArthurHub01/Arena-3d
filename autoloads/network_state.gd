extends Node

const PORT := 8910
const MAX_PLAYERS := 2

var is_host: bool = false
var host_ip: String = ""
var selected_element: ElementType.Type = ElementType.Type.FIRE
var vs_computer: bool = false
var player_nickname: String = "Jogador"
var player_color: Color = Color(0.837638, 0.528975, 0.496618, 1)
