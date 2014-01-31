varying vec3 LightDirection;

uniform sampler2D diffusemap;
uniform sampler2D normalmap;
uniform vec4 LightColor;

void main() {
	vec3 Diffuse = texture2D(diffusemap, gl_TexCoord[0].xy).rgb;
	vec3 Normal = normalize(texture2D(normalmap, gl_TexCoord[0].xy).rgb - 0.5);

	float LightLength = length(LightDirection);
	float LightAttenuation = max((LightColor.a / LightLength) * ((LightColor.a - LightLength) / LightColor.a), 0.0);
	vec3 LightDirNormal = normalize(LightDirection);

	vec3 Light = LightColor.rgb * max(dot(Normal, LightDirNormal), 0.0) * LightAttenuation;

	gl_FragColor = vec4(Light * Diffuse, 1.0);
}

