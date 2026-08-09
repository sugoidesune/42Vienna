#include "helpers/print.hpp"
#include "helpers/Style.hpp"



$ $1 = $().green();
$ $2 = $().red();

int main (void){

    print($("Hello ", 42).red().padx(5), $("Wooorld").green().padx(5).padt(1).padb(3));
    print($().padx(3)(  $1("HELLO")   )(   $2("WORLD")   ));
    print($("BOBB").center(30), "HAHA");
    $().textc(0, 0, 0).bgc(80, 0, 0)("HELLO WORLD").print();
}