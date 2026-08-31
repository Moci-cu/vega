#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec4 sourceRect;
    vec4 cornerRadii;
    float edgeLighting;
    float lowerGlow;
};

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D environmentSource;

float roundedBoxDistance(vec2 point, vec2 halfSize, vec4 radii) {
    float radius = point.x < 0.0
        ? (point.y < 0.0 ? radii.x : radii.w)
        : (point.y < 0.0 ? radii.y : radii.z);
    radius = min(radius, min(halfSize.x, halfSize.y));
    vec2 offset = abs(point) - halfSize + vec2(radius);
    return min(max(offset.x, offset.y), 0.0) + length(max(offset, 0.0)) - radius;
}

void main() {
    vec2 size = max(itemSize, vec2(1.0));
    vec2 point = qt_TexCoord0 * size - size * 0.5;
    float distance = roundedBoxDistance(point, size * 0.5, cornerRadii);
    float antialias = max(fwidth(distance) * 1.8, 1.6);
    float coverage = 1.0 - smoothstep(-antialias, antialias, distance);
    float edgeDistance = max(-distance, 0.0);
    vec2 edgeNormal = normalize(vec2(dFdx(distance), dFdy(distance)) + vec2(0.0001));

    vec2 pixelUv = sourceRect.zw / size;
    vec2 backdropUv = sourceRect.xy + qt_TexCoord0 * sourceRect.zw;
    float opticalFacing = pow(clamp(-edgeNormal.y, 0.0, 1.0), 1.8);
    float lens = (1.0 - smoothstep(0.0, 9.0, edgeDistance))
        * opticalFacing * coverage;
    vec2 nearUv = clamp(backdropUv + edgeNormal * pixelUv * mix(1.5, 5.5, lens),
        vec2(0.001), vec2(0.999));
    vec2 farUv = clamp(backdropUv + edgeNormal * pixelUv * 8.0,
        vec2(0.001), vec2(0.999));
    vec3 localScene = texture(environmentSource, backdropUv).rgb;
    vec3 nearScene = texture(environmentSource, nearUv).rgb;
    vec3 farScene = texture(environmentSource, farUv).rgb;
    vec3 refractedScene = nearScene * 0.72 + farScene * 0.28;
    vec3 localSoftScene = texture(source, backdropUv).rgb;
    vec3 softScene = texture(source, nearUv).rgb * 0.72
        + texture(source, farUv).rgb * 0.28;
    vec2 tangentUv = vec2(-edgeNormal.y * pixelUv.x,
        edgeNormal.x * pixelUv.y) * 6.0;
    vec3 tangentSoftScene = softScene * 0.5
        + texture(source, clamp(nearUv + tangentUv, vec2(0.001), vec2(0.999))).rgb * 0.25
        + texture(source, clamp(nearUv - tangentUv, vec2(0.001), vec2(0.999))).rgb * 0.25;

    vec3 positiveRefraction = max(softScene - localSoftScene, vec3(0.0));
    float localLuminance = dot(localScene, vec3(0.2126, 0.7152, 0.0722));
    float refractedLuminance = dot(refractedScene, vec3(0.2126, 0.7152, 0.0722));
    float contrast = clamp(abs(refractedLuminance - localLuminance) * 3.0, 0.0, 1.0);
    float lightEnergy = clamp(smoothstep(0.025, 0.86, refractedLuminance)
        + contrast * 0.36, 0.0, 1.0);
    float caustic = pow(smoothstep(0.10, 0.92, lightEnergy), 1.35);
    float bloomLuminance = dot(tangentSoftScene, vec3(0.2126, 0.7152, 0.0722));
    float bloomCaustic = pow(smoothstep(0.08, 0.82, bloomLuminance), 1.2);
    float strength = clamp(edgeLighting, 0.0, 1.0)
        * mix(0.58, 1.0, clamp(lowerGlow, 0.0, 1.0));

    float core = (1.0 - smoothstep(0.0, 1.75, abs(distance + 0.65)))
        * opticalFacing * coverage * strength;
    float bloom = smoothstep(0.45, 1.4, edgeDistance)
        * (1.0 - smoothstep(1.4, 5.5, edgeDistance))
        * opticalFacing * coverage * strength * clamp(lowerGlow, 0.0, 1.0);
    float depth = smoothstep(1.2, 3.4, edgeDistance)
        * (1.0 - smoothstep(3.4, 9.0, edgeDistance)) * lens * strength;
    float innerFresnel = smoothstep(1.8, 4.0, edgeDistance)
        * (1.0 - smoothstep(4.0, 13.0, edgeDistance))
        * opticalFacing * coverage * strength;
    float bodyDiffusion = smoothstep(6.0, 13.0, edgeDistance)
        * (1.0 - smoothstep(13.0, 30.0, edgeDistance))
        * opticalFacing * coverage * strength * clamp(lowerGlow, 0.0, 1.0);

    vec3 lightColor = clamp(softScene, 0.0, 1.0);
    vec3 bloomColor = clamp(tangentSoftScene, 0.0, 1.0);
    vec3 causticColor = mix(lightColor, vec3(1.0), 0.14 * caustic);
    vec3 refractedLight = positiveRefraction * depth * (0.90 + 1.45 * contrast);
    float localSoftLuminance = dot(localSoftScene, vec3(0.2126, 0.7152, 0.0722));
    float softLuminance = dot(softScene, vec3(0.2126, 0.7152, 0.0722));
    vec3 bodyRefraction = positiveRefraction * bodyDiffusion
        * (0.30 + 1.0 * contrast);
    float materialEnergy = pow(smoothstep(0.06, 0.86, refractedLuminance), 1.1);
    vec3 materialEmission = vec3(1.0)
        * (innerFresnel * 0.060 + bodyDiffusion * 0.040) * materialEnergy;
    vec3 emission = causticColor * core * mix(0.004, 0.95, caustic)
        + bloomColor * bloom * mix(0.002, 0.18, bloomCaustic)
        + refractedLight + bodyRefraction + materialEmission;

    float shadow = max(localLuminance - refractedLuminance, 0.0)
        * depth * 0.16;
    float bodyShadow = max(localSoftLuminance - softLuminance, 0.0)
        * bodyDiffusion * 0.12;
    float materialAlpha = (innerFresnel * 0.012 + bodyDiffusion * 0.018)
        * materialEnergy;
    float alpha = clamp(core * mix(0.16, 0.28, caustic)
        + bloom * mix(0.004, 0.045, bloomCaustic)
        + shadow + bodyShadow + materialAlpha, 0.0, 0.38);
    vec3 premultiplied = lightColor * alpha;
    float emissionAlpha = clamp(max(max(emission.r, emission.g), emission.b), 0.0, 1.0);
    float outputAlpha = emissionAlpha + alpha * (1.0 - emissionAlpha);
    vec3 outputColor = emission + premultiplied * (1.0 - emissionAlpha);
    fragColor = vec4(min(outputColor, vec3(outputAlpha)) * qt_Opacity,
        outputAlpha * qt_Opacity);
}
