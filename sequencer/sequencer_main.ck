Machine.add("sequencer_bus.ck");
Machine.add("sequencer_audio.ck");
Machine.add("sequencer_viz.ck");

// keep the VM alive forever
while (true) 1::second => now;