#ifndef _MAMEGAME_HPP

#include <xercesc/sax/HandlerBase.hpp>
#include <xercesc/sax2/DefaultHandler.hpp>
#include <xercesc/sax2/Attributes.hpp>
#include <xercesc/util/XMLString.hpp>

#include <map>
#include <list>
#include <string>

using namespace xercesc;


int toint(std::string s);

class DIPvalue{
public:
    std::string name;
    int val;
    bool operator<(const DIPvalue& x) const { return val < x.val; }
};

typedef std::list<DIPvalue> ListDIPValues;
typedef std::list<class DIPsw*>   ListDIPs;

class DIPsw {
public:
    ListDIPValues values;
    std::string name, tag;
    int mask;
    DIPsw( std::string n, std::string t, int m ) :
        name(n), tag(t), mask(m) { }
};

class Game {
    std::list<DIPsw*> dips;
public:
    std::string name, full_name;
    Game( std::string _name ) : name(_name) {}
    ~Game();

    void addDIP( DIPsw* d );
    void dump();
    ListDIPs& getDIPs() { return dips; }
};

class GameMap : public std::map<std::string,Game*> {
public:
    GameMap() {}
    ~GameMap();
};

int parse_MAME_xml( GameMap& games, const char *xmlFile );

class MameParser : public DefaultHandler {
    Game *current;
    DIPsw* current_dip;
    GameMap& games;
public:
    MameParser(GameMap& _games) : games(_games) {
        current = nullptr;
    }
    // void startDocument();
    // void endDocument();
    void startElement   ( const XMLCh *const uri,
        const XMLCh *const localname,
        const XMLCh *const qname,
        const Attributes & attrs 
    );
    void endElement( const XMLCh *const uri,
        const XMLCh *const localname, const XMLCh *const qname );
};


class XMLStr {
    XMLCh* v;
public:
    XMLStr( const char *s ) {
        v = XMLString::transcode(s);
    }
    ~XMLStr() { XMLString::release(&v); }
    operator const XMLCh*() const{ return v; }
};

class StdStr {
    char * v;
public:
    StdStr( const XMLCh *s ) {
        v = XMLString::transcode(s);
    }
    ~StdStr() { XMLString::release(&v); }
    operator const char*() const{ return v; }
};



#endif