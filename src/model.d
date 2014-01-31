module model;

import glutil : GLTexture2D;

abstract class Model {
	abstract render(Matrix2x2 matrix);
}

class Sprite : Model {
	this(GLTexture2D tex) {
		diffuse = tex;
	}

	override render(Matrix2x2 matrix) {
		
	}

private:
	GLTexture2D diffuse;
}
