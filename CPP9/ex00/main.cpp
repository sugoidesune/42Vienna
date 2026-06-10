#include "helpers/ReadFile.hpp"
#include "helpers/WriteFile.hpp"
#include "helpers/Wire.hpp"
#include "helpers/print.hpp"
#include "helpers/templategod.hpp"
#include "helpers/Curried.hpp"
#include "helpers/Map.hpp"
#include "helpers/Vector.hpp"


typedef Pair<Wire, float> DatePricePair;
typedef Map<Wire, float> MapWireFloat;
typedef Vector<DatePricePair> DatePriceVector;

void check_cpp_version() {
     // Standard compilers (GCC, Clang)
    #if __cplusplus == 201103L
        print(BRed("This project is compiling with C++11.").pady(2));
    #elif __cplusplus > 201103L
        print(BRed("This project is using a newer standard than C++11.").pady(2));
    #else
        print(BGreen("This project is using standard C++98/C++03.").pady(2));
    #endif
}

bool is_valid_date_format(const Wire& date_str) {
    if (date_str.length() != 10) return false;
    if (date_str[4] != '-' || date_str[7] != '-') return false;
    for (size_t i = 0; i < 10; ++i) {
        if (i == 4 || i == 7) continue;
        if (!isdigit(date_str[i])) return false;
    }
    Int month = date_str.substr(5, 2).to_int();
    Int day   = date_str.substr(8, 2).to_int();
    return !(
        !month         ||
        !day           ||
        month.val < 1  ||
        month.val > 12 ||
        day.val   < 1  ||
        day.val   > 31);
}

bool validate_exchange(const Wire& date_str, Float value) {
    if (!is_valid_date_format(date_str))return ( printErr(Red("Error: bad input. ").red(date_str)), false);
    if(!value) return (printErr(Red("Error: invalid number.")), false);
    if (value.val < 0) return (printErr(Red("Error: not a positive number.")), false);
    if (value.val > 1000) return ( printErr(Red("Error: too large a number.")), false);
    return true;
}

DatePricePair parse_exchange_line(const Wire& line) {
    Wire date_str = line.contains(" | ") ? line.str_before(" | ") : line;
    if (date_str == "date") return DatePricePair();
    Float v = line.str_after(" | ").to_float();
    if(!validate_exchange(date_str, v)) return DatePricePair();
    return DatePricePair(date_str, v.val);
}

DatePricePair parseBtcCsvLine(const Wire& line) {
    if (!line.contains(","))return DatePricePair();

    Wire date_str = line.str_before(",");
    Float price = line.str_after(",").to_float();

    if (!price || !date_str) return DatePricePair();
    return DatePricePair(date_str, price.val);
}

void calculateExchange(const MapWireFloat& db, const Wire& line) {
    if(!db) return;
    DatePricePair entry = parse_exchange_line(line);
    if(!entry) return; 

    MapWireFloat::const_iterator it = db.smaller_bound(entry.first);
    if(it){
        float value = entry.second;
        float result = value * it->second;
        print(entry.first, " => ", value, " = ", result);
    }
    else
        printErr(Red("Error: no exchange rate available for date => ").red(entry.first));
}



int main(int argc, char** argv) {
    check_cpp_version();
    if (argc < 2) return (printErr(Red("Error: need input file.")), 1);

    Map<Wire, float>  csv_map = ReadFile("data.csv")
        .logError()
        .readonce() 
        .logError("Error: could not read data.csv")
        .split_by('\n') 
        .toMap(parseBtcCsvLine) 
        .logError("Error: failed to parse data.csv");

    ReadFile(argv[1])
        .logError()
        .readonce()
        .logError("Error: Empty Input File.")
        .split_by('\n')
        .forEach(curry(calculateExchange, csv_map));

    return 0;
}








int main2(int argc, char** argv) {
    if (argc < 2) return (printErr(Red("Error: need input file.")), 1);

    ReadFile         csv_file("data.csv");
    Wire             csv_content = csv_file.readonce();
    Vector<Wire>     csv_lines = csv_content.split_by('\n');
    Map<Wire, float> csv_map = csv_lines.toMap(parseBtcCsvLine);
    class Curried<const MapWireFloat &, const Wire &, void> curreidf=     curry(calculateExchange, csv_map);
    ReadFile         input_file(argv[1]);
    Wire             input_content = input_file.readonce();
    Vector<Wire>     input_lines = input_content.split_by('\n');
                     input_lines.forEach(curry(calculateExchange, csv_map));

    return 0;
}



 

