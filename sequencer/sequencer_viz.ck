// sequencer_viz.ck ? static stage + interactive helpers + bottom toolbar (world-anchored)
// Y up. Playhead broadcasts Bus.seatHit[col]. Audio listens in sequencer_audio.ck.

// ---------- GRID ----------
16 => int COLS;
1.0 => float cellX;
1.0 => float cellZ;

0.12 => float padX;
0.18 => float padZ;

// ---------- CHAIRS ----------
0.28 => float seatY;
0.75 => float seatD;
0.12 => float liftY;

0.60 => float backY;
0.14 => float backT;
0.005 => float EPS_Y;
0.005 => float EPS_Z;

// ---------- PERSON (front row audience blobs) ----------
@(1.00, 0.68, 0.78) => vec3 PERSON_COLOR;
0.45 => float BODY_DIAM_XZ;
1.20 => float BODY_STRETCH_Y;
0.60 => float HEAD_REL;
0.12 => float SEAT_SINK_Y;
2.2  => float PERSON_SCALE;

// ---------- COLORS ----------
@(0.45, 0.08, 0.08) => vec3 CHAIR_COLOR;
@(0.08, 0.08, 0.10) => vec3 FLOOR_COLOR;
@(0.02, 0.02, 0.02) => vec3 BG;
@(0.95, 0.95, 0.95) => vec3 PLAYHEAD_COLOR;
@(0.03, 0.07, 0.18) => vec3 SKY_COLOR;
@(0.95, 0.95, 0.85) => vec3 MOON_COLOR;

// ---------- STAGE ----------
0.40 => float STAGE_GAP_Z;
(COLS * cellX * 1.10) => float STAGE_W;
4.8  => float STAGE_D;
0.90 => float STAGE_RISE;
0.15 => float STAGE_THK;

0.28 => float PROS_DEPTH;
2.40 => float PROS_HEIGHT;
0.26 => float PROS_COL_W;
0.22 => float PROS_BEAM_H;

// expose for dancer placement
0.0 => float STAGE_FRONT_Z_GLOBAL;
0.0 => float STAGE_OPEN_W_GLOBAL;

// stage colors
@(0.45, 0.30, 0.18) => vec3 STAGE_COLOR;
@(0.17, 0.17, 0.20) => vec3 STAGE_BACK;
@(0.64, 0.54, 0.28) => vec3 PROS_COLOR;

// ---------- SCENE / CAMERA ----------
GOrbitCamera cam --> GG.scene();
GG.scene().camera(cam);
cam.perspective();
(50.0 * Math.PI / 180.0) => float fov;
fov => cam.fov;
cam.clip(0.1, 100.0);

// compute a distance that roughly fits the stage
(8 * 0.5) / Math.tan(fov * 0.5) + 2.0 => float zFit;

// FINAL camera you want to end on (pulled back + higher)
@(0.0, 442, zFit * 3.0) => cam.pos;
@(0.0, 1.2, 0.0)         => cam.target;

// ---------- INTRO FADE / ZOOM ----------
fun void introScene() {
    // final camera is whatever we just set above
    cam.pos()    => vec3 finalPos;
    cam.target() => vec3 finalTarget;
    
    // start far and a bit higher
    @(finalPos.x, finalPos.y + 0.6, finalPos.z + 20.0) => vec3 startPos;
    
    GG.scene().ambient(@(0.0, 0.0, 0.0));
    cam.pos(startPos);
    cam.target(finalTarget);
    
    5::second => dur d;
    now + d => time tEnd;
    
    while (now < tEnd) {
        (tEnd - now) / d => float frac;
        1.0 - frac => float t;
        Math.pow(t, 1.6) => float e;
        
        startPos.x + (finalPos.x - startPos.x) * e => float x;
        startPos.y + (finalPos.y - startPos.y) * e => float y;
        startPos.z + (finalPos.z - startPos.z) * e => float z;
        cam.pos(@(x, y, z));
        
        GG.scene().ambient(@(0.22 * e, 0.22 * e, 0.24 * e));
        GG.nextFrame() => now;
    }
}
spork ~ introScene();

// ---------- COORD HELPERS ----------
fun float px(int col) { return ((col + 0.5) * cellX) - (COLS * 0.5 * cellX); }

(-8*0.5*cellZ + cellZ*0.5) => float Z_BACK_EDGE_CENTER;
( 8*0.5*cellZ - cellZ*0.5) => float Z_FRONT_EDGE_CENTER;

1  => int   ROW_AT_BACK;
0.35 => float edgeMarginZ;

(ROW_AT_BACK ? (Z_BACK_EDGE_CENTER + edgeMarginZ)
: (Z_FRONT_EDGE_CENTER - edgeMarginZ)) => float ROW_Z;

// seat footprint
Math.max(0.25, cellX - 2.0*padX) => float seatW;
Math.max(0.25, cellZ - 2.0*padZ) => float seatAvailZ;
seatAvailZ * seatD               => float seatZ;

// ----- extra audience rows (visual only) -----
3  => int   AUD_ROWS;  // r=0 interactive
0.35 => float ROW_GAP_Z;
fun float rowZ(int r) { return ROW_Z + r * (seatZ + ROW_GAP_Z); }

// ---------- FLOOR sized across ALL rows ----------
(ROW_Z - seatZ*0.5)            => float firstRowFrontEdgeZ;
(rowZ(AUD_ROWS-1) + seatZ*0.5) => float lastRowBackEdgeZ;

0.20 => float FLOOR_FRONT_EXT;
2.80 => float FLOOR_BACK_EXT;

(firstRowFrontEdgeZ - FLOOR_FRONT_EXT) => float floorFrontEdgeZ;
(lastRowBackEdgeZ  + FLOOR_BACK_EXT )  => float floorBackEdgeZ;

(floorBackEdgeZ - floorFrontEdgeZ)     => float floorDepthZ;
(COLS * cellX)                         => float floorWidthX;
(floorFrontEdgeZ + floorBackEdgeZ) * 0.5 => float floorCenterZ;

// ---------- FLOOR ----------
GMesh floor(new PlaneGeometry, new FlatMaterial(FLOOR_COLOR)) --> GG.scene();
floor.rot(@(-Math.PI * 0.5, 0, 0));
floor.sca(@(floorWidthX, floorDepthZ, 1));
floor.pos(@(0, 0, floorCenterZ));

// ---------- CHAIRS ----------
class Chair { GMesh seat; GMesh back; }
Chair chairs[16 * 3];

fun void buildChair(int col, int r) {
    px(col) => float X;
    rowZ(r) => float Z;
    
    GMesh seatM(new CubeGeometry, new FlatMaterial(CHAIR_COLOR)) --> GG.scene();
    seatM.sca(@(seatW, seatY, seatZ));
    seatM.pos(@( X, liftY + seatY*0.5, Z ));
    
    Math.min(backT, Math.max(0.05, seatZ*0.35)) => float backThickness;
    GMesh backM(new CubeGeometry, new FlatMaterial(CHAIR_COLOR)) --> GG.scene();
    backM.sca(@(seatW*0.98, backY, backThickness));
    (seatM.pos().y + seatM.sca().y*0.5) => float seatTopY;
    (seatM.pos().z + seatM.sca().z*0.5) => float seatBackZ;
    backM.pos(@( X,
    seatTopY + backY*0.5 + EPS_Y,
    seatBackZ + backThickness*0.5 + EPS_Z ));
    
    Chair c; seatM @=> c.seat; backM @=> c.back; c @=> chairs[r*16 + col];
}

for (0 => int r; r < AUD_ROWS; r++) for (0 => int c; c < 16; c++) buildChair(c, r);

// ---------- PEOPLE (front row only) ----------
class Person { GMesh body; GMesh head; 1 => int active; }
Person persons[16];
int hasPersonLocal[16];

fun void addPersonAt(int col){
    if(col < 0 || col >= 16 || hasPersonLocal[col]) return;
    
    px(col) => float X; ROW_Z => float Z;
    (liftY + seatY) => float seatTopY;
    
    Math.min(seatW, seatZ) * BODY_DIAM_XZ * PERSON_SCALE => float bodyDia;
    bodyDia * BODY_STRETCH_Y => float bodyHeight;
    
    GMesh body(new SphereGeometry, new FlatMaterial(PERSON_COLOR)) --> GG.scene();
    body.sca(@( bodyDia, bodyHeight, bodyDia ));
    body.pos(@( X, seatTopY + bodyHeight*0.5 - SEAT_SINK_Y, Z ));
    
    (bodyDia * HEAD_REL) => float headDia;
    GMesh head(new SphereGeometry, new FlatMaterial(PERSON_COLOR)) --> GG.scene();
    head.sca(@( headDia, headDia, headDia ));
    head.pos(@( X, body.pos().y + bodyHeight*0.5 + headDia*0.5, Z ));
    
    Person p; body @=> p.body; head @=> p.head; p @=> persons[col];
    1 => hasPersonLocal[col]; 1 => Bus.hasPerson[col];
    
    // begin fade coroutine (24 beats)
    spork ~ personFade(col);
}

fun void removePersonAt(int col){
    if(col < 0 || col >= 16 || !hasPersonLocal[col]) return;
    persons[col].body.pos(@( persons[col].body.pos().x, -10.0, persons[col].body.pos().z ));
    persons[col].head.pos(@( persons[col].head.pos().x, -10.0, persons[col].head.pos().z ));
    0 => hasPersonLocal[col]; 0 => Bus.hasPerson[col];
}

// ---------- PERSON FADE (24 beats) ----------
fun void personFade(int col) {
    if(col < 0 || col >= 16) return;
    if(!hasPersonLocal[col]) return;
    
    persons[col].body.pos() => vec3 p;
    p.y => float yStart;
    (yStart - 0.2) => float yEnd;
    
    PERSON_COLOR => vec3 cStart;
    @(0.25, 0.25, 0.25) => vec3 cEnd;
    
    Bus.beat * 24 => dur fadeDur;
    now + fadeDur => time tEnd;
    
    while(now < tEnd) {
        (tEnd - now) / fadeDur => float frac;
        1.0 - frac => float t;
        
        // smooth ease-out drift
        Math.pow(t, 0.6) => t;
        
        yStart + (yEnd - yStart) * t => float yNow;
        vec3 cNow; cStart + (cEnd - cStart) * t => cNow;
        
        persons[col].body.pos(@(p.x, yNow, p.z));
        persons[col].body.mat() $ FlatMaterial @=> FlatMaterial mb; mb.color(cNow); persons[col].body.mat(mb);
        persons[col].head.mat() $ FlatMaterial @=> FlatMaterial mh; mh.color(cNow); persons[col].head.mat(mh);
        
        GG.nextFrame() => now;
    }
    
    removePersonAt(col);
}

// ---------- OPTIONAL STAR SHAPE (visual helper) ----------
fun void makeStar(vec3 p, float size) {
    (size * 0.22) => float thick;
    (size)         => float long;
    0.02           => float depth;
    
    float angs[4];
    0.0 => angs[0]; Math.PI*0.5 => angs[1]; Math.PI*0.25 => angs[2]; -Math.PI*0.25 => angs[3];
    
    for (0 => int i; i < 4; i++) {
        GMesh ray(new CubeGeometry, new FlatMaterial(STAR_COLOR)) --> GG.scene();
        ray.sca(@(long, thick, depth));
        ray.pos(p);
        ray.rot(@(0, 0, angs[i]));
    }
    GMesh core(new CubeGeometry, new FlatMaterial(STAR_COLOR)) --> GG.scene();
    core.sca(@(thick*0.9, thick*0.9, depth));
    core.pos(p);
}

// Map stage column [0..15] -> world X across the proscenium opening
fun float stageXForCol(int col) {
    (-STAGE_OPEN_W_GLOBAL * 0.5) => float leftX;
    (STAGE_OPEN_W_GLOBAL / 16.0) => float stepX;
    // clamp defensively
    if(col < 0) 0 => col; if(col > 15) 15 => col;
    return leftX + (col + 0.5) * stepX;
}

// ---------- BUILD STAGE ----------
fun void buildStage() {
    (ROW_Z - seatZ*0.5) => float seatFrontEdgeZ;
    (seatFrontEdgeZ - STAGE_GAP_Z) => float stageFrontZ;
    (stageFrontZ - STAGE_D*0.5)    => float stageCenterZ;
    (stageFrontZ - STAGE_D)        => float stageBackZ;
    stageFrontZ => STAGE_FRONT_Z_GLOBAL;
    
    // platform
    GMesh plat(new CubeGeometry, new FlatMaterial(STAGE_COLOR)) --> GG.scene();
    plat.sca(@(STAGE_W, STAGE_THK, STAGE_D));
    plat.pos(@(0, STAGE_RISE + STAGE_THK*0.5, stageCenterZ));
    
    // sky
    GMesh sky(new PlaneGeometry, new FlatMaterial(SKY_COLOR)) --> GG.scene();
    sky.sca(@(STAGE_W * 1.06, PROS_HEIGHT * 1.50, 1));
    sky.pos(@(0, STAGE_RISE + PROS_HEIGHT*0.70, stageBackZ - 0.02));
    (sky.pos().z + 0.01) => float zFrontOfSky;
    
    
    // proscenium
    (stageFrontZ - PROS_DEPTH*0.5 - 0.03) => float prosZ;
    (STAGE_RISE + PROS_HEIGHT*0.5)       => float prosColY;
    (STAGE_W*0.5 - PROS_COL_W*0.5)       => float prosX;
    
    GMesh colL(new CubeGeometry, new FlatMaterial(PROS_COLOR)) --> GG.scene();
    colL.sca(@(PROS_COL_W, PROS_HEIGHT, PROS_DEPTH));
    colL.pos(@(-prosX, prosColY, prosZ));
    
    GMesh colR(new CubeGeometry, new FlatMaterial(PROS_COLOR)) --> GG.scene();
    colR.sca(@(PROS_COL_W, PROS_HEIGHT, PROS_DEPTH));
    colR.pos(@( prosX, prosColY, prosZ));
    
    GMesh beam(new CubeGeometry, new FlatMaterial(PROS_COLOR)) --> GG.scene();
    beam.sca(@(STAGE_W + PROS_COL_W*0.6, PROS_BEAM_H, PROS_DEPTH));
    beam.pos(@(0, STAGE_RISE + PROS_HEIGHT + PROS_BEAM_H*0.5, prosZ));
    
    // opening bounds
    (STAGE_RISE + STAGE_THK)   => float yBottom;
    (STAGE_RISE + PROS_HEIGHT) => float yTopOpen;
    (STAGE_W - 2.0*PROS_COL_W) => float openW;
    openW => STAGE_OPEN_W_GLOBAL;
    
    // moon
    (-(STAGE_W - 2.0*PROS_COL_W) * 0.33) => float moonX;
    (yBottom + 0.75 * (yTopOpen - yBottom))   => float moonY;
    0.75 => float moonDia;
    GMesh moon(new SphereGeometry, new FlatMaterial(MOON_COLOR)) --> GG.scene();
    moon.sca(@(moonDia, moonDia, moonDia));
    moon.pos(@(moonX, moonY, zFrontOfSky));
    
    // LIGHT RIG (static cans)
    16 => int LIGHT_COLS;
    (STAGE_W / LIGHT_COLS)         => float lx;
    (-STAGE_W*0.5 + lx*0.5)        => float leftLX;
    (STAGE_RISE + PROS_HEIGHT + PROS_BEAM_H) => float rigY;
    (stageFrontZ - PROS_DEPTH*0.5) => float rigZ;
    
    GMesh rigBar(new CubeGeometry, new FlatMaterial(@(0.15,0.15,0.15))) --> GG.scene();
    rigBar.sca(@(STAGE_W * 1.05, 0.08, 0.10));
    rigBar.pos(@(0, rigY, rigZ));
    
    for (0 => int i; i < LIGHT_COLS; i++) {
        (leftLX + i * lx) => float x;
        GMesh can(new CylinderGeometry, new FlatMaterial(@(0.20, 0.20, 0.22))) --> GG.scene();
        can.sca(@(0.08, 0.22, 0.08));
        can.pos(@(x, rigY - 0.12, rigZ + 0.04));
        can.rot(@(-Math.PI * 0.35, 0, 0));
        
        // neutral bulb (gray) ? glows added by setLight() if needed
        GMesh bulb(new SphereGeometry, new FlatMaterial(@(0.35, 0.35, 0.36))) --> GG.scene();
        bulb.sca(@(0.12, 0.12, 0.12));
        bulb.pos(@(x, rigY - 0.16, rigZ + 0.06));
    }
}
buildStage();

// ---------- CURTAIN (solid close, no gap) ----------
@(0.45, 0.10, 0.10) => vec3 CURTAIN_COL;

GMesh curLF; // left front sliding panel
GMesh curLB; // left back extender
GMesh curRF; // right front sliding panel
GMesh curRB; // right back extender

0 => int curtainState;         // 0 = open, 1 = closed
0 => int curtainAnimating;     // 1 while an animation is running
0 => int curtainPausedTransport;

fun void buildCurtains() {
    (STAGE_OPEN_W_GLOBAL * 0.5) => float postX;
    (STAGE_FRONT_Z_GLOBAL - PROS_DEPTH*0.5 + 0.002) => float cz;
    (STAGE_RISE + PROS_HEIGHT*0.5) => float cy;
    (PROS_HEIGHT * 1.25) => float cH;
    0.28 => float baseW;
    
    // LEFT front
    GMesh lf(new PlaneGeometry, new FlatMaterial(CURTAIN_COL)) --> GG.scene();
    lf.sca(@(baseW, cH, 1));
    lf.pos(@(-postX, cy, cz));
    lf @=> curLF;
    
    // LEFT back (collapsed at post)
    GMesh lb(new PlaneGeometry, new FlatMaterial(CURTAIN_COL)) --> GG.scene();
    lb.sca(@(0.001, cH, 1));
    lb.pos(@(-postX, cy, cz + 0.001));
    lb @=> curLB;
    
    // RIGHT front
    GMesh rf(new PlaneGeometry, new FlatMaterial(CURTAIN_COL)) --> GG.scene();
    rf.sca(@(baseW, cH, 1));
    rf.pos(@(postX, cy, cz + 0.002));
    rf @=> curRF;
    
    // RIGHT back
    GMesh rb(new PlaneGeometry, new FlatMaterial(CURTAIN_COL)) --> GG.scene();
    rb.sca(@(0.001, cH, 1));
    rb.pos(@(postX, cy, cz + 0.003));
    rb @=> curRB;
}
buildCurtains();

// animate to 0=open, 1=closed
fun void curtainAnimateTo(int targetState) {
    1 => curtainAnimating;
    
    (STAGE_OPEN_W_GLOBAL * 0.5) => float postX;
    (STAGE_FRONT_Z_GLOBAL - PROS_DEPTH*0.5 + 0.002) => float cz;
    (STAGE_RISE + PROS_HEIGHT*0.5) => float cy;
    (PROS_HEIGHT * 1.25) => float cH;
    
    0.04 => float overlap;     // how much the two panels overlap at center
    (postX - overlap) => float travel; // how far fronts travel inward from posts
    
    // starting poses
    curLF.pos() => vec3 lf0;
    curRF.pos() => vec3 rf0;
    curLB.sca() => vec3 lb0;
    curRB.sca() => vec3 rb0;
    
    vec3 lf1;
    vec3 rf1;
    vec3 lb1;
    vec3 rb1;
    
    if(targetState == 1) {
        // CLOSED: fronts overlap around 0, backs expand to fill
        @(-overlap, cy, cz)       => lf1;
        @( overlap, cy, cz+0.002) => rf1;
        // left back needs width from post to just past center
        @((postX + overlap), cH, 1) => lb1;
        @((postX + overlap), cH, 1) => rb1;
    } else {
        // OPEN: fronts back to posts, backs collapsed
        @(-postX, cy, cz)          => lf1;
        @( postX, cy, cz+0.002)    => rf1;
        @(0.001, cH, 1)            => lb1;
        @(0.001, cH, 1)            => rb1;
    }
    
    0.8::second => dur D;
    now + D => time end;
    0 => int didSweep;
    
    while(now < end && curtainAnimating == 1) {
        (end - now) / D => float frac;
        1.0 - frac => float t;
        
        // fronts
        lf0.x + (lf1.x - lf0.x) * t => float lx;
        rf0.x + (rf1.x - rf0.x) * t => float rx;
        curLF.pos(@(lx, cy, cz));
        curRF.pos(@(rx, cy, cz + 0.002));
        
        // backs
        lb0.x + (lb1.x - lb0.x) * t => float lscale;
        rb0.x + (rb1.x - rb0.x) * t => float rscale;
        
        curLB.sca(@(lscale, cH, 1));
        curRB.sca(@(rscale, cH, 1));
        
        // position backs: grow inward from posts
        if(targetState == 1) {
            // closing -> we center them between post and center as they grow
            curLB.pos(@(-postX + lscale * 0.5, cy, cz + 0.001));
            curRB.pos(@( postX - rscale * 0.5, cy, cz + 0.003));
        } else {
            // opening -> stick to posts
            curLB.pos(@(-postX, cy, cz + 0.001));
            curRB.pos(@( postX, cy, cz + 0.003));
        }
        
        // sweep once when nearly closed
        if(targetState == 1 && t > 0.55 && didSweep == 0) {
            clearAllCols();
            if(Bus.running == 1) {
                0 => Bus.running;
                1 => curtainPausedTransport;
            } else {
                0 => curtainPausedTransport;
            }
            1 => didSweep;
        }
        
        GG.nextFrame() => now;
    }
    
    // snap
    curLF.pos(lf1);
    curRF.pos(rf1);
    curLB.sca(lb1);
    curRB.sca(rb1);
    if(targetState == 1) {
        1 => curtainState;
    } else {
        0 => curtainState;
        if(curtainPausedTransport == 1) {
            1 => Bus.running;
            0 => curtainPausedTransport;
        }
    }
    
    0 => curtainAnimating;
}

// hook for toolbar / ENTER
fun void toggleCurtain() {
    // if mid animation, flip direction
    if(curtainAnimating == 1) {
        0 => curtainAnimating;
        spork ~ curtainAnimateTo(curtainState == 0 ? 1 : 0);
    } else {
        spork ~ curtainAnimateTo(curtainState == 0 ? 1 : 0);
    }
}


// ---------- STAR / LIGHT STATE HELPERS ----------
fun void setStar(int r, int c, int on) {
    if(r < 0 || r >= Bus.STAR_ROWS || c < 0 || c >= 16) return;
    on => Bus.starHas[r][c];
}

// track individual light glows so we can hide them cleanly
GMesh lightGlow[16];

fun void setLight(int c, int on) {
    if(c < 0 || c >= 16) return;
    on => Bus.lightHas[c];
    if(on == 1) {
        (STAGE_W / 16.0) => float lx;
        (-STAGE_W*0.5 + lx*0.5) => float leftLX;
        (STAGE_RISE + PROS_HEIGHT + PROS_BEAM_H) => float rigY;
        ((ROW_Z - seatZ*0.5) - STAGE_GAP_Z - PROS_DEPTH*0.5) => float rigZ;
        (leftLX + c * lx) => float x;
        
        // hide any old glow before making a new one
        if(lightGlow[c] != null) {
            lightGlow[c].pos(@( lightGlow[c].pos().x, -50.0, lightGlow[c].pos().z ));
        }
        
        // random pleasant color (HSV -> RGB)
        vec3 col;
        Color.hsv2rgb(@(
        Std.rand2f(0.0, 1.0),
        Std.rand2f(0.55, 0.85),
        Std.rand2f(0.85, 1.0)
        )) => col;
        
        GMesh glow(new SphereGeometry, new FlatMaterial(col)) --> GG.scene();
        glow.sca(@(0.16, 0.16, 0.16));
        glow.pos(@(x, rigY - 0.15, rigZ + 0.08));
        glow @=> lightGlow[c];
    } else {
        if(lightGlow[c] != null) {
            lightGlow[c].pos(@( lightGlow[c].pos().x, -50.0, lightGlow[c].pos().z ));
        }
    }
}

// ---------- STAR VISUAL STATE + TOGGLE ----------
GMesh starViz[16];       // main core for each star
GMesh starRays[16][4];   // its 4 rays
int   starOn[16];        // state flags

fun float starZ() {
    return (STAGE_FRONT_Z_GLOBAL - STAGE_D + 0.02);
}

// fade configuration (beat-based)
16 => int STAR_FADE_BEATS;    // total fade time
0.6 => float STAR_Y_RISE;     // start height
@(1.0, 1.0, 0.9) => vec3 STAR_COLOR;
@(0.2, 0.2, 0.2) => vec3 STAR_FADE_COLOR;

// toggle creation / removal
fun void toggleStar(int c) {
    if(c < 0 || c >= 16) return;
    
    (starOn[c] == 1 ? 0 : 1) => starOn[c];
    starOn[c] => Bus.starHas[1][c];
    
    (-STAGE_OPEN_W_GLOBAL * 0.5) => float leftX;
    (STAGE_OPEN_W_GLOBAL / 16.0) => float stepX;
    leftX + (c + 0.5) * stepX => float X;
    (STAGE_RISE + 1.4) => float Y;
    starZ() => float Z;
    
    // hide any previous instance
    if(starViz[c] != null) starViz[c].pos(@(X, -50.0, Z));
    for(0 => int i; i < 4; i++) 
        if(starRays[c][i] != null) starRays[c][i].pos(@(X, -50.0, Z));
    
    if(starOn[c] == 1) {
        @(1.00, 0.96, 0.70) => vec3 STAR_SAT;
        
        // core
        GMesh core(new PlaneGeometry, new FlatMaterial(STAR_SAT)) --> GG.scene();
        core.sca(@(0.22, 0.22, 1));
        core.pos(@(X, Y + STAR_Y_RISE, Z));
        core @=> starViz[c];
        
        // four crossing rays
        for(0 => int i; i < 4; i++) {
            GMesh ray(new PlaneGeometry, new FlatMaterial(STAR_SAT)) --> GG.scene();
            ray.sca(@(0.40, 0.06, 1));
            ray.pos(@(X, Y + STAR_Y_RISE, Z + 0.001 + i*1e-5));
            float ang;
            if(i == 0)       0.0            => ang;
            else if(i == 1)  Math.PI * 0.5  => ang;
            else if(i == 2)  Math.PI * 0.25 => ang;
            else             -Math.PI * 0.25 => ang;
            ray.rot(@(0.0, 0.0, ang));
            ray @=> starRays[c][i];
        }
        
        // start the fade coroutine
        spork ~ starFade(c);
    }
}

// fade coroutine: 16-beat drift down + brightness fade
fun void starFade(int col) {
    if(col < 0 || col >= 16) return;
    if(starViz[col] == null) return;
    
    starViz[col].pos() => vec3 p;
    p.y => float yStart;
    (yStart - STAR_Y_RISE) => float yEnd;
    
    STAR_COLOR => vec3 cStart;
    STAR_FADE_COLOR => vec3 cEnd;
    
    Bus.beat * STAR_FADE_BEATS => dur fadeDur;
    now + fadeDur => time tEnd;
    
    while(now < tEnd) {
        // normalized progress 0?1
        (tEnd - now) / fadeDur => float frac;
        1.0 - frac => float t;
        
        // position + color interpolation
        yStart + (yEnd - yStart) * t => float yNow;
        vec3 cNow; cStart + (cEnd - cStart) * t => cNow;
        
        starViz[col].pos(@(p.x, yNow, p.z));
        starViz[col].mat() $ FlatMaterial @=> FlatMaterial m;
        m.color(cNow); starViz[col].mat(m);
        
        for(0 => int i; i < 4; i++) {
            if(starRays[col][i] != null) {
                starRays[col][i].pos(@(p.x, yNow, p.z + 0.001 + i*1e-5));
                starRays[col][i].mat() $ FlatMaterial @=> FlatMaterial mr;
                mr.color(cNow); starRays[col][i].mat(mr);
            }
        }
        
        GG.nextFrame() => now;
    }
    
    // hide everything
    starViz[col].pos(@(p.x, -10.0, p.z));
    for(0 => int i; i < 4; i++) if(starRays[col][i] != null)
        starRays[col][i].pos(@(p.x, -10.0, p.z));
    
    0 => starOn[col];
    0 => Bus.starHas[1][col];
}

// ---------- CHRISTMAS TREE (visual helper + state) ----------
// Visual: brown trunk + three green tiers (upright).
// Audio: toggling a tree updates Bus.treeHas[col] and Bus.treePitch[col] (Hz).

class Tree { 
    GMesh trunk; 
    GMesh t0; 
    GMesh t1; 
    GMesh t2; 
    int   built; 
}
Tree trees[16];
int  treeOn[16];

@(0.06, 0.24, 0.10) => vec3 TREE_GREEN;
@(0.30, 0.18, 0.08) => vec3 TREE_BROWN;

// place Z: mid-stage, clearly in front of the backdrop and behind dancers
fun float treeZ() { return (STAGE_FRONT_Z_GLOBAL - STAGE_D * 0.80); }

// shared dimensions (kept small so they read on stage)
0.18 => float TRUNK_W;  0.30 => float TRUNK_H;  0.18 => float TRUNK_D;
0.80 => float B_RAD;    0.40 => float B_H;      // bottom tier
0.60 => float M_RAD;    0.36 => float M_H;      // middle tier
0.42 => float T_RAD;    0.32 => float T_H;      // top tier

// compute absolute positions for all parts at a given column
fun void setTreePos(int col) {
    stageXForCol(col) => float X;
    (STAGE_RISE + STAGE_THK + 0.01) => float Y0;  // stage top
    treeZ() => float Z;
    
    // trunk sits on the deck
    if(trees[col].trunk != null) {
        trees[col].trunk.pos(@(X, Y0 + TRUNK_H * 0.5, Z));
    }
    
    // bottom tier rests on trunk
    if(trees[col].t0 != null) {
        trees[col].t0.pos(@(X, Y0 + TRUNK_H + B_H * 0.5, Z));
    }
    
    // middle tier stacks above bottom
    if(trees[col].t1 != null) {
        trees[col].t1.pos(@(X, Y0 + TRUNK_H + B_H + M_H * 0.5, Z));
    }
    
    // top tier
    if(trees[col].t2 != null) {
        trees[col].t2.pos(@(X, Y0 + TRUNK_H + B_H + M_H + T_H * 0.5, Z));
    }
}

// one-time build of meshes into the SCENE (no parenting)
fun void buildTreeAt(int col) {
    if(col < 0 || col >= 16 || trees[col].built == 1) return;
    
    // trunk
    GMesh trunk(new CubeGeometry, new FlatMaterial(TREE_BROWN)) --> GG.scene();
    trunk.sca(@(TRUNK_W, TRUNK_H, TRUNK_D));
    
    // tiers (upright cylinders ? no rotation)
    GMesh t0(new CylinderGeometry, new FlatMaterial(TREE_GREEN)) --> GG.scene();
    t0.sca(@(B_RAD, B_H, B_RAD));
    
    GMesh t1(new CylinderGeometry, new FlatMaterial(TREE_GREEN)) --> GG.scene();
    t1.sca(@(M_RAD, M_H, M_RAD));
    
    GMesh t2(new CylinderGeometry, new FlatMaterial(TREE_GREEN)) --> GG.scene();
    t2.sca(@(T_RAD, T_H, T_RAD));
    
    trunk @=> trees[col].trunk;
    t0    @=> trees[col].t0;
    t1    @=> trees[col].t1;
    t2    @=> trees[col].t2;
    1     => trees[col].built;
    
    setTreePos(col);
}

fun void hideTree(int col) {
    if(col < 0 || col >= 16 || trees[col].built == 0) return;
    // drop below the stage; keep X/Z so we can bring it back cleanly
    if(trees[col].trunk != null) trees[col].trunk.pos(@(trees[col].trunk.pos().x, -50.0, trees[col].trunk.pos().z));
    if(trees[col].t0    != null) trees[col].t0.pos(@(trees[col].t0.pos().x,     -50.0, trees[col].t0.pos().z));
    if(trees[col].t1    != null) trees[col].t1.pos(@(trees[col].t1.pos().x,     -50.0, trees[col].t1.pos().z));
    if(trees[col].t2    != null) trees[col].t2.pos(@(trees[col].t2.pos().x,     -50.0, trees[col].t2.pos().z));
}

fun void showTreeAt(int col) {
    buildTreeAt(col); // safe even if already built
    setTreePos(col);
}

fun void toggleTree(int c) {
    if(c < 0 || c >= 16) return;
    
    (treeOn[c] == 1 ? 0 : 1) => treeOn[c];
    treeOn[c] => Bus.treeHas[c];
    
    // bell pitch: pentatonic across stage
    [0,2,4,7,9] @=> int PENT[];
    72 + PENT[(c % 5)] => int midi;
    Std.mtof(midi) => Bus.treePitch[c];
    
    if(treeOn[c] == 1) showTreeAt(c);
    else               hideTree(c);
}

// ---------- TREE FADE (8 beats) ----------
fun void treeFade(int col) {
    if(col < 0 || col >= 16) return;
    if(trees[col].built == 0) return;
    
    (trees[col].t2.pos().y) => float yStart;
    (yStart - 0.2) => float yEnd;
    @(0.06, 0.24, 0.10) => vec3 cStart;
    @(0.10, 0.10, 0.10) => vec3 cEnd;
    
    Bus.beat * 8 => dur fadeDur;
    now + fadeDur => time tEnd;
    
    while(now < tEnd) {
        (tEnd - now) / fadeDur => float frac;
        1.0 - frac => float t;
        yStart + (yEnd - yStart) * t => float yNow;
        vec3 cNow; cStart + (cEnd - cStart) * t => cNow;
        
        // apply to all tiers
        if(trees[col].t0 != null) {
            trees[col].t0.pos(@(trees[col].t0.pos().x, yNow, trees[col].t0.pos().z));
            trees[col].t0.mat() $ FlatMaterial @=> FlatMaterial m0; m0.color(cNow); trees[col].t0.mat(m0);
        }
        if(trees[col].t1 != null) {
            trees[col].t1.pos(@(trees[col].t1.pos().x, yNow, trees[col].t1.pos().z));
            trees[col].t1.mat() $ FlatMaterial @=> FlatMaterial m1; m1.color(cNow); trees[col].t1.mat(m1);
        }
        if(trees[col].t2 != null) {
            trees[col].t2.pos(@(trees[col].t2.pos().x, yNow, trees[col].t2.pos().z));
            trees[col].t2.mat() $ FlatMaterial @=> FlatMaterial m2; m2.color(cNow); trees[col].t2.mat(m2);
        }
        GG.nextFrame() => now;
    }
    
    hideTree(col);
    0 => treeOn[col];
    0 => Bus.treeHas[col];
}


// Keep visuals synced if Bus.treeHas[] changes elsewhere
fun void syncTreesLoop() {
    int last[16];
    for(0 => int i; i < 16; i++) -1 => last[i];
    
    while(true){
        for(0 => int c; c < 16; c++){
            if(Bus.treeHas[c] != last[c]){
                Bus.treeHas[c] => last[c];
                if(last[c] == 1) showTreeAt(c);
                else             hideTree(c);
            }
        }
        Bus.step => now;
    }
}
spork ~ syncTreesLoop();

// ---------- DANCERS (OBJ MODELS) ----------
0.36 => float DANCER_SCALE;   // overall
0.75 => float DANCER_YOFF;    // lift above stage floor
0.55 => float DANCER_ZDEPTH;  // fraction of stage depth back from front

GModel dancerModels[16];
int    dancerPresent[16];
for (0 => int i; i < 16; i++) 0 => dancerPresent[i];

// halos: up to 3 per dancer
GMesh dancerHalos[16][3];

// Map col -> X across opening (reuse stage mapper)
fun float stageXForCol_d(int col) { return stageXForCol(col); }

// make 3 bright little orbs that circle around the dancer
fun void makeHalosForDancer(int col) {
    if(col < 0 || col >= 16) return;
    if(dancerModels[col] == null) return;
    
    dancerModels[col].pos() => vec3 P;
    
    3 => int N;
    // bright, saturated color
    vec3 haloCol;
    Color.hsv2rgb(@(
    Std.rand2f(0.0, 1.0),
    Std.rand2f(0.80, 1.0),  // stronger saturation
    1.0                     // full brightness
    )) => haloCol;
    
    for(0 => int i; i < N; i++) {
        GMesh orb(new SphereGeometry, new FlatMaterial(haloCol)) --> GG.scene();
        orb.sca(@(0.12, 0.12, 0.12));
        orb.pos(P); // will get updated in orbit loop
        orb @=> dancerHalos[col][i];
    }
    
    spork ~ haloOrbitLoop(col);
}

// keep them circling at dancer's mid-height using elapsed time
fun void haloOrbitLoop(int col) {
    if(col < 0 || col >= 16) return;
    
    0.35 => float R;     // radius around dancer
    0.12 => float YOFF;  // height above dancer origin
    3    => int   N;
    
    // phase offsets so they?re spaced evenly
    float phase[N];
    for(0 => int i; i < N; i++) {
        (i $ float) * (2.0 * Math.PI / N) => phase[i];
    }
    
    now => time t0;
    
    while(dancerPresent[col] == 1) {
        dancerModels[col].pos() => vec3 P;
        
        // seconds since we started this loop
        (now - t0) / second => float secs;
        // base angle: adjust speed by changing 0.9
        (secs * 0.9) => float baseAng;
        
        for(0 => int i; i < N; i++) {
            if(dancerHalos[col][i] != null) {
                baseAng + phase[i] => float a;
                (P.x + Math.cos(a) * R) => float x;
                (P.z + Math.sin(a) * R) => float z;
                dancerHalos[col][i].pos(@(x, P.y + YOFF, z));
            }
        }
        
        GG.nextFrame() => now;
    }
    
    // dancer gone -> drop orbs
    for(0 => int i; i < N; i++) {
        if(dancerHalos[col][i] != null) {
            dancerHalos[col][i].pos(@(0, -20.0, 0));
        }
    }
}

// which: 0 = pressed.obj, 1 = green.obj
fun void addDancerModelAtCol(int col, int which) {
    if(col < 0 || col >= 16) return;
    
    string path;
    if(which == 0) "models/pressed.obj" => path;
    else           "models/green.obj"   => path;
    
    GModel m(path) --> GG.scene();
    
    DANCER_SCALE => float s;
    m.sca(@(s, s, s));
    
    stageXForCol_d(col) => float X;
    (STAGE_FRONT_Z_GLOBAL - STAGE_D * DANCER_ZDEPTH) => float Z;
    (STAGE_RISE + STAGE_THK + DANCER_YOFF) => float Y;
    m.pos(@(X, Y, Z));
    
    m @=> dancerModels[col];
    1 => dancerPresent[col];
    
    // any dancer present
    1 => Bus.hasDancer[col];
    
    // lane flags
    Bus.setDancerA(col, (which == 0) ? 1 : 0);
    Bus.setDancerB(col, (which == 1) ? 1 : 0);
    
    // make halos
    makeHalosForDancer(col);
    
    // auto-despawn after 24 beats
    spork ~ dancerLifetime(col, 24);
}

// 24-beat lifetime
fun void dancerLifetime(int col, int beats) {
    if(col < 0 || col >= 16) return;
    Bus.beat * beats => dur life;
    life => now;
    
    if(dancerPresent[col] == 1) {
        // hide model
        if(dancerModels[col] != null) {
            dancerModels[col].pos(@(dancerModels[col].pos().x, -20.0, dancerModels[col].pos().z));
        }
        0 => dancerPresent[col];
        0 => Bus.hasDancer[col];
        0 => Bus.hasDancerA[col];
        0 => Bus.hasDancerB[col];
        60.0 => Bus.dancerPitch[col];
        // halos will drop in the orbit loop
    }
}

// update your clearAtCol to also drop halos
fun void clearAtCol(int col) {
    if(col < 0 || col >= 16) return;
    
    // remove person if present
    if(hasPersonLocal[col]) removePersonAt(col);
    
    // clear stars
    0 => Bus.starHas[0][col];
    0 => Bus.starHas[1][col];
    0 => Bus.starHas[2][col];
    if(starViz[col] != null) {
        starViz[col].pos(@( starViz[col].pos().x, -50.0, starViz[col].pos().z ));
    }
    0 => starOn[col];
    
    // clear light
    0 => Bus.lightHas[col];
    if(lightGlow[col] != null) {
        lightGlow[col].pos(@( lightGlow[col].pos().x, -50.0, lightGlow[col].pos().z ));
    }
    
    // clear dancer
    if(dancerModels[col] != null) {
        dancerModels[col].pos(@( dancerModels[col].pos().x, -50.0, dancerModels[col].pos().z ));
    }
    0 => dancerPresent[col];
    0 => Bus.hasDancer[col];
    0 => Bus.hasDancerA[col];
    0 => Bus.hasDancerB[col];
    60.0 => Bus.dancerPitch[col];
    
    // clear halos too
    for(0 => int i; i < 3; i++) {
        if(dancerHalos[col][i] != null) {
            dancerHalos[col][i].pos(@(0, -20.0, 0));
        }
    }
}

// clear all (added for curtain sweep)
fun void clearAllCols() {
    for(0 => int c; c < 16; c++) {
        clearAtCol(c);
    }
}

// ---------- PLAYHEAD (drives audio) ----------
GMesh playhead(new CubeGeometry, new FlatMaterial(PLAYHEAD_COLOR)) --> GG.scene();
0.0001 => float playheadW;
0.0001 => float playheadY;
(cellZ * 1.2) => float playheadZSpan;
playhead.sca(@(playheadW, playheadY, playheadZSpan));
playhead.pos(@(px(0), liftY + seatY + 0.02, ROW_Z));

fun void playheadLoop(){
    0 => int col;
    while(true){
        if(Bus.running == 1){
            playhead.pos(@(px(col), playhead.pos().y, playhead.pos().z));
            Bus.seatHit[col].broadcast();   // audio listeners respond
            (col + 1) % COLS => col;
        }
        Bus.step => now; // wait one 16th
    }
}
spork ~ playheadLoop();

// =======================================================
// SUPER-THIN, FAUX-TRANSPARENT LIGHT-BAR PLAYHEAD
// =======================================================

// opening mapping (same as dancers)
(-STAGE_OPEN_W_GLOBAL * 0.5) => float OPEN_LEFT_X;
(STAGE_OPEN_W_GLOBAL / 16.0) => float OPEN_STEP_X;
fun float openXForCol(int col){
    if(col < 0) 0 => col; if(col > 15) 15 => col;
    return OPEN_LEFT_X + (col + 0.5) * OPEN_STEP_X;
}

// vertical span: from stage deck to rig bar, right on the rig's Z
(STAGE_RISE + STAGE_THK)                 => float Y_STAGE_TOP;
(STAGE_RISE + PROS_HEIGHT + PROS_BEAM_H) => float Y_RIG_BAR;
((ROW_Z - seatZ*0.5) - STAGE_GAP_Z - PROS_DEPTH*0.5) => float Z_RIG;

(Y_RIG_BAR - Y_STAGE_TOP) => float BAR_H;
(Y_STAGE_TOP + BAR_H*0.5) => float BAR_Y;
(Z_RIG + 0.0005)          => float BAR_Z; // skim the pole

// --- make it skinny ---
(OPEN_STEP_X * 0.48) => float CORE_W;   // was ~0.98; now ~half a column
(CORE_W * 1.06)      => float FEATHER_W;
(CORE_W * 0.0)       => float HALO_OFFS; // keep feathers centered

// --- very pale colors (reads as translucent) ---
@(0.95, 1.00, 0.62) => vec3 COL_CORE;
@(0.88, 0.98, 0.46) => vec3 COL_FTH1;
@(0.76, 0.86, 0.34) => vec3 COL_FTH2;


GMesh beamCore(new PlaneGeometry, new FlatMaterial(COL_CORE)) --> GG.scene();
GMesh beamF1  (new PlaneGeometry, new FlatMaterial(COL_FTH1)) --> GG.scene();
GMesh beamF2  (new PlaneGeometry, new FlatMaterial(COL_FTH2)) --> GG.scene();

beamCore.sca(@(CORE_W,   BAR_H, 1));
beamF1.sca  (@(FEATHER_W,BAR_H, 1));
beamF2.sca  (@(FEATHER_W*1.08, BAR_H, 1)); // slightly wider for soft falloff

// initial at col 0
fun void placeBeamAtX(float x){
    beamCore.pos(@(x, BAR_Y, BAR_Z));
    // tiny Z offsets so planes don't z-fight; centered for a ?glass? feel
    beamF1.pos(@(x, BAR_Y, BAR_Z + 0.0010));
    beamF2.pos(@(x, BAR_Y, BAR_Z + 0.0020));
}
placeBeamAtX(openXForCol(0));

// move per column
fun void placeBeamAtCol(int col){ placeBeamAtX(openXForCol(col)); }

// brief, gentle pulse so it reads but stays subtle
fun void beamPulse(){
    beamCore.mat() $ FlatMaterial @=> FlatMaterial mc;
    beamF1.mat()   $ FlatMaterial @=> FlatMaterial m1;
    beamF2.mat()   $ FlatMaterial @=> FlatMaterial m2;
    @(0.98, 0.96, 0.80) => vec3 HOT;
    
    5 => int N; (Bus.step/8) => dur dt;
    // up
    for(0 => int i; i < N; i++){
        (i$float/(N$float)) => float u;
        mc.color(@( COL_CORE.x + (HOT.x-COL_CORE.x)*u,
        COL_CORE.y + (HOT.y-COL_CORE.y)*u,
        COL_CORE.z + (HOT.z-COL_CORE.z)*u ));
        m1.color(@( COL_FTH1.x + (HOT.x-COL_FTH1.x)*u,
        COL_FTH1.y + (HOT.y-COL_FTH1.y)*u,
        COL_FTH1.z + (HOT.z-COL_FTH1.z)*u ));
        m2.color(@( COL_FTH2.x + (HOT.x-COL_FTH2.x)*u,
        COL_FTH2.y + (HOT.y-COL_FTH2.y)*u,
        COL_FTH2.z + (HOT.z-COL_FTH2.z)*u ));
        dt => now;
    }
    // down
    for(0 => int i; i < N; i++){
        (i$float/(N$float)) => float u;
        mc.color(@( HOT.x + (COL_CORE.x-HOT.x)*u,
        HOT.y + (COL_CORE.y-HOT.y)*u,
        HOT.z + (COL_CORE.z-HOT.z)*u ));
        m1.color(@( HOT.x + (COL_FTH1.x-HOT.x)*u,
        HOT.y + (COL_FTH1.y-HOT.y)*u,
        HOT.z + (COL_FTH1.z-HOT.z)*u ));
        m2.color(@( HOT.x + (COL_FTH2.x-HOT.x)*u,
        HOT.y + (COL_FTH2.y-HOT.y)*u,
        HOT.z + (COL_FTH2.z-HOT.z)*u ));
        dt => now;
    }
}

// follow transport
fun void beamLoop(){
    0 => int col;
    while(true){
        if(Bus.running == 1){
            placeBeamAtCol(col);
            spork ~ beamPulse();
            (col + 1) % Bus.COLS => col;
        }
        Bus.step => now;
    }
}
spork ~ beamLoop();

// ---------- CURSOR (floor plate instead of vertical rod) ----------
GMesh cursor(new PlaneGeometry, new FlatMaterial(@(1.0, 0.95, 0.60))) --> GG.scene();
0.38 => float CURSOR_W;
0.18 => float CURSOR_H;

fun void placeCursorAt(int col) {
    if(col < 0) 0 => col; if(col > 15) 15 => col;
    stageXForCol(col) => float X;
    (STAGE_FRONT_Z_GLOBAL - STAGE_D * 0.54) => float Z;
    (STAGE_RISE + STAGE_THK + 0.01) => float Y;
    cursor.sca(@(CURSOR_W, CURSOR_H, 1));
    cursor.pos(@(X, Y, Z));
    cursor.rot(@(-Math.PI*0.5, 0, 0));
}
0 => int selCol;
placeCursorAt(selCol);

// ---------- BOTTOM TOOLBAR (world-anchored, cute menu) ----------
( cam.pos().z - 4.2 ) => float HUD_Z;
( cam.pos().y - 2.35 ) => float HUD_Y;
0.0 => float HUD_X_CENTER;

// background bar
GMesh hudBG(new PlaneGeometry, new FlatMaterial(@(0.08,0.08,0.09))) --> GG.scene();
hudBG.sca(@(4.8, 0.6, 1));
hudBG.pos(@(HUD_X_CENTER, HUD_Y, HUD_Z));

// slots (8 now: dancerA, dancerB, person, light, star, tree, clear, curtain)
8 => int HUD_SLOTS;
GMesh hudSlot[HUD_SLOTS];
@(0.82,0.82,0.86) => vec3 slotCol;
0.65 => float SLOT_W;
0.38 => float SLOT_H;
-1.95 => float SLOT_X0;

for (0 => int i; i < HUD_SLOTS; i++) {
    GMesh s(new PlaneGeometry, new FlatMaterial(slotCol)) --> GG.scene();
    s.sca(@(SLOT_W, SLOT_H, 1));
    (HUD_X_CENTER + SLOT_X0 + i*SLOT_W) => float sx;
    s.pos(@(sx, HUD_Y, HUD_Z + 0.01));
    s @=> hudSlot[i];
}

// highlight
@(0.98,0.86,0.50) => vec3 hiCol;
GMesh hudHi(new PlaneGeometry, new FlatMaterial(hiCol)) --> GG.scene();
hudHi.sca(@(SLOT_W + 0.04, SLOT_H + 0.04, 1));
hudHi.pos(hudSlot[0].pos());

// tiny icons for each slot
fun void iconSquare(GMesh parentSlot, vec3 color){
    GMesh m(new PlaneGeometry, new FlatMaterial(color)) --> GG.scene();
    m.sca(@(0.26, 0.26, 1));
    m.pos(@( parentSlot.pos().x, parentSlot.pos().y, parentSlot.pos().z + 0.02 ));
}
fun void iconCircle(GMesh parentSlot, vec3 color){
    GMesh m(new SphereGeometry, new FlatMaterial(color)) --> GG.scene();
    m.sca(@(0.16, 0.16, 0.16));
    m.pos(@( parentSlot.pos().x, parentSlot.pos().y, parentSlot.pos().z + 0.02 ));
}
fun void iconCross(GMesh parentSlot, vec3 color){
    GMesh a(new PlaneGeometry, new FlatMaterial(color)) --> GG.scene();
    GMesh b(new PlaneGeometry, new FlatMaterial(color)) --> GG.scene();
    a.sca(@(0.28, 0.05, 1)); b.sca(@(0.28, 0.05, 1));
    a.rot(@(0,0,  0.75)); b.rot(@(0,0, -0.75));
    a.pos(@( parentSlot.pos().x, parentSlot.pos().y, parentSlot.pos().z + 0.02 ));
    b.pos(@( parentSlot.pos().x, parentSlot.pos().y, parentSlot.pos().z + 0.02 ));
}
fun void iconStar(GMesh parentSlot, vec3 color){
    GMesh core(new PlaneGeometry, new FlatMaterial(color)) --> GG.scene();
    core.sca(@(0.22, 0.22, 1));
    core.pos(@( parentSlot.pos().x, parentSlot.pos().y, parentSlot.pos().z + 0.02 ));
    for(0 => int i; i < 4; i++){
        GMesh ray(new PlaneGeometry, new FlatMaterial(color)) --> GG.scene();
        ray.sca(@(0.40, 0.06, 1));
        ray.pos(@( parentSlot.pos().x, parentSlot.pos().y, parentSlot.pos().z + 0.021 + i*1e-5 ));
        float ang;
        if(i == 0)       0.0            => ang;
        else if(i == 1)  Math.PI * 0.5  => ang;
        else if(i == 2)  Math.PI * 0.25 => ang;
        else            -Math.PI * 0.25 => ang;
        ray.rot(@(0.0, 0.0, ang));
    }
}
// tree icon (triangle + trunk)
fun void iconTree(GMesh parentSlot){
    // trunk
    GMesh trunk(new PlaneGeometry, new FlatMaterial(@(0.55,0.35,0.25))) --> GG.scene();
    trunk.sca(@(0.06, 0.10, 1));
    trunk.pos(@( parentSlot.pos().x, parentSlot.pos().y - 0.08, parentSlot.pos().z + 0.02 ));
    // canopy
    GMesh tri1(new PlaneGeometry, new FlatMaterial(@(0.30,0.65,0.35))) --> GG.scene();
    tri1.sca(@(0.22, 0.16, 1));
    tri1.pos(@( parentSlot.pos().x, parentSlot.pos().y + 0.02, parentSlot.pos().z + 0.02 ));
    GMesh tri2(new PlaneGeometry, new FlatMaterial(@(0.30,0.65,0.35))) --> GG.scene();
    tri2.sca(@(0.18, 0.14, 1));
    tri2.pos(@( parentSlot.pos().x, parentSlot.pos().y + 0.10, parentSlot.pos().z + 0.02 ));
}
// curtain icon
fun void iconCurtain(GMesh parentSlot){
    GMesh m(new PlaneGeometry, new FlatMaterial(@(0.70, 0.12, 0.12))) --> GG.scene();
    m.sca(@(0.12, 0.30, 1));
    m.pos(@( parentSlot.pos().x, parentSlot.pos().y, parentSlot.pos().z + 0.02 ));
}

// icons: 0 dancerA  1 dancerB  2 person  3 light  4 star  5 tree  6 clear  7 curtain
iconSquare(hudSlot[0], @(1.00, 0.45, 0.55));
iconSquare(hudSlot[1], @(0.35, 0.75, 1.00));
iconCircle(hudSlot[2], @(1.00, 0.58, 0.84));
iconCircle(hudSlot[3], @(1.00, 0.82, 0.30));
iconStar  (hudSlot[4], @(1.00, 0.96, 0.70));
iconTree  (hudSlot[5]);
iconCross (hudSlot[6], @(1.00, 0.32, 0.38));
iconCurtain(hudSlot[7]);

// ---- tool state ----
0 => int TOOL_DANCER_PRESSED;
1 => int TOOL_DANCER_GREEN;
2 => int TOOL_TOGGLE_PERSON;
3 => int TOOL_TOGGLE_LIGHT;
4 => int TOOL_TOGGLE_STAR;
5 => int TOOL_TOGGLE_TREE;
6 => int TOOL_CLEAR;
7 => int TOOL_CURTAIN;
0 => int currentTool;

fun void setTool(int t){
    if(t < 0) 0 => t; if(t > 7) 7 => t;
    t => currentTool;
    hudHi.pos(hudSlot[t].pos());
}

// ---------- SCALE / PITCH HELPERS ----------
[0,2,4,5,7,9,11,12] @=> int MAJOR8[];
69 => int ROOT_MIDI; // A4

int dancerDegree[16];
for (0 => int i; i < 16; i++) 0 => dancerDegree[i];

fun float majorPitchHz(int degree){
    (degree >= 0 ? degree : -degree) => int a;
    (degree >= 0 ? 1 : -1) => int sgn;
    (a / 7) => int octs; (a % 7) => int step;
    ROOT_MIDI + sgn * (octs*12 + MAJOR8[step]) => int midi;
    return Std.mtof(midi);
}

fun void applyDegreeToDancer(int col){
    if(dancerPresent[col] == 1){
        majorPitchHz(dancerDegree[col]) => Bus.dancerPitch[col];
        <<< "col", col, "degree", dancerDegree[col], "pitchHz", Bus.dancerPitch[col] >>>;
    }
}

// do the action for current tool at selCol
fun void doPlaceAtSelected(){
    if(currentTool == TOOL_DANCER_PRESSED) {
        addDancerModelAtCol(selCol, 0);
        applyDegreeToDancer(selCol);
    } else if(currentTool == TOOL_DANCER_GREEN) {
        addDancerModelAtCol(selCol, 1);
        applyDegreeToDancer(selCol);
    } else if(currentTool == TOOL_TOGGLE_PERSON) {
        if(hasPersonLocal[selCol]) removePersonAt(selCol);
        else addPersonAt(selCol);
    } else if(currentTool == TOOL_TOGGLE_LIGHT) {
        (Bus.lightHas[selCol] == 1 ? 0 : 1) => int on;
        setLight(selCol, on);
    } else if(currentTool == TOOL_TOGGLE_STAR) {
        toggleStar(selCol);
    } else if(currentTool == TOOL_TOGGLE_TREE) {
        toggleTree(selCol);
    } else if(currentTool == TOOL_CLEAR) {
        clearAtCol(selCol);
    } else if(currentTool == TOOL_CURTAIN) {
        toggleCurtain();
    }
}

// ---------- KEYBOARD LOOP ----------
KBHit kb;

fun void kbLoop(){
    <<< "Controls:",
    "Left/Right or A/D: move cursor  |  ENTER: place current tool",
    "1..8: tools [dancerA, dancerB, person, light, star, TREE, clear, CURTAIN]",
    "+ / - : change dancer pitch (major scale degrees)", "" >>>;
    
    while(true){
        kb => now;
        while(kb.more()){
            kb.getchar() => int c;
            
            // left / right (or a/d)
            if(c == 63234 || c == 97  /* a */ ) { selCol--; if(selCol < 0) 0 => selCol; placeCursorAt(selCol); }
            else if(c == 63235 || c == 100 /* d */ ) { selCol++; if(selCol > 15) 15 => selCol; placeCursorAt(selCol); }
            
            // place
            else if(c == 13 || c == 10) { doPlaceAtSelected(); }
            
            // tool select
            else if(c == 49 /*1*/) setTool(TOOL_DANCER_PRESSED);
            else if(c == 50 /*2*/) setTool(TOOL_DANCER_GREEN);
            else if(c == 51 /*3*/) setTool(TOOL_TOGGLE_PERSON);
            else if(c == 52 /*4*/) setTool(TOOL_TOGGLE_LIGHT);
            else if(c == 53 /*5*/) setTool(TOOL_TOGGLE_STAR);
            else if(c == 54 /*6*/) setTool(TOOL_TOGGLE_TREE);
            else if(c == 55 /*7*/) setTool(TOOL_CLEAR);
            else if(c == 56 /*8*/) setTool(TOOL_CURTAIN);
            
            // pitch +/- for dancer at selCol
            else if(c == 43 /* + */ || c == 61 /* = */) { dancerDegree[selCol]++; applyDegreeToDancer(selCol); }
            else if(c == 45 /* - */ || c == 95 /* _ */) { dancerDegree[selCol]--; applyDegreeToDancer(selCol); }
        }
    }
}
spork ~ kbLoop();

// ---------- RENDER ----------
while(true) GG.nextFrame() => now;
