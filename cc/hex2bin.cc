#include <iostream>
#include <iomanip>
#include <sstream>
#include <string>

using namespace std;

int main( int argc, char *argv[] ) {
    while(!cin.eof()) {
        int x;
        string s;
        getline(s,cin);
        stringstream ss(s);
        ss >> hex >> x;
        char b = (char)(x&0xff);
        cout.write(&b,1);
    }
}