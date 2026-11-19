extends Node
## GD-Sync로 바이트를 건네는 작은 노드(22단계). 두 쪽의 노드 경로가 같아야 GD-Sync가 원격 호출을 이어 주므로
## 늘 /root/GdSyncRelay 하나다(GdSyncLink가 만들고 치운다). 시간도 여기서 흘려 준다.

var link: GdSyncLink


## 상대가 call_func로 보낸 바이트(GDSync.expose_func로 열어 둔다).
func receive(data: PackedByteArray) -> void:
	if link != null:
		link.on_remote(data)


func _process(delta: float) -> void:
	if link != null:
		link.poll(delta)
