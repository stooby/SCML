s = Server.local;
s.options.sampleRate = 44100;

// assumes hop of half fftsize, fine
b = Buffer.alloc(s, 1024, 1); // for sampling rates 44100 and 48000
//b = Buffer.alloc(s, 2048, 1); // for sampling rates 88200 and 96000

//analysis of LIVE SOUND INPUT  <====================
(
x = {
	var in, fft, loudness;
	in = SoundIn.ar(0);
	fft = FFT(b, in);
	loudness = Loudness.kr(fft).poll(10);
	//Out.ar(0, Pan2.ar(in));
}.play
)

// TESTS
// sones = 2 ** ((phon - 40) / 10)
// sine of 40 dB = 40 phon at 1000 kHz = 1 sone
// full amp = 100 dB
// -60.dbamp = 0.001 = 1 sone
// -40.dbamp = 0.01 = 4 sone
// -20.dbamp= 0.1 = 16 sone
// 0.dbamp= 1 = 64 sone
(
{
var in, fft, loudness;

in = SinOsc.ar(1000, 0, 0.001); //should be 1 sone
//in = SinOsc.ar(1000, 0, 0.01); //should be 4 sone
//in = SinOsc.ar(1000, 0, 0.1); //should be 16 sone
//in = SinOsc.ar(1000, 0, 1); //should be 64 sone
//in = Saw.ar * SinOsc.ar(4);
//in = WhiteNoise.ar;
//in = Silent.ar; // should be small, around 2 ** ((0 - 40) / 10) = 2 ** (-4) = 0.0625
//in = DC.ar(1);
//in = SinOsc.ar(22050, pi * 0.5, 1);
// fade ins
//in = SinOsc.ar(1000, 0, Line.kr(0, 1, 2));
//in = SinOsc.ar(1000, 0, Line.kr(0, 1, 2) ** 2);
//in = WhiteNoise.ar(Line.kr(0, 1, 2));
//in = PlayBuf.ar(1, d, BufRateScale.kr(d), 1, 0, 1);

fft = FFT(b, in);

loudness = Loudness.kr(fft, 0.25, 6).poll(50);

Out.ar(0, Pan2.ar(in));
K2A.ar(loudness * 0.016)
}.plot(2.0)
)