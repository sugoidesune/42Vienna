#include "Wire.hpp"
#include <iostream>
#include <fstream>
#include <cstdlib>
#include <climits>



Wire::Wire() : string(), _ok(false) {}

Wire::Wire(const string& str) : string(str), _ok(true) {}
Wire::Wire(const Wire& str) : string(str), _ok(str._ok) {}
Wire& Wire::operator=(const Wire& other) {
    if (this != &other) {
        string::operator=(other);
        _ok = other._ok;
    }
    return *this;
}
Wire::~Wire() {}

Wire::Wire(const char* str) : string(str), _ok(true) {}

Wire::Wire(std::istream& ifs) : string(), _ok(true) {
    this->fromStream(ifs);
}

Wire& Wire::replaceAll(const string& from, const string& to) {
    if (from.empty()) return *this; 
    
    size_t pos = 0;
    while ((pos = find(from, pos)) != string::npos) {
        erase(pos, from.length());
        insert(pos, to);
        pos += to.length();
    }
    return *this;
}

Wire& Wire::fromStream(std::istream& ifs) {
    if(ifs.good()) {
        std::istreambuf_iterator<char> startInput(ifs); // begin reading from 'ifs'
        std::istreambuf_iterator<char> endInput;     // end iterator
        assign(startInput, endInput);
    }
    return *this;
}

Wire Wire::str_before(string delimiter) const {
    Wire str = *this;
    size_t pos = find(delimiter);
    if (pos != string::npos)
        return Wire(str.substr(0, pos));
    return Wire();
}
Wire Wire::substr(size_t pos, size_t len = string::npos) const {
    return Wire(string::substr(pos, len));
}

Int Wire::to_int() const {
    Wire s = *this;
    if (s.empty()) {
        return Int();
    }
    char* endptr = NULL;
    errno = 0;
    long val = std::strtol(s.c_str(), &endptr, 10);
    if (errno == ERANGE || *endptr != '\0' || val < INT_MIN || val > INT_MAX) {
        return Int();
    }
    return Int(static_cast<int>(val));
}

Float Wire::to_float() const {
    Wire s = *this;
    if (s.empty()) {
        return Float();
    }
    char* endptr = NULL;
    errno = 0;
    float val = static_cast<float>(std::strtod(s.c_str(), &endptr));
    if (*endptr != '\0') {
        return Float();
    }
    return Float(val);
}

Wire Wire::str_after(string delimiter) const {
    Wire str = *this;
    size_t pos = find(delimiter);
    size_t len = delimiter.length();
    if (pos != string::npos)
        return Wire(str.substr(pos + len));
    return Wire();
}
bool Wire::contains(string delimiter) const {
    return find(delimiter) != string::npos;
}

Wire& Wire::logError(string message = "") {
    if(this->empty() || !this->_ok) {
        if(message.empty())
            std::cerr << "String is empty." << std::endl;
        else
            std::cerr << message << std::endl;
    }
    return *this;
}

Wire::WireVector Wire::split_by( char delimiter) {
    Wire str = *this;
    if(!str || str.empty()) return Wire::WireVector();
    size_t start = 0;
    size_t end = str.find(delimiter);
    Wire::WireVector result;
    while (end != Wire::npos) {
        result.push_back(str.substr(start, end - start));
        start = end + 1;
        end = str.find(delimiter, start);
    }
    result.push_back(str.substr(start));
    return result.ok();
}