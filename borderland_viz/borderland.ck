// =======================
// borderland.ck  (phone + cards unchanged; linear FFT waterfall)
// =======================

// ---------- AUDIO FRONT-END (shared, sndpeek-style tap) ----------
adc => Gain tap; 1.0 => tap.gain;

// legacy branch (harmless)
tap => Gain in => blackhole; 0.8 => in.gain;

// ---------- TIME-DOMAIN for PHONE (sndpeek-style Flip) ----------
220 => int NSEG;               // screen resolution across phone
float samples[NSEG];           // rolling time-domain buffer for bars
Flip phoneFlip => blackhole;   // sndpeek-like time window
NSEG => phoneFlip.size;
tap => phoneFlip;

fun void phone_waveform_update() {
    while (true) {
        phoneFlip.upchuck();
        phoneFlip.output(samples);     // fills 'samples[]' directly
        (NSEG::samp/2) => now;         // hop size similar to sndpeek
    }
}
spork ~ phone_waveform_update();

// ---------- GRAPHICS SCENE ----------
GG.scene() @=> GScene @ scene;

// Bloom (safe wiring; no duplicates)
GG.bloom(true);
GG.bloomPass().intensity(0.65);
GG.bloomPass().radius(0.7);
GG.bloomPass().levels(6);

// fullscreen
GG.fullscreen();

// ---------- PHONE + SCREEN ----------
PBRMaterial phoneBodyMat; phoneBodyMat.color(@(0.03,0.03,0.04)); phoneBodyMat.roughness(0.6); phoneBodyMat.metallic(0.6);
PBRMaterial screenMat;    screenMat.color(@(1.0,1.0,1.0));       screenMat.roughness(0.88);    screenMat.metallic(0.0);
PBRMaterial waveMat;      waveMat.color(@(1.0,0.12,0.10));       waveMat.roughness(0.35);      waveMat.metallic(0.1);

PBRMaterial floorMat; floorMat.color(@(0.01,0.01,0.015)); floorMat.roughness(0.9);
GCube floor --> scene; floor.mat(floorMat); floor.sca(@(40,0.05,40)); floor.pos(@(0,-0.55,0));

GCube phoneBody --> scene; phoneBody.mat(phoneBodyMat);
2.6 => float PHONE_W; 5.2 => float PHONE_H; 0.28 => float PHONE_T;
phoneBody.sca(@(PHONE_W, PHONE_T, PHONE_H)); phoneBody.pos(@(0,0,0));

GCube screen --> scene; screen.mat(screenMat);
0.08 => float BEZEL;
(PHONE_W - 2*BEZEL) => float SCREEN_W;
(PHONE_H - 2*BEZEL) => float SCREEN_H;
0.03 => float SCREEN_T;
screen.sca(@(SCREEN_W, SCREEN_T, SCREEN_H));
screen.pos(@(0, (PHONE_T*0.5 + SCREEN_T*0.5 + 0.01), 0));

(PHONE_T*0.5 + SCREEN_T + 0.012) => float PLANE_Y;


// ---------- RINGS (unchanged) ----------
(PLANE_Y - 0.004) => float RING_Y;
48 => int NUM_CARDS; 3.2 => float RING_RADIUS;
0.85 => float CARD_W; 1.30 => float CARD_L; 0.0015 => float CARD_T;
- Math.PI/10.0 => float SPIN_RAD_PER_SEC;

0.06 => float RADIAL_JITTER; 0.18 => float ROT_JITTER_Z; 0.08 => float SCALE_JITTER;

PBRMaterial matRed, matWhite, matGray;
matRed.color(@(1.0,0.12,0.10)); matRed.roughness(0.35); matRed.metallic(0.05);
matWhite.color(@(0.95,0.95,0.96)); matWhite.roughness(0.75); matWhite.metallic(0.0);
matGray.color(@(0.70,0.70,0.74));  matGray.roughness(0.65);  matGray.metallic(0.05);

GCube cards[NUM_CARDS];
float baseTheta[NUM_CARDS], baseRadius[NUM_CARDS], extraRotZ[NUM_CARDS], scaleW[NUM_CARDS], scaleL[NUM_CARDS];

for (int i; i < NUM_CARDS; i++) {
    new GCube @=> cards[i]; cards[i] --> scene;
    Math.random2(0,2) => int pick;
    if (pick == 0) cards[i].mat(matRed);
    else if (pick == 1) cards[i].mat(matWhite);
    else cards[i].mat(matGray);
    (2.0 * Math.PI * (i $ float) / NUM_CARDS) => baseTheta[i];
    (RING_RADIUS + Math.random2f(-RADIAL_JITTER, RADIAL_JITTER)) => baseRadius[i];
    Math.random2f(-ROT_JITTER_Z, ROT_JITTER_Z) => extraRotZ[i];
    1.0 + Math.random2f(-SCALE_JITTER, SCALE_JITTER) => scaleW[i];
    1.0 + Math.random2f(-SCALE_JITTER, SCALE_JITTER) => scaleL[i];
    cards[i].rot(@(-Math.PI/2.0, baseTheta[i] + Math.PI/2.0, 0.0));
}

(PLANE_Y - 0.006) => float RING2_Y;
40 => int NUM_CARDS2; 2.6 => float RING_RADIUS2;
0.70 => float CARD2_W; 1.05 => float CARD2_L; 0.0015 => float CARD2_T;
Math.PI/8.0 => float SPIN_RAD_PER_SEC2;

0.05 => float RADIAL_JITTER2; 0.06 => float SCALE_JITTER2;

GCube cards2[NUM_CARDS2];
float baseTheta2[NUM_CARDS2], baseRadius2[NUM_CARDS2], scaleW2[NUM_CARDS2], scaleL2[NUM_CARDS2];

for (int i; i < NUM_CARDS2; i++) {
    new GCube @=> cards2[i]; cards2[i] --> scene;
    Math.random2(0,2) => int pick2;
    if (pick2 == 0) cards2[i].mat(matRed);
    else if (pick2 == 1) cards2[i].mat(matWhite);
    else cards2[i].mat(matGray);
    (2.0 * Math.PI * (i $ float) / NUM_CARDS2) => baseTheta2[i];
    (RING_RADIUS2 + Math.random2f(-RADIAL_JITTER2, RADIAL_JITTER2)) => baseRadius2[i];
    1.0 + Math.random2f(-SCALE_JITTER2, SCALE_JITTER2) => scaleW2[i];
    1.0 + Math.random2f(-SCALE_JITTER2, SCALE_JITTER2) => scaleL2[i];
    cards2[i].rot(@(-Math.PI/2.0, 0.0, 0.0));
}

// ---------- TEXT ----------
GText lineStart --> scene; lineStart.text("START"); lineStart.size(0.58); lineStart.color(@(1.0,1.0,1.0));
GText lineGame  --> scene;  lineGame .text("GAME");  lineGame .size(0.58);  lineGame .color(@(1.0,1.0,1.0));
-1.57079632679 => float ROT_FLAT_X; 0.0 => float ROT_UP_Z;
lineStart.rot(@(ROT_FLAT_X, 0.0, ROT_UP_Z));
lineGame .rot(@(ROT_FLAT_X, 0.0, ROT_UP_Z));
0.12 => float Z_UI_CENTER; 0.75 => float wordGap; 0.36 => float stripGap;
(Z_UI_CENTER + 0.5*wordGap) => float z_START;
(Z_UI_CENTER - 0.5*wordGap) => float z_GAME;
(z_START - stripGap)        => float z_STRIP_CTR;
lineStart.pos(@(0.0, PLANE_Y, z_START));
lineGame .pos(@(0.0, PLANE_Y, z_GAME));

// ---- soft drop shadow (single offset copy, semi-transparent) ----
@(0.00, 0.00, 0.00, 0.30) => vec4 SHADOW_RGBA;   // 30% black

GText sShadow --> scene; sShadow.text("START"); sShadow.size(0.58); sShadow.color(SHADOW_RGBA);
GText gShadow --> scene; gShadow.text("GAME");  gShadow.size(0.58); gShadow.color(SHADOW_RGBA);

// tiny offset down-right (X) and toward +Z, slightly lower Y so real text sits above
0.010 => float SX;  0.010 => float SZ;
sShadow.rot(@(ROT_FLAT_X,0,ROT_UP_Z));
gShadow.rot(@(ROT_FLAT_X,0,ROT_UP_Z));
sShadow.pos(@(SX, PLANE_Y - 0.0006, z_START + SZ));
gShadow.pos(@(SX, PLANE_Y - 0.0006, z_GAME  + SZ));



// ---------- CAMERA (GFlyCamera; fly-in -> 2 orbits -> rise to top & hold) ----------
GFlyCamera cam --> scene;
scene.camera(cam);
cam.perspective();

@(0.0, 0.6, 0.0) => vec3 lookCenter; // scene focus

// helpers
fun float ease(float t){ return t*t*(3.0 - 2.0*t); } // smoothstep
fun vec3 vlerp(vec3 a, vec3 b, float u){
    return @( a.x + (b.x-a.x)*u,
    a.y + (b.y-a.y)*u,
    a.z + (b.z-a.z)*u );
}

// --- orbit definition (starts at NORTH edge) ---
Math.PI/2.0 => float A0;           // start angle (NORTH, +Z)
A0 + 2.0*Math.PI => float A1;      // full 360
3.6 => float R0;    9.5 => float R1;  // radius expands
1.25 => float Y0;   3.8 => float Y1;  // height rises

fun vec3 orbitPoint(float u){
    Math.max(0.0, Math.min(1.0, u)) => u;
    ease(u) => float t;
    (R0 + (R1-R0)*t) => float r;
    (Y0 + (Y1-Y0)*t) => float y;
    (A0 + (A1-A0)*t) => float a;
    return @( lookCenter.x + Math.cos(a)*r,
    y,
    lookCenter.z + Math.sin(a)*r );
}

// --- fly-in definition (same azimuth/height as orbit start) ---
Y0 => float FLY_Y;          // EXACT match to orbit start height
20.0 => float EXTRA;        // start distance beyond orbit start radius
R0 + EXTRA => float START_R;

@( lookCenter.x + Math.cos(A0)*START_R,
FLY_Y,
lookCenter.z + Math.sin(A0)*START_R ) => vec3 pStart;

// EXACT handoff to orbit:
orbitPoint(0.0) => vec3 pHandoff;

// timings
3.0  => float START_DELAY;
10.0 => float FLYIN_DUR;
25.0 => float ORBIT_DURATION;   // one orbit
5.0  => float TOP_LIFT_DUR;     // side angle -> top-down
5.0 => float TOP_HOLD_DUR;     // hold overhead
10.0 => float LIFT_HOLD_DUR;   // extra hold after the vertical lift

0.0 => float aAfterOrbit;   // cached azimuth after orbit
0.0 => float rAfterOrbit;   // cached radius after orbit

fun void oneTake(){
    // park at start
    cam.pos(pStart);
    cam.lookAt(lookCenter);
    
    // wait cue
    now + START_DELAY::second => time go;
    while(now < go) GG.nextFrame() => now;
    
    // ---- A: fly-in to orbitPoint(0) ----
    now => time t0;
    (FLYIN_DUR*second) => dur dFly;
    while((now - t0) < dFly){
        (((now - t0)/dFly) $ float) => float u;
        ease(u) => u;
        vlerp(pStart, pHandoff, u) => vec3 p;
        cam.pos(p);
        cam.lookAt(lookCenter);
        GG.nextFrame() => now;
    }
    cam.pos(pHandoff);
    cam.lookAt(lookCenter);
    
    // ---- B: first orbit (0..1) ----
    now => time t1;
    (ORBIT_DURATION*second) => dur dOrb1;
    while((now - t1) < dOrb1){
        (((now - t1)/dOrb1) $ float) => float u;
        orbitPoint(u) => vec3 p;
        cam.pos(p);
        cam.lookAt(lookCenter);
        GG.nextFrame() => now;
    }
    
    // ---- cache azimuth & radius at end of orbit (for later moves) ----
    {
        cam.pos() => vec3 _pAfterOrbit;
        (_pAfterOrbit.x - lookCenter.x) => float _dx;
        (_pAfterOrbit.z - lookCenter.z) => float _dz;
        Math.atan2(_dz, _dx) => aAfterOrbit;                  // azimuth
        Math.sqrt(_dx*_dx + _dz*_dz) => rAfterOrbit;          // radius
    }

    
    // ---- C: from current side angle -> straight overhead ----
    // start: end of orbit path; target: directly above center
    cam.pos() => vec3 fromPos;
    @(lookCenter.x, lookCenter.y + 9.5, lookCenter.z) => vec3 topPos;
    
    now => time t3;
    (TOP_LIFT_DUR*second) => dur dLift;
    while((now - t3) < dLift){
        (((now - t3)/dLift) $ float) => float u;
        ease(u) => u;
        vlerp(fromPos, topPos, u) => vec3 p;
        cam.pos(p);
        cam.lookAt(lookCenter);
        GG.nextFrame() => now;
    }
    cam.pos(topPos);
    cam.lookAt(lookCenter);
    
    // ---- D: hold overhead for 10 seconds, then end ----
    now + (TOP_HOLD_DUR*second) => time tHoldEnd;
    while(now < tHoldEnd) GG.nextFrame() => now;
    
    // ---- E: simple vertical lift (slower; 9s, +15 units in Y) ----
    9.0  => float LIFT_DUR_SEC;          // was 6.0 ? slower now
    15.0 => float LIFT_DELTA_Y_SIMPLE;
    
    cam.pos() => vec3 liftStart;
    @( liftStart.x, liftStart.y + LIFT_DELTA_Y_SIMPLE, liftStart.z ) => vec3 liftEnd;
    
    now => time tE;
    (LIFT_DUR_SEC*second) => dur dE;
    while ((now - tE) < dE) {
        (((now - tE)/dE) $ float) => float u;
        ease(u) => float s;
        vlerp(liftStart, liftEnd, s) => vec3 p;
        cam.pos(p);
        cam.lookAt(lookCenter);
        GG.nextFrame() => now;
    }
    cam.pos(liftEnd);
    cam.lookAt(lookCenter);
    
    
    // ---- F: hold after lift (let the aerial visual breathe) ----
    now + (LIFT_HOLD_DUR*second) => time tLiftHoldEnd;
    while (now < tLiftHoldEnd) {
        cam.lookAt(lookCenter, @(0,1,0.001)); // safe up to avoid orientation twitch
        GG.nextFrame() => now;
    }
    
    // ===== G: spiral down (start EXACTLY at F end) =====
    
    // read the exact pose at end of F
    cam.pos() => vec3 sPos;
    (sPos.x - lookCenter.x) => float sdx;
    (sPos.z - lookCenter.z) => float sdz;
    Math.sqrt(sdx*sdx + sdz*sdz) => float r0;   // may be 0
    sPos.y => float y0;
    
    // angle from current pos if r0>0, else fall back to orbit?s last angle
    (r0 > 1e-9 ? Math.atan2(sdz, sdx) : aAfterOrbit) => float abase;

// shortest-wrap align to aAfterOrbit (adds +/- 2? only; keeps same cos/sin)
(abase - aAfterOrbit) => float dA;
while (dA >  Math.PI)  dA - 2.0*Math.PI => dA;
while (dA <= -Math.PI) dA + 2.0*Math.PI => dA;
(dA + aAfterOrbit) => float a0;

// spiral targets
13.0  => float SPIRAL_DUR;    // seconds
2.0   => float SPIRAL_TURNS;  // turns
0.80  => float rEnd;          // end radius
1.20  => float yEnd;          // end height

// if we start directly above center (r0==0), smoothly "kick in" radius
0.08  => float KICK;          // portion of the timeline for the radius to wake up from 0
now + (SPIRAL_DUR*second) => time tEnd;

// prime the very first frame to be IDENTICAL to F end
cam.pos(sPos);
cam.lookAt(lookCenter, @(0,1,0.001));

while (now < tEnd) {
    // normalized time with clamp + smoothstep
    1.0 - ((tEnd - now) / (SPIRAL_DUR*second)) => float u;
    Math.max(0.0, Math.min(1.0, u)) => u;
    u*u*(3.0 - 2.0*u) => float s; // ease
    
    // continuous angle from a0
    (a0 + (2.0*Math.PI*SPIRAL_TURNS)*s) => float a;
    
    // radius: exact r0 at s=0; if r0==0, grow gently over the first KICK of the motion
    float rk;
    if (r0 <= 1e-9) {
        // make a tiny ease-in just for radius (position stays exactly put at s=0)
        Math.max(0.0, Math.min(1.0, (u / KICK))) => float uk;
        uk*uk*(3.0 - 2.0*uk) => rk;         // 0..1 during kick window
        (rEnd * rk) => rk;                  // ramp from 0 toward rEnd
    } else {
        (r0 + (rEnd - r0)*s) => rk;         // normal lerp when r0>0
    }
    
    // height
    (y0 + (yEnd - y0)*s) => float y;
    
    // position (for s=0: rk==r0, a==a0 -> exactly sPos)
    @( lookCenter.x + Math.cos(a)*rk,
    y,
    lookCenter.z + Math.sin(a)*rk ) => vec3 p;
    
    cam.pos(p);
    cam.lookAt(lookCenter, @(0,1,0.001));
    GG.nextFrame() => now;
}
    
    // ---- H: level out at the phone (final small adjust to a clean, level view) ----
    // Lift or lower slightly to sit right at phone height; keep a modest radius & north-facing look.
    3.0 => float H_DUR;         // seconds
    1.0  => float H_TARGET_R;    // meters from center
    (PLANE_Y + 0.9) => float H_TARGET_Y; // eye height near phone plane
    
    // compute current polar
    cam.pos() => vec3 hPos;
    (hPos.x - lookCenter.x) => float hdx;
    (hPos.z - lookCenter.z) => float hdz;
    Math.atan2(hdz, hdx) => float hAng0;
    Math.sqrt(hdx*hdx + hdz*hdz) => float hR0;
    hPos.y => float hY0;
    
    // end heading: face north (same as A0) for a tidy finish
    A0 => float hAng1;
    
    now => time tH;
    (H_DUR*second) => dur dH;
    while ((now - tH) < dH) {
        (((now - tH)/dH) $ float) => float u;
        ease(u) => float s;
        
        (hAng0 + (hAng1 - hAng0)*s) => float ha;
        (hR0   + (H_TARGET_R - hR0)*s) => float hr;
        (hY0   + (H_TARGET_Y - hY0)*s) => float hy;
        
        @(
        lookCenter.x + Math.cos(ha)*hr,
        hy,
        lookCenter.z + Math.sin(ha)*hr
        ) => vec3 p;
        cam.pos(p);
        cam.lookAt(lookCenter);
        GG.nextFrame() => now;
    }
    
    // ---- I: lift the camera a bit more (straight up) ----
    5.0 => float CAM_LIFT_DUR_SEC;   // seconds
    6.0 => float CAM_LIFT_DY;        // meters
    
    cam.pos() => vec3 camLiftStart;
    @( camLiftStart.x, camLiftStart.y + CAM_LIFT_DY, camLiftStart.z ) => vec3 camLiftEnd;
    
    now => time tI;
    (CAM_LIFT_DUR_SEC*second) => dur dI;
    while ((now - tI) < dI) {
        (((now - tI)/dI) $ float) => float u;
        ease(u) => float s;
        vlerp(camLiftStart, camLiftEnd, s) => vec3 p;
        cam.pos(p);
        cam.lookAt(lookCenter);
        GG.nextFrame() => now;
    }
    cam.pos(camLiftEnd);
    cam.lookAt(lookCenter);
    
    // ---- J: SLOW lift BOTH card rings while tilting camera to look up ----
    // Slower rise (unchanged)
    1.25 => float PASS_CLEAR;        // how far above camera Y to end up
    10.5  => float RINGS_RISE_DUR;    // seconds (slower than before)
    
    // How far above the rings to aim the camera's look target
    2.0  => float LOOK_UP_EXTRA;
    
    // NEW: make the tilt progress slower than the ring lift
    1.8  => float TILT_SLOW;         // >1 = tilt lags; try 1.6?2.2
    
    RING_Y  => float ring1StartY;
    RING2_Y => float ring2StartY;
    
    // where the camera ended after the I-lift
    cam.pos() => vec3 cposAfterLift;
    // target Y for rings (above camera)
    (cposAfterLift.y + PASS_CLEAR) => float ringsTargetY;
    
    // cache initial look target (center) and compute an upward target
    lookCenter.y => float lookY0;
    (ringsTargetY + LOOK_UP_EXTRA) => float lookY1;
    
    now => time tJ;
    (RINGS_RISE_DUR*second) => dur dJ;
    while ((now - tJ) < dJ) {
        (((now - tJ)/dJ) $ float) => float u;
        
        // ring lift uses your normal smoothstep
        ease(u) => float sLift;
        
        // tilt uses a *slower* curve: ease(pow(u, TILT_SLOW))
        Math.pow(u, TILT_SLOW) => float uSlow;
        ease(uSlow) => float sTilt;
        
        // lift rings
        (ring1StartY + (ringsTargetY - ring1StartY) * sLift) => RING_Y;
        (ring2StartY + (ringsTargetY - ring2StartY) * sLift) => RING2_Y;
        
        // tilt gaze upward more slowly
        (lookY0 + (lookY1 - lookY0) * sTilt) => float ly;
        cam.lookAt(@(lookCenter.x, ly, lookCenter.z));
        
        GG.nextFrame() => now;
    }
    
    // snap to exact end state
    ringsTargetY => RING_Y;
    ringsTargetY => RING2_Y;
    cam.lookAt(@(lookCenter.x, lookY1, lookCenter.z));
        
}

spork ~ oneTake();


// ---------- SCREEN WAVEFORM BARS ----------
GCube bars[NSEG];
for (int i; i < NSEG; i++) { new GCube @=> bars[i]; bars[i] --> scene; bars[i].mat(waveMat); }
0.06 => float SIDE_GAP;
(SCREEN_W - 2*SIDE_GAP) / NSEG => float BAR_W;
0.020 => float STRIP_THICK_Z; 0.0012 => float BAR_THICK_Y;
2.40 => float AMP_GAIN; 0.18 => float LERP;
float zDisp[NSEG]; for (int i; i < NSEG; i++) 0.0 => zDisp[i];

// ---------- SQUIGGLY LINE (TIME-DOMAIN) ----------
GLines squiggle --> scene;
squiggle.width(0.012);
squiggle.color(@(1.0, 0.12, 0.10));      // dark red
squiggle.rot(@(-Math.PI/2.0, 0.0, 0.0));
squiggle.pos(@(0.0, PLANE_Y + 0.0012, z_STRIP_CTR)); // float above bars
vec2 wpos[NSEG];
for (int i; i < NSEG; i++) { (-SCREEN_W/2 + SIDE_GAP + BAR_W*0.5) + (i * BAR_W) => wpos[i].x; 0.0 => wpos[i].y; }
squiggle.positions(wpos);
float yLine[NSEG]; for (int i; i < NSEG; i++) 0.0 => yLine[i];

// ===========================
// FFT CHAIN (for waterfall) ? sndpeek-style
// ===========================
1024 => int WINDOW_SIZE;
WINDOW_SIZE*2 => int FFT_SIZE;
((second / samp) $ float) => float SR;

Flip accum => blackhole; tap => accum; WINDOW_SIZE => accum.size;
PoleZero dcbloke; .95 => dcbloke.blockZero;
FFT fft; tap => dcbloke => fft => blackhole;

Windowing.hann(WINDOW_SIZE) => fft.window;
FFT_SIZE => fft.size;
// pre-allocate spectrum buffer
(FFT_SIZE/2) + 1 => int SPEC_N;
complex response[SPEC_N];

// ------- bands (denser than 12 for that ?sea? look) -------
20 => int LAS_NBANDS;
float bandMag[LAS_NBANDS]; for (int b; b < LAS_NBANDS; b++) 0.0 => bandMag[b];

80.0 => float F_LO; 8000.0 => float F_HI;
LAS_NBANDS + 1 => int NEDGES;
float edgeHz[NEDGES]; int edgeBin[NEDGES];
for (int b; b < NEDGES; b++) {
    (b $ float)/(LAS_NBANDS $ float) => float t;
    Math.pow(F_HI/F_LO, t) * F_LO => edgeHz[b];
    (edgeHz[b] / SR * FFT_SIZE) $ int => edgeBin[b];
    if (edgeBin[b] < 0) 0 => edgeBin[b];
    if (edgeBin[b] > (FFT_SIZE/2)) (FFT_SIZE/2) => edgeBin[b];
}

// envelopes + normalization (sndpeek-like)
0.88 => float ATK_F;
0.20 => float REL_F;
0.0015 => float NOISE_FLOOR;
0.015  => float specPeak;

// ===========================
// 8-SPOKE RED SNDPEEK-STYLE WATERFALL (STAR FIELD)
// - Same band-avg, attack/release, rolling-peak normalization
// - Radiates from phone top in 8 directions (N, NE, E, SE, S, SW, W, NW)
// ===========================

8   => int STAR_SPOKES;          // number of directions
90 => int STAR_DEPTH;           // rows per spoke (history length)
0.060 => float STAR_STEP;        // distance between rows along a spoke
0.050 => float STAR_BAND_SP;     // band spacing across a spoke (perpendicular)
0.018 => float STAR_BAR_W;       // cube thickness
0.80  => float STAR_MAX_H;       // max bar height

(PLANE_Y - 0.012)           => float STAR_Y_BASE;   // sit under phone plane
(SCREEN_H/2.0 + 0.20)       => float STAR_START_R;  // start radius (phone edge)

// spoke angles (0..2?): E, NE, N, NW, W, SW, S, SE (looks nice around the phone)
float starAng[STAR_SPOKES];
[ 0.0,
Math.PI/4.0,
Math.PI/2.0,
3.0*Math.PI/4.0,
Math.PI,
5.0*Math.PI/4.0,
3.0*Math.PI/2.0,
7.0*Math.PI/4.0 ] @=> starAng;

// unit direction + perpendicular (x,z) for each spoke
float dirX[STAR_SPOKES], dirZ[STAR_SPOKES], px[STAR_SPOKES], pz[STAR_SPOKES];
float orgX[STAR_SPOKES], orgZ[STAR_SPOKES];

for (int s; s < STAR_SPOKES; s++) {
    Math.cos(starAng[s]) => dirX[s];
    Math.sin(starAng[s]) => dirZ[s];
    -dirZ[s] => px[s];     // perpendicular = rotate 90
    dirX[s] => pz[s];
    
    // start at the phone edge along this spoke
    dirX[s]*STAR_START_R => orgX[s];
    dirZ[s]*STAR_START_R => orgZ[s];
}

// deep red material (bloom already enabled)
PBRMaterial starMat;
starMat.color(@(1.0, 0.12, 0.10));
starMat.roughness(0.35);
starMat.metallic(0.10);

// allocate cubes: [spoke][row][band]
GCube starBar[STAR_SPOKES][STAR_DEPTH][LAS_NBANDS];

// build geometry
for (int s; s < STAR_SPOKES; s++) {
    for (int d; d < STAR_DEPTH; d++) {
        // position along the spoke for this row
        (d $ float) * STAR_STEP => float t;
        (orgX[s] + dirX[s]*t) => float baseX;
        (orgZ[s] + dirZ[s]*t) => float baseZ;
        
        for (int b; b < LAS_NBANDS; b++) {
            new GCube @=> starBar[s][d][b];
            starBar[s][d][b] --> scene;
            starBar[s][d][b].mat(starMat);
            
            // band offset centered across the spoke using its perpendicular
            ((b $ float) - ((LAS_NBANDS-1) $ float)/2.0) * STAR_BAND_SP => float off;
            (baseX + px[s]*off) => float x;
            (baseZ + pz[s]*off) => float z;
            
            // small stub; scale Y on updates
            starBar[s][d][b].sca(@(STAR_BAR_W, 0.006, STAR_BAR_W));
            starBar[s][d][b].pos(@(x, STAR_Y_BASE + 0.003, z));
        }
    }
}

// per-band envelopes for normalization (shared across spokes)
float starEnv[LAS_NBANDS]; for (int b; b < LAS_NBANDS; b++) 0.0 => starEnv[b];

// circular write head (row to overwrite next) ? inline advance (no helper fn)
-1 => int starHead;

// worker: compute sndpeek-style bands, stamp newest row on all spokes
fun void spectrogram_star_worker()
{
    while (true) {
        accum.upchuck();
        fft.upchuck();
        fft.spectrum(response);
        
        0.0 => float frameMax;
        
        // band-averaged magnitudes with attack/release (sndpeek-style)
        for (int b; b < LAS_NBANDS; b++) {
            edgeBin[b] => int k0;
            edgeBin[b+1] => int k1;
            if (k1 < k0) { int t; k0 => t; k1 => k0; t => k1; }
            
            0.0 => float acc; 0 => int cnt;
            int k; k0 => k;
            while (k <= k1 && k < response.size()) {
                (response[k] $ polar).mag + acc => acc;
                cnt++; k++;
            }
            (cnt > 0 ? acc/(cnt $ float) : 0.0) - NOISE_FLOOR => float m;
            if (m < 0.0) 0.0 => m;
            
            if (m > starEnv[b]) (starEnv[b] + ATK_F*(m - starEnv[b])) => starEnv[b];
            else                (starEnv[b] + REL_F*(m - starEnv[b])) => starEnv[b];
            
            if (starEnv[b] > frameMax) starEnv[b] => frameMax;
        }
        
        Math.max(frameMax, specPeak * 0.985) => specPeak;
        
        // advance write head and stamp newest row outward on every spoke
        (starHead + 1) % STAR_DEPTH => starHead;
        
        for (int s; s < STAR_SPOKES; s++) {
            for (int b; b < LAS_NBANDS; b++) {
                (specPeak > 1e-6 ? (starEnv[b] / specPeak) : 0.0) => float n;  // [0..1]
                Math.pow(Math.max(0.0, n), 0.85) * STAR_MAX_H => float h;      // gamma 0.85
                
                starBar[s][starHead][b].sca(@(STAR_BAR_W, Math.max(0.004, h), STAR_BAR_W));
                starBar[s][starHead][b].posY(STAR_Y_BASE + 0.5*h);
            }
        }
        
        (WINDOW_SIZE::samp/2) => now; // half-overlap hop
    }
}
spork ~ spectrogram_star_worker();


// ===========================
// FULL LASER CIRCLE + GLOW + OPTIONAL COLUMN
// drop in before main while(true) loop
// ===========================

// ----- layout -----
128 => int  VIS_ARC;               // angular resolution for full circle
12  => int  VIS_BANDS;             // outward rows
Math.max(3.10, RING_RADIUS + 0.35) => float VIS_BASE_RADIUS;
0.26 => float VIS_BAND_STEP;       // radial spacing
(PLANE_Y - 0.012) => float VIS_Y;  // ground level

// full circle angles
0.0   => float VIS_A0;
2.0*Math.PI => float VIS_SPAN;

// block shape
0.030 => float VIS_SEG_W;
0.0012 => float VIS_SEG_Y;
0.38  => float VIS_SEG_L;

// laser material (deep red for bloom)
PBRMaterial visLaserMat;
visLaserMat.color(@(1.0, 0.12, 0.10));
visLaserMat.roughness(0.35);
visLaserMat.metallic(0.10);

// precompute full circle angles
float visAng[VIS_ARC];
for (int i; i < VIS_ARC; i++) {
    VIS_A0 + VIS_SPAN * ((i $ float) / Math.max(1.0, (VIS_ARC $ float))) => visAng[i];
}

// build circle of laser panels
GCube visSeg[VIS_ARC][VIS_BANDS];
for (int a; a < VIS_ARC; a++) {
    for (int b; b < VIS_BANDS; b++) {
        new GCube @=> visSeg[a][b];
        visSeg[a][b] --> scene;
        visSeg[a][b].mat(visLaserMat);
        visSeg[a][b].sca(@(VIS_SEG_W, VIS_SEG_Y, VIS_SEG_L));
        visSeg[a][b].rot(@(-Math.PI/2.0, visAng[a], 0.0));
        
        (VIS_BASE_RADIUS + b*VIS_BAND_STEP) => float r;
        Math.cos(visAng[a]) * r => float x;
        Math.sin(visAng[a]) * r => float z;
        visSeg[a][b].pos(@(x, VIS_Y, z));
    }
}

// =========================================
// MAKE LASER CIRCLE REACT TO TIME-DOMAIN
// (paste after the static visSeg[][] build, before main loop)
// =========================================

// envelopes per angle (follow the phone squiggle input)
float visEnvA[VIS_ARC]; for (int i; i < VIS_ARC; i++) 0.0 => visEnvA[i];

// reuse the squiggle-friendly envelopes
0.85 => float VIS_ATK_TD;   // attack (fast rise)
0.18 => float VIS_REL_TD;   // release (smooth fall)

// length shaping
0.08  => float VIS_MIN_LEN;     // minimum Z length of each rod
0.42  => float VIS_MAX_EXTRA;   // added length at full amplitude
1.40  => float VIS_GAMMA;       // perceptual curve (lower = more sensitive)

// slight per-band flare so inner bands are a tad longer
0.25  => float VIS_BAND_FLARE;  // 0..1

// how often to update (match phone feel)
16::ms => dur VIS_HOP;

// map angle -> index in samples[]
fun int vis_sample_index_for_angle(float a)
{
    // normalize a in [0, 2?) to [0..1] then into [0..NSEG-1]
    (a - Math.floor(a/(2.0*Math.PI))*(2.0*Math.PI)) => float na;
    (na / (2.0*Math.PI)) * ((NSEG-1) $ float) => float idxf;
    return Math.max(0, Math.min(NSEG-1, (idxf $ int)));
}

// worker: update all rods from time-domain
fun void vis_time_driver()
{
    while (true)
    {
        // envelope per angle from rectified samples
        for (int a; a < VIS_ARC; a++) {
            vis_sample_index_for_angle(visAng[a]) => int i0;
            Math.fabs(samples[i0]) => float m;
            if (m > visEnvA[a]) (visEnvA[a] + VIS_ATK_TD*(m - visEnvA[a])) => visEnvA[a];
            else                 (visEnvA[a] + VIS_REL_TD*(m - visEnvA[a])) => visEnvA[a];
        }
        
        // stamp lengths for every band at each angle
        for (int a; a < VIS_ARC; a++) {
            // perceptual remap + clamp
            Math.max(0.0, visEnvA[a]) => float v;
            Math.pow(v, 1.0 / VIS_GAMMA) => float vv;       // 0..1
            (VIS_MIN_LEN + vv * VIS_MAX_EXTRA) => float L0; // base length
            
            for (int b; b < VIS_BANDS; b++) {
                // subtle flare: inner rows a bit longer
                (1.0 - VIS_BAND_FLARE * (b $ float) / Math.max(1.0, (VIS_BANDS - 1 $ float))) => float flare;
                (L0 * flare) => float L;
                
                // scale on Z
                visSeg[a][b].sca(@(VIS_SEG_W, VIS_SEG_Y, Math.max(0.01, L)));
                
                // tiny radial ?breathing?: push outward by half the length
                (VIS_BASE_RADIUS + b*VIS_BAND_STEP + 0.5*L) => float r;
                Math.cos(visAng[a]) * r => float x;
                Math.sin(visAng[a]) * r => float z;
                visSeg[a][b].pos(@(x, VIS_Y, z));
            }
        }
        
        VIS_HOP => now;
    }
}
spork ~ vis_time_driver();


// ----- soft glow points around the circle -----
int N_GLOWS; 12 => N_GLOWS;
for (int g; g < N_GLOWS; g++) {
    GPointLight glow --> scene;
    glow.color(@(1.0, 0.35, 0.30));
    9.0 => glow.intensity;
    (2.0*Math.PI*g/N_GLOWS) => float a;
    Math.cos(a)*(VIS_BASE_RADIUS+VIS_BAND_STEP*VIS_BANDS) => float x;
    Math.sin(a)*(VIS_BASE_RADIUS+VIS_BAND_STEP*VIS_BANDS) => float z;
    @(x, PLANE_Y + 0.12, z) => glow.pos;
}


// === main execution (single frame loop) ===
time lastTime;
0 => int ringInit;

//main execution 
while (true) {
    // phone bars from time-domain samples[]
    for (int i; i < NSEG; i++) {
        (-SCREEN_W/2 + SIDE_GAP + BAR_W*0.5) + (i * BAR_W) => wpos[i].x;
        (1.0 - LERP) * zDisp[i] + LERP * (samples[i] * AMP_GAIN) => zDisp[i];
        bars[i].sca(@(BAR_W, BAR_THICK_Y, STRIP_THICK_Z));
        (z_STRIP_CTR + zDisp[i]) => float zCenter;
        bars[i].pos(@(wpos[i].x, PLANE_Y, zCenter));
    }
    
    // squiggle line from TIME-DOMAIN samples (single dark red line)
    0.35 => float LINE_LERP_TD;   // smoothing
    1.8  => float LINE_GAIN_TD;   // amplitude scale
    for (int i; i < NSEG; i++) {
        (1.0 - LINE_LERP_TD) * yLine[i] + LINE_LERP_TD * (samples[i] * LINE_GAIN_TD) => yLine[i];
        yLine[i] => wpos[i].y;
    }
    squiggle.positions(wpos);
    
    // ring rotation timing (decor)
    if (!ringInit) { now => lastTime; 1 => ringInit; }
    ((now - lastTime) / second) => float dt; now => lastTime;
    
    (SPIN_RAD_PER_SEC * dt) => float dAngle1;
    for (int i; i < NUM_CARDS; i++) {
        (baseTheta[i] + dAngle1) => baseTheta[i];
        baseRadius[i] => float r;
        Math.cos(baseTheta[i]) * r => float x;
        Math.sin(baseTheta[i]) * r => float z;
        cards[i].rot(@(-Math.PI/2.0, baseTheta[i] + Math.PI/2.0, extraRotZ[i]));
        cards[i].sca(@(CARD_W * scaleW[i], CARD_T, CARD_L * scaleL[i]));
        cards[i].pos(@(x, RING_Y, z));
    }
    
    (SPIN_RAD_PER_SEC2 * dt) => float dAngle2;
    for (int i; i < NUM_CARDS2; i++) {
        (baseTheta2[i] + dAngle2) => baseTheta2[i];
        baseRadius2[i] => float r2;
        Math.cos(baseTheta2[i]) * r2 => float x2;
        Math.sin(baseTheta2[i]) * r2 => float z2;
        cards2[i].rot(@(-Math.PI/2.0, baseTheta2[i] + Math.PI/2.0, 0.0));
        cards2[i].sca(@(CARD2_W * scaleW2[i], CARD2_T, CARD2_L * scaleL2[i]));
        cards2[i].pos(@(x2, RING2_Y, z2));
    }
    
    GG.nextFrame() => now;
}