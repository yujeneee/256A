// sequencer_bus.ck ? shared event/state bus for the sequencer

public class Bus {
    // --- grid ---
    static int COLS;
    
    // --- events ---
    static Event seatHit[16];     // broadcast each 16th for column i
    static Event tempoChanged;
    
    // --- front-row seats -> kick ---
    static int   hasPerson[16];
    static float seatVel[16];
    
    // --- transport / tempo ---
    static float bpm;
    static dur   beat;
    static dur   step;
    static int   running;
    
    // ---- STARS (3 rows x 16 cols) -> hi-hat ----
    static int STAR_ROWS;
    static int STAR_COLS;
    static int starHas[3][16];
    
    // ---- LIGHTS (1 row x 16) -> snare ----
    static int LIGHT_COLS;
    static int lightHas[16];
    
    // ---- DANCERS (stage 1 row x 16) -> melody ----
    static int   hasDancer[16];     // 1 if any dancer occupies stage col
    static float dancerPitch[16];   // per-dancer pitch (Hz), driven by viz
    
    // Separate lanes for two dancer types (A/B)
    static int   hasDancerA[16];    // 1 if Dancer A at column
    static int   hasDancerB[16];    // 1 if Dancer B at column
    
    // ---- TREES (stage prop) -> bell ----   // NEW
    static int   treeHas[16];       // 1 if a tree exists at this column
    static float treePitch[16];     // bell freq (Hz) to use for this tree
    
    // ---- init ----
    fun static void init() {
        16 => COLS;
        
        // transport defaults
        120.0 => bpm;
        updateTempo();
        1 => running;
        
        // seats
        for (0 => int i; i < 16; i++) {
            0   => hasPerson[i];
            1.0 => seatVel[i];
        }
        
        // stars
        initStars();
        
        // lights
        initLights();
        
        // dancers
        for (0 => int i; i < 16; i++) {
            0      => hasDancer[i];
            0      => hasDancerA[i];
            0      => hasDancerB[i];
            440.0  => dancerPitch[i]; // default A4
        }
        
        // trees
        for (0 => int j; j < 16; j++) {
            0     => treeHas[j];
            880.0 => treePitch[j]; // bright bell default (A5)
        }
    }
    
    // ---- tempo helpers ----
    fun static void setBPM(float b) {
        Math.max(30.0, Math.min(240.0, b)) => bpm;
        updateTempo();
    }
    
    fun static void updateTempo() {
        (60.0 / bpm) :: second => beat;
        beat / 4 => step; // 16ths
        tempoChanged.broadcast();
    }
    
    // ---- stars helpers ----
    fun static void initStars() {
        3  => STAR_ROWS;
        16 => STAR_COLS;
        for (0 => int r; r < STAR_ROWS; r++) {
            for (0 => int c; c < STAR_COLS; c++) 0 => starHas[r][c];
        }
    }
    
    fun static void setStar(int r, int c, int on) {
        if (r >= 0 && r < STAR_ROWS && c >= 0 && c < STAR_COLS) on => starHas[r][c];
    }
    
    // ---- lights helpers ----
    fun static void initLights() {
        16 => LIGHT_COLS;
        for (0 => int c; c < LIGHT_COLS; c++) 0 => lightHas[c];
    }
    
    fun static void setLight(int c, int on) {
        if (c >= 0 && c < LIGHT_COLS) on => lightHas[c];
    }
    
    // ---- dancer helpers (optional to use) ----
    // keep hasDancer[col] mirrored as (A || B)
    fun static void setDancerA(int c, int on){
        if(c < 0 || c >= COLS) return;
        on => hasDancerA[c];
        ((hasDancerA[c] != 0) || (hasDancerB[c] != 0)) => hasDancer[c];
    }
    
    fun static void setDancerB(int c, int on){
        if(c < 0 || c >= COLS) return;
        on => hasDancerB[c];
        ((hasDancerA[c] != 0) || (hasDancerB[c] != 0)) => hasDancer[c];
    }
    
    fun static void setDancerPitch(int c, float hz){
        if(c < 0 || c >= COLS) return;
        hz => dancerPitch[c];
    }
    
    // ---- tree helpers (optional; mirrors light/star style) ----
    fun static void setTree(int c, int on){
        if(c < 0 || c >= COLS) return;
        on => treeHas[c];
    }
    
    fun static void setTreePitch(int c, float hz){
        if(c < 0 || c >= COLS) return;
        hz => treePitch[c];
    }
}

// auto-init
Bus.init();
