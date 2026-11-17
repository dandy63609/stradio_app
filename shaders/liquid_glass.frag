#version 460 core
#include <flutter/runtime_effect.glsl>

// Ported from https://github.com/dashersw/liquid-glass-js (MIT License)
// for STRADIO Flutter (ImageFilter.shader / BackdropFilter).
// Supports rounded rectangle ('rounded'), circle ('circle'), and capsule ('pill') SDF refraction.

uniform vec2 u_resolution;
uniform float u_borderRadius;
uniform float u_warp;
uniform float u_edgeIntensity;
uniform float u_rimIntensity;
uniform float u_baseIntensity;
uniform float u_edgeDistance;
uniform float u_rimDistance;
uniform float u_baseDistance;
uniform float u_cornerBoost;
uniform float u_rippleEffect;
uniform float u_tintOpacity;
uniform sampler2D u_image;

out vec4 fragColor;

float roundedRectDistance(vec2 coord, vec2 size, float radius) {
  vec2 center = size * 0.5;
  vec2 pixelCoord = coord * size;
  vec2 toCorner = abs(pixelCoord - center) - (center - radius);
  float outsideCorner = length(max(toCorner, 0.0));
  float insideCorner = min(max(toCorner.x, toCorner.y), 0.0);
  return (outsideCorner + insideCorner - radius);
}

float circleDistance(vec2 coord, vec2 size, float radius) {
  vec2 centerPixel = size * 0.5;
  vec2 pixelCoord = coord * size;
  return length(pixelCoord - centerPixel) - radius;
}

bool isPill(vec2 size, float radius) {
  float heightRatioDiff = abs(radius - size.y * 0.5);
  return (heightRatioDiff < 2.0) && (size.x > size.y + 4.0);
}

bool isCircle(vec2 size, float radius) {
  float minDim = min(size.x, size.y);
  return (abs(radius - minDim * 0.5) < 1.5) && (abs(size.x - size.y) < 4.0);
}

float pillDistance(vec2 coord, vec2 size, float radius) {
  vec2 center = size * 0.5;
  vec2 pixelCoord = coord * size;
  vec2 capsuleStart = vec2(radius, center.y);
  vec2 capsuleEnd = vec2(size.x - radius, center.y);
  vec2 capsuleAxis = capsuleEnd - capsuleStart;
  float capsuleLength = length(capsuleAxis);
  if (capsuleLength > 0.0) {
    vec2 toPoint = pixelCoord - capsuleStart;
    float t = clamp(dot(toPoint, capsuleAxis) / dot(capsuleAxis, capsuleAxis), 0.0, 1.0);
    vec2 closestPointOnAxis = capsuleStart + t * capsuleAxis;
    return length(pixelCoord - closestPointOnAxis) - radius;
  }
  return length(pixelCoord - center) - radius;
}

void main() {
  vec2 pixelPos = FlutterFragCoord().xy;
  vec2 coord = pixelPos / u_resolution;

  float distFromEdgeShape;
  vec2 shapeNormal;

  if (isPill(u_resolution, u_borderRadius)) {
    distFromEdgeShape = -pillDistance(coord, u_resolution, u_borderRadius);
    vec2 capsuleStart = vec2(u_borderRadius, u_resolution.y * 0.5);
    vec2 capsuleEnd = vec2(u_resolution.x - u_borderRadius, u_resolution.y * 0.5);
    vec2 capsuleAxis = capsuleEnd - capsuleStart;
    vec2 toPoint = pixelPos - capsuleStart;
    float t = clamp(dot(toPoint, capsuleAxis) / max(dot(capsuleAxis, capsuleAxis), 0.0001), 0.0, 1.0);
    vec2 closestPointOnAxis = capsuleStart + t * capsuleAxis;
    vec2 normalDir = pixelPos - closestPointOnAxis;
    shapeNormal = length(normalDir) > 0.0 ? normalize(normalDir) : vec2(0.0, 1.0);
  } else if (isCircle(u_resolution, u_borderRadius)) {
    distFromEdgeShape = -circleDistance(coord, u_resolution, u_borderRadius);
    shapeNormal = normalize(coord - vec2(0.5, 0.5));
  } else {
    distFromEdgeShape = -roundedRectDistance(coord, u_resolution, u_borderRadius);
    shapeNormal = normalize(coord - vec2(0.5, 0.5));
  }

  distFromEdgeShape = max(distFromEdgeShape, 0.0);
  float minDim = min(u_resolution.x, u_resolution.y);
  float distFromEdge = distFromEdgeShape / minDim;
  float normalizedDistance = distFromEdgeShape;

  float baseIntensity = 1.0 - exp(-normalizedDistance * u_baseDistance);
  float edgeIntensity = exp(-normalizedDistance * u_edgeDistance);
  float rimIntensity = exp(-normalizedDistance * u_rimDistance);

  float baseComponent = u_warp > 0.5 ? baseIntensity * u_baseIntensity : 0.0;
  float totalIntensity = baseComponent + edgeIntensity * u_edgeIntensity + rimIntensity * u_rimIntensity;
  vec2 baseRefraction = shapeNormal * totalIntensity;

  float cornerProximity = max(min(coord.x, 1.0 - coord.x), min(coord.y, 1.0 - coord.y)) * minDim;
  float cornerBoost = exp(-cornerProximity * 0.3) * u_cornerBoost;
  vec2 cornerRefraction = shapeNormal * cornerBoost;

  vec2 perpendicular = vec2(-shapeNormal.y, shapeNormal.x);
  float ripple = sin(distFromEdge * 25.0) * u_rippleEffect * rimIntensity;
  vec2 textureRefraction = perpendicular * ripple;

  vec2 refractedUV = clamp(coord + baseRefraction + cornerRefraction + textureRefraction, 0.001, 0.999);
  vec4 sampled = texture(u_image, refractedUV);

  // Warm Ivory (#F5F0E8) daylight glass tint + specular rim catchlight
  vec3 warmIvoryTop = vec3(0.980, 0.968, 0.949);
  vec3 warmIvoryBottom = vec3(0.918, 0.894, 0.863);
  vec3 gradientTint = mix(warmIvoryTop, warmIvoryBottom, coord.y);
  vec3 tinted = mix(sampled.rgb, gradientTint, u_tintOpacity);
  tinted += vec3(rimIntensity * 0.14);

  float maskDistance;
  if (isPill(u_resolution, u_borderRadius)) {
    maskDistance = pillDistance(coord, u_resolution, u_borderRadius);
  } else if (isCircle(u_resolution, u_borderRadius)) {
    maskDistance = circleDistance(coord, u_resolution, u_borderRadius);
  } else {
    maskDistance = roundedRectDistance(coord, u_resolution, u_borderRadius);
  }
  float mask = 1.0 - smoothstep(-1.0, 1.0, maskDistance);

  fragColor = vec4(tinted, mask);
}
