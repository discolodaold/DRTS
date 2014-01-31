varying vec3 LightDir;
varying vec3 LightColor;

uniform sampler2D colormap;
uniform sampler2D normmap;

void main() {
    vec2 texCoord = gl_TexCoord[0].st;
    vec4 diffuse = texture2D(colormap, texCoord);

    if(diffuse.a < 0.1) discard;

    vec3 norm = texture2D(normmap, texCoord).rgb * 2.0 - 1.0;
    float d = max(dot(normalize(norm), LightDir), 0.0);

    vec3 color =
        ((diffuse.rgb + gl_Color.rgb * max(diffuse.a * 2.0 - 1.0, 0.0)) * d) * min(diffuse.a * 2.0, 1.0);

    gl_FragColor = vec4(color, 1.0);
}

