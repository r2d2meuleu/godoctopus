## Base class for components which depend on a [CharacterBodyComponent] to manipulate a [CharacterBody2D] before and after it moves during each frame.
## Components which need to perform updates AFTER [method CharacterBody2D.move_and_slide] must connect to the [signal CharacterBodyComponent.didMove] signal.
## NOTE: This is NOT the base class for the [CharacterBodyComponent] itself.
## @experimental

class_name CharacterBodyManipulatingComponentBase
extends Component


#region Parameters
#endregion


#region State

var characterBodyComponent: CharacterBodyComponent:
	get:
		# NOTE: Use [findFirstChildOfType()] instead of [getCoComponent()] so that subclasses of [CharacterBodyComponent] may be used.
		if not characterBodyComponent: characterBodyComponent = parentEntity.findFirstComponentSublcass(CharacterBodyComponent)
		return characterBodyComponent

var body: CharacterBody2D:
	get:
		if not body: body = characterBodyComponent.body
		return body
		
#endregion


func getRequiredComponents() -> Array[Script]:
	return [CharacterBodyComponent]


# Called whenever the node enters the scene tree.
func ready():
	#super._enter_tree()
	
	if not self.characterBodyComponent:
		printError("Missing CharacterBody2D in parent Entity: \n" + parentEntity.logFullName)
