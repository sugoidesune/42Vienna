#ifndef VECTOR_HPP
#define VECTOR_HPP

#include "Iterator.hpp"
#include "templategod.hpp"
#include "Map.hpp"
#include <string>

template <typename T>
class Vector : public std::vector<T> {
private:
    typedef std::vector<T>                         _vec;
    typedef typename _vec::iterator                _RawIter;
    typedef typename _vec::const_iterator          _RawCIter;
    typedef typename _vec::reverse_iterator        _RawRIter;
    typedef typename _vec::const_reverse_iterator  _RawCRIter;

public:
    typedef Iterator<_RawIter>          iterator;
    typedef Iterator<_RawCIter>         const_iterator;
    typedef Iterator<_RawRIter>         reverse_iterator;
    typedef Iterator<_RawCRIter>        const_reverse_iterator;

    OK_CHECK(Vector)

    // --- Orthodox Canonical Form (Rule of Three - C++98) ---
    Vector() { _ok = false; }
    ~Vector() {}

    // Copy from other Vector
    Vector(const Vector& other) : _vec(other), _ok(other._ok) {}
    Vector& operator=(const Vector& other) { _vec::operator=(other), _ok = other._ok; return *this; }

    // Converting from std::vector (copy only)
    Vector(const _vec& other) : _vec(other), _ok(true) {}
    Vector& operator=(const _vec& other) { _vec::operator=(other), _ok = true; return *this; }

    // --- Vector from container + function ---
    // Usage: Vector<Val> v(container, fn)  where fn(element) returns something with operator bool
    template <typename CONTAINER, typename FN>
    Vector(const CONTAINER& container, FN fn) {
        typedef typename fn_return_type<FN>::type result_type;
        _ok = true;
        if (container.size() == 0) { _ok = false; return; }
        for (size_t i = 0; i < container.size(); ++i) {
            result_type content = fn(container[i]);
            if (content) {
                add(content);
            }
        }
    }

    // --- Iterators (wrapping raw → Iterator) ---
    iterator begin()               { return iterator(_vec::begin()); }
    iterator end()                 { return iterator(_vec::end()).notok(); }
    const_iterator begin() const   { return const_iterator(_vec::begin()); }
    const_iterator end() const     { return const_iterator(_vec::end()).notok(); }
    reverse_iterator rbegin()      { return reverse_iterator(_vec::rbegin()); }
    reverse_iterator rend()        { return reverse_iterator(_vec::rend()).notok(); }
    const_reverse_iterator rbegin() const { return const_reverse_iterator(_vec::rbegin()); }
    const_reverse_iterator rend() const   { return const_reverse_iterator(_vec::rend()).notok(); }

    // --- add: push a value onto the vector ---
    void add(const T& value) {
        _vec::push_back(value);
    }

    // --- add: push a value that has operator bool (e.g. Val, Pair) ---
    template <typename U>
    void add(const U& value) {
        if (value)
            _vec::push_back(value);
    }

    // --- operator(): chainable add ---
    Vector& operator()(const T& value) {
        add(value);
        return *this;
    }

    // --- map: transform each element via fn, produce new Vector ---
    // Usage: Vector<NewType> result = vec.map(myFunction);
    template <typename FN>
    Vector<typename fn_return_type<FN>::type> map(FN fn) const {
        Vector<typename fn_return_type<FN>::type> result;
        for (size_t i = 0; i < this->size(); ++i) {
            typename fn_return_type<FN>::type content = fn((*this)[i]);
            if (content) {
                result.add(content);
            }
        }
        return result.ok();
    }

    template <typename FN>
    Map<typename fn_return_type<FN>::type::first_type, typename fn_return_type<FN>::type::second_type>
    toMap(FN fn) const {
        return Map<typename fn_return_type<FN>::type::first_type, typename fn_return_type<FN>::type::second_type>(*this, fn);
    }

    template <typename FN>
    Vector &forEach(FN fn) {
        for (size_t i = 0; i < this->size(); ++i) {
            fn((*this)[i]);
        }
        return *this;
    }

    // --- logError: print diagnostic if empty or invalid ---
    Vector& logError(std::string message = "") {
        if (this->empty() || !this->_ok) {
            if (message.empty())
                std::cerr << "Vector is empty." << std::endl;
            else
                std::cerr << message << std::endl;
        }
        return *this;
    }

};

#endif // VECTOR_HPP
