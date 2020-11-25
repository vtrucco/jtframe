# FIR
pkg load signal

Fs=1.5e6/16;
f1=15000/Fs;
f2=24000/Fs;
N=127
hc=round(fir1(N-1,f1,'low')*2^15);
printf("Stopband attenuation %d dB\n", N*22*(f2-f1))
hc_fft=abs(fft(hc));
hdb=20*log10(hc_fft);
haux=hc';
save filter49 haux
printf("Gain at DC %d dB = %d \n", hdb(1), hc_fft(1))
# use freqz(hc) to display the frequency response