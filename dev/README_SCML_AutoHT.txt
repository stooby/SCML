SCML_AutoHT README

Demo video: https://vimeo.com/185095490

* This is a prototype of a basic auto-harmonizer & auto-tuner instrument made with SuperCollider and Wekinator.  With this system, analyzed features of a mono audio signal input can be interpreted by machine learning algorithms implemented with Wekinator to modulate digital audio effects control parameters in real-time.

* This project code is intended to be an example template of a SuperCollider instrument that can interface with external software or programming environments via OSC.

* In this particular example, the timbre and pitch of streaming audio can modulate such parameters as: auto-harmonizer & auto-tuner level balancing, auto-harmonizer chord presets, auto-tuner pitch mapping, and reverb wetness.
	- Keep in mind the models contained in the Wekinator project file included with this project were all trained with my male tenor singing voice (w/ lots of falsetto training data) as well as whistling.  If you cannot whistle or are not a male tenor, you may want to consider re-training the models to suit your specific voice.

* Things you will need to make this work:
- SuperCollider: http://supercollider.github.io/download)
- Wekinator: http://www.wekinator.org/downloads/
- WekiInputHelper: http://www.wekinator.org/input-helper/

* Setup / Operation Instructions:

1. Setup your audio recording and playback system:
	- Connect an external microphone to your computer (recommended for higher quality sound, but a laptop’s internal mic will work fine too)
	- Connect headphones to your audio system’s output to avoid feedback (IMPORTANT!!)

2. Open the WekiInputHelper file included with this project and click “Start Listening.”

3. Open the Wekinator project file included with this project. Click “Start Listening” and “Run.”

4. Open the “SCML_AutoHT.scd” file with the SuperCollider IDE and evaluate chunk #1 to configure the SC server’s system audio I/O settings and boot the SC server. (Consult the code comments and SuperCollider’s help documentation if you need further assistance configuring the SC server’s audio input and output based on your specific audio hardware setup.)

5. Once the SC server’s booted, evaluate the next two chunks of code (#2 & 3) to launch the auto-harmonizer-tuner instrument example.  You should hear the auto-harmonizer processing your voice when you sing into the mic.
	- Singing different vowels (AH, EH, EE, OH, OO) will change the harmonizer chord presets. 
	- Whistling will switch the instrument into ‘auto-tune’ mode.

6. When you’re done, evaluate the next chunk of code (#4) to shutdown this instrument example. (You can re-evaluate line #3 to restart the instrument after it’s been shutdown.)

* Notes about the included Wekinator project file:
	- Several different machine learning algorithms are being implemented with Wekinator to classify extracted audio features from an input signal in terms of timbre (sound source) and pitch.
	- Output 1: kNN algorithm (k = 1) classifies timbre (singing vs. whistling) based on 13 MFCC and 1 pitch tracker feature inputs (“singing detected” == 1, “whistling detected” == 2)
	- Output 2: neural network (1 hidden layer) derives a relative pitch measure respective of voice timbre from 13 MFCC and 1 pitch tracker feature inputs (lowest pitch range extremes of both singing and whistling voices == 0 and highest extremes == 1, with floating point interpolation between).
	- Output 3: kNN algorithm (k = 1) classifies five formants/vowels of a singing male tenor voice (AH == 1, EH == 2, EE == 3, OH == 4, OO ==5) using 13 MFCC feature inputs.
	- Output 4: neural network (1 hidden layer) with the same functionality as the ‘Output 3’ model detailed above.  Using 13 MFCC feature inputs, the neural network identifies five different formants/vowels of a singing male tenor voice (1.0 - 5.0 | AH - OO). (This output was not used with this version of the SuperCollider program, but it could be useful for controlling some other sound synthesis parameters in the future.  At this point it mainly serves as a way of comparing the behavior of a neural network to a kNN algorithm using the same training data). 

——

This is an experimental instrument feature intended to demonstrate one possible application of a more general audio feature extractor tool made with SuperCollider:
https://github.com/stooby/SCML

All of this will be integrated in various ways into this ongoing interactive, embedded audio project:  https://github.com/stooby/sonic-mirror

st, 2016
