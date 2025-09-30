// ================== AUDIO ==================
SinOsc s => Gain g => dac;
440 => s.freq;
0.05 => g.gain;

Event noteTrig;
int notePC; // 0..11

fun void musicLoop() {
    while (true) {
        Math.random2f(0.05, 0.30) => g.gain;
        Math.random2(200, 800)    => int f;
        f => s.freq;
        
        Std.ftom(f) $ int => int midi;
        (midi % 12 + 12) % 12 => notePC; // clamp 0..11
        noteTrig.broadcast();
        
        500::ms => now;
    }
}
spork ~ musicLoop();

// ================== COLORS ==================
vec3 pcColor[12];
fun void initPalette() {
    @(0.95,0.30,0.40) => pcColor[0];   // C
    @(0.95,0.55,0.30) => pcColor[1];   // C#
    @(0.95,0.80,0.30) => pcColor[2];   // D
    @(0.75,0.90,0.30) => pcColor[3];   // D#
    @(0.40,0.90,0.40) => pcColor[4];   // E
    @(0.30,0.85,0.70) => pcColor[5];   // F
    @(0.35,0.75,0.95) => pcColor[6];   // F#
    @(0.45,0.55,0.95) => pcColor[7];   // G
    @(0.65,0.45,0.95) => pcColor[8];   // G#
    @(0.90,0.45,0.90) => pcColor[9];   // A
    @(0.95,0.45,0.65) => pcColor[10];  // A#
    @(0.95,0.45,0.50) => pcColor[11];  // B
}
initPalette();

// ================== VISUALS (ChuGL) ==================
// OPTIONAL: if supported in your build, uncomment one:
// GG.window().size(1280, 800);
// GG.fullscreen(true);

// Create two spheres
GSphere A --> GG.scene();
GSphere B --> GG.scene();

0.40 => A.sca;    // slightly smaller so full orbit fits
0.40 => B.sca;
@(0.85,0.85,0.90) => A.color;
@(0.85,0.85,0.90) => B.color;

// Change both colors on each new note
fun void noteListener() {
    while (true) {
        noteTrig => now;
        pcColor[notePC] => A.color;
        pcColor[notePC] => B.color;
    }
}
spork ~ noteListener();

// Orbit: A at angle t, B at t + PI (opposite)
// Large radius so you see the whole orbit
fun void orbitTwo() {
    0.0 => float t;
    2.2 => float R;   // smaller radius so both stay in view
    0.3 => float H;   // lower vertical lift
    
    time last => now;
    while (true) {
        GG.nextFrame() => now;
        (now - last) => dur dt; now => last;
        dt / 1::second => float dtSec;
        
        // orbit speed (feel free to tweak)
        t + 0.6 * dtSec => t;
        
        // A at angle t
        Math.cos(t) * R => A.posX;
        H => A.posY;
        Math.sin(t) * R => A.posZ;
        
        // B opposite (t + PI)
        Math.cos(t + Math.PI) * R => B.posX;
        H => B.posY;
        Math.sin(t + Math.PI) * R => B.posZ;
        
        A.rotateY(0.012);
        B.rotateY(-0.012);
    }
}

spork ~ orbitTwo();

// ================== FRAME LOOP ==================
while (true) { GG.nextFrame() => now; }
