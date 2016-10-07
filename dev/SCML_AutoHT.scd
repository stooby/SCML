//***** SCML (SuperCollider Machine Listening) - Wekinator Auto-Harmonizer & Auto-Tuner **********

//OPERATING INSTRUCTIONS:
//Evaluate the chunks of code below in order from #1 - #3 to startup this SC instrument.
//Evalute chunk #4 to turn off the instrument.  (At this point, you can optionally restart the instrument by re-evaluating chunk #3).

//NOTE:  Make sure this project's included WekiInputHelper and Wekinator project files are up and running before launching this SC instrument.  (They should be included in the project .zip file you downloaded to access this .scd file.  See the README for all the details.)

( //#1 ======INITIALIZE SC SERVER ======
//if the server fails to boot, try, try again. It's stubborn sometimes. Alternatively, evaluate each line one-by-one for a more stable bootup.
o = Server.local.options;
o.sampleRate = 44100;
o.blockSize = 512;
o.inDevice = nil; //use system default audio input (change value to manually configure input)
o.outDevice = nil; //use system default audio output (change value to manually configure output)
s.latency = 0.05; //0.2 is SC default
s.boot;
)
ServerOptions.devices; //evaluate this to see what audio input/output devices are available (if you want to customize your audio I/O configuration)

( //#2 ======SETUP======

//OSC In/Out ----------
~oscOut_weki = NetAddr("127.0.0.1", 6448); //configure connection to default Wekinator input port

~oscIn_weki_1 = {|numIn, defKey, port = 12000|
	var outBus;
	outBus = Bus.control(s, numIn);

	OSCdef.new(key: defKey.asSymbol, func: { |msg, time, addr, recvPort|
		var outArray = Array.newClear(msg.size - 1); //(# of Weki outputs - 1) b/c msg[0] is msg name
		for (1, msg.size - 1, {|i| outArray[i - 1] = msg[i];} ); //collect OSC msg vals into an array
		outBus.setn(outArray);
		//outBus.setnSynchronous(outArray); //would this yield better timing accuracy???
	}, path: '/wek/outputs', recvPort: port);

	outBus; //return bus for receiving all msg vals from Weki OSC output
};

//BUSSES-----------

~bus_input1 = Bus.audio(s, 1);
~bus_loudness = Bus.control(s, 1);
~bus_rms = Bus.control(s, 1);
~bus_mfcc = Bus.control(s, 13);
~bus_pitch = Bus.control(s, 2);
~bus_pitch2 = Bus.control(s, 4);
~bus_specCent = Bus.control(s, 1);
~bus_specFlat = Bus.control(s, 1);
~bus_onsets = Bus.control(s, 1);

~bus_dryIn1Amp = Bus.control(s, 1); //dry input level bus
~bus_vocAmp = Bus.control(s, 1); //voc proc synth sum level bus
~bus_wislAmp = Bus.control(s, 1); //whistle proc synth sum level bus
~bus_vocwislMix = Bus.control(s, 1); //mix balance between vocal FX synths and whistle FX synths
~bus_accompAmp = Bus.control(s, 1); //level of summed, mixed accomp synths
~bus_verbMix = Bus.control(s, 1);
~bus_verbRoom = Bus.control(s, 1);

~bus_vocSynthSum = Bus.audio(s, 2);
~bus_wislSynthSum = Bus.audio(s, 2);

~bus_dryIn1Amp.set(0.3); //make these static values b/c using SelectX's to control mix levels?
~bus_accompAmp.set(1.0);
~bus_vocAmp.set(0.6); //two voc accomp synths (0.5 x 2 = 1.0)
~bus_wislAmp.set(1.0); //make these static values b/c using SelectX's to control mix levels?
~bus_vocwislMix.set(0.0); //0 = voc accomp only, 1 = whistle accomp only. Set via control routine

~bus_verbMix.set(0.3);
~bus_verbRoom.set(0.4);

//SYNTH DEFS ----------
SynthDef.new(\mono2stereo, { //pass mono input to stereo output
	|in, amp = 1, pan = 0.0, out|
	var sig;
	sig = In.ar(in) * amp;
	//sig = InFeedback.ar(in) * amp;
	sig = Pan2.ar(sig, pan);
	//OffsetOut.ar(out, sig);
	Out.ar(out, sig);
} ).add;

SynthDef.new(\reverb2x2, {|outBus, mix = 0.25, room = 0.15, damp = 0.2, amp = 1.0|
	var sigIn, sigOut;
	sigIn = In.ar(outBus, 2);
	sigOut = FreeVerb2.ar(sigIn[0], sigIn[1], mix, room, damp, amp);
	ReplaceOut.ar(outBus, sigOut);
} ).add;

~wekiSyn_voc1b = {|oscInBus, audioIn, audioOut, interval = 5.0, pan = 0.0, amp = 1.0|
	var numCh, inMsg, sigIn, sigOut, returnSynth, pitchRatio, pitchDisp, panMod;

	numCh = oscInBus.numChannels;

	returnSynth = SynthDef(\vocHarm_weki1, {|interval, pan, amp, mix = 1.0|
		sigIn = In.ar(audioIn, 1);
		inMsg = In.kr(oscInBus, numCh);

		pitchRatio = interval.asFloat.round(0.01).midiratio; //set pitch transposition (semi-tone intervals)
		//pitchDisp = LinLin.kr(inMsg[1], 0, 1, 0, 0.12).round(0.01); //scale weki out1 for pitchDisp val

		sigOut = SelectX.ar(mix, [sigIn, PitchShift.ar(sigIn, 0.1, pitchRatio, 0, 0.002)]);
		//sigOut = SelectX.ar(mix, [sigIn, PitchShift.ar(sigIn, 0.1, pitchRatio, pitchDisp, 0.002)]);
		//sigOut = FreeVerb.ar(sigOut, mix: 0.33, room: LinLin.kr(inMsg[1], 0, 1, 0.1, 0.4)); //no...make another synth for verb processing sum out...

		//panMod = LinLin.kr(inMsg[1], 0, 1, -0.35, 0.35).round(0.01); //consider
		//pan = Clip.kr(pan.asFloat + panMod, -0.9, 0.9); //consider

		sigOut = Pan2.ar(sigOut, pan.asFloat); //?? yes?
		//sigOut = Splay.ar(sigOut, LinLin.kr(inMsg[1], 0, 1, 0, 0.2)); //yea / no?

		Out.ar(audioOut, sigOut * amp);
	}).play(addAction: \addToTail);

	returnSynth;
};

~wekiSyn_voc1 = {//|oscInBus, audioIn, audioOut, interval = 5.0, pan = 0.0, /*scaleBuf,*/ amp = 1.0, mix = 1.0| //FUNCTION ARGS AREN'T BEING TRANSFERED TO SYNTHDEF ARGS !!!!!
	|oscInBus, audioIn, audioOut|
	var numCh, inMsg, sigIn, sigOut, returnSynth, pitchRatio, pitchDisp, panMod;

	numCh = oscInBus.numChannels;

	returnSynth = SynthDef(\vocHarm_weki1, {|interval = 5.0, pan = 0.0, amp = 0.5, mix = 1.0|
		sigIn = In.ar(audioIn, 1);
		inMsg = In.kr(oscInBus, numCh);

		pitchRatio = interval.asFloat.round(0.01).midiratio; //set pitch transposition (semi-tone intervals)
		//pitchDisp = LinLin.kr(inMsg[1], 0, 1, 0, 0.12).round(0.01); //scale weki out1 for pitchDisp val

		sigOut = SelectX.ar(mix, [sigIn, PitchShift.ar(sigIn, 0.1, pitchRatio, 0, 0.002)]);
		//sigOut = SelectX.ar(mix, [sigIn, PitchShift.ar(sigIn, 0.1, pitchRatio, pitchDisp, 0.002)]);
		//sigOut = FreeVerb.ar(sigOut, mix: 0.33, room: LinLin.kr(inMsg[1], 0, 1, 0.1, 0.4)); //no...make another synth for verb processing sum out...

		//panMod = LinLin.kr(inMsg[1], 0, 1, -0.35, 0.35).round(0.01); //consider
		//pan = Clip.kr(pan.asFloat + panMod, -0.9, 0.9); //consider

		sigOut = Pan2.ar(sigOut, pan.asFloat); //?? yes?
		//sigOut = Splay.ar(sigOut, LinLin.kr(inMsg[1], 0, 1, 0, 0.2)); //yea / no?

		Out.ar(audioOut, sigOut * amp);
	}).play(addAction: \addToTail);

	returnSynth;
};

~wekiSyn_wisl1 = {//|oscInBus, audioIn, audioOut, scaleBuf, amp = 1.0, mix = 1.0|
	|oscInBus, audioIn, audioOut, scaleBuf| //add arg for initial interval scale spread of weki output1???? (12 == (-12, 12) | 5 == (-5, 5) | etc...)
	var numCh, inMsg, sigIn, sigOut, returnSynth, pitchRatio, pitchDisp;

	numCh = oscInBus.numChannels;

	returnSynth = SynthDef(\wislHarm_weki1, {|amp = 1.0, mix = 1.0| //can't use scaleBuf as arg for this synthDef :(
		sigIn = In.ar(audioIn, 1);
		inMsg = In.kr(oscInBus, numCh);

		pitchRatio = DegreeToKey.kr(scaleBuf.bufnum, LinLin.kr(inMsg[1], 0, 1, 5, -5).round(1)).midiratio; //convert Weki out 1 into a transposition ratio from mapped scale degrees

		//pitchDisp = LinLin.kr(inMsg[1], 0, 1, 0, 0.12).round(0.01); //scale weki out1 for pitchDisp val

		sigOut = SelectX.ar(mix, [sigIn, PitchShift.ar(sigIn, 0.1, pitchRatio, 0, 0.002)]); //no pDisp
		//sigOut = SelectX.ar(mix, [sigIn, PitchShift.ar(sigIn, 0.1, pitchRatio, pitchDisp, 0.002)]); //pDisp

		sigOut = Pan2.ar(sigOut, 0);
		//sigOut = Pan2.ar(sigOut, LinLin.kr(inMsg[1], 0, 1, -0.35, 0.35)); //mod pan w/ weki out??

		Out.ar(audioOut, sigOut * amp);
	}).play(addAction: \addToTail);

	returnSynth;
};

SynthDef.new(\XFadeStereo, {
	|in1, in2, out, amountControlBus, amp = 1.0|
	var inArray, mixSignal, sig;
	inArray = [In.ar(in1, 2), In.ar(in2, 2)];
	//inArray = [InFeedback.ar(in1), InFeedback.ar(in2)];
	mixSignal = SelectX.ar(amountControlBus, inArray);
	sig = mixSignal * amp;
	//OffsetOut.ar(out, sig); //should I use this instead?
	Out.ar(out, sig);
} ).add;

SynthDef(\LinInterp_num, {//imported from SonicMirror
	arg startVal, stopVal, duration, mult = 1, out;
	Out.kr(out, Line.kr(startVal, stopVal, duration, mul: mult, doneAction: 2));
} ).add;

SynthDef.new(\subMix, {//imported from SonicMirror
	|in, amp = 1, out|
	var sig;
	sig = In.ar(in) * amp;
	//sig = InFeedback.ar(in) * amp;
	//OffsetOut.ar(out, sig);
	Out.ar(out, sig);
} ).add;

//---ORIG SYNTH DEFS from SCML ---

SynthDef.new(\monAudioInput, {
	arg inChannel = 0, amp = 1, outBus;
	var sig = SoundIn.ar(bus: inChannel, mul: amp); //defaults to first channel of system audio input
	OffsetOut.ar(outBus, sig);
}).add;

SynthDef.new(\monAudioInFFT, {//considering this as a way to use only one buffer to store FFT analysis, and have other feature extraction synths receive input from said FFT buffer.  Could be useful to increase CPU efficiency, but helpfile advises against this...
	arg inChannel = 0, amp = 1, buffer, outBus;
	var sig, fft;
	sig = SoundIn.ar(bus: inChannel, mul: amp);
	fft = FFT(buffer, sig, wintype: 1); //<--and then how should other synths access this fft buffer???
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

SynthDef.new(\Pitch2, {
	arg input, ampThresh = 0.04, median = 7, minFreq = 60, maxFreq = 4000, outBus;
	var sigIn, freq, hasFreq, midinote;
	sigIn = In.ar(input);
    # freq, hasFreq = Pitch.kr(sigIn, ampThreshold: ampThresh, median: median, minFreq: minFreq, maxFreq: maxFreq);
	//midinote = Lag.kr(freq.cpsmidi.round(1), 0.05);
	midinote = freq.cpsmidi.round(1);
	Out.kr(outBus, [freq, hasFreq, midinote]);
    //freq.poll(trig: 10, label: "Freq");
	//hasFreq.poll(trig: 10, label: "HasFreq");
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

//FUNCS------------------------
~sumFunc_xin = {arg busArray;  //bus val concat function for variable size arg array of feat busses
	var numCh = 0, busCol, outArray, outBus;
	busArray.do({|item| numCh = numCh + item.numChannels}); //calculate total # bus channels
	outBus = Bus.control(s, numCh);
	busCol = Array.newClear(busArray.size);

	~sumSyn_xin = SynthDef(\sumSyn_xin, { //<----is it possible to dynamically generate synths that are freed when this function is terminated w/out assigning to environment variable???
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
	var numCh = bus.numChannels; //needed for message posting...
	bus.get( {arg val; { //<---changing to getSynchronous prevents OSC output for some reason...?
		netAdr.sendMsg(*[oscMsg] ++ val); //transmit feature vals via OSC
		/*switch (bus, //monitor feature values in SC (can be commented out to reduce CPU)
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
				("Pitch-MIDInote:" + val[3]).postln;
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
		); */
	}.defer; } );
};

~streamFeatures = {
	arg bus, netAdr, oscMsg, rate = 0.04;
	Routine ( {
		~getSend_busSum.value(bus, netAdr, oscMsg);
		rate.yieldAndReset;
	} );
};

~transmitFeatures = { //works, but not sure if busses are being permanently allocated?
	arg busOut, busInArray, netAdr, oscMsg, rate = 0.04, act = true;
	if (act == true,
		{
			busOut = ~sumFunc_xin.value(busInArray);
			~transmit = ~streamFeatures.value(busOut, netAdr, oscMsg, rate);
			~transmit.play;
		},
		{//else
			~transmit.stop;
			~sumSyn_xin.free;
			busOut.free;
		}
	);
};

//===========ACCOMP SYNTH AND FX CONTROL ROUTINE===========
~flag_wekSyn_prevIn = 1; //langside flag storing last input from WekiOut1, 1 == voc, 2 == whistle
~flag_wekSyn_prevIn_change = false; //flag for debouncing sudden changes due to input noise
~flag_wekSyn_prevVow = 1; //flag for storing last input from WekiOut3, 1 == ah, 2 == eh, 3 == ee, 4 == oh, 5 == oo
~flag_wekSyn_prevVow_change = false; //flag for debouncing sudden changes due to input noise
~yieldTime_wsc1 = 0.1;
~debounceTime = 0.3;

~routine_wekiSynthControl1 = {|oscInBus, rate = 0.1|
	Routine ({
		//~yieldTime_wsc1 = rate.asFloat; //<---necessary?
		oscInBus.get({ |msg|
			if (msg[0] == 1, { //"voc detected"
				if (~flag_wekSyn_prevIn == 1, { //sound source has not changed since prev bus.get
					var x;
					~flag_wekSyn_prevIn_change = false; //reset debounce flag in case it was previously triggered
					//CARRY ON... do anything???
					//"msg[0] = 1 - NO CHANGE".postln;

					//MONITOR CHANGES IN msg[2] <<<<<<<<
					x = case
					{msg[2] == 1} {//if msg[2] == 1 - 'AH' DETECTED
						//"msg[2] = 1 - AH".postln;
						~vocA1.set(\interval, -5, \pan, -0.75);
						~vocA2.set(\interval, 4.25, \pan, 0.75);
						/*
						if (~flag_wekSyn_prevVow == 1, { //msg[2] has not changed since prev bus.get

						~flag_wekSyn_prevVow_change = false; //reset flag if it was triggered by noise

						//CARRY ON W/ 'AH' COMMANDS

						~yieldTime_wsc1 = rate.asFloat; //0.1 <----necessary???
						} , { //else if ~flag_prevVow != 1, maybe we're changing vowels
						//DEBOUNCE
						if (~flag_wekSyn_prevVow_change == false, {
						~flag_wekSyn_prevVow_change = true;
						"msg[2] = 1 | prev msg[2] = ? - STATE CHANGE TEST".postln;
						~yieldTime_wsc1 = ~debounceTime; //"debounce" time
						}, { //else if ~flag_stateChange == true, state has changed and remained same long enough to rule out noise, and we can proceed with triggered changes
						~flag_wekSyn_prevVow_change = false;

						//DO STUFF WHEN 'AH' FIRST DETECTED

						~flag_wekSyn_prevVow = 1; //set flag to remember last state before resetting routine
						"msg[2] = 1 | prev msg[2] = ? - STATE CHANGE CONFIRMED".postln;
						~yieldTime_wsc1 = rate; //<---yea?

						} );
						} );
						*/
					}
					{msg[2] == 2} {//if msg[2] == 2 - 'EH' DETECTED
						//DEBOUNCE?

						//"msg[2] = 1 - EH".postln;
						~vocA1.set(\interval, -3, \pan, -0.6);
						~vocA2.set(\interval, 5, \pan, 0.6);

						//ANYTHING ELSE? (OPTIONAL EFFECTS PER VOWEL?

						//~yieldTime_wsc1 = rate.asFloat; //actually not here?
					}
					{msg[2] == 3} {//if msg[2] == 3 - 'EE'
						//DEBOUNCE?

						//"msg[2] = 1 - EE".postln;
						~vocA1.set(\interval, -4, \pan, -0.45);
						~vocA2.set(\interval, 10, \pan, 0.45);
						//~yieldTime_wsc1 = rate.asFloat;
					}
					{msg[2] == 4} {//if msg[2] == 4 - 'OH'
						//DEBOUNCE?

						//"msg[2] = 1 - OH".postln;
						~vocA1.set(\interval, -3, \pan, -0.6);
						~vocA2.set(\interval, 7, \pan, 0.6);
						//~yieldTime_wsc1 = rate.asFloat;
					}
					{msg[2] == 5} {//if msg[2] == 5 'OO'
						//DEBOUNCE?

						//"msg[2] = 1 - OO".postln;
						~vocA1.set(\interval, -4, \pan, -0.25);
						~vocA2.set(\interval, 5, \pan, 0.25);
						//~yieldTime_wsc1 = rate.asFloat;
					};
					~yieldTime_wsc1 = rate.asFloat; //<---
				} , { //else ~flag_wekSyn_prevIn == 2, we're changing from  "2 - whistling" to "1 - voc"

					//CHECK TO SEE IF TIME THRESHOLD SURPASSED BEFORE CONFIRMING STATE CHANGE
					if (~flag_wekSyn_prevIn_change == false, {
						~flag_wekSyn_prevIn_change = true;
						//"msg[0] = 1 | prev msg[0] = 2 - STATE CHANGE TEST".postln;
						~yieldTime_wsc1 = ~debounceTime; //"debounce" time
					}, { //else if ~flag_stateChange == true, state has changed and remained same long enough to rule out noise, and we can proceed with triggered changes
						var interpSynth, interpVerbRoom, interpVerbMix;
						~flag_wekSyn_prevIn_change = false;
						//XFADE ~mixAmount.bus from whistle to voc processing synth busses (1.0 - 0.0)
						interpSynth = Synth(\LinInterp_num, [\startVal, 1.0, \stopVal, 0.0, \duration, 0.2, \out, ~bus_vocwislMix]);
						interpVerbRoom = Synth(\LinInterp_num, [\startVal, 0.7, \stopVal, 0.4, \duration, 0.2, \out, ~bus_verbRoom]);
						interpVerbMix = Synth(\LinInterp_num, [\startVal, 0.6, \stopVal, 0.3, \duration, 0.2, \out, ~bus_verbMix]);
						//0.2.yield; //<---CAUSES ERROR b/c "Not in Routine" - worried I'd need this for stability? otherwise routine might just race away and fire off lots of these synths on edge cases?

						~flag_wekSyn_prevIn = 1; //set flag to remember last state before resetting routine
						//"msg[0] = 1 | prev msg[0] = 1 - STATE CHANGE CONFIRMED".postln;
						~yieldTime_wsc1 = rate.asFloat; //<---
					} );
				} );
			} , { //ELSE======= if msg[0] == 2 "whistling detected"
				if (~flag_wekSyn_prevIn == 2, { //sound source has not changed since prev bus.get
					~flag_wekSyn_prevIn_change = false; //reset debounce flag

					//CARRY ON.... do anything?
					//"msg[0] = 2 - NO CHANGE".postln;

					~yieldTime_wsc1 = rate.asFloat; //<----
				} , { //else flag must have changed recently from "1 - voc" to "2 - whistling"

					//CHECK TO SEE IF TIME THRESHOLD SURPASSED BEFORE CONFIRMING STATE CHANGE
					if (~flag_wekSyn_prevIn_change == false, {
						~flag_wekSyn_prevIn_change = true;
						//"msg[0] = 2 | prev msg[0] = 1 - STATE CHANGE TEST".postln;
						~yieldTime_wsc1 = ~debounceTime; //"debounce" time <---
					}, { //else if ~flag_stateChange == true, state has changed and remained same long enough to rule out noise, and we can proceed with triggered changes
						var interpSynth, interpVerbRoom, interpVerbMix;
						~flag_wekSyn_prevIn_change = false;

						//XFADE ~mixAmount.bus from voc to whistle processing synth busses (0.0 - 1.0)
						interpSynth = Synth(\LinInterp_num, [\startVal, 0.0, \stopVal, 1.0, \duration, 0.2, \out, ~bus_vocwislMix]);
						interpVerbRoom = Synth(\LinInterp_num, [\startVal, 0.4, \stopVal, 0.7, \duration, 0.2, \out, ~bus_verbRoom]);
						interpVerbMix = Synth(\LinInterp_num, [\startVal, 0.3, \stopVal, 0.6, \duration, 0.2, \out, ~bus_verbMix]);
						//0.2.yield; //<---CAUSES ERROR b/c "Not in Routine" - worried I'd need this for stability? otherwise routine might just race away and fire off lots of these synths on edge cases?

						~flag_wekSyn_prevIn = 2; //set flag to remember last state before resetting routine
						//"msg[0] = 2 | prev msg[0] = 2 - STATE CHANGE CONFIRMED".postln;
						~yieldTime_wsc1 = rate.asFloat; //<---
					} );
				} );
			} );
		});
		//"Out of .get, before slight .yield".postln;
		0.02.yield; //<-----ANY OTHER WAY W/OUT INDUCING LATENCY!??????
	//	("yieldTime_wsc1 = " ++ ~yieldTime_wsc1).postln;
		~yieldTime_wsc1.yieldAndReset; //<---necessary or simply leave as rate.yieldAndReset???
	});
};

~initAutoHT = Routine({
	~scale1 = Scale.majorPentatonic.degrees; //[0, 2, 4, 7, 9]
	~scaleBuf = Buffer.alloc(s, ~scale1.size, 1, {|b| b.setnMsg(0, ~scale1) } );

	i = Synth(\monAudioInput, [\outBus, ~bus_input1]);
	l = Synth(\Loudness, [\input, ~bus_input1, \outBus, ~bus_loudness]).moveAfter(i);
	m = Synth(\MFCC, [\input, ~bus_input1, \outBus, ~bus_mfcc]).moveAfter(i);
	p = Synth(\Pitch, [\input, ~bus_input1, \outBus, ~bus_pitch]).moveAfter(i); //outputs two values (freq)

	"AUDIO IN & FEATURE EXTRACTOR SYNTHS ACTIVE...".postln;

	0.2.wait;

	//TRANSMIT FEATURES
	~busSum_xin = ~sumFunc_xin.value([~bus_loudness, ~bus_mfcc, ~bus_pitch]); //collect loudness, mfcc, and pitch features to output via OSC to Wekinator
	~transmit = ~streamFeatures.value(~busSum_xin, ~oscOut_weki, "/wek/inputs", 0.08);
	SystemClock.play(~transmit);
	"OSC Out".postln;

	0.2.wait;

	//RECEIVE WEKI OSC OUTPUT
	~bus_oscIn_1 = ~oscIn_weki_1.value(numIn: 4, defKey: "oscDef1", port: 12000);  //open port to receive OSC output from Wekinator and send to a control bus

	~wekiSynthControl1 = ~routine_wekiSynthControl1.value(oscInBus: ~bus_oscIn_1, rate: 0.1); //create routine to get latest values from OSC input control bus
	SystemClock.play(~wekiSynthControl1); //start OSC input bus monitoring routine
	"OSC In".postln;

	0.2.wait;

	~dryIn1 = Synth(\mono2stereo, [\in, ~bus_input1, \amp, ~bus_dryIn1Amp.asMap, \out, 0]).moveAfter(i); //pipe dry mono input to stereo output

	~wisA1 = ~wekiSyn_wisl1.value(oscInBus: ~bus_oscIn_1, audioIn: ~bus_input1, audioOut: ~bus_wislSynthSum, scaleBuf: ~scaleBuf).moveAfter(~dryIn1); //whistle harmonizer 1

	~vocA1 = ~wekiSyn_voc1.value(oscInBus: ~bus_oscIn_1, audioIn: ~bus_input1, audioOut: ~bus_vocSynthSum).moveAfter(~dryIn1); //voc harmonizer 1

	~vocA2 = ~wekiSyn_voc1.value(oscInBus: ~bus_oscIn_1, audioIn: ~bus_input1, audioOut: ~bus_vocSynthSum).moveAfter(~dryIn1); //voc harmonizer 2

	"AutoHarmonizer and AutoTune Synths Active...".postln;
	0.2.wait;

	~dryIn1.set(\amp,  ~bus_dryIn1Amp.asMap);
	~wisA1.set(\amp, ~bus_wislAmp.asMap);
	~vocA1.set(\amp, ~bus_vocAmp.asMap);
	~vocA2.set(\amp, ~bus_vocAmp.asMap);
	"Configure Synths...".postln;
	0.2.wait;

	~accomp_mix = Synth(\XFadeStereo, [\in1, ~bus_vocSynthSum, \in2, ~bus_wislSynthSum, \out, 0, \amountControlBus, ~bus_vocwislMix.asMap, \amp, ~bus_accompAmp.asMap], addAction: \addToTail);

	~fx_reverb = Synth(\reverb2x2, [\outBus, 0, \mix, ~bus_verbMix.asMap, \room, ~bus_verbRoom.asMap], addAction: \addToTail); //stereo reverb processing sum output
	//0.1.yield;
	"--AUTOHARMTUNE ACTIVE--".postln;
});

)

// #3 ======ACTIVATE WEKI INSTRUMENT EXAMPLE #1 (Auto-harmonize & Auto-tune) ======
SystemClock.play(~initAutoHT);

// #4 --- STOP / CLEANUP INSTRUMENT EXAMPLE ---
(
~initAutoHT.stop;
~initAutoHT.reset;
~transmit.stop;
~transmit.free;
~sumSyn_xin.free;
~busSum_xin.free;

~scaleBuf.free;
i.free;
l.free;
m.free;
p.free;
~dryIn1.free;
~wisA1.free;
~vocA1.free;
~vocA2.free;
~accomp_mix.free;
~fx_reverb.free;

~bus_oscIn_1.free;
~wekiSynthControl1.stop;
~wekiSynthControl1.free;
OSCdef(\oscDef1).free;

s.freeAll;
)

s.quit; //shut down the server before exiting SuperCollider