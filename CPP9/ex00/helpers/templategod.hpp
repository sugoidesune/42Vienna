#ifndef TEMPLATEGOD_HPP
#define TEMPLATEGOD_HPP

#include "Wire.hpp"
#include "Curried.hpp"
#include <vector>

template <typename FN>
struct fn_return_type;

template <typename R, typename Arg>
struct fn_return_type<R (*)(Arg)> {
    typedef R type;
};

#define OK_CHECK(CLASSNAME) \
    bool _ok;\
    operator bool() const { return _ok; }; \
    CLASSNAME& ok() { _ok = true; return *this; }; \
    CLASSNAME& notok() { _ok = false; return *this; };

template <typename A, typename B>
struct Pair {
    typedef A first_type;
    typedef B second_type;
    A first;
    B second;
    Pair() : first(), second(), _ok(false) {}
    Pair(const Pair& other) : first(other.first), second(other.second), _ok(other._ok) {}
    Pair& operator=(const Pair& other) {
        if (this != &other) {
            first = other.first;
            second = other.second;
            _ok = other._ok;
        }
        return *this;
    }
    ~Pair() {}
    Pair(const A& f, const B& s) : first(f), second(s), _ok(true) {}
    OK_CHECK(Pair)
    operator std::pair<const A, B>() const {
        return std::pair<const A, B>(first, second);
    }
};

template <typename content_type>
struct Val {
    content_type val;
    Val() : val(), _ok(false) {}
    Val(const Val& other) : val(other.val), _ok(other._ok) {}
    Val& operator=(const Val& other) {
        if (this != &other) {
            val = other.val;
            _ok = other._ok;
        }
        return *this;
    }
    ~Val() {}
    explicit Val(const content_type& v) : val(v), _ok(true) {}
    OK_CHECK(Val)
};


typedef Val<int> Int ;
typedef Val<float> Float ;

// template <typename CONTAINER, typename FN>
// std::map<typename fn_return_type<FN>::type::first_type, typename fn_return_type<FN>::type::second_type>
// container_to_map(const CONTAINER& container, FN fn) {
//     typedef typename fn_return_type<FN>::type PairLikeType;
//     Map<typename PairLikeType::first_type, typename PairLikeType::second_type> result;
//     if(container.size() == 0) return result;
//     for (size_t i = 0; i < container.size(); ++i) {
//         PairLikeType p = fn(container[i]);
//         if(p)
//             result.insert(std::make_pair(p.first, p.second));
//     }
//     return result;
// };

#endif