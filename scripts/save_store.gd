extends RefCounted
## Reads and writes the save JSON.
##
## On the web the text lives in the browser's localStorage, so a reload or a
## reopened tab keeps the farm. Everywhere else (and on the web when the browser
## refuses localStorage, e.g. private windows or file:// pages) it falls back to
## a plain savegame.json in the user data folder.

const WEB_KEY := "farming_save_v1"
const FILE_PATH := "user://savegame.json"

## Wrapped in try/catch because localStorage throws when storage is blocked or full.
const _JS_HELPERS := """
window.farmSaveWrite = function (key, text) {
	try { window.localStorage.setItem(key, text); return true; }
	catch (e) { return false; }
};
window.farmSaveRead = function (key) {
	try { var value = window.localStorage.getItem(key); return value === null ? "" : value; }
	catch (e) { return ""; }
};
window.farmSaveClear = function (key) {
	try { window.localStorage.removeItem(key); } catch (e) {}
};
"""

static var _browser = null

static func write_text(text: String) -> bool:
	var browser = _browser_window()
	if browser != null and bool(browser.farmSaveWrite(WEB_KEY, text)):
		return true
	return _write_file(text)

static func read_text() -> String:
	var browser = _browser_window()
	if browser != null:
		var stored = browser.farmSaveRead(WEB_KEY)
		var text: String = "" if stored == null else str(stored)
		if text != "":
			return text
	return _read_file()

static func clear() -> void:
	var browser = _browser_window()
	if browser != null:
		browser.farmSaveClear(WEB_KEY)
	if FileAccess.file_exists(FILE_PATH):
		DirAccess.remove_absolute(FILE_PATH)

## The browser window object, or null when not running in a browser.
static func _browser_window():
	if not OS.has_feature("web") or not Engine.has_singleton("JavaScriptBridge"):
		return null
	if _browser == null:
		var bridge = Engine.get_singleton("JavaScriptBridge")
		bridge.eval(_JS_HELPERS, true)
		_browser = bridge.get_interface("window")
	return _browser

static func _write_file(text: String) -> bool:
	var file := FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveStore: cannot write %s (%s)"
			% [FILE_PATH, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(text)
	file.close()
	return true

static func _read_file() -> String:
	if not FileAccess.file_exists(FILE_PATH):
		return ""
	var file := FileAccess.open(FILE_PATH, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text
