## Animates the Entity's [AnimatedSprite2D] based on the [TileBasedPositionComponent]'s movement.
## Requirements: [TileBasedPositionComponent], [AnimatedSprite2D]

class_name TileBasedAnimationComponent
extends Component


#region Parameters
@export var idleAnimation: StringName = &"idle"
@export var walkAnimation: StringName = &"walk"

@export var flipWhenWalkingLeft: bool = true
@export var isEnabled := true
#endregion


#region State

var tileBasedPositionComponent: TileBasedPositionComponent:
	get:
		if not tileBasedPositionComponent: tileBasedPositionComponent = self.getCoComponent(TileBasedPositionComponent)
		return tileBasedPositionComponent

var animatedSprite: AnimatedSprite2D:
	get:
		if not animatedSprite: animatedSprite = parentEntity.findFirstChildOfType(AnimatedSprite2D)
		return animatedSprite

#endregion


## Returns a list of required component types that this component depends on.
func getRequiredcomponents() -> Array[Script]:
	return [TileBasedPositionComponent]


func _ready() -> void:
	tileBasedPositionComponent.willStartMovingToNewTile.connect(onTileBasedPositionComponent_willStartMovingToNewTile)
	tileBasedPositionComponent.didArriveAtNewTile.connect(onTileBasedPositionComponent_didArriveAtNewTile)


func onTileBasedPositionComponent_willStartMovingToNewTile(newDestination: Vector2i) -> void:
	if not isEnabled: return
	
	animatedSprite.play(walkAnimation)
	
	if flipWhenWalkingLeft:
		animatedSprite.flip_h = tileBasedPositionComponent.inputVector.x < 0


func onTileBasedPositionComponent_didArriveAtNewTile(newDestination: Vector2i) -> void:
	if not isEnabled: return
	
	animatedSprite.play(idleAnimation)
