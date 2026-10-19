#version 300 es
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

const vec3 PHOSPHOR = vec3(0.1725, 0.6824, 0.1804);
const float SCAN_OPACITY = 0.35;

float scanDark(float row) {
  if (row < 2.0) return 0.0;
  if (row < 3.0) return 0.30 * (row - 2.0);
  return 0.30;
}

float scanTint(float row) {
  if (row < 1.0) return 0.05;
  if (row < 2.0) return 0.05 * (2.0 - row);
  return 0.0;
}

float vignette(vec2 uv) {
  float d = length(uv - 0.5);
  if (d <= 0.44) return 0.0;
  if (d <= 0.58) return mix(0.0, 0.05, (d - 0.44) / 0.14);
  if (d <= 0.78) return mix(0.05, 0.32, (d - 0.58) / 0.20);
  return mix(0.32, 0.62, clamp((d - 0.78) / 0.22, 0.0, 1.0));
}

void main() {
  vec4 pixel = texture(tex, v_texcoord);
  float row = mod(gl_FragCoord.y, 4.0);

  vec3 color = pixel.rgb;
  color = mix(color, PHOSPHOR, scanTint(row) * SCAN_OPACITY);
  color = mix(color, vec3(0.0), scanDark(row) * SCAN_OPACITY);
  color = mix(color, vec3(0.0), vignette(v_texcoord));

  fragColor = vec4(color, pixel.a);
}
