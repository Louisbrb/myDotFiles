#version 300 es
precision mediump float;

uniform sampler2D tex;
uniform float time;
uniform int wl_output;
in vec2 v_texcoord;
out vec4 fragColor;

// ==============================================================
// TWEAKABLE CONSTANTS
// ==============================================================

// --- Star Layer 1 ---
const float STAR1_SCALE     = 1880.0;   // Grid density (higher = more stars)
const float STAR1_DENSITY   = 0.1;   // Fraction of cells with stars (0-1)
const float STAR1_SPEED     = 0.05;   // Scroll speed in cells/sec
const float STAR1_INTENSITY = 100.0;    // Brightness multiplier

// --- Star Layer 2 ---
const float STAR2_SCALE     = 200.0;
const float STAR2_DENSITY   = 0.06;
const float STAR2_SPEED     = 0.15;
const float STAR2_INTENSITY = 0.5;

// --- Star Appearance ---
const float STAR_SIZE       = 1.0;   // Higher = smaller stars
const float STAR_TWINKLE    = 2.0;    // Twinkle speed
const float STAR_MIN_BRIGHT = 10.7;    // Minimum brightness (0-1)
const float STAR_MAX_BRIGHT = 22.0;    // Maximum brightness (0-1)
const float STAR_GLOW       = 0.55;   // Overall star glow intensity

// --- Bloom ---
const float BLOOM_SPREAD    = 2.0;    // Spread radius
const float BLOOM_THRESHOLD = 0.4;    // Brightness threshold
const float BLOOM_INTENSITY = 0.1;    // Overall bloom strength

// --- Scanlines ---
const float SCAN_PERIOD     = 4.0;    // Line spacing (pixels)
const float SCAN_STRENGTH   = 0.07;   // Darkness intensity (0-1)

// --- Vignette ---
const float VIG_INTENSITY   = 0.15;   // Edge darkening (0-1)
const float VIG_CURVE       = 1.5;    // Falloff curve

// ==============================================================

// ----------------------------------------------------------
// Pseudo-random float from a vec2 seed
// ----------------------------------------------------------
float pseudoRand(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// ----------------------------------------------------------
// Brightness (luminance)
// ----------------------------------------------------------
float luma(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}

// ----------------------------------------------------------
// Star layer — grid built in uv-space.
// scale   = grid density (higher = more, smaller cells)
// density = fraction of cells that get a star (0–1)
// speed   = scroll speed in cells/sec
// seed    = offset so each layer has unique positions
// ----------------------------------------------------------
float starLayer(vec2 uv, float scale, float density, float speed, float seed) {
    vec2 coords = uv * scale + vec2(0.0, time * speed);
    vec2 id     = floor(coords);
    vec2 frac   = fract(coords);

    float stars = 0.0;
    for (int i = -1; i <= 1; i++) {
        for (int j = -1; j <= 1; j++) {
            vec2 nb = id + vec2(float(i), float(j));
            float r = pseudoRand(nb + seed);
            if (r < density) {
                vec2 pos = vec2(
                    pseudoRand(nb + seed + 100.0),
                    pseudoRand(nb + seed + 150.0)
                ) * 0.8 + 0.1;

                float bright = pseudoRand(nb + seed + 200.0) * 0.5 + 0.5;
                float phase  = pseudoRand(nb + seed + 300.0) * 6.283185;
                bright *= STAR_MIN_BRIGHT + (STAR_MAX_BRIGHT - STAR_MIN_BRIGHT) * sin(time * STAR_TWINKLE + phase);

                float dist = length(frac - pos - vec2(float(i), float(j)));
                stars += bright * max(0.0, 1.0 - dist * STAR_SIZE);
            }
        }
    }
    return stars;
}

// ----------------------------------------------------------
// Bloom — 13-tap cross/diagonal, uses real texel size
// ----------------------------------------------------------
vec3 bloom(vec2 uv, vec2 texelSize) {
    vec3 acc    = vec3(0.0);
    float weight = 0.0;

    vec2  offsets[13];
    float weights[13];

    offsets[0]  = vec2( 0.0,  0.0); weights[0]  = 1.0;
    offsets[1]  = vec2( 1.0,  0.0); weights[1]  = 0.6;
    offsets[2]  = vec2(-1.0,  0.0); weights[2]  = 0.6;
    offsets[3]  = vec2( 0.0,  1.0); weights[3]  = 0.6;
    offsets[4]  = vec2( 0.0, -1.0); weights[4]  = 0.6;
    offsets[5]  = vec2( 1.0,  1.0); weights[5]  = 0.3;
    offsets[6]  = vec2(-1.0,  1.0); weights[6]  = 0.3;
    offsets[7]  = vec2( 1.0, -1.0); weights[7]  = 0.3;
    offsets[8]  = vec2(-1.0, -1.0); weights[8]  = 0.3;
    offsets[9]  = vec2( 2.0,  0.0); weights[9]  = 0.15;
    offsets[10] = vec2(-2.0,  0.0); weights[10] = 0.15;
    offsets[11] = vec2( 0.0,  2.0); weights[11] = 0.15;
    offsets[12] = vec2( 0.0, -2.0); weights[12] = 0.15;

    for (int i = 0; i < 13; i++) {
        vec2 sampleUv = uv + offsets[i] * texelSize * BLOOM_SPREAD;
        vec3 col = texture(tex, sampleUv).rgb;
        float bright = max(0.0, luma(col) - BLOOM_THRESHOLD) * 2.0;
        acc    += col * bright * weights[i];
        weight += bright * weights[i];
    }

    if (weight > 0.001) {
        acc /= weight;
    }
    return acc * weight * BLOOM_INTENSITY;
}

// ----------------------------------------------------------
// Main
// ----------------------------------------------------------
void main() {
    vec2 uv = v_texcoord;

    // Get actual texture resolution
    vec2 res     = vec2(textureSize(tex, 0));
    vec2 texelSz = 1.0 / res;

    // ---- Original screen ----
    vec4 screen = texture(tex, uv);

    // ---- Bloom ----
    vec3 glow = bloom(uv, texelSz);

    // ---- Stars ----
    float s1 = starLayer(uv, STAR1_SCALE, STAR1_DENSITY, STAR1_SPEED, 0.0);
    float s2 = starLayer(uv, STAR2_SCALE, STAR2_DENSITY, STAR2_SPEED, 500.0);
    float starGlow = clamp(s1 * STAR1_INTENSITY + s2 * STAR2_INTENSITY, 0.0, 1.0);

    // ---- Scanlines ----
    float scanY = uv.y * res.y;
    float scan  = 1.0 - SCAN_STRENGTH * (sin(scanY / SCAN_PERIOD * 3.14159265) * 0.5 + 0.5);

    // ---- Vignette ----
    vec2 vig = uv * 2.0 - 1.0;
    float vigFactor = 1.0 - VIG_INTENSITY * pow(length(vig), VIG_CURVE);

    // ---- Combine ----
    vec3 colour  = screen.rgb;
    colour += glow;                          // bloom bleed
    colour += vec3(starGlow) * STAR_GLOW;    // stars
    colour *= scan;                          // scanlines
    colour *= vigFactor;                     // vignette

    fragColor = vec4(colour, screen.a);
}
