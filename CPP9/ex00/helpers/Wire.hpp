#ifndef WIRE_HPP
#define WIRE_HPP

#include <string>
#include "templategod.hpp"
#include "Vector.hpp"
using std::string;



class Wire : public string {
public:
    typedef Vector<Wire> WireVector;
    // Orthodox Canonical Form
    Wire();
    Wire(const Wire& str);
    Wire& operator=(const Wire& other);
    ~Wire();

    // Additional constructors
    Wire(const string& str);
    Wire(const char* str);
    Wire(std::istream& ifs);
    
    // replaceAll method
    Wire& replaceAll(const string& from, const string& to);
    Wire& fromStream(std::istream& ifs);
    Wire str_before(string delimiter) const;
    Wire str_until(char delimiter) const;
    Wire str_after(string delimiter) const;
    Float to_float() const;
    Int to_int() const;
    Wire substr(size_t pos, size_t len) const;
    bool contains(string delimiter) const;
    Wire::WireVector split_by( char delimiter);
    Wire& logError(string message);
    OK_CHECK(Wire)
};

#endif