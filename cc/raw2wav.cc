#include "WaveWritter.hpp"
#include <iostream>

using namespace std;

int main() {
    WaveWritter ww("out.wav",55780, false);
    while( !cin.eof() ) {
        int16_t data[2];
        cin.read( (char*)&data, 4 );
        if( cin.eof() ) break;
        // data[1] = data[0]; // convert mono to stereo
        ww.write(data);
    }
}