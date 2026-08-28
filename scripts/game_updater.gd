extends Node
class_name GameUpdater

const REPO := "ArthurHub01/Arena-3d"
const API_URL := "https://api.github.com/repos/%s/releases/latest" % REPO
const ASSET_NAMES := {
	"Windows": "arena3d.exe",
	"Linux": "arena3d.x86_64",
}

signal up_to_date()
signal update_available(version: String, download_url: String)
signal check_failed(reason: String)
signal download_progress(percent: float)
signal download_complete()
signal download_failed(reason: String)

var _check_request: HTTPRequest
var _download_request: HTTPRequest
var _download_target_path: String

func _ready() -> void:
	_check_request = HTTPRequest.new()
	add_child(_check_request)
	_check_request.request_completed.connect(_on_check_completed)

	_download_request = HTTPRequest.new()
	add_child(_download_request)
	_download_request.request_completed.connect(_on_download_completed)

func check_for_update() -> void:
	var err := _check_request.request(API_URL, ["User-Agent: Arena3DUpdater"])
	if err != OK:
		check_failed.emit("Falha ao iniciar verificação (erro %d)" % err)

func _on_check_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		check_failed.emit("Não foi possível verificar atualizações (código %d)" % response_code)
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null or not json.has("tag_name"):
		check_failed.emit("Resposta inválida do servidor de atualização")
		return

	var latest_version: String = json["tag_name"]
	if latest_version == GameVersion.VERSION:
		up_to_date.emit()
		return

	var asset_name: String = ASSET_NAMES.get(OS.get_name(), "")
	var download_url := ""
	for asset in json.get("assets", []):
		if asset.get("name", "") == asset_name:
			download_url = asset.get("browser_download_url", "")
			break

	if download_url.is_empty():
		check_failed.emit("Versão %s disponível, mas sem arquivo para este sistema" % latest_version)
		return

	update_available.emit(latest_version, download_url)

func download_update(download_url: String) -> void:
	var current_exe := OS.get_executable_path()
	_download_target_path = current_exe.get_base_dir().path_join("_arena3d_update.tmp")
	_download_request.download_file = _download_target_path
	var err := _download_request.request(download_url, ["User-Agent: Arena3DUpdater"])
	if err != OK:
		download_failed.emit("Falha ao iniciar download (erro %d)" % err)

func _on_download_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		download_failed.emit("Falha ao baixar atualização (código %d)" % response_code)
		return
	download_complete.emit()

func apply_update_and_restart() -> void:
	var current_exe := OS.get_executable_path()
	var base_dir := current_exe.get_base_dir()

	if OS.get_name() == "Windows":
		var script_path := base_dir.path_join("_update.bat")
		var win_new := _download_target_path.replace("/", "\\")
		var win_exe := current_exe.replace("/", "\\")
		var content := "@echo off\r\ntimeout /t 1 /nobreak >nul\r\nmove /y \"%s\" \"%s\"\r\nstart \"\" \"%s\"\r\ndel \"%%~f0\"\r\n" % [win_new, win_exe, win_exe]
		var f := FileAccess.open(script_path, FileAccess.WRITE)
		f.store_string(content)
		f.close()
		OS.create_process(script_path, [])
	else:
		var script_path := base_dir.path_join("_update.sh")
		var content := "#!/bin/bash\nsleep 1\nmv -f \"%s\" \"%s\"\nchmod +x \"%s\"\n\"%s\" &\nrm -- \"$0\"\n" % [_download_target_path, current_exe, current_exe, current_exe]
		var f := FileAccess.open(script_path, FileAccess.WRITE)
		f.store_string(content)
		f.close()
		OS.execute("chmod", ["+x", script_path])
		OS.create_process(script_path, [])

	get_tree().quit()
