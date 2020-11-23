# FIR
pkg load signal

f1=0.48;
f2=0.52;
N=127
hc=round(fir1(N-1,f1,'low')*2^15);
printf("Stopband attenuation %d dB\n", N*22*(f2-f1))
haux=hc';
save filter2 haux