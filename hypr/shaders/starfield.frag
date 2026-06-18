#version 300 es
precision mediump float;

uniform sampler2D tex;
uniform float time;
uniform int wl_output;

in vec2 v_texcoord;
out vec4 fragColor;

// ----------------------------------------------------------
// Brightness (luminance) of a colour
// ----------------------------------------------------------
float luma(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}

// ----------------------------------------------------------
// Pseudo-random float from a vec2 seed
// ----------------------------------------------------------
float pseudoRand(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// ----------------------------------------------------------
// Compute a single star layer. density controls how many
// cells get a star, scale controls the grid density.
// seedOffset lets us get different positions per layer.
// ----------------------------------------------------------
float starLayer(vec2 uv, float scale, float density, float speed, float seedOffset) {
    vec2 coords = uv * scale + vec2(0.0, time * speed);
    vec2 id   = floor(coords);
    vec2 frac = fract(coords);

    float stars = 0.0;
    for (int i = -1; i <= 1; i++) {
        for (int j = -1; j <= 1; j++) {
            vec2 nb = id + vec2(float(i), float(j));
            float r = pseudoRand(nb + seedOffset);
            if (r < density) {
                vec2 pos = vec2(
                    pseudoRand(nb + seedOffset + 100.0),
                    pseudoRand(nb + seedOffset + 150.0)
                ) * 0.8 + 0.1;

                float bright = pseudoRand(nb + seedOffset + 200.0) * 0.5 + 0.5;
                float phase  = pseudoRand(nb + seedOffset + 300.0) * 6.283185;
                bright *= 0.7 + 0.3 * sin(time * 2.0 + phase);

                float dist = length(frac - pos - vec2(float(i), float(j)));
                stars += bright * max(0.0, 1.0 - dist * 30.0);
            }
        }
    }
    return stars;
}

// ----------------------------------------------------------
// Fake bloom: sample the screen at offsets around the current
// pixel and average the bright parts. A single-pass
// approximation — no multi-pass blur available here.
// We use a cross + diagonal pattern (13 taps) which spreads
// light in all directions without looking too directional.
// ----------------------------------------------------------
vec3 bloom(vec2 uv, vec2 texelSize) {
    // How far the glow spreads — tweak this for more/less bleed
    float spread = 3.0;

    vec3 acc = vec3(0.0);
    float weight = 0.0;

    // Offsets: centre + 4 cardinal + 4 diagonal + 4 at 2x distance
    // Weights fall off with distance
    vec2 offsets[13];
    float weights[13];

    // Centre
    offsets[0]  = vec2( 0.0,  0.0); weights[0]  = 1.0;
    // Cardinal x1
    offsets[1]  = vec2( 1.0,  0.0); weights[1]  = 0.6;
    offsets[2]  = vec2(-1.0,  0.0); weights[2]  = 0.6;
    offsets[3]  = vec2( 0.0,  1.0); weights[3]  = 0.6;
    offsets[4]  = vec2( 0.0, -1.0); weights[4]  = 0.6;
    // Diagonal x1
    offsets[5]  = vec2( 1.0,  1.0); weights[5]  = 0.3;
    offsets[6]  = vec2(-1.0,  1.0); weights[6]  = 0.3;
    offsets[7]  = vec2( 1.0, -1.0); weights[7]  = 0.3;
    offsets[8]  = vec2(-1.0, -1.0); weights[8]  = 0.3;
    // Cardinal x2 (wider spread)
    offsets[9]  = vec2( 2.0,  0.0); weights[9]  = 0.15;
    offsets[10] = vec2(-2.0,  0.0); weights[10] = 0.15;
    offsets[11] = vec2( 0.0,  2.0); weights[11] = 0.15;
    offsets[12] = vec2( 0.0, -2.0); weights[12] = 0.15;

    for (int i = 0; i < 13; i++) {
        vec2 sampleUv = uv + offsets[i] * texelSize * spread;
        vec3 col = texture(tex, sampleUv).rgb;
        // Only let bright pixels contribute — this is what makes
        // it a "glow" rather than just a blur
        float bright = max(0.0, luma(col) - 0.5) * 2.0;
        acc += col * bright * weights[i];
        weight += bright * weights[i];
    }

    // Normalise, but keep it zero if nothing was bright
    if (weight > 0.001) {
        acc /= weight;
    }
    return acc * weight * 0.4;  // 0.4 = overall glow intensity
}

void main() {
    vec2 uv = v_texcoord;

    // Texel size for offsetting bloom samples.
    // If you want pixel-perfect accuracy, declare:
    //   uniform vec2 screen_size;
    // in hyprland.conf and replace with 1.0 / screen_size.
    vec2 texelSize = vec2(1.0 / 1920.0, 1.0 / 1080.0);

    // ---- Original screen ----
    vec4 screen = texture(tex, uv);

    // ---- Bloom / glow bleed ----
    vec3 glow = bloom(uv, texelSize);

    // ---- Scanlines ----
    // Subtle horizontal lines. Lower scanFreq = fewer, chunkier
    // lines (more pixel-art CRT feel). scanStrength = darkness.
    float scanFreq     = 3.0;
    float scanStrength = 0.07;
    float scanY = uv.y * 1080.0;
    float scan  = 1.0 - scanStrength * (sin(scanY * 3.14159265 * scanFreq) * 0.5 + 0.5);

    // ---- Vignette ----
    vec2 vig = uv * 2.0 - 1.0;
    float vigFactor = 1.0 - 0.35 * pow(length(vig), 2.5);

    // ---- Stars ----
    // Two parallax layers: slow/large and fast/small.
    // They scroll upward and twinkle. Added before scanlines
    // and vignette so they feel like they're on the same CRT.
    float stars1 = starLayer(uv, 80.0,  0.08, 0.05, 0.0);
    float stars2 = starLayer(uv, 200.0, 0.06, 0.15, 500.0);
    float starGlow = clamp(stars1 * 0.7 + stars2 * 0.5, 0.0, 1.0);

    // ---- Combine ----
    vec3 colour = screen.rgb;
    colour += glow;                          // bloom bleed on bright areas
    colour += vec3(starGlow) * 0.55;         // star overlay
    colour *= scan;                          // scanline darkening
    colour *= vigFactor;                     // vignette edges

    fragColor = vec4(colour, screen.a);
}
