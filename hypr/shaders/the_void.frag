#version 300 es
// ~ The Void ~ a Hyprland screen shader
// Nothing is added to the screen. Ever. No stars, no mist, no flashes.
// The void only *takes*: darkness leans in, swells, and slowly moves,
// while anything bright stands out harsh and exposed. The place is alive,
// but it never resolves into anything you can point at.
//
//   decoration {
//       screen_shader = ~/.config/hypr/shaders/the_void.frag
//   }
// live-test:  hyprctl keyword decoration:screen_shader ~/.config/hypr/shaders/the_void.frag
// disable:    hyprctl keyword decoration:screen_shader ""

precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
uniform float time; // replace with 0.0 if unavailable (the void goes still)

out vec4 fragColor;

// ------- tweakables -------
const float DESAT      = 0.18;  // gray pull
const float COLD       = 0.22;  // cold cast in the shadows
const float SWALLOW    = 0.35;  // how deeply the moving darkness eats the dark areas
const float EXPOSED    = 0.15;  // extra harshness/contrast on bright content
const float LEAN_AMT   = 0.10;  // how far the vignette's center wanders
const float VIGNETTE   = 0.60;  // base edge darkness
// ---------------------------

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i),              hash(i + vec2(1, 0)), f.x),
               mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void main() {
    vec2 uv = v_texcoord;
    vec4 pixColor = texture(tex, uv);
    vec3 col = pixColor.rgb;

    float lum = dot(col, vec3(0.299, 0.587, 0.114));

    // --- quiet cold grade ---
    col = mix(col, vec3(lum), DESAT);
    vec3 voidColor = vec3(0.10, 0.14, 0.20); // barely-blue darkness
    float shadowMask = 1.0 - smoothstep(0.0, 0.5, lum);
    col = mix(col, col * (voidColor * 3.0), shadowMask * COLD);

    // --- the living dark ---
    // ONE enormous, glacially slow field. Scale is so large and motion so slow
    // that it never reads as texture or dots - only as darkness that is
    // deeper *here* than *there*, and was not a moment ago.
    vec2 p = uv * 1.4 + vec2(time * 0.008, time * -0.005);
    float deep = noise(p) * 0.6 + noise(p * 0.5 + 31.7 - time * 0.003) * 0.4;
    deep = smoothstep(0.2, 0.9, deep);              // broad, soft regions
    float swallow = mix(1.0, 0.55 + 0.45 * deep, SWALLOW); // only ever darkens
    col *= mix(1.0, swallow, shadowMask);           // and only in the dark

    // --- nothing can hide ---
    // bright content gets pushed slightly harder: a touch more contrast and a
    // hair of bloom-less glare, so windows feel exposed against the dark
    float exposedMask = smoothstep(0.45, 0.9, lum);
    col = mix(col, pow(col, vec3(0.92)) * 1.04, exposedMask * EXPOSED);

    // --- the void leans in ---
    // the vignette's center slowly wanders and its grip tightens and loosens
    // on a long, uneven cycle, like attention shifting in the dark
    vec2 lean = vec2(sin(time * 0.043), cos(time * 0.031)) * LEAN_AMT;
    float breathe = 0.85 + 0.15 * sin(time * 0.07) * sin(time * 0.013 + 2.0);
    vec2 c = uv - 0.5 - lean;
    c.x *= 1.1;
    float vig = clamp(1.0 - dot(c, c) * VIGNETTE * 2.0 * breathe, 0.0, 1.0);
    vig = pow(vig, 1.6);
    // edges fall into the void color, never pure black, never a hard ring
    col = mix(voidColor * 0.4, col, mix(0.80, 1.0, vig));
    col *= vig * 0.3 + 0.7;

    fragColor = vec4(col, pixColor.a);
}
