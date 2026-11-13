extends AudioStreamPlayer

func _ready() -> void:
	if stream is AudioStreamMP3:
		var looping_stream := stream.duplicate() as AudioStreamMP3
		looping_stream.loop = true
		stream = looping_stream
	play()
