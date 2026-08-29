class_name LanDiscovery
extends Node

signal host_found(ip: String)

const DISCOVERY_PORT := 8911
const BROADCAST_INTERVAL := 1.0
const BEACON_MESSAGE := "ARENA3D_HOST"

var _broadcast_socket: PacketPeerUDP
var _listen_socket: PacketPeerUDP
var _broadcast_timer: float = 0.0
var _known_ips: Array = []

func start_broadcasting() -> void:
	_stop_broadcasting()
	_broadcast_socket = PacketPeerUDP.new()
	_broadcast_socket.set_broadcast_enabled(true)
	_broadcast_socket.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	_broadcast_timer = 0.0
	set_process(true)

func start_listening() -> void:
	_stop_listening()
	_known_ips.clear()
	_listen_socket = PacketPeerUDP.new()
	var err := _listen_socket.bind(DISCOVERY_PORT)
	if err != OK:
		_listen_socket = null
		return
	set_process(true)

func stop() -> void:
	_stop_broadcasting()
	_stop_listening()
	set_process(false)

func _stop_broadcasting() -> void:
	if _broadcast_socket:
		_broadcast_socket.close()
		_broadcast_socket = null

func _stop_listening() -> void:
	if _listen_socket:
		_listen_socket.close()
		_listen_socket = null

func _process(delta: float) -> void:
	if _broadcast_socket:
		_broadcast_timer -= delta
		if _broadcast_timer <= 0.0:
			_broadcast_timer = BROADCAST_INTERVAL
			_broadcast_socket.put_packet(BEACON_MESSAGE.to_utf8_buffer())
	if _listen_socket:
		while _listen_socket.get_available_packet_count() > 0:
			var packet := _listen_socket.get_packet()
			var ip := _listen_socket.get_packet_ip()
			if packet.get_string_from_utf8() == BEACON_MESSAGE and not _known_ips.has(ip):
				_known_ips.append(ip)
				host_found.emit(ip)
