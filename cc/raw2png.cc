#include <cstdio>
#include <cstdlib>
#include <cstring>

int main( int argc, char *argv[]) {
    int width=256, height=224;
    char fname[512]="/dev/stdin";
    char extra[512]="";
    int framecnt=1;
    bool verbose=false;

    for( int k=1; k<argc; k++ ) {
        if( strcmp("-w",argv[k])==0 ) {
            if(++k>=argc) {
                printf("Error: expecting number after -w\n");
                return 1;
            }
            width=strtol( argv[k], nullptr, 0 );
            continue;
        }
        if( strcmp("-h",argv[k])==0 ) {
            if(++k>=argc) {
                printf("Error: expecting number after -h\n");
                return 1;
            }
            height=strtol( argv[k], nullptr, 0 );
            continue;
        }
        if( strcmp("-f",argv[k])==0 ) {
            if(++k>=argc) {
                printf("Error: expecting file name after -f\n");
                return 1;
            }
            strncpy( fname, argv[k], 511 );
            fname[511]=0;
            if( verbose ) printf("Reading from %s\n",fname);
            continue;
        }
        if( strcmp("-v",argv[k])==0 ) {
            verbose = true;
            continue;
        }
        if( strcmp(":", argv[k])==0 ) {
            int rest=512, cp=0;
            while( ++k < argc && rest>0 ) {
                strncpy( extra+cp, argv[k], rest );
                cp += strlen( argv[k] );
                if( cp < 512 )
                    extra[cp++]=' ';
                else
                    break;
            }
            extra[ cp<512 ? cp : 511 ]=0;
            break;
        }
        if( strcmp("--help", argv[k])==0 || strcmp("-help", argv[k])==0 ) {
            puts(
    "Converter from video simulation to PNG files\n"
    "Part of JTFRAME. (c) Jose Tejada, aka jotego\n"
    "Usage: raw2png [-w width] [-h height] [-f filename] [-v] [: extra arguments]\n"
    "       Default size is 256x224 and standard input is read\n"
    "       The extra arguments apply to the 'convert' linux tool, which is\n"
    "       used to make the binary to PNG conversion.\n"
    "       Identical frames are ommitted. When the first incomplete frame is\n"
    "       found the program exits.\n\n"
    "       -v      verbose\n"
    "       -w      width\n"
    "       -h      height\n"
    "       -f      input file name\n"
            );
        }
        printf("Unknown argument %s\n", argv[k] );
        return 1;
    }

    FILE *f = fopen(fname,"rb");
    if( f == NULL ) {
        printf("Cannot open file %s\n", fname );
        return 1;
    }
    const int bufsize = width*height*4;
    char *buf =new char[ bufsize ];
    char *last=new char[ bufsize ];
    memset( last, 0, bufsize );
    while( !feof(f) ) {
        size_t rdcnt = fread( buf, width*4, height, f );
        if( rdcnt==height ) {
            if( memcmp( last, buf, bufsize )!=0 ) {
                memcpy( last, buf, bufsize );
                FILE *fout = fopen("frame.raw","wb");
                size_t wrcnt = fwrite( buf, 1, bufsize, fout );
                if( wrcnt == bufsize ) {
                    char exes[1024];
                    sprintf(exes,"convert %s -filter Point "
                        "-size %dx%d -depth 8 RGBA:frame.raw frame_%d.png",
                        extra, width, height, framecnt);
                    if( verbose ) puts(exes);
                    system(exes);
                }
                fclose(fout);
            }
            framecnt++;
        } else break;
    }
    fclose(f);
    delete[] buf;
    buf = nullptr;
    delete[] last;
    last = nullptr;
    return 0;
}