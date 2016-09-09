//************************ SCML (SuperCollider Machine Listening) ************************

//INSTRUCTIONS:
//    • Evaluate the below blocks of code in order, one at a time from #1 - #4 to boot the server, analyze your computer's default audio input, and transmit extracted features via OSC.
//    • Evaluate the "CLEANUP" code at the bottom before quitting SuperCollider.


( //#1 ======INITIALIZE SC SERVER ======
//if server fails to start:  try again...or manually boot server w/ Cmd+B (it's stubborn sometimes)
o = Server.local.options;
o.sampleRate = 44100;
o.blockSize = 64;
//ServerOptions.inDevices; //view available audio input devices
o.inDevice = nil; //use system default audio input, change the value to match your desired audio input
//s.latency = 0.05; //uncomment and evaluate this line if you want to adjust latency... 0.2 is SC default
s.boot;
)

( //#2 ======SETUP======

//OSC PORTS----------
~oscPort_weki = NetAddr("127.0.0.1", 6448); //configure connection to default Wekinator input port
//~oscPort_sc = NetAddr("127.0.0.1", 57120); // sclang default input port

//SYNTHDEFS-----------
SynthDef.new(\monAudioInput, {
	arg inChannel = 0, amp = 1, outBus;
	var sig = SoundIn.ar(bus: inChannel, mul: amp); //defaults to first channel of system audio input
	OffsetOut.ar(outBus, sig);
}).add;

SynthDef.new(\Loudness, {
	//arg input, buffer, outBus;
	arg input, outBus;
	var sigIn, fft, loudness;
	sigIn = In.ar(input);
	//fft = FFT(buffer, sigIn, wintype: 1);
	fft = FFT(LocalBuf(1024), sigIn, wintype: 1); //using LocalBuf per HelpFile recommendation, 1024 frame size recommended for samp rates 44100 and 48000 and 2048 for rates 88200 and 96000
	loudness = Loudness.kr(fft);
	//loudness.poll(trig: 10, label: "Sones");
	Out.kr(outBus, loudness);
}).add;

SynthDef.new(\RMS, {
	arg input, numSamp = 40, outBus;
	var sigIn, rms;
	sigIn = In.ar(input);
	rms = (RunningSum.kr(sigIn.squared, numSamp) / numSamp).sqrt;
	//rms.poll(trig: 10, label: "RMS");
	Out.kr(outBus, rms);
}).add;

SynthDef.new(\Pitch, {
	arg input, ampThresh = 0.04, median = 7, minFreq = 60, maxFreq = 4000, outBus;
	var sigIn, freq, hasFreq;
	sigIn = In.ar(input);
    # freq, hasFreq = Pitch.kr(sigIn, ampThreshold: ampThresh, median: median, minFreq: minFreq, maxFreq: maxFreq);
    //freq = Lag.kr(freq.cpsmidi.round(1).midicps, 0.05);
	Out.kr(outBus, [freq, hasFreq]);
    //freq.poll(trig: 10, label: "Freq");
	//hasFreq.poll(trig: 10, label: "HasFreq");
}).add;

SynthDef.new(\MFCC, {
	//arg input, buffer, outBus;
	arg input, outBus;
	var sigIn, fft, array;
	sigIn = In.ar(input);
	//fft = FFT(buffer, sigIn, wintype: 1);
	fft = FFT(LocalBuf(1024), sigIn, wintype: 1);
	array = MFCC.kr(fft); //outputs 13 coefficients by default
	Out.kr(outBus, array);
	//array.poll(trig: 10, label: "MFCCs");
}).add;

SynthDef.new(\specCent, {
	arg input, outBus;
	var sigIn, fft, centroid;
	sigIn = In.ar(input);
	fft = FFT(LocalBuf(2048), sigIn, wintype: 1);
	centroid = SpecCentroid.kr(fft);
	Out.kr(outBus, centroid);
}).add;

SynthDef.new(\specFlat, {
	arg input, outBus;
	var sigIn, fft, flatness, flatdb, flatdbScaled;
	sigIn = In.ar(input);
	fft = FFT(LocalBuf(2048), sigIn, wintype: 1);
	flatness = SpecFlatness.kr(fft);

	//flatdb = 10 * flat.log; //convert flatness to decibels
	//flatdbScaled = LinLin.kr(flatdb, -45, -1.6, 0, 1).max(-10); // Rescale db roughly to 0...1

	Out.kr(outBus, flatness);
}).add;

SynthDef.new(\onsets, {
	arg input, outBus, threshold = 0.5, trigtime = 0.1, odtype = \rcomplex, reltime = 1.0, floor = 0.1;
	var sigIn, fft, onsets, trigger;
	sigIn = In.ar(input);
	fft = FFT(LocalBuf(512), sigIn, wintype: 1);
	onsets = Onsets.kr(fft, threshold, odtype, reltime, floor);
	trigger = EnvGen.kr(Env([1, 1, 0], [0, trigtime], curve: \hold), onsets); //after onset is detected, send trigger value of '1'  for 'trigtime' seconds to control bus
	//trigger.poll(10, label: 'trig'); //uncomment this to monitor trigger val constantly
	Out.kr(outBus, trigger);
}).add;

//BUFFERS AND BUSSES-----------

~bus_input1 = Bus.audio(s, 1);
~bus_loudness = Bus.control(s, 1);
~bus_rms = Bus.control(s, 1);
~bus_mfcc = Bus.control(s, 13);
~bus_pitch = Bus.control(s, 2);
~bus_specCent = Bus.control(s, 1);
~bus_specFlat = Bus.control(s, 1);
~bus_onsets = Bus.control(s, 1);

//FUNCS------------------------
~sumFunc_xin = {arg busArray;  //bus val concat function for variable size arg array of feat busses
	var numCh = 0, busCol, outArray, outBus;
	busArray.do({|item| numCh = numCh + item.numChannels}); //calculate total # bus channels
	outBus = Bus.control(s, numCh);
	busCol = Array.newClear(busArray.size);

	~sumSyn_xin = SynthDef(\sumSyn_xin, {
		busArray.do({|item, i| busCol[i] = In.kr(item, item.numChannels); }); //input bus vals to var array
		busCol.do({|item| //concat all bus vals into single out array
			if (item.numChannels == 1,
				{outArray = outArray ++ [item]},
				{outArray = outArray ++ (item.numChannels.collect( {|i| item[i]} ))}
			);
		});
		Out.kr(outBus, outArray);
	}).play(addAction: \addToTail);

	outBus; //return new bus w/ concat values of all input busses in arg array
};

~getSend_busSum = {arg bus, netAdr, oscMsg;
	var numCh = bus.numChannels;
	bus.get( {arg val; {
		netAdr.sendMsg(*[oscMsg] ++ val); //transmit feature vals via OSC
		switch (bus, //monitor feature values in SC (can be commented out to reduce CPU)
			~busSum_ldns_mfcc, {
				("Loudness:" + val[0].round(0.0001)).postln;
				("MFCC:" + val[1..13].round(0.0001)).postln;
				("-------").postln;
			},
			~busSum_ldns_sFlat_sCent, {
				("Loudness:" + val[0].round(0.0001)).postln;
				("Flatness:" + val[1].round(0.0001)).postln;
				("Centroid:" + val[2].round(0.0001)).postln;
				("-------").postln;
			},
			~busSum_ldns_pitch, {
				("Loudness:" + val[0].round(0.0001)).postln;
				("Pitch-freq:" + val[1].round(0.01)).postln;
				("Pitch-hasFreq?:" + val[2]).postln;
				("-------").postln;
			},
			{//all other busses (cases)
				if (numCh > 1,
					{
						numCh.do({arg item; ("Feature_" ++ (item + 1) ++ ":" + val[item].round(0.0001)).postln;});
						("-------").postln;
					},
					{("Feature_1:" + val.round(0.0001)).postln;} //else
				);
			}
		);
	}.defer; } );
};

~streamFeatures = {
	arg bus, netAdr, oscMsg, rate = 0.04;
	Routine ( {
		~getSend_busSum.value(bus, netAdr, oscMsg);
		rate.yieldAndReset;
	} );
};
)

(
// #3 ======ACTIVATE AUDIO INPUT ANALYSIS SYNTHS======
//you can optionally comment out the audio feature synths you don't want to use to reduce CPU, all are active by default
i = Synth(\monAudioInput, [\outBus, ~bus_input1]);

//LOUDNESS (volume - perceptual measure in Sones) ------
l = Synth(\Loudness, [\input, ~bus_input1, \outBus, ~bus_loudness]).moveAfter(i);

//RMS (volume) ------
r = Synth(\RMS, [\input, ~bus_input1, \numSamp, 40, \outBus, ~bus_rms]).moveAfter(i);

//MFCC
m = Synth(\MFCC, [\input, ~bus_input1, \outBus, ~bus_mfcc]).moveAfter(i);

//PITCH TRACKER
p = Synth(\Pitch, [\input, ~bus_input1, \outBus, ~bus_pitch]).moveAfter(i); //outputs two values (freq

//SPECTRAL CENTROID
c = Synth(\specCent, [\input, ~bus_input1, \outBus, ~bus_specCent]).moveAfter(i);

//SPECTRAL FLATNESS
f = Synth(\specFlat, [\input, ~bus_input1, \outBus, ~bus_specFlat]).moveAfter(i);

//ONSETS
n = Synth(\onsets, [\input, ~bus_input1, \outBus, ~bus_onsets, \threshold, 0.7]).moveAfter(i);
//o.set(\threshold, 0.5); //evaluate to change detection threshold (between 0 - 1)
)

//#4 ======OUTPUT AUDIO FEATURES VIA OSC======

// Evaluate one chunk below at a time to output different feature sets via OSC. Evaluate the corresponding STOP chunk before attempting to transmit alternate feature combinations.

// Default OSC output (~oscPort_weki): IP - 127.0.0.1,  Port # 6448

(//TRANSMIT LOUDNESS AND MFCCs - (14 features)
~busSum_ldns_mfcc = ~sumFunc_xin.value( [~bus_loudness, ~bus_mfcc] );
~transmit = ~streamFeatures.value(~busSum_ldns_mfcc, ~oscPort_weki, "/wek/inputs", 0.04); //adjust last argument value to change rate OSC messages are output (0.04 or about 25 times/sec is default)
~transmit.play;
)
( //STOP transmitting (NOTE:  evaluate this chunk before transmitting other feature sets)
~transmit.stop;
~sumSyn_xin.free;
~busSum_ldns_mfcc.free;
)


(//TRANSMIT LOUDNESS, SPECTRAL FLATNESS, AND SPECTRAL CENTROID - (3 features)
~busSum_ldns_sFlat_sCent = ~sumFunc_xin.value( [~bus_loudness, ~bus_specFlat, ~bus_specCent] );
~transmit = ~streamFeatures.value(~busSum_ldns_sFlat_sCent, ~oscPort_weki, "/wek/inputs", 0.04);
~transmit.play;
)
( //STOP transmitting
~transmit.stop;
~sumSyn_xin.free;
~busSum_ldns_sFlat_sCent.free;
)


(//TRANSMIT LOUDNESS AND PITCH - (3 features: [loudness value, frequency value, 0 or 1 indicating whether or not the detected audio has a definite pitch] )
~busSum_ldns_pitch = ~sumFunc_xin.value( [~bus_loudness, ~bus_pitch] );
~transmit = ~streamFeatures.value(~busSum_ldns_pitch, ~oscPort_weki, "/wek/inputs", 0.04);
~transmit.play;
)
( //STOP transmitting
~transmit.stop;
~sumSyn_xin.free;
~busSum_ldns_pitch.free;
)


(//TRANSMIT LOUDNESS, SPECTRAL FLATNESS, ONSETS - (3 features)
~busSum_ldns_sFlat_onset = ~sumFunc_xin.value( [~bus_loudness, ~bus_specFlat, ~bus_onsets] );
~transmit = ~streamFeatures.value(~busSum_ldns_sFlat_onset, ~oscPort_weki, "/wek/inputs", 0.04);
~transmit.play;
)
(//STOP transmitting
~transmit.stop;
~sumSyn_xin.free;
~busSum_ldns_sFlat_onset.free;
)


(//TRANSMIT LOUDNESS, SPECTRAL FLATNESS, PITCH, SPECTRAL CENTROID - (5 features)
~busSum_ldns_sFlat_pitch_sCent = ~sumFunc_xin.value( [~bus_loudness, ~bus_specFlat, ~bus_pitch, ~bus_specCent] );
~transmit = ~streamFeatures.value(~busSum_ldns_sFlat_pitch_sCent, ~oscPort_weki, "/wek/inputs", 0.04);
~transmit.play;
)
(//STOP transmitting
~transmit.stop;
~sumSyn_xin.free;
~busSum_ldns_sFlat_pitch_sCent.free;
)


(//TRANSMIT FEATURES - CUSTOM  (variable size feature bus set)
~busSum_xin = ~sumFunc_xin.value([~bus_loudness, ~bus_mfcc]); //input desired feature busses in array to monitor (separate w/ comma)
~transmit = ~streamFeatures.value(~busSum_xin, ~oscPort_weki, "/wek/inputs", 0.04);
~transmit.play;
)
( //STOP transmitting
~transmit.stop;
~sumSyn_xin.free;
~busSum_xin.free;
)


// ======CLEANUP======
//Evaluate the below code before quitting SuperCollider

( //evaluate this chunk first to stop all active synths and free all busses
s.freeAll;

~bus_input1.free;
~bus_loudness.free;
~bus_rms.free;
~bus_mfcc.free;
~bus_pitch.free;
~bus_specCent.free;
~bus_specFlat.free;
~bus_onsets.free;

~oscPort_weki.disconnect;
)

s.quit; //shutdown the SC server