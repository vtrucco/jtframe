#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <list>
#include <set>

#include "mamegame.hpp"


using namespace std;

void makeMRA( Game* g, string& rbf, string& dipbase );

set<string> swapregions;
set<string> fillregions;
set<string> ignoreregions;
map<string,int> startregions;
map<string,int> fracregions;

int main(int argc, char * argv[] ) {
    bool print=false;
    string fname="mame.xml";
    string rbf, dipbase("16");
    bool   fname_assigned=false;

    for( int k=1; k<argc; k++ ) {
        string a = argv[k];
        if( a=="-swapbytes" ) {
            swapregions.insert(string(argv[++k]));
            continue;
        }
        if( a=="-fill" ) {
            fillregions.insert(string(argv[++k]));
            continue;
        }
        if( a=="-start" ) {
            string reg(argv[++k]);
            int offset=strtol( argv[++k], NULL, 0 );
            startregions[reg]=offset;
            continue;
        }
        if( a=="-dipbase" ) {
            dipbase=argv[++k];
            continue;
        }
        if( a=="-ignore" ) {
            ignoreregions.insert(string(argv[++k]));
            continue;
        }
        if( a=="-frac" ) {
            string reg(argv[++k]);
            int frac=strtol( argv[++k], NULL, 0 );
            fracregions[reg]=frac;
            continue;
        }
        if( a=="-rbf" ) {
            rbf =argv[++k];
            continue;
        }
        if( a == "-help" || a =="-h" ) {
            cout << "mame2dip: converts MAME dipswitch definition to MRA format\n"
                    "          by Jose Tejada. Part of JTFRAME\n"
                    "Usage:\n"
                    "          first argument:  path to file containing 'mame -listxml' output\n"
                    "    -swapbytes <region> swap bytes for named region\n"
                    "    -fill    <region>   fill gaps between files within region\n"
                    "    -ignore  <region>   ignore a given region\n"
                    "    -start   <region>   set start of region in MRA file\n"
                    "    -rbf     <name>     set RBF file name\n"
                    "    -dipbase <number>   First bit to use as DIP setting in MiST status word\n"
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
        cout << g.second->name << '\n';
        makeMRA(g.second, rbf, dipbase);
    }
    return 0;
}

void replace( string&aux, const char *find_text, const char* new_text ) {
    int pos;
    int n = strlen(find_text);
    while( (pos=aux.find(find_text))!=string::npos ) {
        aux.replace(pos,n,new_text);
    }
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

void makeROM( Node& root, Game* g ) {
    Node& n = root.add("rom");
    n.add_attr("index","0");
    string zips = g->name+".zip";
    if( g->cloneof.size() ) {
        zips = zips + "|" + g->cloneof+".zip";
    }
    n.add_attr("zip",zips);
    n.add_attr("type","merged");
    n.add_attr("md5","None"); // important or MiSTer will not let the game boot
    int dumped=0;
    g->moveRegionBack("proms"); // This region should appear last
    for( ROMRegion* region : g->getRegionList() ) {
        if ( ignoreregions.count(region->name)>0 ) continue;
        auto start_offset = startregions.find(region->name);
        if( start_offset != startregions.end() ) {
            int s = start_offset->second;
            int rep = s-dumped;
            if( rep<0 ) {
                cout << "WARNING: required start value is too low for "
                " region " << region->name << '\n';
            } else if( rep>0 ) {
                Node& fill = n.add("part","FF");
                char buf[32];
                snprintf(buf,32,"0x%X",rep);
                fill.add_attr("repeat",buf);
                dumped=s;
            }
        }
        char title[128];
        snprintf(title,128,"%s - starts at 0x%X", region->name.c_str(), dumped );
        n.comment( title );
        bool swap = swapregions.count(region->name)>0;
        bool fill = fillregions.count(region->name)>0;     
        // is it a fractioned region?
        auto frac_idx = fracregions.find(region->name);
        int frac=0;
        if( frac_idx!= fracregions.end() ) {
            frac = frac_idx->second;
        }
        string frac_output="0";
        switch( frac ) {
            case 2: frac_output="16"; break;
            case 4: frac_output="32"; break;
            case 0: break;
            default: cout << "WARNING: unsupported frac value for region " 
                          << region->name << "\n"; 
                     continue;
        }
        if( frac==0 ) {
            int offset=0;
            for( ROM* r : region->roms ) {
                // Fill in gaps between ROM chips
                if( offset != r->offset && fill) {
                    Node& part = n.add("part","FF");
                    int rep = r->offset - offset;
                    char buf[32];
                    snprintf(buf,32,"0x%X",rep);
                    part.add_attr("repeat",buf);
                    dumped += rep;
                }
                Node& parent = swap ? n.add("interleave") : n;
                if( swap ) {
                    parent.add_attr("output","16");
                }
                Node& part = parent.add("part");
                part.add_attr("name",r->name);
                part.add_attr("crc",r->crc);
                if( swap ) {
                    part.add_attr("map","12");
                }
                offset = r->offset + r->size;
                dumped += r->size;
            }
        } else {
            // Fractioned ROMs
            // First check that the count is correct
            if( region->roms.size()%frac != 0 ) {
                cout << "WARNING: Total number of ROM entries does not much fraction value"
                    " for region " << region->name << "\n";
                continue;
            }
            const int roms_size = region->roms.size();
            ROM** roms = new ROM*[roms_size];
            int aux=0;
            int step=roms_size/frac;
            for( ROM* r : region->roms ) roms[aux++] = r;
            // Dump ROMs
            for( aux=0; aux<roms_size/frac; aux++ ) {
                Node& inter=n.add("interleave");
                inter.add_attr("output",frac_output);
                for( int chunk=0; chunk<frac; chunk++) {
                    ROM*r = roms[aux+chunk*step];
                    Node& part = inter.add("part");
                    part.add_attr("name",r->name);
                    part.add_attr("crc",r->crc);
                    char *mapping = new char[frac+1];
                    for( int k=0; k<frac; k++ ) mapping[k]='0';
                    mapping[frac]=0;
                    mapping[frac-1-chunk]='1';
                    part.add_attr("map",mapping);
                    delete[] mapping;
                    dumped += r->size;
                }
            }
            delete[] roms;
        }
    }
    char endsize[128];
    snprintf(endsize,128,"Total 0x%X bytes - %d kBytes",dumped,dumped>>10);
    n.comment(endsize);
}

void makeDIP( Node& root, Game* g, string& dipbase ) {
    ListDIPs& dips=g->getDIPs();
    int base=-8;
    bool ommit_parenthesis=true;
    string last_tag, last_location;
    if( dips.size() ) {
        Node& n = root.add("switches");
        n.add_attr("default","FF,FF");
        n.add_attr("base",dipbase);
        for( DIPsw* dip : dips ) {
            if( dip->tag != last_tag /*|| dip->location != last_location*/ ) {
                n.comment( dip->tag );
                //if( last_tag.size() ) 
                base+=8;
                last_tag = dip->tag;
                last_location = dip->location;
                // cout << "base = " << base << "\ntag " << dip->tag << "\nlocation " << dip->location << '\n';
            }
            Node &dipnode = n.add("dip");
            dipnode.add_attr("name",dip->name);
            // Bits
            int bit0 = base;
            int bit1 = base;
            int m    = dip->mask;
            int k;
            for( k=0; k<32; k++ ) {
                if( (m&1) == 0 ) {
                    m>>=1;
                    bit0++;
                }
                else
                    break;
            }
            for( bit1=bit0; k<32;k++ ) {
                if( (m&1) == 1 ) {
                    m>>=1;
                    bit1++;
                }
                else
                    break;
            }
            --bit1;
            //if( bit0 > base ) bit0-=base;
            //if( bit1 > base ) bit1-=base;
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
                replace( aux, "0000", "0k");
                replace( aux, " Coins", "");
                replace( aux, " Coin", "");
                replace( aux, " Credits", "");
                replace( aux, " Credit", "");
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
}

void makeJOY( Node& root, Game* g ) {
    Node& n = root.add("buttons");
    n.add_attr("names","Fire,Jump,Start,Coin,Pause");
    n.add_attr("default","A,B,R,L,Start");
}

void makeMOD( Node& root, Game* g ) {
    int mod_value = 0;
    if( g->rotate!=0 ) {
        root.comment("Vertical game");
        mod_value |= 1;
    }
    char buf[4];
    snprintf(buf,4,"%02X",mod_value);
    Node& mod=root.add("rom",buf);
    mod.add_attr("index","1");
}

void makeMRA( Game* g, string& rbf, string& dipbase ) {
    string indent;
    Node root("misterromdescription");

    Node& about = root.add("about","");
    about.add_attr("author","jotego");
    about.add_attr("webpage","https://patreon.com/topapate");
    about.add_attr("source","https://github.com/jotego");
    about.add_attr("twitter","@topapate");

    root.add("name",g->description);
    root.add("setname",g->name);
    if( rbf.length()>0 ) {
        root.add("rbf",rbf);
    }

    makeROM( root, g );
    makeMOD( root, g );
    makeDIP( root, g, dipbase );
    makeJOY( root, g );

    string fout_name = g->description+".mra";
    ofstream fout(fout_name);
    if( !fout.good() ) {
        cout << "ERROR: cannot create " << fout_name << '\n';
        return;
    }
    fout <<
"<!--          FPGA compatible core of arcade hardware by Jotego\n"
"\n"
"              This core is available for hardware compatible with MiST and MiSTer\n"
"              Other FPGA systems may be supported by the time you read this.\n"
"              This work is not mantained by the MiSTer project. Please contact the\n"
"              core author for issues and updates.\n"
"\n"
"              (c) Jose Tejada, 2020. Please support the author\n"
"              Patreon: https://patreon.com/topapate\n"
"              Paypal:  https://paypal.me/topapate\n"
"\n"
"              The author does not endorse or participate in illegal distribution\n"
"              of copyrighted material. This work can be used with legally\n"
"              obtained ROM dumps or with compatible homebrew software\n"
"\n"
"              This file license is GNU GPLv2.\n"
"              You can read the whole license file in\n"
"              https://opensource.org/licenses/gpl-2.0.php\n"
"\n"
"-->\n\n";
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
        if( nodes.size() || value.size() ) {
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
        } else {
            os << "/>\n";
        }
    }
}

Node::~Node() {
    for( Node* n: nodes ) delete n;
    for( Attr* a: attrs ) delete a;
}
