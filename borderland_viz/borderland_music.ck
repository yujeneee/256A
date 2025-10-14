// ===================================================
// BORDERLAND ? Standalone 95s Build (continuous layers)
// Key center: A minor / A harmonic minor (eerie, tense).
// No mic, no keyboard ? pure audio so it won't stop early.
// Layers keep running once they start; chaos near the end.
// Final hit at ~95s then graceful fade.
// ===================================================

// ---------- GLOBALS (local to this file) ------------
global Gain MUSIC_BUS;           // shared audio bus the visuals can analyze
global int  MUSIC_RUNNING; 1 => MUSIC_RUNNING;
global int  MUSIC_FRENZY;  0 => MUSIC_FRENZY;


// ---------- MASTER BUS ------------------------------
Gain master => JCRev verb => dac;
0.30 => master.gain;
0.18 => verb.mix;

// tap the summed music mix (pre-reverb) for the visualizer
master => MUSIC_BUS => blackhole;

// Global fade + stop
fun void fadeOutAll(dur D) {
    100 => int steps;
    master.gain() => float g0;
    for (int i; i < steps; i++) {
        g0 * (1.0 - (i+1)$float/steps) => master.gain;
        (D/steps) => now;
    }
    0.0 => master.gain;
    0 => MUSIC_RUNNING;
}

// ===================================================
// INSTRUMENTS (all continuous once started)
// ===================================================

// (0s) DRONE ? sustained, uneasy, continuous
fun void inst_drone() {
    SawOsc s1 => Gain mix => LPF f => Gain g => master;
    SawOsc s2 => mix;
    0.5 => mix.gain;
    0.22 => g.gain;
    110.0  => s1.freq;   // A2
    111.3  => s2.freq;   // slight detune for beating
    520.0  => f.freq;
    
    float curF1; s1.freq() => curF1;
    float curF2; s2.freq() => curF2;
    float curCut; f.freq() => curCut;
    
    0.0 => float ph;       // for slow tremolo
    0.18 => float baseAmp;
    0.07 => float tremDepth;
    
    while (MUSIC_RUNNING) {
        // re-target slowly every ~1s
        float tf; 110.0 + Std.rand2f(-2.0, 2.0) => tf;
        float tc; 520.0 + Std.rand2f(-25.0, 25.0) => tc;
        Math.max(200.0, Math.min(1600.0, tc)) => tc;
        
        50 => int steps; // 50 * 20ms = 1s
        for (int i; i < steps && MUSIC_RUNNING; i++) {
            curF1 + (tf - curF1) * 0.03 => curF1;
            curF2 + (tf + 1.3 - curF2) * 0.03 => curF2;
            curCut + (tc - curCut) * 0.03 => curCut;
            
            curF1 => s1.freq;
            curF2 => s2.freq;
            curCut => f.freq;
            
            // ~0.2 Hz tremolo
            ph + (2.0 * Math.PI * 0.2 * 0.02) => ph;
            baseAmp + tremDepth * Math.sin(ph) => float amp;
            Math.max(0.0, amp) => g.gain;
            
            20::ms => now;
        }
    }
}

// (10s) CLOCK ? irregular ticks; continuous
fun void inst_clock() {
    SawOsc t => LPF pf => ADSR env => Gain g => master;
    900 => pf.freq;
    0.16 => g.gain;
    env.set(5::ms, 40::ms, 0.0, 60::ms);
    
    while (MUSIC_RUNNING) {
        float bpm;
        if (MUSIC_FRENZY) 168.0 => bpm; else 118.0 => bpm;
        
        (60.0 / bpm) * Std.rand2f(0.85, 1.25) => float beat;
        
        Std.rand2f(180.0, 260.0) => float hz; // around A/E region
        hz => t.freq;
        
        // ON
        env.keyOn();
        now + (beat * 0.12)::second => time tEnd;
        while (MUSIC_RUNNING && now < tEnd) 10::ms => now;
        // OFF
        env.keyOff();
        now + (beat * 0.88)::second => tEnd;
        while (MUSIC_RUNNING && now < tEnd) 10::ms => now;
    }
}

// (20s) SUB BASS ? heartbeat on A minor; continuous
fun void inst_bass() {
    SawOsc s => LPF bf => ADSR e => Gain g => master;
    e.set(3::ms, 60::ms, 0.0, 70::ms);
    0.22 => g.gain;
    600 => bf.freq;
    
    // A, G, F, E (add G# in frenzy for tension)
    int bassDeg[5];
    [45, 43, 41, 40, 44] @=> bassDeg; // MIDI: A2,G2,F2,E2,G#2
    
    while (MUSIC_RUNNING) {
        int idx;
        if (MUSIC_FRENZY) Std.rand2(0,4) => idx; else Std.rand2(0,3) => idx;
        int m; bassDeg[idx] => m;
        Std.mtof(m) => float hz; hz => s.freq;
        
        int r; if (MUSIC_FRENZY) 900 => r; else 500 => r;
        280 + Std.rand2(0, r) => bf.freq;
        
        dur onD; dur offD;
        if (MUSIC_FRENZY) { 90::ms => onD; 70::ms => offD; }
        else              { 130::ms => onD; 120::ms => offD; }
        
        e.keyOn(); onD => now; e.keyOff();
        offD => now;
    }
}

// (30s) BLEEPS ? A harmonic minor; continuous
fun void inst_bleeps() {
    BlitSaw b => LPF filt => ADSR e => Gain g => master;
    0.35 => g.gain;
    1200 => filt.freq;
    e.set(5::ms, 120::ms, 0.18, 140::ms);
    
    // A harm minor pool (A, B, C, D, E, F, G#)
    float notes[7];
    440.0  => notes[0];
    493.88 => notes[1];
    523.25 => notes[2];
    587.33 => notes[3];
    659.25 => notes[4];
    698.46 => notes[5];
    830.61 => notes[6];
    
    while (MUSIC_RUNNING) {
        int thr; if (MUSIC_FRENZY) 2 => thr; else 4 => thr;
        int gate; Std.rand2(0,6) => gate;
        
        if (gate > thr) {
            int idx; Std.rand2(0, 6) => idx;
            float f; notes[idx] => f;
            // sometimes drop an octave
            int down; Std.rand2(0,3) => down; if (down == 0) f * 0.5 => f;
            f => b.freq;
            
            float cf; 1000 + Std.rand2(-200, 240) => cf;
            Math.max(400.0, cf) => cf; cf => filt.freq;
            
            e.keyOn(); 110::ms => now; e.keyOff();
        }
        
        float wL; float wH;
        if (MUSIC_FRENZY) { 0.07 => wL; 0.16 => wH; }
        else              { 0.22 => wL; 0.48 => wH; }
        float w; Std.rand2f(wL, wH) => w;
        w::second => now;
    }
}

// (40s) NOISE AIR ? swells; continuous
fun void inst_noise() {
    Noise n => HPF h => Gain g => master;
    800 => h.freq;
    0.06 => g.gain;
    
    while (MUSIC_RUNNING) {
        int coin; Std.rand2(0,10) => coin;
        int thr;  if (MUSIC_FRENZY) 4 => thr; else 7 => thr;
        if (coin > thr) 0.24 => g.gain; else 0.06 => g.gain;
        
        dur d; if (MUSIC_FRENZY) 60::ms => d; else 120::ms => d;
        d => now;
    }
}

// (45s) SIREN ? melodic saw that pulses in volume; continuous
fun void inst_siren() {
    // Saw with slow gain LFO and gentle pitch wobble (A5 center)
    SawOsc s => LPF f => Gain g => master;
    0.16 => g.gain;  // overall loudness
    1800 => f.freq;  // bright but not harsh
    880.0 => s.freq; // A5 center
    
    0.0 => float phAmp;   // amplitude LFO phase
    0.0 => float phPitch; // pitch wobble phase
    
    while (MUSIC_RUNNING) {
        // LFO rates (faster in frenzy)
        float ampRate; if (MUSIC_FRENZY) 0.6 => ampRate; else 0.35 => ampRate; // Hz
        float pitRate; if (MUSIC_FRENZY) 0.4 => pitRate; else 0.35 => pitRate; // Hz
        
        // compute per-step (10ms) updates for about 1s
        for (int i; i < 100 && MUSIC_RUNNING; i++) {
            // amplitude LFO depth
            0.12 => float base;   // baseline gain
            0.15 => float depth;  // pulse depth
            base + depth * Math.sin(phAmp) => float amp;
            Math.max(0.0, amp) => g.gain;
            
            // slight pitch wobble around A5; more intense in frenzy
            float wobDepth; if (MUSIC_FRENZY) 12.0 => wobDepth; else 6.0 => wobDepth; // Hz
            880.0 + wobDepth * Math.sin(phPitch) => s.freq;
            
            // optional subtle filter motion
            f.freq() + Std.rand2(-8, 14) => float cf;
            Math.max(600.0, Math.min(4200.0, cf)) => f.freq;
            
            // advance phases
            phAmp + 2.0 * Math.PI * ampRate * 0.01 => phAmp;   // dt = 10ms
            phPitch + 2.0 * Math.PI * pitRate * 0.01 => phPitch;
            
            10::ms => now;
        }
    }
}

// (50s) ARP ? A harmonic minor shards; continuous
fun void inst_arp() {
    BlitSaw a => LPF filt => ADSR e => Gain g => master;
    0.13 => g.gain;
    1400 => filt.freq;
    e.set(4::ms, 160::ms, 0.22, 200::ms);
    
    int scale[]; [69, 71, 72, 74, 76, 77, 80] @=> scale; // A,B,C,D,E,F,G#
    
    while (MUSIC_RUNNING) {
        int idx; Std.rand2(0, scale.size()-1) => idx;
        int m; scale[idx] => m;
        int add12; Std.rand2(0,1) => add12; if (add12 == 1) 12 +=> m;
        
        Std.mtof(m) => float hz; hz => a.freq;
        
        int cf; 1200 + Std.rand2(-250, 260) => cf;
        Math.max(300, cf) => cf; cf => filt.freq;
        
        dur onD; dur offD;
        if (MUSIC_FRENZY) { 75::ms => onD; 55::ms => offD; }
        else              { 130::ms => onD; 100::ms => offD; }
        
        e.keyOn(); onD => now; e.keyOff();
        offD => now;
    }
}

// (60s) GLITCH ? metallic stutter; continuous
fun void inst_glitch() {
    SinOsc s1 => Gain mix => LPF f => ADSR e => Gain g => master;
    SinOsc s2 => mix;
    0.5 => mix.gain;
    0.12 => g.gain;
    1000 => f.freq;
    e.set(3::ms, 50::ms, 0.0, 60::ms);
    
    220 => s1.freq;   // near A3
    227 => s2.freq;
    
    while (MUSIC_RUNNING) {
        s1.freq() + Std.rand2f(-8, 8) => float f1; Math.max(60.0, f1) => s1.freq;
        s2.freq() + Std.rand2f(-8, 8) => float f2; Math.max(60.0, f2) => s2.freq;
        float ff; f.freq() + Std.rand2f(-40, 40) => ff;
        Math.max(200.0, Math.min(4000.0, ff)) => f.freq;
        
        dur onD; dur offD;
        if (MUSIC_FRENZY) { 40::ms => onD; 40::ms => offD; }
        else              { 70::ms => onD; 90::ms => offD; }
        
        e.keyOn(); onD => now; e.keyOff();
        offD => now;
    }
}

// (88?94s) RISER ? glide/brighten; continuous during window
fun void inst_riser() {
    SawOsc s => LPF f => Gain g => master;
    0.12 => g.gain;
    900 => f.freq;
    220 => s.freq;
    
    time t0 => time t;
    6::second => dur D; // 88?94
    while (MUSIC_RUNNING && (t - t0 < D)) {
        s.freq() + 3.0 => float sf; Math.min(5000.0, sf) => s.freq;
        f.freq() + 18  => float cf; Math.min(6500.0, cf) => f.freq;
        40::ms => now; now => t;
    }
    0.16 => g.gain; // hold into final hit
}

// ===== KICK (starts at 35s) =====

// helper: one synth kick hit into provided bus
fun void kickOnce(dur L, Gain @bus) {
    SinOsc s => ADSR e => bus;         e.set(1::ms, 60::ms, 0.0, 40::ms);
    Noise n => BPF bp => ADSR ce => bus; 2000 => bp.freq; 2.5 => bp.Q; ce.set(1::ms, 10::ms, 0.0, 10::ms);
    0.7 => s.gain; 0.15 => n.gain;
    
    90.0 => float fStart; 40.0 => float fEnd;
    (L / 2::ms) $ int => int steps; if (steps < 1) 1 => steps;
    
    e.keyOn(); ce.keyOn();
    for (int i; i < steps && MUSIC_RUNNING; i++) {
        (i $ float) / (steps $ float) => float x;
        fStart + (fEnd - fStart) * Math.pow(x, 0.35) => float f;
        Math.max(20.0, f) => s.freq;
        2::ms => now;
    }
    e.keyOff(); ce.keyOff();
}

// (35s) KICK ? continuous 4-on-the-floor; busier in frenzy
fun void inst_kick() {
    Gain bus => LPF out => Gain g => master;
    120.0 => out.freq;
    0.22 => g.gain;
    
    while (MUSIC_RUNNING) {
        float bpm; if (MUSIC_FRENZY) 168.0 => bpm; else 118.0 => bpm;
        (60.0/bpm)::second => dur stepD;
        
        for (int i; i < 4 && MUSIC_RUNNING; i++) {
            spork ~ kickOnce(90::ms, bus);
            
            // in frenzy, occasional offbeat ghost
            if (MUSIC_FRENZY && (i == 1 || i == 3)) {
                now + (stepD * 0.5) => time tGhost;
                while (MUSIC_RUNNING && now < tGhost) 2::ms => now;
                spork ~ kickOnce(65::ms, bus);
            }
            stepD => now;
        }
    }
}

// FINAL HIT (~95s) ? A-minor chord + G# tension, then fade
fun void final_hit() {
    SawOsc p1 => Gain g1 => master; 0.22 => g1.gain; 440.00 => p1.freq;   // A4
    SawOsc p2 => Gain g2 => master; 0.20 => g2.gain; 523.25 => p2.freq;   // C5
    SawOsc p3 => Gain g3 => master; 0.18 => g3.gain; 659.25 => p3.freq;   // E5
    SawOsc p4 => Gain g4 => master; 0.14 => g4.gain; 830.61 => p4.freq;   // G#5
    SawOsc d1 => Gain g5 => master; 0.12 => g5.gain; 447.0  => d1.freq;   // detune up
    SawOsc d2 => Gain g6 => master; 0.12 => g6.gain; 435.0  => d2.freq;   // detune down
    // Sub A
    SawOsc sub => LPF lf => Gain gs => master;
    110 => sub.freq; 240 => lf.freq; 0.33 => gs.gain;
    
    1000::ms => now;
    spork ~ fadeOutAll(1.7::second);
}

// ===================================================
// SCHEDULER ? layers keep running; frenzy flips at 60s
// ===================================================
fun void timeline95() {
    time t0 => time t;
    
    <<< "0s: drone" >>>;        spork ~ inst_drone();
    
    while (MUSIC_RUNNING && now < t0 + 10::second) 10::ms => now;
    if (MUSIC_RUNNING) { <<< "10s: clock" >>>;   spork ~ inst_clock(); }
    
    while (MUSIC_RUNNING && now < t0 + 20::second) 10::ms => now;
    if (MUSIC_RUNNING) { <<< "20s: bass"  >>>;   spork ~ inst_bass(); }
    
    while (MUSIC_RUNNING && now < t0 + 30::second) 10::ms => now;
    if (MUSIC_RUNNING) { <<< "30s: bleeps" >>>;  spork ~ inst_bleeps(); }
    
    // 35s: kick starts
    while (MUSIC_RUNNING && now < t0 + 35::second) 10::ms => now;
    if (MUSIC_RUNNING) { <<< "35s: kick" >>>;   spork ~ inst_kick(); }
    
    while (MUSIC_RUNNING && now < t0 + 40::second) 10::ms => now;
    if (MUSIC_RUNNING) { <<< "40s: noise" >>>;   spork ~ inst_noise(); }
    
    // 45s: siren starts
    while (MUSIC_RUNNING && now < t0 + 45::second) 10::ms => now;
    if (MUSIC_RUNNING) { <<< "45s: siren" >>>;   spork ~ inst_siren(); }
    
    while (MUSIC_RUNNING && now < t0 + 50::second) 10::ms => now;
    if (MUSIC_RUNNING) { <<< "50s: arp"   >>>;   spork ~ inst_arp(); }
    
    while (MUSIC_RUNNING && now < t0 + 60::second) 10::ms => now;
    if (MUSIC_RUNNING) { <<< "60s: FRENZY + glitch" >>>; 1 => MUSIC_FRENZY; spork ~ inst_glitch(); }
    
    while (MUSIC_RUNNING && now < t0 + 88::second) 10::ms => now;
    if (MUSIC_RUNNING) { <<< "88s: riser" >>>;   spork ~ inst_riser(); }
    
    while (MUSIC_RUNNING && now < t0 + 95::second) 10::ms => now;
    if (MUSIC_RUNNING) { <<< "95s: final" >>>;   final_hit(); }
}

// ===================================================
// BOOT ? run timeline and keep VM alive
// ===================================================
spork ~ timeline95();
while (MUSIC_RUNNING) 50::ms => now;

