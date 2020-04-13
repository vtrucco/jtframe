#include <iostream>
#include <string>

using namespace std;

int main(int argc, char * argv[] ) {
    bool print=false;
    cout << "<mame>\n";
    while( !cin.eof() ) {        
        string line;
        getline( cin, line );
        if( !print ) {
            if( line.find("cps1.cpp") != string::npos ) print=true;
        }
        if( print ) {
            cout << line << '\n';
            if( line.find("</machine>") != string::npos ) print=false;
        }
    }
    cout << "</mame>\n";
    return 0;
}