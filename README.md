# SCML (SuperCollider Machine Listening)
---
* SCML is an audio feature extractor made with SuperCollider that converts audio signal feature data into OSC messages.

* This is intended to be a convenient toolbox of various SC machine listening UGens wrapped into SynthDefs that can be configured and triggered by the user to analyze audio signals in real-time.  Feature data can optionally be output as OSC messages to other OSC-friendly programming environments or software (like [Wekinator](http://www.wekinator.org/)).

### What you will need:
* A computer with an installation of [SuperCollider](http://supercollider.github.io/) and a microphone. (A laptop’s built-in mic works just fine).

### Operating Instructions:
* Open the "SCML.scd" file with SuperCollider. Evaluate the bracketed blocks of code in order from #1 - 4 to begin analyzing your computer’s default audio input and transmitting extracted features via OSC.

---
This is a work in progress.  It will be enhanced in the future and eventually merged into the [Sonic Mirror](https://github.com/stooby/sonic-mirror) project.

“SCML.scd” is the stable and more user-friendly version of this project. The ‘dev’ folder is where new features and experimental code will live before being merged into “SCML.scd”

st, 2016