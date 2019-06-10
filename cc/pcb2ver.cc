#include <string>
#include <map>
#include <iostream>
#include <fstream>
#include <cstdlib>
#include <iomanip>

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
    cout << c.type << " " << c.instance << "(\n";
    int count = c.pin_count();
    for( auto k : c.pins ) {
        cout << "    ." << setiosflags(ios_base::left) << setw(10) << c.get_alt_name(k.first)
             << "( " << setw(24) << k.second << " )";
        if( --count ) cout << ',';
        cout << '\n';
    }
    cout << ");\n\n";
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

void match_parts( ComponentMap& comps, ComponentMap& mods );

int main(int argc, char *argv[]) {
    string fname;
    if( argc>1 ) {
        fname = argv[1];
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
        parse_library("../hdl/jt74.v", mods);
        match_parts( comps, mods );
    }
    catch(int code ) {
        cout << "ERROR " << code << "\n";
    }
    for( auto& k : comps ) {
        dump(*k.second);
    }
    cout << "============================\n";
    // delete the maps
    delete_map( comps );
    delete_map( mods  );
}

void match_parts( ComponentMap& comps, ComponentMap& mods ) {
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
        k.second->set_ref(ref);
    }
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
        cout << "ERROR: problem with library file\n";
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
            Component *p = new Component( ref_name, ref_name );
            // add ports
            while(!fin.eof()) {
                getline( fin, line );
                strip_blanks( line );
                if( line.find(")")!=string::npos ) break; // end of module
                pos = line.find( "// pin:" );
                if( pos!=string::npos ) { // found pin!
                    int pin = atoi( line.substr(pos+7).c_str() );
                    string name = line.substr(0,pos);
                    pos = name.find_last_of(",");
                    if( pos == string::npos ) {
                        pos = name.find_last_of(" ");
                        if( pos == string::npos ) {
                            cout << "Warning: // pin: statement found on an incomplete line.\n";
                            cout << line << '\n';
                            continue;
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
                    p->set_pin( pin, name );
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




















