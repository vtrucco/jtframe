#include <stdio.h>
#include <stdlib.h>

void fill( char *fname, int*ram);

int main(int argc, char *argv[]) {
    int ram[512];
    char *fname_def = "filter";
    char *fname = argc>1 ? argv[1] : fname_def;
    fill( fname, ram );
    for( int j=0; j<512; j++ )
        printf("%04X\n",ram[j]&0xffff);
    return 0;
}

void fill( char *fname, int*ram ) {
    FILE *fin;
    int j=0;
    char buf[256];
    for( int k=0; k<512; k++ ) ram[k]=0;
    fin = fopen( fname ,"r" );
    do {
        fgets( buf, 256, fin );
    }while( buf[0]=='#' );
    do{
        int n;
        n = strtol(buf, NULL, 0);
        ram[j++] = n;
        fgets( buf, 256, fin );
    }while(!feof(fin) && j<256);
    fclose(fin);
}