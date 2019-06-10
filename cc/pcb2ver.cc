#include <string>
#include <map>
#include <iostream>
#include <fstream>
#include <cstdlib>

using namespace std;
typedef map<int,string> Pins;

class Component{
        Pins pins;
        string instance, type;
    public:
        Component( string _inst, string _type ) : instance(_inst), type(_type) {}
        void set_pin(int k, const string& val);
        void dump();
};

void Component::set_pin(int k, const string& val ) {
    pins[k]=val;
}

void Component::dump() {
    cout << type << " " << instance << "(\n";
    for( auto k : pins ) {
        cout << "." << k.first << "( " << k.second << " );\n";
    }
    cout << ");\n";
};

typedef map<string,Component*> ComponentMap;

void parse_netlist( const char *fname, ComponentMap& comps );

int main(int argc, char *argv[]) {
    ComponentMap comps;
    try {
        parse_netlist( "popeye_model.net", comps );
    }
    catch(int code ) {
        cout << "ERROR " << code << "\n";
    }
    cout << "============================\n";
    // delete the map
    while( comps.size() ) {
        comps.begin()->second->dump();
        delete comps.begin()->second;
        comps.erase( comps.begin() );
    }
}

void parse_netlist( const char *fname, ComponentMap& comps ) {
    ifstream fin(fname);
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
            cout << type_name << " " << inst_name << '\n';
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
            cout << netname << '\n';
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
                cout << "\t" << ref_name << " -> " << pin_number << '\n';
                comps[ref_name]->set_pin( atoi(pin_number.c_str()), netname );
                if( line.find(")))") != string::npos ) break; // end of net
            }
        }
    }
}




















