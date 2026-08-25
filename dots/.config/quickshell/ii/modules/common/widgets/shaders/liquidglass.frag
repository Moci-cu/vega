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

void main() {
    vec2 size = max(itemSize, vec2(1.0));
    vec2 point = qt_TexCoord0 * size - size * 0.5;
    float distance = roundedBoxDistance(point, size * 0.5, vec4(min(size.x, size.y) * 0.5));
    float antialias = max(fwidth(distance), 0.75);
    float coverage = 1.0 - smoothstep(-antialias, antialias, distance);

    float edgeDistance = max(-distance, 0.0);
    float edgeLens = 1.0 - smoothstep(1.0, 9.0, edgeDistance);
    vec2 direction = point / max(length(point), 1.0);
    vec2 pixelUv = sourceRect.zw / size;
    vec2 wallpaperUv = sourceRect.xy + qt_TexCoord0 * sourceRect.zw;
    wallpaperUv += direction * pixelUv * refraction * edgeLens;
    wallpaperUv = clamp(wallpaperUv, vec2(0.001), vec2(0.999));

    vec3 color = texture(source, wallpaperUv).rgb;
    color = mix(color, glassTint.rgb, glassTint.a);

    vec2 edgeNormal = normalize(vec2(dFdx(distance), dFdy(distance)) + vec2(0.0001));
    float facingLight = max(dot(edgeNormal, normalize(lightDirection)), 0.0);
    float rim = (1.0 - smoothstep(0.25, 2.0, edgeDistance)) * coverage;
    float specular = rim * (0.14 + 0.34 * pow(facingLight, 2.5));
    color = mix(color, vec3(1.0), specular);
    color *= 1.0 - rim * (1.0 - facingLight) * 0.045;

    float alpha = coverage * qt_Opacity;
    fragColor = vec4(color * alpha, alpha);
}
