extends SceneTree
func _init():
    var pack = PackedScene.new()
    var scene = preload("res://Player/GLBs/mastercharacterClothing.glb").instantiate()
    var anim_player = scene.get_node("AnimationPlayer")
    if anim_player:
        print("Animations found:")
        for anim_name in anim_player.get_animation_list():
            print("- ", anim_name)
    else:
        print("No AnimationPlayer found.")
    quit()
