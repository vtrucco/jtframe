#include <iostream>
#include <fstream>
#include <string>
#include <list>

#include "mamegame.hpp"


using namespace std;

void makeMRA( Game* g );

int main(int argc, char * argv[] ) {
    bool print=false;
    string fname="mame.xml";
    bool   fname_assigned=false;
    for( int k=1; k<argc; k++ ) {
        string a = argv[k];
        if( a == "-help" || a =="-h" ) {
            cout << "mame2dip: converts MAME dipswitch definition to MRA format\n"
                    "          by Jose Tejada. Part of JTFRAME\n"
                    "Usage:\n"
                    "          first argument:  path to file containing 'mame -listxml' output\n"
            ;
            return 0;
        }
        if( !fname_assigned ) {
            fname = argv[k];
            fname_assigned = true;
        } else {
            cout << "ERROR: Unknown argument " << argv[k] << "\n";
            return 1;
        }
    }
    GameMap games;
    parse_MAME_xml( games, fname.c_str() );
    for( auto& g : games ) {
        makeMRA(g.second);
    }
    return 0;
}

class Node {
    list<Node*> nodes;
public:
    string name, value;
    Node( string n, string v="" ) : name(n), value(v) { }
    Node& add( string n, string v="");
    void dump(ostream& os, string indent="" );
    virtual ~Node();
};

void makeMRA( Game* g ) {
    string indent;
    Node root("misterromdescription");
    root.add("name",g->name); // should be full_name. Not implemented yet
    root.add("setname",g->name);
    ListDIPs& dips=g->getDIPs();
    if( dips.size() ) {
        Node& n = root.add("switches");
        for( DIPsw* dip : dips ) {
            //root.comment( dip->tag );
            n.add("dip");
        }
    }
    string fout_name = g->name+".mra";
    ofstream fout(fout_name);
    if( !fout.good() ) {
        cout << "ERROR: cannot create " << fout_name << '\n';
        return;
    }
    root.dump(fout);
}

Node& Node::add( string n, string v ) {
    Node *nd = new Node(n, v);
    nodes.push_back(nd);
    return *nd;
}

void Node::dump(ostream& os, string indent ) {
    os << indent << "<" << name << ">";
    if( !nodes.size()) {
        string aux = value.size()>80 ? "\n" : "";
        os << aux;
        os << value << aux;
    } else {
        os << '\n';
        for( Node* n : nodes ) {
            n->dump(os, indent+"    ");
        }
        os << indent;
    }
    os << "</" << name << ">\n";
}

Node::~Node() {
    for( Node* n: nodes ) delete n;
}
