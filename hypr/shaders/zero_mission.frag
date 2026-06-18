#version 300 es
// ~ Crateria v2 ~ a Hyprland screen shader
// Keeps the muted teal-indigo grade, but adds the actual *weather*:
//  - layered mist that slowly drifts through dark areas
//  - rare, distant lightning-like glow pulses from off-screen
//  - faint ordered dithering for that GBA texture in the gradients
//
//   decoration {
//       screen_shader = ~/.config/hypr/shaders/zero_mission.frag
//   }
// live-test:  hyprctl keyword decoration:screen_shader ~/.config/hypr/shaders/zero_mission.frag
// disable:    hyprctl keyword decoration:screen_shader ""

precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
uniform float time; // replace with 0.0 if unavailable (mist/lightning freeze)

out vec4 fragColor;

// ------- tweakables -------
const float DESAT       = 0.20;  // gray pull
const float GRADE       = 0.28;  // teal/indigo push in shadows
const float MIST_AMT    = 0.10;  // drifting fog visibility (the main new thing)
const float LIGHTNING   = 0.20;  // distant pulse brightness; 0.0 to disable
const float DITHER_AMT  = 0.012; // GBA-ish ordered dither in gradients
const float VIGNETTE    = 0.45;
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
    return mix(mix(hash(i),               hash(i + vec2(1, 0)), f.x),
               mix(hash(i + vec2(0, 1)),  hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.07; a *= 0.5; }
    return v;
}

// 4x4 Bayer matrix for ordered dithering
float bayer(vec2 px) {
    int x = int(mod(px.x, 4.0));
    int y = int(mod(px.y, 4.0));
    int idx = y * 4 + x;
    int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
    return float(m[idx]) / 16.0 - 0.5;
}

void main() {
    vec2 uv = v_texcoord;
    vec4 pixColor = texture(tex, uv);
    vec3 col = pixColor.rgb;

    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    float darkMask = 1.0 - smoothstep(0.05, 0.45, lum); // where atmosphere lives

    // --- grade (same family as before) ---
    col = mix(col, vec3(lum), DESAT);
    vec3 shadowColor = vec3(0.16, 0.24, 0.34);
    float shadowMask = 1.0 - smoothstep(0.0, 0.55, lum);
    col = mix(col, col * (shadowColor * 2.2), shadowMask * GRADE);

    // --- layered drifting mist ---
    // two fog sheets moving at different speeds/scales, like parallax layers
    vec2 drift1 = vec2(time * 0.018, time * 0.004);
    vec2 drift2 = vec2(-time * 0.011, time * 0.007);
    float mist = fbm(uv * vec2(3.0, 5.0) + drift1) * 0.65
               + fbm(uv * vec2(7.0, 11.0) + drift2) * 0.35;
    mist = smoothstep(0.35, 0.85, mist);            // break it into patches
    vec3 mistColor = vec3(0.30, 0.42, 0.50);        // pale cold fog
    col += mistColor * mist * MIST_AMT * darkMask;

    // --- distant lightning / energy pulse ---
    // a rare flash that blooms in from the upper-left, ramps fast, decays slow
    float cycle = 23.0;                              // seconds between strikes
    float t = mod(time, cycle);
    float strike = exp(-t * 2.2) * step(0.0, t);     // sharp attack, slow decay
    // second, weaker echo flash right after, like real lightning
    strike += exp(-(t - 0.4) * 3.0) * step(0.4, t) * 0.5;
    vec2 srcDir = uv - vec2(-0.2, -0.3);             // light source off upper-left
    float falloff = 1.0 - clamp(length(srcDir) * 0.8, 0.0, 1.0);
    vec3 flashColor = vec3(0.55, 0.70, 0.95);
    col += flashColor * strike * falloff * LIGHTNING * darkMask;

    // --- GBA ordered dither, visible only in smooth dark gradients ---
    col += bayer(gl_FragCoord.xy) * DITHER_AMT * darkMask;

    // --- vignette toward murk, not black ---
    vec2 c = uv - 0.5;
    c.x *= 1.15;
    float vig = clamp(1.0 - dot(c, c) * VIGNETTE * 2.0, 0.0, 1.0);
    vig = pow(vig, 1.3);
    col = mix(shadowColor * 0.35, col, mix(0.88, 1.0, vig));
    col *= vig * 0.2 + 0.8;

    fragColor = vec4(col, pixColor.a);
}
