// sequencer_audio.ck ? Kick (people) + Hat (stars) + Snare (lights) + Dancer (melody) + Bell (trees)
// This file assumes Bus exposes:
//   - Event seatHit[16]
//   - int hasPerson[16], float seatVel[16]
//   - int STAR_ROWS, int STAR_COLS, int starHas[3][16]
//   - int LIGHT_COLS, int lightHas[16]
//   - int hasDancer[16], float dancerPitch[16]
//   - int treeHas[16], float treePitch[16]   // NEW: from viz (trees trigger bell)
//
// Keyboard/UI logic lives in sequencer_viz.ck ? this file JUST plays audio.

// ---------------------------------------------
// Kick: simple sine thump with quick LPF + ADSR
class Kick {
    SinOsc s => LPF f => ADSR env => dac;
    0.5  => s.gain;
    60.0 => s.freq;
    120.0 => f.freq;
    env.set(5::ms, 40::ms, 0.2, 80::ms);
    
    fun void play(float vel) {
        // small pitch + gain variation
        60 + Math.random2(-10, 10) => s.freq;
        Math.max(0.0, Math.min(1.0, vel)) * 0.6 => s.gain;
        
        env.keyOn();
        100::ms => now;
        env.keyOff();
    }
}

// ---------------------------------------------
// Hat (closed): noise -> HPF -> LPF -> short envelope
class Hat {
    Noise n => HPF h1 => LPF l1 => ADSR env => dac;
    
    0.25 => n.gain;   // base noise level
    6000 => h1.freq;  // high-pass to remove lows
    11000 => l1.freq; // low-pass to tame harshness
    env.set(1::ms, 18::ms, 0.0, 12::ms);
    
    fun void play(float vel) {
        // subtle per-hit variance so it feels alive
        Std.rand2f(5000, 8000)  => h1.freq;
        Std.rand2f(9000, 13000) => l1.freq;
        Math.max(0.0, Math.min(1.0, vel)) * 0.8 => n.gain;
        
        env.keyOn();
        15::ms => now;
        env.keyOff();
        15::ms => now;
    }
}

// ---------------------------------------------
// Snare: noise crack + body via bandpass + short envelopes
class Snare {
    // two noise layers through different BPFs for a tighter snare
    Noise n1 => BPF bp1 => ADSR env1 => dac;
    Noise n2 => BPF bp2 => ADSR env2 => dac;
    
    // base setup
    0.12 => n1.gain;   0.08 => n2.gain;
    1800 => bp1.freq;  1200 => bp2.freq;
    1.8  => bp1.Q;     1.2  => bp2.Q;
    
    env1.set(1::ms, 60::ms, 0.0, 30::ms);
    env2.set(1::ms, 90::ms, 0.0, 40::ms);
    
    fun void play(float vel) {
        // tiny per-hit variance
        Std.rand2f(1500, 2200) => bp1.freq;
        Std.rand2f(1000, 1600) => bp2.freq;
        
        // scale layer gains with velocity
        Math.max(0.0, Math.min(1.0, vel)) * 0.18 => n1.gain;
        Math.max(0.0, Math.min(1.0, vel)) * 0.14 => n2.gain;
        
        env1.keyOn(); env2.keyOn();
        8::ms => now;
        env1.keyOff(); env2.keyOff();
    }
}

// ---------------------------------------------
// Dancer A: bright saw lead w/ gentle vibrato + LPF + ADSR
class DancerA {
    SawOsc s => LPF f => ADSR env => dac;
    
    0.15 => s.gain;
    2800 => f.freq; 0.9 => f.Q;
    env.set(4::ms, 120::ms, 0.15, 140::ms);
    
    fun void vibratoOnce(float baseFreq) {
        0.0 => float t;
        120::ms => dur hold;
        time end; now + hold => end;
        while(now < end){
            (Math.sin(2.0*Math.PI*5.8*t) * 0.02 * baseFreq) + baseFreq => s.freq;
            1::ms => now; t + 0.001 => t;
        }
        baseFreq => s.freq;
    }
    
    fun void play(float vel, float freq) {
        Math.max(0.0, Math.min(1.0, vel)) * 0.25 => float g;
        g => s.gain;
        Std.rand2f(2200, 3400) => f.freq;
        spork ~ vibratoOnce(freq);
        env.keyOn(); 140::ms => now; env.keyOff();
    }
}

// ---------------------------------------------
// Dancer B: saw + tri blend (present/compiled; optional)
class DancerB {
    SawOsc s1 => Gain mix => LPF f => ADSR env => dac;
    TriOsc s2 => mix; 0.7 => mix.gain;
    
    0.12 => s1.gain; 0.08 => s2.gain;
    2400 => f.freq; 0.8 => f.Q;
    env.set(6::ms, 160::ms, 0.12, 220::ms);
    
    fun void play(float vel, float freq) {
        Math.max(0.0, Math.min(1.0, vel)) * 0.22 => float g1;
        Math.max(0.0, Math.min(1.0, vel)) * 0.18 => float g2;
        g1 => s1.gain; g2 => s2.gain;
        freq => s1.freq; freq => s2.freq;
        Std.rand2f(2000, 3200) => f.freq;
        env.keyOn(); 200::ms => now; env.keyOff();
    }
}

// ---------------------------------------------
// Bell (for Trees): simple additive ping with quick decay
class Bell {
    Gain mix => ADSR env => dac;
    SinOsc p1 => mix;  // fundamental
    SinOsc p2 => mix;  // ~2.4x
    SinOsc p3 => mix;  // ~3.76x
    
    0.12 => mix.gain;
    0.60 => p1.gain;
    0.28 => p2.gain;
    0.18 => p3.gain;
    env.set(2::ms, 280::ms, 0.0, 180::ms);
    
    fun void play(float baseHz) {
        // safe default
        (baseHz > 0 ? baseHz : 880.0) => float f;
        f        => p1.freq;
        f * 2.40 => p2.freq;
        f * 3.76 => p3.freq;
        // tiny random detune for shimmer
        Std.rand2f(-0.8, 0.8) => float cents;
        Math.pow(2.0, cents/1200.0) => float det;
        p2.freq() * det => p2.freq;
        p3.freq() / det => p3.freq;
        
        env.keyOn();
        60::ms => now;
        env.keyOff();
    }
}

// ---------------------------------------------
// Instruments
Kick    kick;
Hat     hat;
Snare   snare;
DancerA dancerA;
DancerB dancerB; // optional
Bell    bell;    // NEW

// ---------------------------------------------
// Per-column event listener: fires when playhead hits this column
fun void seatListener(int idx) {
    while (true) {
        // wait for the visual playhead to broadcast this step
        Bus.seatHit[idx] => now;
        
        // --- Kick: only if someone is seated on that column (front row)
        if (Bus.hasPerson[idx] == 1) {
            spork ~ kick.play(Bus.seatVel[idx]);
        }
        
        // --- Hat: if ANY star row has this column active
        0 => int anyStar;
        for (0 => int r; r < Bus.STAR_ROWS; r++) {
            if (Bus.starHas[r][idx] == 1) { 1 => anyStar; break; }
        }
        if (anyStar == 1) {
            spork ~ hat.play(0.7);
        }
        
        // --- Snare: if the light at this column is active
        if (Bus.lightHas[idx] == 1) {
            spork ~ snare.play(0.8);
        }
        
        // --- Trees: bell ping if a tree is present at this column
        if (Bus.treeHas[idx] == 1) {
            spork ~ bell.play(Bus.treePitch[idx]);
        }
        
        // --- Dancer(s): melody ? pitch supplied by viz via Bus.dancerPitch[idx]
        if (Bus.hasDancer[idx] == 1) {
            spork ~ dancerA.play(0.85 /*vel*/, Bus.dancerPitch[idx]);
            // If you later expose Bus.hasDancerB[idx], you can also:
            // if(Bus.hasDancerB[idx] == 1) spork ~ dancerB.play(0.85, Bus.dancerPitch[idx]);
        }
    }
}

// Spin up listeners for all 16 columns
for (0 => int i; i < 16; i++) {
    spork ~ seatListener(i);
}

// Keep the shred alive
while (true) 1::second => now;

