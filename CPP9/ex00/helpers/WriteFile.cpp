#include "WriteFile.hpp"
#include "print.hpp"

WriteFile::WriteFile() : std::ofstream(), _filename() {}

WriteFile::WriteFile(const std::string &filename)
	: std::ofstream(), _filename() {
	open(filename);
}

WriteFile::~WriteFile() {
	if (this->is_open())
		std::ofstream::close();
}

bool WriteFile::operator!() const {
	return !this->is_open() || this->fail() || this->bad();
}

void WriteFile::close() {
	std::ofstream::close();
}

void WriteFile::write(const std::string &content) {
	(*this) << content;
}

bool WriteFile::open(const std::string &filename) {
	_filename = filename;
	if (this->is_open())
		std::ofstream::close();
	std::ofstream::open(filename.c_str());
	return !(*this);
}

bool WriteFile::printErr() const {
	if (!(*this)) {
		::printErr("Error: could not create output file: ", _filename);
		return true;
	}
	return false;
}

const std::string &WriteFile::filename() const {
	return _filename;
}
