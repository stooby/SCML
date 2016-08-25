s = Server.local;
s.options.sampleRate = 44100;
s.latency = 0.05; //evaluate this line if you want to adjust latency... 0.2 is SC default

s.plotTree;

~oscPort_weki = NetAddr("127.0.0.1", 6448); //configure connection to default Wekinator input port

~oscPort_sc = NetAddr("127.0.0.1", 57120); // sclang default input port

( //#1 =============
//SYNTHDEFS-----------
SynthDef.new(\monAudioInput, {
	arg inChannel = 0, amp = 1, outBus;
	var sig = SoundIn.ar(bus: inChannel, mul: amp);
	OffsetOut.ar(outBus, sig);
}).add;

SynthDef.new(\monAudioInFFT, {//considering this as a way to use only one buffer to store FFT analysis, and have other feature extraction synths receive input from said FFT buffer.  Could be useful to increase CPU efficiency, but helpfile advises against this...
	arg inChannel = 0, amp = 1, buffer, outBus;
	var sig, fft;
	sig = SoundIn.ar(bus: inChannel, mul: amp);
	fft = FFT(buffer, sig, wintype: 1); //<--and then how do other synths access this fft buffer???
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
	flatness = SpecFlatness.kr(fft);  //consider normalizing more or rounding???

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

SynthDef.new(\busSum_loud_mfcc, {
	arg loudnessBus, mfccBus, outBus;
	var loudness, mfcc;
	loudness = In.kr(loudnessBus);
	mfcc = In.kr(mfccBus, 13);
	Out.kr(outBus, [loudness, mfcc[0], mfcc[1], mfcc[2], mfcc[3], mfcc[4], mfcc[5], mfcc[6], mfcc[7], mfcc[8], mfcc[9], mfcc[10], mfcc[11], mfcc[12]]);
}).add;
//BUFFERS AND BUSSES-----------

// assumes hop of half fftsize, fine.....not necessary if using LocalBuf
//b = Buffer.alloc(s, 1024, 1); // for sampling rates 44100 and 48000
//b = Buffer.alloc(s, 2048, 1); // for sampling rates 88200 and 96000
//~buf_Loudness = Buffer.alloc(s, 1024, 1); //not necessary if using LocalBuf
//~buf_MFCC = Buffer.alloc(s, 1024, 1); //not necessary if using LocalBuf

~bus_input1 = Bus.audio(s, 1);
~bus_loudness = Bus.control(s, 1);
~bus_rms = Bus.control(s, 1);
~bus_mfcc = Bus.control(s, 13);
~bus_pitch = Bus.control(s, 2);
~bus_specCent = Bus.control(s, 1);
~bus_specFlat = Bus.control(s, 1);
~bus_onsets = Bus.control(s, 1);
~bus_sumOut = Bus.control(s, 14); //change the channel count to match the sum of the total # of feature outputs you're monitoring (e.g. loudness(1) + mfcc(13) = 14)
)

// #2 =============
i = Synth(\monAudioInput, [\outBus, ~bus_input1]);  //execute this to activate audio input to be analyzed
i.free;
//i = Synth(\monAudioInFFT, [\buffer, b, \outBus, ~bus_input1]); //experimental...

//#3 =============
//evaluate the below segments of code to monitor and transmit your preferred audio features

//LOUDNESS (volume - perceptual measure in Sones) ------
l = Synth(\Loudness, [\input, ~bus_input1, \outBus, ~bus_loudness]).moveAfter(i);
l.free;
//l = Synth(\Loudness, [\input, ~bus_input1, \buffer, ~buf_Loudness, \outBus, ~bus_loudness]).moveAfter(i); //create Loudness synth

//RMS (volume) ------
r = Synth(\RMS, [\input, ~bus_input1, \numSamp, 40, \outBus, ~bus_rms]).moveAfter(i);
r.free;

//MFCC
m = Synth(\MFCC, [\input, ~bus_input1, \outBus, ~bus_mfcc]).moveAfter(i);
//m = Synth(\MFCC, [\input, ~bus_input1, \buffer, ~buf_MFCC, \outBus, ~bus_mfcc]).moveAfter(i);
m.free;

//PITCH TRACKER
p = Synth(\Pitch, [\input, ~bus_input1, \outBus, ~bus_pitch]).moveAfter(i);
p.free;

(//testing output from pitch bus
~pitchFeatures = {
	inf.do{
		~bus_pitch.get( {arg val; {
			("Freq:" + val[0].round(0.01)).post;
			(" | hasPitch?:" + val[1]).postln;
			//("-------").postln;
		}.defer; } );
		0.04.wait;
	};
}.fork;
)
~pitchFeatures.stop;

//SPECTRAL CENTROID
c = Synth(\specCent, [\input, ~bus_input1, \outBus, ~bus_specCent]).moveAfter(i);
c.free;

(//testing output from spectral centroid synth
~specCentFeatures = {
	inf.do{
		~bus_specCent.get( {arg val; {
			("Centroid:" + val.round(0.01)).postln;
		}.defer; } );
		0.08.wait;
	};
}.fork;
)
~specCentFeatures.stop;

//SPECTRAL FLATNESS
f = Synth(\specFlat, [\input, ~bus_input1, \outBus, ~bus_specFlat]).moveAfter(i);
f.free;

(//testing output from spectral flatness synth
~specFlatFeatures = {
	inf.do{
		~bus_specFlat.get( {arg val; {
			("Flatness:" + val.round(0.00001)).postln;
		}.defer; } );
		0.08.wait;
	};
}.fork;
)
~specFlatFeatures.stop;


//ONSETS
o = Synth(\onsets, [\input, ~bus_input1, \outBus, ~bus_onsets, \threshold, 0.7]).moveAfter(i);
o.free;

o.set(\threshold, 0.5); //evaluate to change detection threshold (between 0 - 1)

(//simple output test for onsets synth
~onsetFeatures = {
	inf.do{
		~bus_onsets.get( {arg val; {
			if (val == 1, {
				var currentSec = thisThread.seconds.round(0.01);
				("ONSET DETECTED: " + currentSec).postln;
			} );
		}.defer;} );
		0.1.wait;
	};
}.fork;
)
~onsetFeatures.stop;

//==============================================
//sum all features into one control bus
~featureSum = Synth.tail(s, \busSum_loud_mfcc, [\loudnessBus, ~bus_loudness, \mfccBus, ~bus_mfcc, \outBus, ~bus_sumOut]);
~featureSum.free;

(//begin transmitting features via OSC
~sendFeatures = {
	inf.do{

		~bus_sumOut.get( {arg val; { //get current feature vals in this bus and output via OSC
			~oscPort_weki.sendMsg(*["/wek/inputs"] ++ val);
			//("Sones:" + val[0].round(0.0001)).postln;
			//("MFCC:" + val[1..13].round(0.0001)).postln;
			//("RMS:" + val[1].round(0.00001)).postln;
			//("-------").postln;
		}.defer; } );
		0.04.wait;
	};
}.fork;
)
~sendFeatures.stop; //stop transmitting features

s.plotTree;

//CLEANUP =============
l.free;
r.free;
m.free;
p.free;
c.free;
f.free;
i.free;



//%%%%%%%%%%%TESTING%%%%%%%%%%%%%%%%%%%%
~compareBus.stop;
(
~compareBus = {
	inf.do{
		~bus_sumOut.get( {arg val; {
			for ( 1, 12, {|i| (val[i].round(0.0001) + "  ").post;} );
			val[13].round(0.0001).postln;
		}.defer; } );

		~bus_mfcc.get( { arg val; {
			for ( 0, 11, {|i| (val[i].round(0.0001) + "  ").post;} );
			val[12].round(0.0001).post; ("  ").postln;
			("-----").postln;
		}.defer });
		2.wait;
	};
}.fork;
)
//%%%%%%%%%%%TESTING%%%%%%%%%%%%%%%%%%%%

(  //run for MFCC graphic display
var ms;

w = Window.new("Thirteen MFCC coefficients", Rect(200, 400, 300, 300));

ms = MultiSliderView.new(w, Rect(10, 10, 260, 280));

ms.value_(Array.fill(13, 0.0));
ms.valueThumbSize_(20.0);
ms.indexThumbSize_(20.0);
ms.gap_(0);

w.front;

r = {

inf.do{

~bus_mfcc.getn(13, { arg val; { ms.value_(val * 0.9); /*val.postln; */}.defer });

0.04.wait; // 25 frames per second
};

}.fork;

)

r.stop;