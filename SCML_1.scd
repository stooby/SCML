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

SynthDef.new(\monAudioInputFFT, {
	arg inChannel = 0, amp = 1, buffer, outBus;
	var sig, fft;
	sig = SoundIn.ar(bus: inChannel, mul: amp);
	fft = FFT(buffer, sig, wintype: 1); //<--and then how do other synths access this fft???
	OffsetOut.ar(outBus, sig);
}).add;

SynthDef.new(\Loudness, {
	arg input, buffer, outBus;
	var sigIn, fft, loudness;
	sigIn = In.ar(input);
	fft = FFT(buffer, sigIn, wintype: 1);
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
	arg input, ampThresh = 0.04, median = 7, minFreq = 60, maxFreq = 4000;
	var sigIn, freq, hasFreq;
	sigIn = In.ar(input);
    # freq, hasFreq = Pitch.kr(sigIn, ampThreshold: ampThresh, median: median, minFreq: minFreq, maxFreq: maxFreq);
    //freq = Lag.kr(freq.cpsmidi.round(1).midicps, 0.05);
    freq.poll(trig: 10, label: "Freq");
	//hasFreq.poll(trig: 10, label: "HasFreq");
}).add;

SynthDef.new(\MFCC, {
	arg input, buffer, outBus;
	var sigIn, fft, array;
	sigIn = In.ar(input);
	fft = FFT(buffer, sigIn, wintype: 1);
	array = MFCC.kr(fft); //outputs 13 coefficients by default
	Out.kr(outBus, array);
	//array.poll(trig: 10, label: "MFCCs");
}).add;


SynthDef.new(\busSum, {
	arg loudnessBus, mfccBus, outBus;
	var loudness, mfcc;
	loudness = In.kr(loudnessBus);
	mfcc = In.kr(mfccBus, 13);
	Out.kr(outBus, [loudness, mfcc[0], mfcc[1], mfcc[2], mfcc[3], mfcc[4], mfcc[5], mfcc[6], mfcc[7], mfcc[8], mfcc[9], mfcc[10], mfcc[11], mfcc[12]]);
}).add;
//BUFFERS AND BUSSES-----------

// assumes hop of half fftsize, fine
b = Buffer.alloc(s, 1024, 1); // for sampling rates 44100 and 48000
//b = Buffer.alloc(s, 2048, 1); // for sampling rates 88200 and 96000

~buf_Loudness = Buffer.alloc(s, 1024, 1);
~buf_MFCC = Buffer.alloc(s, 1024, 1);

~bus_input1 = Bus.audio(s, 1);
~bus_Loudness = Bus.control(s, 1);
~bus_RMS = Bus.control(s, 1);
~bus_MFCC = Bus.control(s, 13);

~bus_sumOut = Bus.control(s, 14);
)

// #2 =============
i = Synth(\monAudioInput, [\outBus, ~bus_input1]);  //execute this to activate audio input to be analyzed

//#3 =============
//evaluate the below segments of code to monitor and transmit your preferred audio features)

//LOUDNESS (perceptually-based VOLUME measure) ------
l = Synth(\Loudness, [\input, ~bus_input1, \buffer, ~buf_Loudness, \outBus, ~bus_Loudness]).moveAfter(i); //create Loudness synth

//RMS (volume) ------
r = Synth(\RMS, [\input, ~bus_input1, \numSamp, 40, \outBus, ~bus_RMS]).moveAfter(i);

//MFCC
m = Synth(\MFCC, [\input, ~bus_input1, \buffer, ~buf_MFCC, \outBus, ~bus_MFCC]).moveAfter(i);

//Pitch tracker
p = Synth(\Pitch, [\input, ~bus_input1]).moveAfter(i);

//sum all features into one control bus
~featureSum = Synth.tail(s, \busSum, [\loudnessBus, ~bus_Loudness, \mfccBus, ~bus_MFCC, \outBus, ~bus_sumOut]);
~featureSum.free;

(//begin transmitting features via OSC
~sendFeatures = {
	inf.do{
		~bus_sumOut.get( {arg val; {
			~oscPort_weki.sendMsg("/wek/inputs", val[0], val[1], val[2], val[3], val[4], val[5], val[6], val[7], val[8], val[9], val[10], val[11], val[12], val[13]);
			//~oscPort_weki.sendMsg("/wek/inputs", val.do({|item| item;}); );
			//("Sones:" + val[0].round(0.0001)).postln;
			//("MFCC:" + val[1..13].round(0.0001)).postln;
			//(" | RMS: ").post; val[1].round(0.00001).postln;
			//("-------").postln;
		}.defer; } );
		0.04.wait;
	};
}.fork;
)
~sendFeatures.stop; //stop transmitting features

s.plotTree;


//CLEANUP =============
b.free;
l.free;
r.free;
p.free;
m.free;

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

		~bus_MFCC.get( { arg val; {
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

~bus_MFCC.getn(13, { arg val; { ms.value_(val * 0.9); /*val.postln; */}.defer });

0.04.wait; // 25 frames per second
};

}.fork;

)

r.stop;