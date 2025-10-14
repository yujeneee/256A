// launch.ck ? run both music + visuals simultaneously

me.sourceDir() => string root;

// --- start music (first, so sound initializes properly) ---
Machine.add(root + "borderland_music.ck");

// --- start visuals immediately after ---
Machine.add(root + "borderland.ck");

// --- keep VM alive while both run ---
120::second => now;
