
// Reverse iterator because Apple clang does not support ranges as of xcode 14
namespace Solis::Util
{
    template <typename T>
    struct ReverseIterable { T& iterable; };

    template <typename T>
    auto begin (ReverseIterable<T> w) { return std::rbegin(w.iterable); }

    template <typename T>
    auto end (ReverseIterable<T> w) { return std::rend(w.iterable); }

    template <typename T>
    ReverseIterable<T> Reverse (T&& iterable) { return { iterable }; }
}