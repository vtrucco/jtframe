# Converts logo128.png to a 1-bit hex file
# to be used with osd.v

[r c] = size(I)
# bit conversion
f=fopen("osdback.hex","w");

for j=1:2:r
	# fill to make width = 256
	for k=c+1:8:256
		fprintf(f,"0\n")
	endfor
	for k=1:8:c
		val=0;
		for b=0:7
			if I(j,k+b)!=0
				printf("*")				
				val=bitset(val,b+1);
			else
				printf(" ")
			endif
		endfor
		fprintf(f,"%X\n",val)
	endfor
	printf("\n")
endfor
fclose(f)