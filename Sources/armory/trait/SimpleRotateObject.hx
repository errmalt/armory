package armory.trait;

import iron.math.Vec4;
import iron.system.Input;
import armory.trait.physics.RigidBody;

/**
    Simple script to rotate an object around using the keyboard with RT(x), FG(y), VB(z).
	Can be used for testing and debuging.
**/
class SimpleRotateObject extends iron.Trait {

	@prop
	var speed:Float = 0.1;

	var keyboard:Keyboard;
	var rb:RigidBody;

	public function new() {
		super();

		notifyOnInit(function() {
			rb = object.getTrait(RigidBody);
			keyboard = Input.getKeyboard();
		});

		notifyOnUpdate(function() {
			var rotate = Vec4.zero();

			if(keyboard.down("r")){
				rotate.x += 1;
			}

			if(keyboard.down("t")){
				rotate.x -= 1;
			}

			if(keyboard.down("f")){
				rotate.y += 1;
			}

			if(keyboard.down("g")){
				rotate.y -= 1;
			}

			if(keyboard.down("v")){
				rotate.z += 1;
			}

			if(keyboard.down("b")){
				rotate.z -= 1;
			}

			if(!rotate.equals(Vec4.zero())){
				rotateObject(rotate);
			}
		});
	}

	function rotateObject(vec:Vec4){
		if(rb != null){
			rb.setAngularVelocity(0, 0, 0);
			rb.transform.rotate(vec, speed);
			rb.syncTransform();
		} else {
			object.transform.rotate(vec, speed);
		}
	}
}
