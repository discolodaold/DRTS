varying vec3 LightDirection;

uniform sampler2D skymap;
uniform sampler2D colormap;
uniform sampler2D normmap;

uniform vec2 camera;
uniform vec4 LightColor;

vec4 linearstep(vec4 lo, vec4 hi, float input) {
    return lo * (1.0 - input) + hi * input;
}

vec3 linearstep(vec3 lo, vec3 hi, float input) {
    return lo * (1.0 - input) + hi * input;
}

vec4 terrain(float A) {
    if(A > 0.9)
        return vec4(1.0, 1.0, 1.0, 1.0);
    else if(A > 0.8)
        return linearstep(vec4(0.35, 0.6, 0.35, 1.0), vec4(1.0, 1.0, 1.0, 1.0), (A - 0.8) / 0.1);
    else if(A > 0.3)
        return linearstep(vec4(0.25, 0.5, 0.25, 1.0), vec4(0.35, 0.6, 0.35, 1.0), (A - 0.3) / 0.5);
    else if(A > 0.15)
        return linearstep(vec4(1.0, 1.0, 0.0, 1.0), vec4(0.25, 0.5, 0.25, 1.0), (A - 0.15) / 0.15);
    else if(A > 0.1)
        return linearstep(vec4(0.2, 0.2, 0.5, 0.5), vec4(1.0, 1.0, 0.0, 1.0), (A - 0.1) / 0.05);
    else
        return vec4(0.2, 0.2, 0.5, 0.5);
}

void main() {
	vec2 DiffuseCoord = gl_TexCoord[0].xy;
	vec2 DetailCoord = gl_TexCoord[0].xy * 4.0;
	vec2 SkyCoord  = gl_TexCoord[0].xy + (camera * 0.0001);

	vec4 COL = texture2D(colormap, DiffuseCoord);

	vec4 diffuse = terrain(COL.a);

	vec3 TerrainNormal = COL.rgb * 2.0 - 1.0;
	vec3 DetailNormal = texture2D(normmap, DetailCoord).rgb * 2.0 - 1.0;
	vec3 Normal = normalize(TerrainNormal*4 + DetailNormal);

	float LightLength = length(LightDirection);
	float LightAttenuation = max((LightColor.a / LightLength) * ((LightColor.a - LightLength) / LightColor.a), 0.0);
	vec3 LightDirNormal = normalize(LightDirection);
	vec3 Light = LightColor.rgb * max(dot(Normal, LightDirNormal), 0.0) * LightAttenuation;

	vec3 Sky = texture2D(skymap, SkyCoord).rgb;

	gl_FragColor = vec4(linearstep(Sky, Light * diffuse.rgb, diffuse.a), 1.0);
}

