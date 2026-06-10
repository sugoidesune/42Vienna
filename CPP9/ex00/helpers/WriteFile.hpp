#ifndef WRITEFILE_HPP
#define WRITEFILE_HPP

#include <fstream>
#include <string>

class WriteFile : public std::ofstream {
public:
	WriteFile();
	WriteFile(const std::string &filename);
	~WriteFile();

	bool operator!() const;

	void close();
	void write(const std::string &content);

	// ReadFile-style helpers
	bool open(const std::string &filename);
	bool printErr() const;
	const std::string &filename() const;

private:
	std::string _filename;

	// Non-copyable (std::ofstream is not copyable)
	WriteFile(const WriteFile &other);
	WriteFile &operator=(const WriteFile &other);
};

#endif
