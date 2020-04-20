#include <iostream>
#include <fstream>
#include <sstream>
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

struct Attr {
    string name, value;
};

class Node {
    list<Node*> nodes;
    list<Attr*> attrs;
    bool is_comment;
public:
    string name, value;
    Node( string n, string v="" ) : name(n), value(v), is_comment(false) { }
    Node& add( string n, string v="");
    void add_attr( string n, string v="");
    void dump(ostream& os, string indent="" );
    void comment( string v );
    virtual ~Node();
};

void makeMRA( Game* g ) {
    string indent;
    Node root("misterromdescription");
    root.add("name",g->name); // should be full_name. Not implemented yet
    root.add("setname",g->name);
    ListDIPs& dips=g->getDIPs();
    int base=0;
    bool ommit_parenthesis=true;
    string last_tag;
    if( dips.size() ) {
        Node& n = root.add("switches");
        for( DIPsw* dip : dips ) {
            if( dip->tag != last_tag ) {
                n.comment( dip->tag );
                if( last_tag.size() ) base+=8;
                last_tag = dip->tag;
            }
            Node &dipnode = n.add("dip");
            dipnode.add_attr("name",dip->name);
            // Bits
            int bit0 = base;
            int bit1 = base;
            int m    = dip->mask;
            int k;
            for( k=0; k<8; k++ ) {
                if( (m&1) == 0 ) {
                    m>>=1;
                    bit0++;
                }
                else
                    break;
            }
            for( bit1=bit0; k<8;k++ ) {
                if( (m&1) == 1 ) {
                    m>>=1;
                    bit1++;
                }
                else
                    break;
            }
            --bit1;
            stringstream bits;
            if( bit1==bit0 )
                bits << dec << bit0;
            else
                bits << dec << bit0 << "," << bit1;
            dipnode.add_attr("bits",bits.str());
            // Add DIP configuration values
            stringstream ids;
            for( DIPvalue& dval : dip->values ) {
                string aux = dval.name;
                if( ommit_parenthesis ) {
                    while(1) {
                        int x = aux.find_first_of('(');
                        if( x!=string::npos) {
                            int y = aux.find_first_of(')');
                            if( y!=string::npos) {
                                aux = aux.substr(0,x)+aux.substr(y+1);
                            } else break;
                        } else break;
                    }
                }
                if( aux[aux.length()-1]==' ' ) {
                    aux.erase( aux.end()-1 );
                }
                ids << aux << ',';
            }
            string ids_str = ids.str();
            ids_str.erase( ids_str.length()-1, 1 ); // delete final comma
            dipnode.add_attr("ids",ids_str);
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

void Node::add_attr( string n, string v) {
    Attr* a = new Attr({n,v});
    attrs.push_back(a);
}

void Node::comment( string v ) {
    Node *nd = new Node(v);
    nodes.push_back(nd);    
    nd->is_comment = true;
}

void Node::dump(ostream& os, string indent ) {
    if( is_comment ) {
        os << indent << "<!-- " << name << " -->\n";
    }
    else {
        os << indent << "<" << name;
        if( attrs.size() ) {
            for( Attr* a : attrs ) {
                os << " " << a->name << "=\"" << a->value << '\"';
            }
        }
        os << ">";
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
}

Node::~Node() {
    for( Node* n: nodes ) delete n;
    for( Attr* a: attrs ) delete a;
}
