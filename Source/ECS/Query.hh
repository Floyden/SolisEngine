#pragma once
#include "Defines.hh"
#include "Entity.hh"

namespace Solis::ECS
{
    
class World;
struct QueryBase {};

template<typename... Args>
class Query : public QueryBase
{
public:
    using Types = typename std::tuple<Args...>;
    static constexpr size_t TypeCount = sizeof...(Args);
    
    template<int N>
    using TypeOf = typename std::tuple_element<N, Types>::type;

    struct QueryIter
    {
        bool operator==(QueryIter const & other) const { return mCurrent == other.mCurrent; }
        bool operator!=(QueryIter const & other) const { return !(*this == other); }

        QueryIter operator++() 
        {
            mCurrent = FindNext();
            return *this; 
        }

        QueryIter operator++(int) 
        {
            auto old = *this;
            mCurrent = FindNext();
            return old; 
        }

        Query::Types operator*() { 
            return CreateReference(); }

    private:
        QueryIter(Query const& query) : mCurrent(std::nullopt), mQuery(query) {};

        Optional<Entity> FindNext() const;
        Query::Types CreateReference() const;

        Optional<Entity> mCurrent;
        Query<Args...> const& mQuery;

        friend class Query<Args...>;
    };

public:
    Query(World& world) : mWorld(world) 
    {
        static_assert((std::is_reference_v<Args> && ...));
    };

    std::tuple<Args...> GetSingle();

    void Test();

    QueryIter begin() const { return ++QueryIter(*this); }
    QueryIter end() const { return QueryIter(*this); }

public:
    // Container functions

private:
    World& mWorld;
};

} // namespace Solis::ECS
