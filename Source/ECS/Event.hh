#pragma once

#include <chrono>
#include <mutex>
#include <type_traits>
#include "Defines.hh"


namespace Solis::ECS
{
    class IEvent{};

    template<class U>
    concept CEvent = std::is_base_of_v<IEvent, U>;

    template<CEvent T>
    class EventReader;

    class EventStorageBase
    {
    public:
        virtual void Update() = 0;
    };

    template<CEvent T>
    class EventStorage : public EventStorageBase
    {
    public:
        using EventType = T;

        EventStorage() = default;
        ~EventStorage() = default;

        void Push(T event) 
        {
            std::lock_guard<std::mutex> const _guard(mL);
            mEvents.push_back(event);
        }

        void Update() {
            std::lock_guard<std::mutex> const _guard(mL);

            mLastUpdate = std::chrono::steady_clock::now();
            mEvents.erase(mEvents.begin(), mEvents.begin() + mLastFrame);
            mLastFrame = mEvents.size();
        }

        size_t Length() const
        {
            return mEvents.size();
        }

    private:
        friend class EventReader<T>;
        Deque<T> mEvents;
        size_t mLastFrame;
        std::chrono::time_point<std::chrono::steady_clock> mLastUpdate;
        std::mutex mL;
    };

    class EventWriterBase{};
    template<CEvent T>
    class EventWriter : public EventWriterBase {
    public:
        using StorageType = EventStorage<T>;
        using EventType = T;
        EventWriter(EventStorage<T>& storage) : mStorage(storage) {};

        void Send(T event) 
        {
            mStorage.Push(event);
        }
    private:
        EventStorage<T>& mStorage;
    };

    class EventReaderBase{};
    template<CEvent T>
    class EventReader : public EventReaderBase
    {
    public:
        using StorageType = EventStorage<T>;
        using EventType = T;

        EventReader() = delete;
        EventReader(EventStorage<T> const& storage) : mStorage(storage), mOffset(0) {};
       
        Optional<T> Next() 
        {
            if (HasUpdated())
            {
                mOffset = mOffset >= mLastFrame ? mOffset - mLastFrame : 0;
                mLastFrame = mStorage.mLastFrame;
                mLastUpdate = mStorage.mLastUpdate;
            }

            if (mOffset < mStorage.Length())
                return mStorage.mEvents[mOffset++];
            else
                return {};
        }


        bool HasUpdated() const
        {
            return mStorage.mLastUpdate > mLastUpdate;
        }

    private:
        EventStorage<T> const& mStorage;
        std::chrono::time_point<std::chrono::steady_clock> mLastUpdate;
        size_t mLastFrame;
        size_t mOffset;
    };

}
