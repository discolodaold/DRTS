varying vec3 LightDir;
varying vec3 LightColor;

uniform float time;

void main() {
    LightDir = normalize(vec3(sin(time), cos(time), 1.0));
    LightColor = vec3(0.95, 0.95, 0.85);

    gl_TexCoord[0] = gl_MultiTexCoord0;
    gl_Position = ftransform();
    gl_FrontColor = gl_Color;
}
