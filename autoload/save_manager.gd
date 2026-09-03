extends Node
## Persistência do save em user://save.json. JSON versionado, debounce, backup
## rotativo e migração em cadeia — mesmo padrão consolidado no projeto anterior deste
## repositório; a bíblia (#17.3) define o que o save contém, não o mecanismo de escrita.

const SAVE_PATH := "user://save.json"
const BACKUP_DIR := "user://backups/"
const BACKUP_COUNT := 3
const CURRENT_VERSION := 1
const DEBOUNCE_SEG := 2.0

var _pending_data: Dictionary = {}
var _debounce_timer: Timer


func _ready() -> void:
	DirAccess.make_dir_absolute(BACKUP_DIR)
	_debounce_timer = Timer.new()
	_debounce_timer.wait_time = DEBOUNCE_SEG
	_debounce_timer.one_shot = true
	_debounce_timer.timeout.connect(_flush_save)
	add_child(_debounce_timer)


## Chamado pelos sistemas de jogo a cada ação relevante. Não escreve em disco
## imediatamente — aguarda o debounce.
func request_save(data: Dictionary) -> void:
	_pending_data = data
	_debounce_timer.start()


## Escreve imediatamente, ignorando o debounce. Usado em pausa/fechamento do app.
func force_save(data: Dictionary) -> void:
	_pending_data = data
	_debounce_timer.stop()
	_flush_save()


func _flush_save() -> void:
	if _pending_data.is_empty():
		return
	_rotate_backups()
	_pending_data["version"] = CURRENT_VERSION
	var text := JSON.stringify(_pending_data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: falha ao abrir %s para escrita (%s)" % [SAVE_PATH, error_string(FileAccess.get_open_error())])
		return
	file.store_string(text)
	file.close()


func _rotate_backups() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var dir := DirAccess.open(BACKUP_DIR)
	if dir == null:
		return
	var oldest := BACKUP_DIR + "backup_%d.json" % BACKUP_COUNT
	if dir.file_exists("backup_%d.json" % BACKUP_COUNT):
		dir.remove(oldest)
	for i in range(BACKUP_COUNT - 1, 0, -1):
		var src := "backup_%d.json" % i
		if dir.file_exists(src):
			dir.rename(BACKUP_DIR + src, BACKUP_DIR + "backup_%d.json" % (i + 1))
	dir.copy(SAVE_PATH, BACKUP_DIR + "backup_1.json")


## Retorna o save já migrado para CURRENT_VERSION, ou {} se não existir save algum.
func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: save.json corrompido, ignorando")
		return {}
	return _migrate(parsed)


## Cadeia de migração. Cada versão futura adiciona um bloco `if data.version == N`.
func _migrate(data: Dictionary) -> Dictionary:
	var version: int = data.get("version", 1)
	# version == 1 é o formato atual, nada a migrar ainda.
	data["version"] = CURRENT_VERSION
	return data
