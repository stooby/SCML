# SCML - SuperCollider Machine Listening
---
* SCML is an audio feature extractor made with SuperCollider that converts audio signal feature data into OSC message output for interfacing with external programming environments or software.

* This is intended to be a convenient toolbox of various SC machine listening UGens wrapped into SynthDefs that can be configured and triggered by the user to analyze audio signals in real-time.

* Additionally, this is also a template for designing SuperCollider instruments that can be controlled via OSC input from external sources.  Example instruments featured in this project are designed to be controlled via machine learning models created with [Wekinator](http://www.wekinator.org/).
	- For example, included is a prototype of a basic auto-harmonizer & auto-tuner instrument. [Video demo available here.](https://vimeo.com/185095490)
	- When used in conjunction with the included Wekinator project files, analyzed features of a mono audio signal input (singing & whistling voice) can be interpreted by machine learning algorithms implemented within Wekinator to modulate the auto-harmonizer & auto-tuner control parameters in real-time.
	- In this particular example, the timbre and pitch of streaming audio can modulate such parameters as: auto-harmonizer & auto-tuner level balancing, auto-harmonizer chord presets, auto-tuner pitch mapping, and reverb wetness.
	- Keep in mind the models contained in the Wekinator project file included with this project were all trained with my male tenor singing voice (w/ lots of falsetto training data) as well as whistling.  If you cannot whistle or are not a male tenor, you may want to consider re-training the models to suit your purpose.


### What you will need:
* [SuperCollider](http://supercollider.github.io/)
* A microphone (a laptop’s built-in mic will do)

If you want to run the machine-learning-controlled instrument examples:
* [Wekinator](http://www.wekinator.org/downloads/)
* [WekiInputHelper](http://www.wekinator.org/input-helper/)


### Operating Instructions:
1. Connect a microphone to your computer (recommended for higher quality sound, but a laptop’s internal mic will work fine too)

2. Open the "SCML.scd" file with SuperCollider and evaluate chunk #1 to boot the SC server using your system’s default audio input and outputs.
	- Alternatively (if you’re using an external mic), you may need to edit the “o.sampleRate,” “o.inDevice,” “o.outDevice,” and “s.latency” values first to configure the server’s I/O settings to suit your audio hardware setup. See the comments and SuperCollider’s help documentation for further assistance.

* A. If you want to run the example instrument in conjunction with the Wekinator machine learning software:
	- RECOMMENDED: Monitor your system’s audio output with headphones to avoid audio feedback.
	A1. With the SC server booted, evaluate chunk #2.

	A2. Launch WekiInputHelper and open the WekiInputHelper file included in the “WekinatorProjectFiles” folder. Click “Start Listening” and click on the “Send and Monitor” tab.

	A3. Launch Wekinator and open the Wekinator project file included in the “WekinatorProjectFiles” folder. Click “Start Listening” and “Run.”

	A4. Within the “SCML.scd” file in SuperCollider, evaluate item #3 to activate the auto-harmonizer & auto-tuner instrument example.
		- You should hear the auto-harmonizer processing your voice when you sing into the mic. Singing different vowels (AH, EH, EE, OH, OO) will change the harmonizer chord presets.
		- Whistling will switch the instrument into ‘auto-tune’ mode.

	A5. When you’re done, evaluate chunk #4 to shutdown this instrument example. (You can re-evaluate item #3 to restart the instrument after it’s been shutdown.)

* B. If you don’t want to run the example instrument in conjunction with Wekinator, and simply want to output audio feature data via OSC:
	B1. Configure the OSC Output Host and Port address values in the first line of the code at the top of chunk #2.  (Alternatively, configure the OSC input settings in your external programming environment / software to match these values).
	B2. Skip over chunks #3 and #4 and evaluate chunk “B” within the “Custom Configuration” portion of the code. This will activate input monitoring of your system’s first audio input channel as well as a variety of audio feature extractor “synths.”
	B3. Below chunk “B” within the “Output Audio Features via OSC” section, evaluate individual “TRANSMIT” chunks to output various combinations of audio feature data via OSC.  Be sure to evaluate corresponding “STOP” chunks before attempting to transmit alternate feature sets.
	B4. When you’re finished, evaluate the “CLEANUP” chunk and shutdown the server before quitting SuperCollider.

### Notes about Wekinator and the included Wekinator project files:

* [Wekinator](http://www.wekinator.org/) is a free, open source machine learning software created by [Rebecca Fiebrink](https://github.com/fiebrink1) that allows users to build interactive systems with minimal amounts of training data and without having to write any code.

* SCML is designed to work with Wekinator to integrate machine learning as part of a larger instrument system.  The included Wekinator project files have been trained to classify various sound events based on extracted audio feature data provided by SuperCollider.

* The “VocWhistle_inpHelp.inputproj” file is a WekiInputHelper file designed to smooth the raw OSC output data from “SCML.scd” (SuperCollider) before passing it on to the “VocWhistle_ld-mfcc-pitch_1” Wekinator project file.  Eventually this functionality will be implemented in the SCML code itself, but for now it serves as a convenient bridge.

* Within the “VocWhistle_ld-mfcc-pitch_1” project file, several different machine learning algorithms are being implemented to classify audio input signals in terms of timbre and pitch:
	- Output 1: kNN algorithm (k = 1) classifies timbre (singing vs. whistling) based on 13 MFCC and 1 pitch tracker feature inputs (“singing detected” == 1, “whistling detected” == 2)

	- Output 2: neural network (1 hidden layer) derives a relative pitch measure respective of voice timbre from 13 MFCC and 1 pitch tracker feature inputs (lowest pitch range extremes of both singing and whistling voices == 0 and highest extremes == 1, with floating point interpolation between).

	- Output 3: kNN algorithm (k = 1) classifies five formants/vowels of a singing male tenor voice (AH == 1, EH == 2, EE == 3, OH == 4, OO ==5) using 13 MFCC feature inputs.

	- Output 4: neural network (1 hidden layer) with the same functionality as the ‘Output 3’ model detailed above.  Using 13 MFCC feature inputs, the neural network identifies five different formants/vowels of a singing male tenor voice (1.0 - 5.0 | AH - OO). (This output was not used with this version of SCML, but it could be useful for controlling some other sound synthesis parameters in the future.  At this point it mainly serves as a way of comparing the behavior of a neural network to a kNN algorithm using the same training data).

* You may find you’ll need to add training data or delete all examples and re-train the models outright in the Wekinator project file so they better respond to your voice.  [Here’s a detailed walkthrough](http://www.wekinator.org/walkthrough/) on how to do this.

---
This is a work in progress.  It will be enhanced in the future and eventually merged into the [Sonic Mirror](https://github.com/stooby/sonic-mirror) project.

“SCML.scd” is the stable and more user-friendly version of this project. The ‘dev’ folder is where new features and experimental code will live before being merged into “SCML.scd”

st, 2016