#include <string>
#include <map>
#include <iostream>
#include <fstream>
#include <cstdlib>
#include <cstring>
#include <iomanip>
#include <sstream>
#include <set>

using namespace std;
typedef map<int,string> Pins;

class Component{
        Pins pins;
        string instance, type;
        Component *alt_names;
    public:
        Component( string _inst, string _type ) : instance(_inst), type(_type) {
            alt_names=NULL;
        }
        const string& get_name() { return instance; }
        const string& get_type() { return type; }
        const Pins& get_pins() { return pins; }
        int pin_count() { return pins.size(); }
        void set_pin(int k, const string& val);
        void set_ref( Component *alt ) { 
            if( alt == NULL ) {
                cout << "ERROR: No pair for type " << type << "\n";
                return;
            }
            // cout << instance << " paired with " << alt->get_name() << '\n';
            alt_names=alt; 
        }
        string get_alt_name( int k); // Get alternative name for pin k from reference
        string get_pinname(int k);
        friend void dump(Component& c);
};

string Component::get_alt_name( int k ) {
    if( alt_names )
        return alt_names->get_pinname(k);
    else
        return "Unknown_pin";
}

string Component::get_pinname(int k) {
    auto i = pins.find(k);
    if( i != pins.end() ) return i->second;
    else return "Unknown_pin";
}

void Component::set_pin(int k, const string& val ) {
    pins[k]=val;
}

void dump(Component& c) {
    cout << c.alt_names->type << " " << c.instance << "(\n";
    int count = c.pin_count();
    typedef map<int,string> BusIndex;
    typedef map<string, BusIndex *> BusMap;
    BusMap buses;
    
    // first dump all pins which are not buses
    for( auto k : c.pins ) {
        string pin_name = c.get_alt_name(k.first);
        size_t pos;
        if( (pos=pin_name.find("[")) != string::npos ) {
            // this is part of a bus
            string bus = pin_name.substr(0,pos);
            BusMap::iterator this_bus = buses.find(bus);
            BusIndex* bi=NULL;
            if( this_bus == buses.end() ) { // first element of this bus
                bi = new BusIndex;              
                buses[bus] = bi;
            } else {
                bi = this_bus->second;
            }
            pos++;
            // cout << pin_name << "\n\t";
            int bus_pin = atoi( pin_name.substr(pos).c_str() );
//            cout << "bus pin: " << bus_pin << " -> " << k.second << '\n';
            (*bi)[bus_pin] = k.second;
            continue;
        }
        cout << "    ." << setiosflags(ios_base::left) << setw(10) << pin_name
             << "( " << setw(24) << k.second << " )";
        if( --count ) cout << ',';
        cout << '\n';
    }
    // Now the buses
    count = buses.size();
    for( auto k : buses ) {
        BusIndex *bi = k.second;
        cout << setw(0) << "    ." << setiosflags(ios_base::left) << setw(10) << k.first;
//        cout << "bus: " << k.first << " of size " << bi->size() << '\n';     
        cout << "({ ";
        for( int i= bi->size()-1;  i>=0; i-- ) {
            cout << bi->at(i);
            if(i) cout << ",\n                  "; else cout << "})";
        }
        if( --count ) cout << ',';
        cout << '\n';
    }
    cout << ");\n\n";    
    // free memory
    for( auto k : buses ) {
        delete k.second;
    }
};

typedef map<string,Component*> ComponentMap;

void parse_netlist( const string& fname, ComponentMap& comps );
void parse_library( const char *fname, ComponentMap& comps );

void delete_map( ComponentMap& m ) {
    while( m.size() ) {
        delete m.begin()->second;
        m.erase( m.begin() );
    }
}

int match_parts( ComponentMap& comps, ComponentMap& mods );

void dump_wires( ComponentMap& comps ) {
    set<string> wires;
    for( auto& k : comps ) {
        const Pins& pins = k.second->get_pins();
        for( auto& p : pins ) wires.insert( p.second );
    }
    // now dump the wires
    for( auto& w : wires ) {
        if( w[0] != '1' )
            cout << "wire " << w << ";\n";
    }
}

int main(int argc, char *argv[]) {
    string fname, libname="../hdl/jt74.v";
    bool do_wires=false;
    // parse command line
    for(int k=1; k<argc; k++ ) {
        if( strcmp(argv[k],"--wires")==0 || strcmp(argv[k],"-w")==0 ) {
            do_wires=true;
            continue;
        }
        if( strncmp(argv[k],"--lib",5)==0 || strcmp(argv[k],"-l")==0 ) {            
            if( argv[k][1]=='l' ) {
                if( ++k == argc ) {
                    cout << "ERROR: expecting path to library file after -l argument.\n";
                    return 1;
                }
                libname = argv[k];
            }
            else {
                libname = string(argv[k]).substr(6);
            }
            if( !ifstream(libname).good() ) {
                cout << "ERROR: cannot open library file: " << libname << '\n';
                return 1;
            }
            continue;
        }                 
        if( strcmp(argv[k],"--help")==0 || strcmp(argv[k],"-h")==0 ) {
            cout << "pcb2ver, part of JTFRAME open source hardware development framework.\n";
            cout << "KiCAD netlist to verilog converter.\n";
            cout << "(c) Jose Tejada Gomez (aka jotego) 2019\n";
            cout << "Contact twitter: @topapate\n\n";
            cout << "Usage: pcb2ver netlist-file [--wires|-w] [--lib=|-l path-to-library]\n";
            cout << "\t\t--wires or -w: add wire definition for signals at top of the file.\n";
            cout << "\t\t--lib or -l  : set path to library file.\n";
            cout << "\t\t               The libray file must contain a list of verilog modules,\n";
            cout << "\t\t               after the module name there must be a comment and a ref\n";
            cout << "\t\t               statement. After each port there must be a comment and a\n";
            cout << "\t\t               pin statement. Check out hdl/jt74.v in jtframe for several\n";
            cout << "\t\t               examples.\n";
            cout << "\tpcb2ver -h|--help\n\t\tDisplays this help message.\n";
            return 0;
        }
        if( fname.size()!=0 ) {
            cout << "ERROR: input file was already assigned to " << fname << ".\n";
            return 1;
        }
        fname = argv[k];
        if( !ifstream(fname).good() ) {
            cout << "ERROR: Cannot find file " << fname << '\n';
            return 1;
        }
    }
    if( fname=="" ) {
        cout << "ERROR: must provide a KiCAD netlist file name\n";
        cout << "\tpcb2ver netlist\n";
        return 1;
    }

    ComponentMap comps, mods;
    try {
        parse_netlist( fname, comps );
        parse_library(libname.c_str(), mods);
        if( match_parts( comps, mods ) != 0 ) {
            throw 3;
        };
        if( do_wires ) dump_wires( comps );
        for( auto& k : comps ) {
            dump(*k.second);
        }        
    }
    catch(int code ) {
        cout << "ERROR " << code << "\n";
    }
    // delete the maps
    delete_map( comps );
    delete_map( mods  );
}

int match_parts( ComponentMap& comps, ComponentMap& mods ) {
    int unmatched=0;
    for( auto& k : comps ) {
        Component *ref = NULL;
        const string& type = k.second->get_type();
        // cout << "Searching for " << type << '\n';
        for( auto& j : mods ) {
            const string& mod_name = j.second->get_name();
            // cout << "\t" << mod_name << '\n';
            if( type.size() != mod_name.size() ) continue;
            for(int c=0; c<type.size(); c++ ) {
                if( mod_name[c]=='?' ) continue;
                if( mod_name[c]!=type[c] ) goto nope;
            }
            ref = j.second;
            nope:
            continue;
        }
        if( ref==NULL ) unmatched++;
        k.second->set_ref(ref);
    }
    return unmatched;
}

void strip_blanks(string &s ) {
    string b;
    b.reserve( s.size() );
    bool blank=false;
    for( int i=0; i<s.size(); i++ ) {
        if( s[i] == ' ' || s[i] == '\t' ) {
            b.append( 1, ' ' );
            while( i+1<s.size() && (s[i+1]==' ' || s[i+1]=='\t') ) i++;
        }
        else b.append( 1, s[i] );
    }
    // remove the trailing blank
    if( b.size()>0 && b[b.size()-1] == ' ' ) b=b.substr(0,b.size()-1);
    s = b;
}

void parse_library( const char *fname, ComponentMap& comps ) {
    ifstream fin(fname);
    if( !fin.good() ) {
        cout << "ERROR: problem with library file " << fname << '\n';
        cout << "provide a valid library file path via --lib command.\n";
        throw 2;
    }
    while( !fin.eof() ) {
        // find a line with module and ref definitions
        const string mod_tag("module");
        string line;
        getline( fin, line );
        strip_blanks( line );
        size_t pos  = line.find("module");
        size_t pos2 = line.find("// ref:");
        if( pos != string::npos && pos2 != string::npos && pos<pos2 ) {
            pos += 7;
            if( pos > line.size() ) continue;
            size_t aux = line.find_first_of(" )", pos );
            if( aux == string::npos ) continue;
            string module_name = line.substr(pos, aux-pos-1);
            pos2+=7;
            if( line[pos2]==' ' ) pos2++;
            string ref_name = line.substr(pos2);
            Component *p = new Component( ref_name, module_name );
            // add ports
            while(!fin.eof()) { // search for all ports
                getline( fin, line );
                strip_blanks( line );
                if( line.find(")")!=string::npos ) break; // end of module
                // is it a bus?
                int bus=-1;
                pos = line.substr(0, line.find("//")).find( "[" );
                if( pos != string::npos ) {
                    pos++;
                    pos2 = line.find(":",pos);
                    string bus_def = line.substr(pos, pos2-pos);
                    // cout << "bus def=" << bus_def << endl;
                    bus = atoi( bus_def.c_str() );
                    // cout << "Found bus of size " << bus << ":0\n";
                }
                pos = line.find( "// pin:" );
                if( pos!=string::npos ) { // found pin!
                    // find pin name
                    string name = line.substr(0,pos);
                    pos = name.find_last_of(",");
                    if( pos == string::npos ) {
                        pos = name.find_last_of(" ");
                        if( pos == string::npos ) {
                            cout << "Warning: // pin: statement found on an incomplete line.\n";
                            cout << line << '\n';
                            continue;   // this port will be ignored
                        }
                    }
                    name = name.substr(0,pos); // remove comma
                    pos2 = name.find_last_of(" ");
                    if( pos2 == string::npos ) {
                        cout << "Warning: // pin: statement found on an incomplete line.\n";
                        cout << line << '\n';
                        continue;
                    }
                    name = name.substr(pos2+1);
                    string pin_str = line.substr( line.find("// pin:")+7 );
                    pos=0;
                    do{
                        string pin_alpha;
                        size_t pin_next = pin_str.find(",",pos);                        
                        if(pin_next==string::npos) {
                            pin_next=0;
                            pin_alpha = pin_str;
                        } else {
                            pin_alpha = pin_str.substr(pos,pin_next-pos);
                        }
                        int pin = atoi( pin_alpha.c_str() );
                        if(bus>=0 ) {
                            // cout << "Bus proc: " << pin_str << '\n';
                            stringstream aux;
                            aux << bus;                            
                            string bus_name=name+"["+aux.str()+"]";
                            p->set_pin( pin, bus_name );
                            pin_str=pin_str.substr(pin_next);
                            if( pin_str.size() > 0 && pin_str[0]==',' ) pin_str=pin_str.substr(1);
                        }
                        else p->set_pin( pin, name );
                    }while( --bus>=0 );
                }
            }
            // cout << "Module " << p->get_name() << " with " << p->pin_count() << " pins.\n";
            comps.insert( pair<string, Component*>(ref_name,p) );
        }
    }
    // cout << comps.size() << " library modules added.\n";
}


void parse_netlist( const string& fname, ComponentMap& comps ) {
    ifstream fin(fname);
    if( !fin.good() ) return;
    while( !fin.eof() ) {
        // components
        const string comp_tag("(comp (ref ");
        string line;
        getline( fin, line );
        size_t pos = line.find(comp_tag);
        if( pos!=string::npos ) {
            pos+=comp_tag.size();
            size_t pos2=line.find(")",pos);
            string inst_name = line.substr(pos,pos2-pos);
            // search for module type
            pos = string::npos;
            while(!fin.eof() ) {
                const string value_tag("(value ");
                getline( fin, line );
                pos = line.find( value_tag );
                if( pos!=string::npos ) { pos+=value_tag.size(); break; }
            }
            if( pos == string::npos ) {
                cout << "Syntax error in netlist\n";
                throw 1;
            }
            pos2=line.find(")",pos);
            string type_name = line.substr(pos,pos2-pos);
            // cout << type_name << " " << inst_name << '\n';
            Component *newcomp = new Component( inst_name, type_name );
            comps.insert( pair<string,Component*>(inst_name, newcomp) );
        }
        if( line.find("(nets")!=string::npos ) break;
    }
    // nets
    while( !fin.eof() ) {
        const string net_tag("(net (code ");
        string line;
        getline( fin, line );
        size_t pos = line.find(net_tag);
        if( pos!=string::npos ) {
            const string netname_tag("(name ");
            pos = line.find( netname_tag )+netname_tag.size();
            if( line[pos]=='\"' ) pos++;
            size_t pos2 = line.find("\")",pos);
            if( pos2 == string::npos ) {
                pos2=line.find(")",pos );
            }
            string netname = line.substr(pos,pos2-pos);
            // adjust the name
            if( netname[0]=='/' ) netname=netname.substr(1);
            while( (pos=netname.find_first_of("-()")) != string::npos )
                netname[pos]='_';
            if( netname== "VCC" || netname=="VDD" ) netname = "1'b1";
            if( netname== "GND" || netname=="VSS" ) netname = "1'b0";
            // cout << netname << '\n';
            // find nodes
            while(!fin.eof() ) {
                const string noderef_tag("node (ref ");
                getline( fin, line );
                pos=line.find(noderef_tag)+noderef_tag.size();
                pos2=line.find(")",pos);
                string ref_name = line.substr(pos,pos2-pos);
                pos=line.find("(pin ")+5;
                pos2=line.find(")",pos);
                string pin_number = line.substr(pos,pos2-pos);
                // cout << "\t" << ref_name << " -> " << pin_number << '\n';
                comps[ref_name]->set_pin( atoi(pin_number.c_str()), netname );
                if( line.find(")))") != string::npos ) break; // end of net
            }
        }
    }
}




















