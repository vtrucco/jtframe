fir2_69.hex: filter fir_coeff
	fir_coeff > fir2_69.hex

filter: jtframe_fir2.m
	octave jtframe_fir2.m

fir_coeff: fir_coeff.c
	gcc fir_coeff.c -o fir_coeff