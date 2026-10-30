#version 450
layout(set = 2, binding = 0) uniform MaterialUniforms {
    vec4 _CameraPosition; // @default = vec4(0.0, 15.0, 0.0, 1.0)
    vec4 _CameraForward; // @default = vec4(0.0, -1.0, 0.0, 0.0)
    float _Phase; // @default = 0.0
} uMaterial;
layout(location = 0) in vec3 localPosition;
layout(location = 1) in vec3 worldPosition;
layout(location = 2) in vec3 worldNormal;
layout(location = 0) out vec4 outColor;

float hexEdge(vec2 p)
{
    const vec2 spacing = vec2(1.0,1.7320508);
    vec2 a = mod(p,spacing)-spacing*0.5;
    vec2 b = mod(p-spacing*0.5,spacing)-spacing*0.5;
    vec2 cell = dot(a,a)<dot(b,b) ? a : b;
    vec2 q = abs(cell);
    float distanceToEdge = 0.5-max(q.x,dot(q,vec2(0.5,0.8660254)));
    float aa = max(fwidth(distanceToEdge),0.003);
    return 1.0-smoothstep(0.015,0.015+aa,distanceToEdge);
}
void main()
{
    vec3 p = normalize(localPosition);
    vec3 n = normalize(worldNormal);
    vec3 v = uMaterial._CameraPosition.w>0.5 ? normalize(-uMaterial._CameraForward.xyz)
        : normalize(uMaterial._CameraPosition.xyz-worldPosition);
    float t = uMaterial._Phase;
    float fresnel = pow(1.0-clamp(dot(n,v),0.0,1.0),2.6);
    float groundRim = exp(-max(p.y,0.0)*85.0);

    // Three planar projections keep the lattice continuous across the dome seam and pole.
    vec3 weights = pow(abs(p),vec3(6.0));
    weights /= max(weights.x+weights.y+weights.z,0.001);
    float lattice = dot(weights,vec3(hexEdge(p.yz*13.0),hexEdge(p.xz*13.0),hexEdge(p.xy*13.0)));

    // Flow is evaluated on 3D surface position; the two travelling wavefronts cross in different directions.
    float phaseA = dot(p,vec3(1.8,5.5,1.1))-t*1.05;
    float phaseB = dot(p,vec3(-2.1,3.2,2.5))+t*0.72;
    float waveA = pow(0.5+0.5*sin(phaseA*6.2831853),22.0);
    float waveB = pow(0.5+0.5*sin(phaseB*6.2831853),32.0);
    float flow = (waveA*0.75+waveB*0.4)*(0.5+0.5*sin(dot(p,vec3(2.0,-1.0,3.0))+t*0.65));
    float broadGlow = pow(0.5+0.5*sin(phaseA*6.2831853),4.0);
    float highlight = pow(max(dot(n,normalize(vec3(-0.45,0.8,-0.4))),0.0),12.0);
    float shell = 0.025+fresnel*0.32+groundRim*0.35;
    float filaments = lattice*(0.025+flow*0.13)+flow*0.075;
    float alpha = clamp(shell+filaments+broadGlow*0.018+highlight*0.06,0.0,0.72);
    vec3 tint = mix(vec3(0.06,0.36,0.8),vec3(0.22,1.0,1.4),0.25+fresnel*0.75);
    // Emission is independent of shell opacity, keeping the interior readable as the rim brightens.
    vec3 glow = vec3(0.22,0.9,1.5)*(groundRim*0.75+fresnel*0.4+flow*0.32+lattice*0.04+lattice*flow*0.15);
    glow += vec3(0.35,0.7,0.95)*highlight*0.14;
    outColor = vec4(tint*alpha+glow,alpha);
}
