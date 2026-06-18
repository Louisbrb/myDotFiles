#version 300 es
// ~ Deep Space ~ a Hyprland screen shader
// Subtle cosmic color grading + twinkling starfield + nebula haze + vignette.
// Save somewhere like ~/.config/hypr/shaders/space.frag and enable with:
//   decoration {
//       screen_shader = ~/.config/hypr/shaders/space.frag
//   }
// or live-test:  hyprctl keyword decoration:screen_shader ~/.config/hypr/shaders/space.frag
// disable with:  hyprctl keyword decoration:screen_shader ""

precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
uniform float time; // available on recent Hyprland; remove star twinkle if yours lacks it

out vec4 fragColor;

// ------- tweakables -------
const float STAR_DENSITY   = 0.9985; // higher = fewer stars (0.997 - 0.9995)
const float STAR_STRENGTH  = 0.35;   // star brightness
const float NEBULA_AMOUNT  = 0.06;   // purple/blue haze intensity
const float GRADE_AMOUNT   = 0.18;   // how strongly to push the cosmic tint
const float VIGNETTE_POWER = 0.35;   // edge darkening
// ---------------------------

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// cheap value noise for the nebula
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 4; i++) {
        v += amp * noise(p);
        p *= 2.1;
        amp *= 0.5;
    }
    return v;
}

void main() {
    vec2 uv = v_texcoord;
    vec4 pixColor = texture(tex, uv);
    vec3 col = pixColor.rgb;

    // luminance of the screen content (used to keep effects out of bright areas)
    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    float darkMask = smoothstep(0.35, 0.05, lum); // strongest on dark backgrounds

    // --- cosmic color grade: cool shadows, slightly violet mids ---
    vec3 shadowTint = vec3(0.55, 0.62, 1.00); // icy blue
    vec3 midTint    = vec3(0.85, 0.78, 1.00); // soft violet
    vec3 graded = col;
    graded *= mix(vec3(1.0), shadowTint, (1.0 - lum) * GRADE_AMOUNT);
    graded = mix(graded, graded * midTint, GRADE_AMOUNT * 0.5);

    // --- drifting nebula haze (only over dark regions) ---
    vec2 np = uv * 3.0 + vec2(time * 0.01, -time * 0.006);
    float neb = fbm(np);
    vec3 nebColor = mix(vec3(0.25, 0.10, 0.45),  // deep purple
                        vec3(0.05, 0.25, 0.50),  // teal-blue
                        noise(uv * 2.0 + 7.3));
    graded += nebColor * neb * NEBULA_AMOUNT * darkMask;

    // --- twinkling starfield (only over dark regions) ---
    vec2 grid = floor(uv * vec2(220.0, 130.0)); // star cell resolution
    float h = hash(grid);
    if (h > STAR_DENSITY) {
        float twinkle = 0.5 + 0.5 * sin(time * (1.5 + h * 4.0) + h * 60.0);
        float starLum = (h - STAR_DENSITY) / (1.0 - STAR_DENSITY); // 0..1
        // slight color variety: white, blue-white, warm
        vec3 starCol = mix(vec3(1.0), mix(vec3(0.7, 0.8, 1.0), vec3(1.0, 0.9, 0.75), hash(grid + 1.7)), 0.5);
        graded += starCol * starLum * twinkle * STAR_STRENGTH * darkMask;
    }

    // --- gentle vignette, like looking through a porthole ---
    vec2 c = uv - 0.5;
    float vig = 1.0 - dot(c, c) * VIGNETTE_POWER * 2.0;
    graded *= clamp(vig, 0.0, 1.0);

    fragColor = vec4(graded, pixColor.a);
}
