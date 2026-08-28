#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec4 sourceRect;
    vec4 cornerRadii;
    vec4 glassTint;
    vec2 lightDirection;
    float refraction;
    float enhancedOptics;
    float interactiveOptics;
    float responsiveOptics;
    float interaction;
    vec2 interactionPoint;
    float thicknessOverride;
    float edgeLighting;
};

layout(binding = 1) uniform sampler2D source;

float roundedBoxDistance(vec2 point, vec2 halfSize, vec4 radii) {
    float radius = point.x < 0.0
        ? (point.y < 0.0 ? radii.x : radii.w)
        : (point.y < 0.0 ? radii.y : radii.z);
    radius = min(radius, min(halfSize.x, halfSize.y));
    vec2 offset = abs(point) - halfSize + vec2(radius);
    return min(max(offset.x, offset.y), 0.0) + length(max(offset, 0.0)) - radius;
}

vec3 sampleScatteredBackdrop(vec2 uv, vec2 pixelUv, float radius) {
    vec2 horizontal = vec2(pixelUv.x * radius, 0.0);
    vec2 vertical = vec2(0.0, pixelUv.y * radius);
    vec2 low = vec2(0.001);
    vec2 high = vec2(0.999);
    vec3 color = texture(source, clamp(uv, low, high)).rgb * 0.24;
    color += texture(source, clamp(uv + horizontal, low, high)).rgb * 0.12;
    color += texture(source, clamp(uv - horizontal, low, high)).rgb * 0.12;
    color += texture(source, clamp(uv + vertical, low, high)).rgb * 0.12;
    color += texture(source, clamp(uv - vertical, low, high)).rgb * 0.12;
    color += texture(source, clamp(uv + horizontal + vertical, low, high)).rgb * 0.07;
    color += texture(source, clamp(uv + horizontal - vertical, low, high)).rgb * 0.07;
    color += texture(source, clamp(uv - horizontal + vertical, low, high)).rgb * 0.07;
    color += texture(source, clamp(uv - horizontal - vertical, low, high)).rgb * 0.07;
    return color;
}

void main() {
    vec2 size = max(itemSize, vec2(1.0));
    vec2 point = qt_TexCoord0 * size - size * 0.5;
    float distance = roundedBoxDistance(point, size * 0.5, cornerRadii);
    float antialias = max(fwidth(distance), 0.75);
    float coverage = 1.0 - smoothstep(-antialias, antialias, distance);

    float edgeDistance = max(-distance, 0.0);
    vec2 edgeNormal = normalize(vec2(dFdx(distance), dFdy(distance)) + vec2(0.0001));
    vec2 radialDirection = point / max(length(point), 1.0);
    float interactive = step(0.5, interactiveOptics);
    float responsive = step(0.5, responsiveOptics);
    float opticalMotion = max(interactive, responsive);
    float interactionAmount = clamp(interaction, 0.0, 1.0);
    float expansion = interactive * smoothstep(64.0, 420.0, size.y);
    float thickness = thicknessOverride >= 0.0
        ? clamp(thicknessOverride, 0.0, 1.0)
        : smoothstep(56.0, 420.0, min(size.x, size.y));
    thickness = mix(thickness, max(thickness, 0.18), responsive);
    float barEdgeLens = 1.0 - smoothstep(1.0, 9.0, edgeDistance);
    float glassEdgeLens = smoothstep(0.0, 1.25, edgeDistance)
        * (1.0 - smoothstep(1.25, 7.0, edgeDistance));
    float responsiveEdgeLens = 0.45 * (1.0 - smoothstep(0.0, 2.2, edgeDistance))
        + smoothstep(0.6, 2.4, edgeDistance) * (1.0 - smoothstep(2.4, 8.0, edgeDistance));
    float interactiveEdgeLens = smoothstep(0.0, 1.4, edgeDistance)
        * (1.0 - smoothstep(1.4, mix(7.0, 9.0, expansion), edgeDistance));
    float edgeLens = mix(mix(barEdgeLens, glassEdgeLens, enhancedOptics), responsiveEdgeLens, responsive);
    edgeLens = mix(edgeLens, interactiveEdgeLens, interactive);
    vec2 direction = mix(mix(radialDirection, edgeNormal, enhancedOptics), edgeNormal, responsive);
    vec2 pointerOffset = (qt_TexCoord0 - interactionPoint) * size;
    float pointerFalloff = exp(-length(pointerOffset) / max(40.0, min(size.x, size.y) * 0.65));
    vec2 pointerDirection = normalize(-pointerOffset + vec2(0.0001));
    direction = normalize(mix(direction, pointerDirection,
        interactive * interactionAmount * pointerFalloff * 0.12));
    vec2 pixelUv = sourceRect.zw / size;
    vec2 backdropUv = sourceRect.xy + qt_TexCoord0 * sourceRect.zw;
    float lensStrength = refraction * mix(1.0, 0.45, enhancedOptics);
    float materialization = smoothstep(0.0, 1.0, qt_Opacity);
    lensStrength = mix(lensStrength,
        refraction * mix(1.05, 1.35, thickness) * (1.0 + 0.18 * interactionAmount) * materialization,
        responsive);
    lensStrength *= 1.0 + interactive * (0.24 * expansion + 0.12 * interactionAmount * pointerFalloff);
    lensStrength *= mix(1.0, materialization, interactive);
    backdropUv += direction * pixelUv * lensStrength * edgeLens;
    backdropUv = clamp(backdropUv, vec2(0.001), vec2(0.999));

    vec3 backdrop = texture(source, backdropUv).rgb;
    if (responsive > 0.5) {
        float scatterRadius = mix(1.4, 3.2, thickness);
        vec3 scattered = sampleScatteredBackdrop(backdropUv, pixelUv, scatterRadius);
        backdrop = mix(backdrop, scattered, 0.28 + 0.22 * thickness + 0.04 * interactionAmount);
    }

    float backdropLuminance = dot(backdrop, vec3(0.2126, 0.7152, 0.0722));
    if (enhancedOptics > 0.5) {
        float luminanceShift = (0.46 - backdropLuminance) * mix(0.10, 0.14, thickness);
        backdrop = clamp(backdrop + vec3(luminanceShift), 0.0, 1.0);
        float shiftedLuminance = dot(backdrop, vec3(0.2126, 0.7152, 0.0722));
        float saturation = mix(1.02, 0.82, thickness);
        backdrop = clamp(mix(vec3(shiftedLuminance), backdrop, saturation), 0.0, 1.0);
        float dynamicRange = mix(0.92, 0.62, thickness);
        backdrop = clamp(vec3(0.5) + (backdrop - vec3(0.5)) * dynamicRange, 0.0, 1.0);
    } else if (responsive > 0.5) {
        backdrop = clamp(backdrop + vec3((0.50 - backdropLuminance) * 0.045), 0.0, 1.0);
        float shiftedLuminance = dot(backdrop, vec3(0.2126, 0.7152, 0.0722));
        backdrop = clamp(vec3(0.5) + (backdrop - vec3(0.5)) * mix(0.98, 0.90, thickness), 0.0, 1.0);
        backdrop = mix(vec3(shiftedLuminance), backdrop, 0.97);
    }

    float tintAlpha = glassTint.a;
    if (enhancedOptics > 0.5)
        tintAlpha = clamp(tintAlpha + 0.055 + 0.18 * thickness + 0.075 * smoothstep(0.58, 0.92, backdropLuminance), 0.0, 0.80);
    else if (responsive > 0.5)
        tintAlpha = clamp(tintAlpha + 0.065 + 0.05 * thickness + 0.015 * smoothstep(0.75, 0.95, backdropLuminance), 0.0, 0.58);
    vec3 color = mix(backdrop, glassTint.rgb, tintAlpha);

    vec2 responsiveLight = normalize(lightDirection
        + vec2((interactionPoint.x - 0.5) * 0.70, (interactionPoint.y - 0.5) * 0.35));
    vec2 activeLight = normalize(mix(normalize(lightDirection), responsiveLight, opticalMotion));
    float facingLight = max(dot(edgeNormal, activeLight), 0.0);
    float rim = (1.0 - smoothstep(0.25, 2.0, edgeDistance)) * coverage;
    float specular = rim * (0.14 + 0.34 * pow(facingLight, 2.5));
    float edgeLight = clamp(edgeLighting, 0.0, 1.0);
    if (responsive > 0.5) {
        float innerRim = smoothstep(0.8, 2.4, edgeDistance)
            * (1.0 - smoothstep(2.4, 5.8, edgeDistance)) * coverage;
        float depthRim = smoothstep(3.4, 5.2, edgeDistance)
            * (1.0 - smoothstep(5.2, 9.0, edgeDistance)) * coverage;
        float keyHighlight = pow(facingLight, 4.0);
        float interactionGlow = interactionAmount * pointerFalloff;
        specular = rim * (0.065 + 0.30 * keyHighlight)
            + innerRim * (0.02 + 0.105 * keyHighlight)
            + depthRim * 0.025 * keyHighlight
            + (rim + 0.45 * innerRim) * 0.13 * interactionGlow;

        vec2 spillUv = clamp(backdropUv + activeLight * pixelUv * mix(4.0, 8.0, thickness), vec2(0.001), vec2(0.999));
        vec2 spillTangent = vec2(-edgeNormal.y * pixelUv.x, edgeNormal.x * pixelUv.y) * mix(2.5, 4.0, thickness);
        vec2 depthUv = clamp(backdropUv - edgeNormal * pixelUv * mix(2.5, 4.5, thickness), vec2(0.001), vec2(0.999));
        vec3 ambientSpill = texture(source, spillUv).rgb * 0.5
            + texture(source, clamp(spillUv + spillTangent, vec2(0.001), vec2(0.999))).rgb * 0.25
            + texture(source, clamp(spillUv - spillTangent, vec2(0.001), vec2(0.999))).rgb * 0.25;
        color = mix(color, ambientSpill, innerRim * 0.06);
        color = mix(color, texture(source, depthUv).rgb, depthRim * (0.10 + 0.05 * interactionAmount));
        color = mix(color, vec3(1.0), clamp(specular * edgeLight, 0.0, 0.48));

        float lowerFacing = smoothstep(0.05, 0.90, edgeNormal.y);
        float lowerHighlight = lowerFacing * (0.10 * rim + 0.048 * innerRim + 0.015 * depthRim);
        color = mix(color, vec3(1.0), lowerHighlight * edgeLight);

        float opposingLight = pow(max(dot(edgeNormal, -activeLight), 0.0), 2.5);
        color *= 1.0 - (rim * 0.075 + innerRim * 0.035) * opposingLight * (1.0 + 0.25 * thickness) * edgeLight;
    } else if (interactive > 0.5) {
        float innerRim = smoothstep(0.8, 2.4, edgeDistance)
            * (1.0 - smoothstep(2.4, mix(6.2, 8.2, expansion), edgeDistance)) * coverage;
        float depthRim = smoothstep(3.0, 4.8, edgeDistance)
            * (1.0 - smoothstep(4.8, mix(7.0, 9.5, expansion), edgeDistance)) * coverage;
        float interactionGlow = interactionAmount * pointerFalloff;
        specular = rim * (0.08 + 0.28 * pow(facingLight, 3.5))
            + innerRim * (0.018 + 0.07 * facingLight + 0.025 * expansion)
            + (rim + 0.4 * innerRim) * 0.10 * interactionGlow;

        float ambientLuminance = dot(backdrop, vec3(0.2126, 0.7152, 0.0722));
        vec3 ambientSpill = clamp(backdrop
            + (backdrop - vec3(ambientLuminance)) * 0.22, 0.0, 1.0);
        color = mix(color, ambientSpill,
            innerRim * (0.035 + 0.045 * expansion) + rim * 0.018 * expansion);
        color = mix(color, vec3(1.0), clamp(specular * edgeLight, 0.0, 0.40));

        float opposingLight = pow(max(dot(edgeNormal, -activeLight), 0.0), 2.5);
        float edgeShadow = (rim * (0.045 + 0.025 * expansion)
            + innerRim * (0.012 + 0.022 * expansion)) * opposingLight
            + depthRim * 0.018 * expansion;
        color *= 1.0 - edgeShadow * edgeLight;
    } else {
        color = mix(color, vec3(1.0), specular * edgeLight);
        color *= 1.0 - rim * (1.0 - facingLight) * 0.045 * edgeLight;
    }

    float alpha = coverage * qt_Opacity;
    fragColor = vec4(color * alpha, alpha);
}
