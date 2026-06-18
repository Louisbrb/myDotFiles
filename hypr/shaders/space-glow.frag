// Space Glow Shader for Hyprland
// Gentle pixel art shader with ambient glow and reduced eye strain

precision mediump float;
varying vec2 v_texcoord;
uniform sampler2D tex;

// Shader parameters - adjust these to your preference
const float SCANLINE_INTENSITY = 0.1;    // Subtle scanlines
const float GLOW_AMOUNT = 0.05;           // Ambient glow
const float BRIGHTNESS_REDUCTION = 0.05; // Gentle brightness reduction
const float VIGNETTE_STRENGTH = 0.4;     // Edge darkening
const float WARMTH = 0.0;                // Color temperature adjustment

// Glow parameters
const float GLOW_RADIUS = 3.0;
const float GLOW_THRESHOLD = 0.5;        // Only glow bright pixels

void main() {
    vec2 uv = v_texcoord;
    
    // Get the original pixel color
    vec4 color = texture2D(tex, uv);
    
    // Apply brightness reduction to tame whites
    color.rgb *= (1.0 - BRIGHTNESS_REDUCTION);
    
    // Scanline effect (subtle horizontal lines)
    float scanline = sin(uv.y * 3.14159 * float(textureSize(tex, 0).y)) * 0.5 + 0.5;
    color.rgb *= 1.0 - (SCANLINE_INTENSITY * (1.0 - scanline));
    
    // Ambient glow effect
    if (GLOW_AMOUNT > 0.0) {
        vec3 glow = vec3(0.0);
        float totalWeight = 0.0;
        
        // Sample surrounding pixels for glow
        vec2 texelSize = 1.0 / vec2(textureSize(tex, 0));
        int samples = int(GLOW_RADIUS);
        
        for (int x = -samples; x <= samples; x++) {
            for (int y = -samples; y <= samples; y++) {
                vec2 offset = vec2(float(x), float(y)) * texelSize;
                vec4 sample = texture2D(tex, uv + offset);
                
                // Only accumulate bright pixels
                float brightness = dot(sample.rgb, vec3(0.299, 0.587, 0.114));
                if (brightness > GLOW_THRESHOLD) {
                    float distance = length(vec2(float(x), float(y)));
                    float weight = 1.0 / (1.0 + distance);
                    glow += sample.rgb * weight;
                    totalWeight += weight;
                }
            }
        }
        
        if (totalWeight > 0.0) {
            glow /= totalWeight;
            color.rgb = mix(color.rgb, glow, GLOW_AMOUNT * 0.3);
        }
    }
    
    // Color warmth adjustment
    if (WARMTH != 0.0) {
        color.r += WARMTH * 0.2;
        color.b -= WARMTH * 0.12;
    }
    
    // Vignette effect (darkens edges)
    vec2 center = uv - 0.5;
    float dist = length(center);
    float vignette = 1.0 - (dist * VIGNETTE_STRENGTH);
    color.rgb *= vignette;
    
    // Clamp to valid range
    color.rgb = clamp(color.rgb, 0.0, 1.0);
    
    gl_FragColor = color;
}
