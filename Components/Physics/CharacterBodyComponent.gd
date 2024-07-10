## Manages updates to a [CharacterBody2D]. Ensures that [method CharacterBody2D.move_and_slide] is called only once every frame (to prevent excessive movement) and updates related flags.
## Components which need to process updates AFTER the [CharacterBody2D] moves must connect to the [signal CharacterBodyComponent.didMove] signal.
## NOTE: This component must come AFTER all other components which move the body, like [JumpControlComponent].
## @experimental

class_name CharacterBodyComponent
extends Component

# TODO: Call move_and_slide() and update flags only when requested by other components?


#region Parameters

## If `null` then it will be acquired from the parent [Entity] on [method _enter_tree()]
@export var body: CharacterBody2D:
	get:
		if body == null and not skipFirstWarning:
			printWarning("body is null! Call parentEntity.getBody() to find and remember the Entity's CharacterBody2D")
		return body

#endregion


#region State

var wasOnFloor:		bool ## Was the body on the floor before the last [method CharacterBody2D.move_and_slide]?
var wasOnWall:		bool ## Was the body on a wall before the last [method CharacterBody2D.move_and_slide]?
var wasOnCeiling:	bool ## Was the body on a ceiling before the last [method CharacterBody2D.move_and_slide]?

var previousWallNormal: Vector2 ## The direction of the wall we were in contact with.

## This avoids the superfluous warning when checking the [member body] for the first time in [method _enter_tree()].
var skipFirstWarning:		bool = true

var shouldMoveThisFrame:	bool = false

#endregion


#region Signals
signal didMove ## Emitted after [method CharacterBody2D.move_and_slide]
#endregion


# Called whenever the node enters the scene tree.
func _enter_tree() -> void:
	super._enter_tree()
	
	if self.body == null and parentEntity != null:
		self.body = parentEntity.getBody()
	
	if not body:
		printError("Missing CharacterBody2D in parent Entity: \n" + parentEntity.logFullName)


func _physics_process(delta: float) -> void:
	# DEBUG: printLog("_physics_process()")
	
	if self.shouldMoveThisFrame:
		updateStateBeforeMove()
		body.move_and_slide()
		updateStateAfterMove()
		
		self.shouldMoveThisFrame = false # Reset the flag so we don't move more than once.
		didMove.emit()


func queueMoveAndSlide():
	self.shouldMoveThisFrame = true


func updateStateBeforeMove():
	self.wasOnFloor		= body.is_on_floor()
	self.wasOnWall		= body.is_on_wall()
	self.wasOnCeiling	= body.is_on_ceiling()
	
	if wasOnWall: 
		self.previousWallNormal = body.get_wall_normal()


func updateStateAfterMove():
	pass
