#ifndef CURRIED_HPP
#define CURRIED_HPP

// The Functor class that stores the function pointer and the first argument
template<typename Arg1, typename Arg2, typename Result>
class Curried {
private:
    Result (*_func)(Arg1, Arg2);
    Arg1 _bound_arg; // Can hold by value or reference depending on what's passed

public:
    // --- Orthodox Canonical Form ---
    Curried() : _func(NULL), _bound_arg(Arg1()) {}
    Curried(const Curried& other) : _func(other._func), _bound_arg(other._bound_arg) {}
    Curried& operator=(const Curried& other) {
        if (this != &other) {
            _func = other._func;
            _bound_arg = other._bound_arg;
        }
        return *this;
    }
    ~Curried() {}

    // Constructor caches the function pointer and first argument
    Curried(Result (*func)(Arg1, Arg2), Arg1 bound_arg)
        : _func(func), _bound_arg(bound_arg) {}

    // The overloaded operator makes this object callable with just the second argument
    Result operator()(Arg2 arg2) const {
        return _func(_bound_arg, arg2);
    }
};

template <typename T>
struct type_identity {
    typedef T type;
};

// Helper function to allow automatic template type deduction
template<typename Arg1, typename Arg2, typename Result>
Curried<Arg1, Arg2, Result> curry(Result (*func)(Arg1, Arg2), typename type_identity<Arg1>::type bound_arg) {
    return Curried<Arg1, Arg2, Result>(func, bound_arg);
}

template <typename F>
struct function_traits;

template <typename R, typename A1, typename A2>
struct function_traits<R (*)(A1, A2)> {
    typedef Curried<A1, A2, R> curried_type;
    typedef R return_type;
    typedef A1 arg1_type;
    typedef A2 arg2_type;
};

#define CURRIED_FN(func) function_traits<__typeof__(&func)>::curried_type

#endif
