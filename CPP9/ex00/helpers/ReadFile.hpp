#ifndef READFILE_HPP
#define READFILE_HPP

#include <fstream>
#include <string>
#include "Wire.hpp"
#include "templategod.hpp"

class ReadFile : public std::ifstream {
public:
	ReadFile();
	explicit ReadFile(const std::string &filename);
	~ReadFile();

	// Allow: if (!input) { ... }
	// Reflects stream error state and open state.
	bool operator!();
    bool error();
    bool printErr();
	ReadFile &logError();
    Wire read();
	Wire readonce();

	void close();
	OK_CHECK(ReadFile)
private:
    std::string _filename;

	// Non-copyable (std::ifstream is not copyable)
	ReadFile(const ReadFile &other);
	ReadFile &operator=(const ReadFile &other);
};

#endif
