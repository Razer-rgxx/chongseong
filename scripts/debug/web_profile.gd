extends SceneTree
## 웹판 무게 재기: 장면마다 WebQuality를 켠 채로 열어 그리기 횟수·물체·빛·노드를 센다.
## 돌리기: xvfb-run -a godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility --fixed-fps 30 --resolution 1280x720 -s scripts/debug/web_profile.gd

const SCENES: Array[String] = ["res://scenes/title/title.tscn", "res://scenes/lobby/lobby.tscn", "res://scenes/world/main.tscn", "res://scenes/field/field.tscn", "res://scenes/future/future.tscn", "res://scenes/past/past.tscn"]


func _init() -> void:
	WebQuality.force = true
	var only: Array = OS.get_cmdline_user_args()
	for path in SCENES:
		if not only.is_empty() and not only.has(path.get_file().get_basename()):
			continue
		change_scene_to_file(path)
		for k in 90:
			await process_frame
		var vp := root.get_viewport()
		var t0: int = Time.get_ticks_usec()
		for k in 30:
			await process_frame
		var ms: float = (Time.get_ticks_usec() - t0) / 30000.0
		var lights: int = 0
		var meshes: int = 0
		for n in current_scene.find_children("*", "Light3D", true, false):
			if (n as Light3D).visible:
				lights += 1
		meshes = current_scene.find_children("*", "GeometryInstance3D", true, false).size()
		print("%-8s draw %5d (그림자 %5d) 물체 %5d 삼각형 %7dk  빛 %3d  그림물체 %5d  노드 %6d  %.1fms" % [
			path.get_file().get_basename(),
			vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
			vp.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
			vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_OBJECTS_IN_FRAME),
			vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME) / 1000,
			lights, meshes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), ms])
	quit()
