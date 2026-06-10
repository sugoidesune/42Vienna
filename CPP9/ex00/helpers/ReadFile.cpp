#include "ReadFile.hpp"
#include "print.hpp"

ReadFile::ReadFile() : std::ifstream() {}

ReadFile::ReadFile(const std::string &filename)
	: std::ifstream(filename.c_str()) , _filename(filename) {}

ReadFile::~ReadFile() {
	if (this->is_open())
		std::ifstream::close();
}

bool ReadFile::operator!(){
	return this->error();
}

bool ReadFile::error() {
    _ok = !(!this->is_open() || this->fail() || this->bad());
    return !_ok;
}

bool ReadFile::printErr() {
    if(this->error())
        ::printErr("Error: could not open input file: ", _filename);
    return this->error();
}

ReadFile &ReadFile::logError() {
    this->printErr();
    return *this;
}

Wire ReadFile::read() {
    if(!this->error())
        return Wire(*this);
    return Wire();
}

Wire ReadFile::readonce() {
    Wire content = this->read();
    this->close();
    return content;
}

void ReadFile::close() {
	std::ifstream::close();
}
