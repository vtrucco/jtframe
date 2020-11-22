#include <stdio.h>
#include <stdlib.h>

void fill( int*ram);

int main() {
    int ram[512];
    fill( ram );
    for( int j=0; j<512; j++ )
        printf("%04X\n",ram[j]&0xffff);
    return 0;
}

void fill( int*ram) {
    FILE *fin;
    int j=0;
    char buf[256];
    for( int k=0; k<512; k++ ) ram[k]=0;
    fin = fopen( "filter" ,"r" );
    do {
        fgets( buf, 256, fin );
    }while( buf[0]=='#' );
    do{
        int n;
        n = strtol(buf, NULL, 0);
        ram[j++] = n;
        fgets( buf, 256, fin );
    }while(!feof(fin));
    fclose(fin);
}