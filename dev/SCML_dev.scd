//************************ SCML (SuperCollider Machine Listening)_dev ************************
//new features and experimental code goes here before being merged into "SCML"

( //#1 ======INITIALIZE SC SERVER ======
o = Server.local.options;
o.sampleRate = 44100;
//o.blockSize = 64;
o.device = nil; //use system default soundcard
s.latency = 0.05; //uncomment and evaluate this line if you want to adjust latency... 0.2 is SC default
s.boot;
)
o.blockSize = 512;
o.blockSize;
( //#2 ======SETUP======

//NetAddr.localAddr;   // retrieve the current IP and port

//OSC In/Out ----------
~oscOut_weki = NetAddr("127.0.0.1", 6448); //configure connection to default Wekinator input port
//~oscPort_sc = NetAddr("127.0.0.1", 57120); // sclang default input port
//~oscIn_weki = NetAddr("127.0.0.1", 12000); //doesn't seem to be helpful when used in OSCFunc

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

/*SynthDef.new(\wekiInputTest, { |oscInBus|  //simple OSC input TEST SYNTHDEF
	var inMsg;

	inMsg = In.kr(oscInBus, 4);

	Poll.kr(3, inMsg[0], 'oscIn');
	//inMsg[0].poll(3, 'oscIn');
}).add; */

/*~oscIn_weki_1 = OSCFunc.new( { |msg, time, addr, recvPort|  //ORIG ATTEMPT w/ OSCFunc :(
	//numCh = msg.size - 1;
	var outArray = Array.newClear(msg.size - 1); //(# of Weki outputs - 1) b/c val[0] is msg name
	for (1, msg.size - 1, {|i| outArray[i - 1] = msg[i];} );
	~bus_oscIn_1.setn(outArray);
}, '/wek/outputs', recvPort: 12000); */

//================= NEW VOC/WHISTLE ACCOMP INST CODE =================//

//NOTE TO SELF!!!!!:
//--either:
//   I. a.Control synth group volumes w/ Line.kr sends to control busses (~bus_wislAmp, etc.)
//      b. connect ALL synth outputs to [0, 1] or just 0?? multichannel expansion right?
//      .......simple...but not possible to process audio signals from specific synths since all outputting to master output bus channels [0, 1] ....   maybe okay for now

//   II. a.Control synth group volumes w/ Line.kr sends to control busses (~bus_wislAmp, etc.)
//       b. connect synth outputs to different subBusses (~bus_vocSynthSum, etc..)
//       c. connect subBusses to 1+ synths that output signals from subBusses to audio out
//      ..slightly more complicated...but can process different subMixes this way MUCH more flexible

//   III. a. Control synth group volumes w/ Line.kr sends to control busses (~bus_wislAmp, etc.)
//        b. connect synth outputs to respective sub busses (~bus_vocSynthSum, etc...)
//        c. Use "accomp mix" synthDef w/ SelectX ugen, and an additional "AccompMix" control bus to control balance between voc and wisl synths being sent to final output (e.g. if ~bus_vocWislMix == 0.0, only voc accomp synths heard, if ~bus_vocWislMix == 1.0, only whistle synth(s) heard
//      ....DOING THIS METHOD... conceptually more intuitive and easy to control w/ routine.

~bus_dryIn1Amp = Bus.control(s, 1); //dry input level bus
~bus_vocAmp = Bus.control(s, 1); //voc proc synth sum level bus
~bus_wislAmp = Bus.control(s, 1); //whistle proc synth sum level bus
~bus_vocwislMix = Bus.control(s, 1); //mix balance between vocal FX synths and whistle FX synths

~bus_vocSynthSumOut = Bus.audio(s, 2); //yea? to make it easier to process groups of synths?
~bus_wislSynthSum = Bus.audio(s, 2); //yea?

~bus_vocSynthSub = Bus.audio(s, 2); //NOT NEEDED? if not using subMix synths...
~bus_wislSynthSub = Bus.audio(s, 2); //NOT NEEDED? if not using subMix synths...
~bus_outMain = Bus.audio(s, 2);  //NOT NEEDED?

~bus_dryIn1Amp.set(0.3); //make these static values b/c using SelectX's to control mix levels?
~bus_vocAmp.set(0.5); //make these static values b/c using SelectX's to control mix levels?
~bus_wislAmp.set(1.0); //make these static values b/c using SelectX's to control mix levels?
~bus_vocwislMix.set(0.0); //0 = voc accomp only, 1 = whistle accomp only. Set via control routine
~bus_accompAmp.set(0.7); //if using this method, set ~bus_vocAmp and ~bus_wislAmp to (1.0)

~dryIn1_mix = Synth(\subMix, [\inBus, ~bus_input1, \amp, ~bus_dryIn1Amp.asMap, \outBus, ~bus_outMain]); //bus for adjusting level of raw input and sending to main out

~vocSynthSum_mix = Synth(\subMix, [\inBus, ~bus_vocSynthSum, \amp, ~bus_vocAmp.asMap, \outBus, ~bus_outMain/*or just 0???*/]); //voc accomp sum mix synth. NOT NEEDED IF: controlling subSynth levels w/ ~bus_vocAmp and outputting to ~bus_vocSynthSum, OTHERWISE - create additional bus to output to from this synth to use as input bus for ~accomp_mix XFADE synth

~wislSynthSum_mix = Synth(\subMix, [\inBus, ~bus_wislSynthSum, \amp, ~bus_wislAmp.asMap, \outBus, ~bus_outMain]); //whistle accomp sum mix synth. NOT NEEDED IF: controlling subSynth levels w/ ~bus_wislAmp and outputting to ~bus_wislSynthSum, OTHERWISE - create additional bus to output to from this synth to use as input bus for ~accomp_mix XFADE synth

~masterOut = Synth(\subMix, [in: ~bus_outMain, out: 0]); //NEEDED?


~accomp_mix = Synth(\XFade, [\in1, ~bus_vocSynthSum, \in2, ~bus_wislSynthSum, \out, ~bus_outMain /*or 0, or [0, 1]?*/, \amountControlBus, ~bus_vocwislMix, \amp, ~bus_accompAmp]); //harmonizer synth selector, ~bus_vocwislMix controls whether voc or whistle harmonizers are heard

~wisA1 = ~wekiSyn_wisl1.value(oscInBus: ~bus_oscIn_1, audioIn: ~bus_input1, audioOut: ~bus_wislSynthSum, scaleBuf: ~scaleBuf, amp: ~bus_wislAmp); //whistle harmonizer 1

~vocA1 = ~wekiSyn_voc1.value(oscInBus: ~bus_oscIn_1, audioIn: ~bus_input1, audioOut: ~bus_vocSynthSum, interval: 5.0, pan: 0.25, amp: ~bus_vocAmp); //voc harmonizer 1

~vocA2 = ~wekiSyn_voc1.value(oscInBus: ~bus_oscIn_1, audioIn: ~bus_input1, audioOut: ~bus_vocSynthSum, interval: -2.0, pan: -0.25, amp: ~bus_vocAmp); //voc harmonizer 2

//NEW AUTOHARMONIZE SYNTH DEFS ------ vvvvvvvvvvvvvvvvvvv ----------
~wekiSyn_voc1 = {|oscInBus, audioIn, audioOut, interval = 5.0, pan = 0.0, /*scaleBuf,*/ amp = 1.0, mix = 1.0|
	var numCh, inMsg, sigIn, sigOut, returnSynth, pitchRatio, pitchDisp, panMod;

	numCh = oscInBus.numChannels;

	returnSynth = SynthDef(\vocHarm_weki1, {|interval = 5.0, pan = 0.0, amp = 1.0, mix = 1.0|
		sigIn = In.ar(audioIn, 1);
		inMsg = In.kr(oscInBus, numCh);

		pitchRatio = interval.asFloat.round(0.01).midiratio; //set pitch transposition (semi-tone intervals)
		pitchDisp = LinLin.kr(inMsg[1], 0, 1, 0, 0.12).round(0.01); //scale weki out1 for pitchDisp val

		//sigOut = SelectX.ar(mix, [sigIn, PitchShift.ar(sigIn, 0.1, pitchRatio, 0, 0.002)]);
		sigOut = SelectX.ar(mix, [sigIn, PitchShift.ar(sigIn, 0.1, pitchRatio, pitchDisp, 0.002)]);
		//sigOut = FreeVerb.ar(sigOut, mix: 0.33, room: LinLin.kr(inMsg[1], 0, 1, 0.1, 0.4)); //no...make another synth for verb processing sum out...

		//panMod = LinLin.kr(inMsg[1], 0, 1, -0.35, 0.35).round(0.01); //consider
		//pan = Clip.kr(pan.asFloat + panMod, -0.9, 0.9); //consider

		sigOut = Pan2.ar(sigOut, pan.asFloat); //?? yes?
		//sigOut = Splay.ar(sigOut, LinLin.kr(inMsg[1], 0, 1, 0, 0.2)); //yea / no?

		Out.ar(audioOut, sigOut * amp);
	}).play(addAction: \addToTail);

	returnSynth;
};

~wekiSyn_wisl1 = {|oscInBus, audioIn, audioOut, scaleBuf, amp = 1.0, mix = 1.0| //add arg for initial interval scale spread of weki output1???? (12 == (-12, 12) | 5 == (-5, 5) | etc...)
	var numCh, inMsg, sigIn, sigOut, returnSynth, pitchRatio, pitchDisp;

	numCh = oscInBus.numChannels;

	returnSynth = SynthDef(\wislHarm_weki1, {|amp = 1.0, mix = 1.0| //can't use scaleBuf as arg for this synthDef :(
		sigIn = In.ar(audioIn, 1);
		inMsg = In.kr(oscInBus, numCh);

		pitchRatio = DegreeToKey.kr(scaleBuf.bufnum, LinLin.kr(inMsg[1], 0, 1, 5, -5).round(1)).midiratio; //convert Weki out 1 into a transposition ratio from mapped scale degrees

		pitchDisp = LinLin.kr(inMsg[1], 0, 1, 0, 0.12).round(0.01); //scale weki out1 for pitchDisp val

		//sigOut = SelectX.ar(mix, [sigIn, PitchShift.ar(sigIn, 0.1, pitchRatio, 0, 0.002)]); //no pDisp
		sigOut = SelectX.ar(mix, [sigIn, PitchShift.ar(sigIn, 0.1, pitchRatio, pitchDisp, 0.002)]); //pDisp

		//sigOut = FreeVerb.ar(sigOut, mix: 0.33, room: LinLin.kr(inMsg[1], 0, 1, 0.01, 0.7)); //?? yes?
		sigOut = Pan2.ar(sigOut, LinLin.kr(inMsg[1], 0, 1, -0.35, 0.35)); //mod pan w/ weki out??

		Out.ar(audioOut, sigOut * amp);
	}).play(addAction: \addToTail);

	returnSynth;
};
//NEW AUTOHARMONIZE SYNTH DEFS ------ ^^^^^^^^^^^^^^^^^^^ ----------

//=======SIMPLE TESTS of Voc and Whistle Auto-Harmonize Synths===========//
~testSynth = ~wekiSyn_vocSimp.value;
~testSynth.set(\interval, -2.0, \pan, 0.0, \mix, 0.2);
~testSynth.free;

~wekiSyn_vocSimp = {|interval = 5.0, pan = 0.0, /*scaleBuf,*/ amp = 1.0, mix = 1.0| //add arg for initial interval scale spread of weki output1???? (12 == (-12, 12) | 5 == (-5, 5) | etc...)
	var sigIn, sigOut, returnSynth, pitchRatio;

	returnSynth = SynthDef(\vocHarm_weki1, {|interval = 5.0, pan = 0.0, /*scaleBuf,*/ amp = 1.0, mix = 1.0| //<--needed to control synth after initial creation w/ ~wekiSyn_wisl1 execution???
		sigIn = SoundIn.ar(0);

		pitchRatio = interval.asFloat.round(0.01).midiratio; //set pitch transposition (semi-tone intervals)
		sigOut = SelectX.ar(mix, [sigIn, PitchShift.ar(sigIn, 0.1, pitchRatio, 0, 0.002)]); //<----not sure if I want this dry/wet signal mixing functionality.....decide...?
		//sigOut =  PitchShift.ar(sigIn, 0.1, pitchRatio, 0, 0.002);

		//sigOut = FreeVerb.ar(sigOut, mix: 0.33, room: LinLin.kr(inMsg[1], 0, 1, 0.01, 0.25)); //?? yes?
		sigOut = Pan2.ar(sigOut, pan.asFloat); //?? yes?
		//sigOut = Splay.ar(sigOut, LinLin.kr(inMsg[1], 0, 1, 0, 0.2)); //yea / no?

		Out.ar(0, sigOut * amp);
	}).play(addAction: \addToTail);

	returnSynth;
};

~scale1 = Scale.majorPentatonic.degrees; //[0, 2, 4, 7, 9]
~scaleBuf = Buffer.alloc(s, ~scale1.size, 1, {|b| b.setnMsg(0, ~scale1) } );
~scaleBuf.free;
~testSynth = ~wekiSyn_wislSimp.value(controlIn: ~bus_MouseX, scaleBuf: ~scaleBuf);
~testSynth.set(\room, 0.65, \rmix, 0.3, \mix, 0.6,  \pan, 0.0);
~testSynth.free;

SynthDef.new(\mousey, {|out|
	var sig = MouseX.kr(0, 1);
	Out.kr(out, sig);
} ).add;

~bus_MouseX = Bus.control(s, 1);
~mousey = Synth(\mousey, [~bus_MouseX]);

~wekiSyn_wislSimp = {|controlIn, scaleBuf, amp = 1.0, mix = 1.0, room = 0.65, rmix = 0.3, pan = 0.0| //add arg for initial interval scale spread of weki output1???? (12 == (-12, 12) | 5 == (-5, 5) | etc...)
	var sigIn, sigOut, controlVal, returnSynth, pitchRatio;

	returnSynth = SynthDef(\wislHarm_weki1, {|pitchInt = 3, amp = 1.0, mix = 1.0, room = 0.65, rmix = 0.3, pan = 0.0| //<--needed to control synth after initial creation w/ ~wekiSyn_wisl1 execution???
		controlVal = In.kr(controlIn, 1);
		sigIn = SoundIn.ar(0);
		//pitchRatio = DegreeToKey.kr(scaleBuf.bufnum, pitchInt.round(0.01)).midiratio;
		pitchRatio = DegreeToKey.kr(scaleBuf.bufnum, LinLin.kr(controlVal, 0, 1, 5, -5).round(1)).midiratio;
		sigOut = SelectX.ar(mix, [sigIn, PitchShift.ar(sigIn, 0.1, pitchRatio, 0, 0.002)]); //<----not sure if I want this dry/wet signal mixing functionality.....decide...?

		sigOut = FreeVerb.ar(sigOut, mix: rmix, room: room); //?? yes?
		sigOut = Pan2.ar(sigOut, pan); //?? yes?
		//sigOut = Splay.ar(sigOut, splay); //not stereo spreader I believe (at least w/ one input...?)

		Out.ar(0, sigOut * amp);
	}).play(addAction: \addToTail);

	returnSynth;
};
//========^^^^^^^^^====SIMPLE TESTS======^^^^^^^^^===============//

//~first accomp synth, primitive Select of output .... synth amp and scale args are hardcoded..........
/*~wekiSyn_wisl1 = {|oscInBus, audioIn, scaleBuf| //add arg for initial interval scale spread of weki output1???? (12 == (-12, 12) | 5 == (-5, 5) | etc...)
	var numCh, inMsg, sigIn, sigOut, sigVoc, sigWhistle, returnSynth, pitchRatio;

	numCh = oscInBus.numChannels;
	//scale =  Scale.majorPentatonic;
	//scale = [0, 2, 4, 7, 9];

	returnSynth = SynthDef(\vwharm_weki1, { //<--put scaleBuf arg here too for scale modulation?
		sigIn = In.ar(audioIn, 1);
		inMsg = In.kr(oscInBus, numCh);

		sigVoc = SinOsc.ar(220, mul: 0.1);

		//pitchRatio = LinLin.kr(inMsg[1], 0, 1, 12, -12).round(1).midiratio.round(0.001).poll(2);
		pitchRatio = DegreeToKey.kr(scaleBuf.bufnum, LinLin.kr(inMsg[1], 0, 1, 5, -5).round(1)).midiratio; //convert Weki out 1 into a transposition ratio from mapped scale degrees
		sigWhistle = SelectX.ar(0.7, [sigIn, PitchShift.ar(sigIn, 0.1, pitchRatio, 0, 0.002)]); //<--working
		//sigWhistle = SinOsc.ar(440, mul: 0.1);

		sigOut = SelectX.ar(inMsg[0] > 1.0, [sigVoc, sigWhistle]);

		Out.ar([0, 1], sigOut);

		//Poll.kr(3, inMsg[0], 'oscIn');
		//inMsg[0].poll(3, 'oscIn');
	}).play(addAction: \addToTail);

	returnSynth;
}; */


/*
//PITCH SHIFTING VOC / WHISTLING <------TRY THESE PARAMETERS
play({
    PitchShift.ar(
        AudioIn.ar([1,2]),    // stereo audio input
        0.1,             // grain size
		MouseX.kr(0.25, 3, 1),    //pitchRatio: mod by Weki_Output2 (Relative Pitch Follower)
		MouseY.kr(0, 0.15), // pitch dispersion: mod/switch case different vals based on WekiOut1, 3, 4?
		0.002 // time dispersion
    )
})
*/
//===========ACCOMP SYNTH AND FX CONTROL ROUTINE===========
~flag_wekSyn_prevIn = 1; //langside flag storing last input from WekiOut1, 1 == voc, 2 == whistle
~flag_wekSyn_prevIn_change = false; //flag for debouncing sudden changes due to input noise
~flag_wekSyn_prevVow = 1; //flag for storing last input from WekiOut3, 1 == ah, 2 == eh, 3 == ee, 4 == oh, 5 == oo
~flag_wekSyn_prevVow_change = false; //flag for debouncing sudden changes due to input noise

~routine_wekiSynthControl1 = {|oscInBus, rate = 0.1| //<<<<<<<<<<<<<<<<<<
	Routine ({
		var yieldTime = rate; //<---necessary? maybe need to change to permit state change activity?
		oscInBus.get({ |msg|
			{
				if (msg[0] == 1, { //"voc detected"
					if (~flag_wekSyn_prevIn == 1, { //sound source has not changed since prev bus.get
						~flag_wekSyn_prevIn_change = false; //reset debounce flag in case it was previously triggered
						//CARRY ON... do anything???
						"msg[0] = 1 - NO CHANGE".postln;

						//MONITOR CHANGES IN msg[2] <<<<<<<<
						switch (msg[2],
							1, {//if msg[2] == 1
								if (~flag_wekSyn_prevVow == 1, { //msg[2] has not changed since prev bus.get
									~flag_wekSyn_prevVow_change = false; //reset flag if it was triggered by noise

									//CARRY ON W/ 'AH' COMMANDS

									yieldTime = rate; //0.1 <----necessary???
								} , { //else if ~flag_prevVow != 1, maybe we're changing vowels
									//DEBOUNCE
									if (~flag_wekSyn_prevVow_change == false, {
										~flag_wekSyn_prevVow_change = true;
										"msg[2] = 1 | prev msg[2] = ? - STATE CHANGE TEST".postln;
										yieldTime = 0.3; //"debounce" time
									}, { //else if ~flag_stateChange == true, state has changed and remained same long enough to rule out noise, and we can proceed with triggered changes
										~flag_wekSyn_prevVow_change = false;

										//DO STUFF WHEN 'AH' FIRST DETECTED

										~flag_wekSyn_prevVow = 1; //set flag to remember last state before resetting routine
										"msg[2] = 1 | prev msg[2] = ? - STATE CHANGE CONFIRMED".postln;
										yieldTime = rate; //<---yea?
									} );
								} );
							},
							2, {//if msg[2] == 2
								//DEBOUNCE
								//DO STUFF WHEN 'EH' DETECTED
							},
							3, {//if msg[2] == 3

							},
							4, {//if msg[2] == 4

							},
							5, {//if msg[2] == 5

							}
						);


						yieldTime = rate; //0.1 <----necessary???
					} , { //else ~flag_wekSyn_prevIn == 2, we're changing from  "2 - whistling" to "1 - voc"

						//CHECK TO SEE IF TIME THRESHOLD SURPASSED BEFORE CONFIRMING STATE CHANGE
						if (~flag_wekSyn_prevIn_change == false, {
							~flag_wekSyn_prevIn_change = true;
							"msg[0] = 1 | prev msg[0] = 2 - STATE CHANGE TEST".postln;
							yieldTime = 0.3; //"debounce" time
						}, { //else if ~flag_stateChange == true, state has changed and remained same long enough to rule out noise, and we can proceed with triggered changes
							~flag_wekSyn_prevIn_change = false;

							//fade in Voc processing synths
							//fade out whistle processing synth(s)

							~flag_wekSyn_prevIn = 1; //set flag to remember last state before resetting routine
							"msg[0] = 1 | prev msg[0] = 1 - STATE CHANGE CONFIRMED".postln;
							yieldTime = rate; //<---yea?
						} );
					} );
				} , { //else if msg[0] == 2 "whistling detected"
					if (~flag_wekSyn_prevIn == 2, { //sound source has not changed since prev bus.get
						~flag_wekSyn_prevIn_change = false; //reset debounce flag

						//CARRY ON.... do anything?
						"msg[0] = 2 - NO CHANGE".postln;

						yieldTime = rate; //0.1 <----necessary???
					} , { //else flag must have changed recently from "1 - voc" to "2 - whistling"

						//CHECK TO SEE IF TIME THRESHOLD SURPASSED BEFORE CONFIRMING STATE CHANGE
						if (~flag_wekSyn_prevIn_change == false, {
							~flag_wekSyn_prevIn_change = true;
							"msg[0] = 2 | prev msg[0] = 1 - STATE CHANGE TEST".postln;
							yieldTime = 0.3; //"debounce" time
						}, { //else if ~flag_stateChange == true, state has changed and remained same long enough to rule out noise, and we can proceed with triggered changes
							~flag_wekSyn_prevIn_change = false;

							//fade in whistle processing synths
							//fade out Voc processing synth(s)

							~flag_wekSyn_prevIn = 2; //set flag to remember last state before resetting routine
							"msg[0] = 2 | prev msg[0] = 2 - STATE CHANGE CONFIRMED".postln;
							yieldTime = rate; //<---yea?
						} );
					} );
				} );
			}.defer;
		});
		yieldTime.yieldAndReset; //<---necessary or simply leave as rate.yieldAndReset???
	});
};


////////////////SYNTH DEFS IMPORTED FROM SONIC MIRROR////////////////
/*SynthDef.new(\pitchShifter, {
	arg inBus, outBus, windowSize = 0.2, pitchRatio = 1, pitchDispers = 0, timeDispers = 0.2, amp = 1;
	var sigIn, sigOut;
	sigIn = In.ar(inBus, 1);
	//sigIn = InFeedback.ar(inBus, 1);
	sigOut = PitchShift.ar(sigIn, windowSize, pitchRatio, pitchDispers, timeDispers, amp);
	Out.ar(outBus, sigOut);
}).add; */

SynthDef.new(\XFade, { //newer version w/ global amp control
	|in1, in2, out, amountControlBus, amp = 1|
	var inArray, mixSignal, sig;
	inArray = [In.ar(in1), In.ar(in2)];
	//inArray = [InFeedback.ar(in1), InFeedback.ar(in2)];
	mixSignal = SelectX.ar(amountControlBus, inArray);
	sig = mixSignal * amp;
	//OffsetOut.ar(out, sig); //should I use this instead?
	Out.ar(out, sig);
} ).add;

SynthDef(\LinInterp_pitch, {
	arg startVal, stopVal, duration, out;
	Out.kr(out, Line.kr(startVal, stopVal, duration, doneAction: 2).midiratio);
} ).add;

SynthDef(\LinInterp_rate, {
	arg startVal, stopVal, duration, out, rateMod = 1;
	var outputVal = rateMod * Line.kr(startVal, stopVal, duration, doneAction: 2).midiratio;
	Out.kr(out, outputVal);
} ).add;

SynthDef(\LinInterp_num, {
	arg startVal, stopVal, duration, mult = 1, out;
	Out.kr(out, Line.kr(startVal, stopVal, duration, mul: mult, doneAction: 2));
} ).add;

SynthDef.new(\subMix, { //<--NEW - utility
	|in, amp = 1, out|
	var sig;
	sig = In.ar(in) * amp;
	//sig = InFeedback.ar(in) * amp;
	//OffsetOut.ar(out, sig);
	Out.ar(out, sig);
} ).add;

SynthDef.new(\mainOut, { //<--NEW w/ Lo-cut
	|in, loCutoff = 90, rQ = 1, amp = 1|
	var sig;
	sig = BHiPass4.ar( In.ar(in), loCutoff, rq: rQ, mul: amp);
	//sig = In.ar(in) * amp;
	//sig = InFeedback.ar(in) * amp;
	//OffsetOut.ar(0, sig);
	Out.ar([0, 1], sig);
} ).add;
//==================NEW NEW NEW ======================//
//==================ORIG SCML ORIG SCML ORIG ======================//

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
	var numCh = bus.numChannels;
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

)

// #3 ======ACTIVATE AUDIO INPUT ANALYSIS SYNTHS======
i = Synth(\monAudioInput, [\outBus, ~bus_input1]);

//LOUDNESS (volume - perceptual measure in Sones) ------
l = Synth(\Loudness, [\input, ~bus_input1, \outBus, ~bus_loudness]).moveAfter(i);

//RMS (volume) ------
r = Synth(\RMS, [\input, ~bus_input1, \numSamp, 40, \outBus, ~bus_rms]).moveAfter(i);

//MFCC
m = Synth(\MFCC, [\input, ~bus_input1, \outBus, ~bus_mfcc]).moveAfter(i);

//PITCH TRACKER
p = Synth(\Pitch, [\input, ~bus_input1, \outBus, ~bus_pitch]).moveAfter(i); //outputs two values (freq
~p2 = Synth(\Pitch2, [\input, ~bus_input1, \outBus, ~bus_pitch2]).moveAfter(i);
~p2.free;
//SPECTRAL CENTROID
c = Synth(\specCent, [\input, ~bus_input1, \outBus, ~bus_specCent]).moveAfter(i);

//SPECTRAL FLATNESS
f = Synth(\specFlat, [\input, ~bus_input1, \outBus, ~bus_specFlat]).moveAfter(i);

//ONSETS
n = Synth(\onsets, [\input, ~bus_input1, \outBus, ~bus_onsets, \threshold, 0.7]).moveAfter(i);
n.set(\threshold, 0.5); //evaluate to change detection threshold (between 0 - 1)


//#4 ======OUTPUT AUDIO FEATURES VIA OSC======

// Default OSC output (~oscOut_weki): IP - 127.0.0.1,  Port # 6448

(//TRANSMIT LOUDNESS AND MFCCs - (14 features)
~busSum_ldns_mfcc = ~sumFunc_xin.value( [~bus_loudness, ~bus_mfcc] );
~transmit = ~streamFeatures.value(~busSum_ldns_mfcc, ~oscOut_weki, "/wek/inputs", 0.1); //adjust last argument value to change rate OSC messages are output (0.04 or about 25 times/sec is default)
SystemClock.play(~transmit);
)
( //STOP transmitting (NOTE:  evaluate this chunk before transmitting other feature sets)
~transmit.stop;
~sumSyn_xin.free;
~busSum_ldns_mfcc.free;
)


(//TRANSMIT LOUDNESS, SPECTRAL FLATNESS, AND SPECTRAL CENTROID - (3 features)
~busSum_ldns_sFlat_sCent = ~sumFunc_xin.value( [~bus_loudness, ~bus_specFlat, ~bus_specCent] );
~transmit = ~streamFeatures.value(~busSum_ldns_sFlat_sCent, ~oscOut_weki, "/wek/inputs", 0.1);
SystemClock.play(~transmit);
)
( //STOP transmitting
~transmit.stop;
~sumSyn_xin.free;
~busSum_ldns_sFlat_sCent.free;
)

//!!!!!!!!!!!
(//TRANSMIT LOUDNESS AND PITCH - (3 features: [loudness value, frequency value, 0 or 1 indicating whether or not the detected audio has a definite pitch] )
~busSum_ldns_pitch = ~sumFunc_xin.value( [~bus_loudness, ~bus_pitch2] ); //!!!!!CHANGED outbus from ~bus_pitch
~transmit = ~streamFeatures.value(~busSum_ldns_pitch, ~oscOut_weki, "/wek/inputs", 0.08);
SystemClock.play(~transmit);
)
( //STOP transmitting
~transmit.stop;
~sumSyn_xin.free;
~busSum_ldns_pitch.free;
)

(//TRANSMIT LOUDNESS, SPECTRAL FLATNESS, ONSETS - (3 features)
~busSum_ldns_sFlat_onset = ~sumFunc_xin.value( [~bus_loudness, ~bus_specFlat, ~bus_onsets] );
~transmit = ~streamFeatures.value(~busSum_ldns_sFlat_onset, ~oscOut_weki, "/wek/inputs", 0.04);
SystemClock.play(~transmit);
)
(//STOP transmitting
~transmit.stop;
~sumSyn_xin.free;
~busSum_ldns_sFlat_onset.free;
)


(//TRANSMIT LOUDNESS, SPECTRAL FLATNESS, SPECTRAL CENTROID, PITCH - (5 features)
~busSum_ldns_sFlat_pitch_sCent = ~sumFunc_xin.value( [~bus_loudness, ~bus_specFlat, ~bus_specCent, ~bus_pitch] );
~transmit = ~streamFeatures.value(~busSum_ldns_sFlat_pitch_sCent, ~oscOut_weki, "/wek/inputs", 0.04);
SystemClock.play(~transmit);
)
(//STOP transmitting
~transmit.stop;
~sumSyn_xin.free;
~busSum_ldns_sFlat_pitch_sCent.free;
)


(//TRANSMIT FEATURES - Loudness, Flatness, Pitch[2]  (variable size feature bus set)
~busSum_xin = ~sumFunc_xin.value([~bus_loudness, ~bus_specFlat, ~bus_pitch]); //input desired feature busses in array to monitor (separate w/ comma)
~transmit = ~streamFeatures.value(~busSum_xin, ~oscOut_weki, "/wek/inputs", 0.1);
SystemClock.play(~transmit);
)
( //STOP transmitting
~transmit.stop;
~sumSyn_xin.free;
~busSum_xin.free;
)


///////=======TESTING OSC INPUT=======//////////
~test1 = ~routine_wekiSynthControl1.value(~bus_loudness);
SystemClock.play(~test1);
~test1.stop;

~bus_oscIn_1 = ~oscIn_weki_1.value(numIn: 4, defKey: "oscDef1", port: 12000);  //#1

~bus_oscIn_1.get({|i| i.postln;/*var a; a = i[0].asInteger; i[0].postln; i[0].isFloat.postln; a.isFloat.postln;*/ });

(//#2
~scale1 = Scale.majorPentatonic.degrees; //[0, 2, 4, 7, 9]
~scaleBuf = Buffer.alloc(s, ~scale1.size, 1, {|b| b.setnMsg(0, ~scale1) } ); //create buffer to store scale
~testSynth = ~wekiSyn_wisl1.value(oscInBus: ~bus_oscIn_1, audioIn: ~bus_input1, scaleBuf: ~scaleBuf);
)

~bus_oscIn_1.free;
~oscIn_weki_1.free;
~testSynth.free;
s.plotTree;

OSCdef.all;
OSCdef.freeAll;
OSCdef(\oscDef1).free;
///////TESTING SCRATCH//////////

(//TRANSMIT FEATURES - CUSTOM  (variable size feature bus set) //<----!!!!!
~busSum_xin = ~sumFunc_xin.value([~bus_loudness, ~bus_mfcc, ~bus_pitch]); //input desired feature busses in array to monitor (separate w/ comma)
~transmit = ~streamFeatures.value(~busSum_xin, ~oscOut_weki, "/wek/inputs", 0.08);
SystemClock.play(~transmit);
//~transmit.play;
)
( //STOP transmitting
~transmit.stop;
~sumSyn_xin.free;
~busSum_xin.free;
)

/////////testing new convenience function...in the works...not huge priority now....
~transmitFeatures.value(~busSum_ldns_mfcc, [~bus_loudness, ~bus_mfcc], ~oscOut_weki, "/wek/inputs", 0.5, act: false);
s.plotTree;
s.queryAllNodes;

// ======CLEANUP======
(
s.freeAll;

~bus_input1.free;
~bus_loudness.free;
~bus_rms.free;
~bus_mfcc.free;
~bus_pitch.free;
~bus_specCent.free;
~bus_specFlat.free;
~bus_onsets.free;

~oscOut_weki.disconnect;
OSCdef.freeAll;
)

s.quit;