@tool
extends SceneTree

func _init() -> void:
	if Engine.is_editor_hint() and EditorInterface:
		var s: EditorSettings = EditorInterface.get_editor_settings()
		print("Current SDK setting: ", s.get_setting("export/android/android_sdk_path"))
		s.set_setting("export/android/android_sdk_path", "C:/Users/jatin/AppData/Local/Android/Sdk")
		s.set_setting("export/android/debug_keystore", "C:/Users/jatin/.android/debug.keystore")
		s.set_setting("export/android/debug_keystore_user", "androiddebugkey")
		s.set_setting("export/android/debug_keystore_pass", "android")
		s.set_setting("export/android/java_sdk_path", "C:/Program Files/Android/Android Studio/jbr")
		print("Updated SDK setting: ", s.get_setting("export/android/android_sdk_path"))
	else:
		print("Engine not editor hint or EditorInterface null")
	quit()
