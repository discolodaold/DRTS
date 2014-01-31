varying vec3 LightDirection;
uniform vec3 LightPos;

void main() {
	LightDirection = LightPos - gl_Vertex.xyz;
    gl_Position = ftransform();
}

