varying vec3 LightDirection;
varying vec3 LightColor;

uniform vec3 LightPos;

void main() {
	LightDirection = LightPos - gl_Vertex.xyz;

	gl_TexCoord[0] = gl_MultiTexCoord0;
    gl_Position = ftransform();
}

