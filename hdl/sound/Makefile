all: fir2_69.hex uprate3.hex

fir2_69.hex: filter fir_coeff
	fir_coeff > fir2_69.hex

uprate3.hex: filter3 fir_coeff
	fir_coeff filter3 > uprate3.hex

filter: jtframe_fir2.m
	octave jtframe_fir2.m

filter3: jtframe_fir3.m
	octave jtframe_fir3.m

fir_coeff: fir_coeff.c
	gcc fir_coeff.c -o fir_coeff