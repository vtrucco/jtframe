#include "mamegame.hpp"
#include <xercesc/sax2/XMLReaderFactory.hpp>

#include <iostream>
#include <iomanip>
#include <sstream>
#include <map>
#include <list>
// Other include files, declarations, and non-Xerces-C++ initializations.

using namespace xercesc;
using namespace std;

#define TOSTR(a,b) string a( (const char*)StdStr(b) )
#define GET_STR_ATTR( a ) string a( (const char*)StdStr( attrs.getValue(XMLStr(#a)) ) );

void MameParser::startElement( const XMLCh *const uri,
        const XMLCh *const localname, const XMLCh *const qname, const Attributes & attrs ) 
{
    TOSTR( _localname, localname );
    if( _localname == "machine" ) {
        GET_STR_ATTR( name );
        current = new Game(name);
        games[name] = current;
    }
    if( _localname == "dipswitch" ) {
        GET_STR_ATTR( name );
        GET_STR_ATTR( tag  );
        GET_STR_ATTR( mask );
        current_dip = new DIPsw( name, tag, toint(mask));
        current->addDIP( current_dip );
    }
    if( _localname == "dipvalue" ) {
        GET_STR_ATTR( name );
        GET_STR_ATTR( value );
        current_dip->values.push_back( { name, toint(value)} );
    }
}

void MameParser::endElement( const XMLCh *const uri,
        const XMLCh *const localname, const XMLCh *const qname ) {
    TOSTR( _localname, localname );
    if( _localname == "dipswitch" ) {
        current_dip->values.sort();
        current_dip = nullptr;
    }
}

void Game::addDIP( DIPsw* d ) {
    dips.push_back(d);   
}

void Game::dump() {
    cout << name << '\n';
    for( auto k : dips ) {
        cout << '\t' << k->name << '\t' << k->tag << '\t' << hex << k->mask << '\n';
    }
}

Game::~Game() {
    for( auto k : dips ) {
        delete k;
    }
}

int toint(string s) {
    stringstream ss(s);
    int x;
    ss >> x;
    return x;
}

GameMap::~GameMap() {
    for( auto& g : *this ) {
        delete g.second;
        g.second=nullptr;
    }
    clear();
}

int parse_MAME_xml( GameMap& games, const char *xmlFile ) {
    try {
        XMLPlatformUtils::Initialize();
    }
    catch (const XMLException& toCatch) {
        // Do your failure processing here
        return 1;
    }

    SAX2XMLReader* parser = XMLReaderFactory::createXMLReader();

    MameParser mame(games);
    parser->setErrorHandler(&mame);
    parser->setContentHandler( (ContentHandler*) &mame);

    try {
        parser->parse(xmlFile);
    }
    catch (const XMLException& toCatch) {
        char* message = XMLString::transcode(toCatch.getMessage());
        cout << "Exception message is: \n"
             << message << "\n";
        XMLString::release(&message);
        return -1;
    }
    catch (const SAXParseException& toCatch) {
        char* message = XMLString::transcode(toCatch.getMessage());
        cout << "Exception message is: \n"
             << message << "\n";
        XMLString::release(&message);
        return -1;
    }
    catch (...) {
        cout << "Unexpected Exception \n" ;
        return -1;
    }

    delete parser;
    XMLPlatformUtils::Terminate();
    return 0;
}