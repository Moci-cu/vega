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
};

layout(binding = 1) uniform sampler2D source;

vec3 sampleGaussianBackdrop(vec2 uv, vec2 texelSize) {
    vec2 offset = texelSize * 1.2;
    vec2 low = vec2(0.001);
    vec2 high = vec2(0.999);
    vec3 color = texture(source, clamp(uv, low, high)).rgb * 0.140625;
    color += texture(source, clamp(uv + vec2(offset.x, 0.0), low, high)).rgb * 0.1171875;
    color += texture(source, clamp(uv - vec2(offset.x, 0.0), low, high)).rgb * 0.1171875;
    color += texture(source, clamp(uv + vec2(0.0, offset.y), low, high)).rgb * 0.1171875;
    color += texture(source, clamp(uv - vec2(0.0, offset.y), low, high)).rgb * 0.1171875;
    color += texture(source, clamp(uv + offset, low, high)).rgb * 0.09765625;
    color += texture(source, clamp(uv - offset, low, high)).rgb * 0.09765625;
    color += texture(source, clamp(uv + vec2(offset.x, -offset.y), low, high)).rgb * 0.09765625;
    color += texture(source, clamp(uv + vec2(-offset.x, offset.y), low, high)).rgb * 0.09765625;
    return color;
}

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
    float antialias = max(fwidth(distance), 0.75);
    float coverage = 1.0 - smoothstep(-antialias, antialias, distance);

    float edgeDistance = max(-distance, 0.0);
    vec2 edgeNormal = normalize(vec2(dFdx(distance), dFdy(distance)) + vec2(0.0001));
    vec2 radialDirection = point / max(length(point), 1.0);
    float thickness = smoothstep(56.0, 420.0, min(size.x, size.y));
    float barEdgeLens = 1.0 - smoothstep(1.0, 9.0, edgeDistance);
    float glassEdgeLens = smoothstep(0.0, 1.25, edgeDistance)
        * (1.0 - smoothstep(1.25, 7.0, edgeDistance));
    float edgeLens = mix(barEdgeLens, glassEdgeLens, enhancedOptics);
    vec2 direction = mix(radialDirection, edgeNormal, enhancedOptics);
    vec2 pixelUv = sourceRect.zw / size;
    vec2 backdropUv = sourceRect.xy + qt_TexCoord0 * sourceRect.zw;
    float lensStrength = refraction * mix(1.0, 0.45, enhancedOptics);
    backdropUv += direction * pixelUv * lensStrength * edgeLens;
    backdropUv = clamp(backdropUv, vec2(0.001), vec2(0.999));

    vec3 backdrop = texture(source, backdropUv).rgb;
    if (enhancedOptics > 0.5) {
        float blurScale = mix(1.0, 1.8, thickness);
        backdrop = sampleGaussianBackdrop(backdropUv, pixelUv * blurScale);
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
    }

    float tintAlpha = glassTint.a;
    if (enhancedOptics > 0.5)
        tintAlpha = clamp(tintAlpha + 0.055 + 0.18 * thickness + 0.075 * smoothstep(0.58, 0.92, backdropLuminance), 0.0, 0.80);
    vec3 color = mix(backdrop, glassTint.rgb, tintAlpha);

    float facingLight = max(dot(edgeNormal, normalize(lightDirection)), 0.0);
    float rim = (1.0 - smoothstep(0.25, 2.0, edgeDistance)) * coverage;
    float specular = rim * (0.14 + 0.34 * pow(facingLight, 2.5));
    color = mix(color, vec3(1.0), specular);
    color *= 1.0 - rim * (1.0 - facingLight) * 0.045;

    float alpha = coverage * qt_Opacity;
    fragColor = vec4(color * alpha, alpha);
}
