# Garmin Sync Behavior Summary

## Sync Types

### 1. Manual "Sync with Device" Button ✅ **FULL HISTORICAL SYNC**

**When:** User clicks "Sync with Garmin" button in the app

**Behavior:**
- ✅ Fetches **ALL historical activities** from the past year
- ✅ Gets complete activity history
- ✅ May take longer but ensures all data is available

**Code:**
```swift
useIncrementalSync: false // Fetches all activities from past year
```

**Use Case:**
- User wants to see all their historical activities
- User wants to ensure complete data sync
- User manually triggers sync

---

### 2. Initial Connection Sync ✅ **INCREMENTAL (FAST)**

**When:** User first connects Garmin account

**Behavior:**
- ✅ Fetches last 7 days only (if no previous workouts)
- ✅ Or fetches from last stored activity (incremental)
- ✅ Fast connection process
- ✅ Doesn't overwhelm API on first connection

**Code:**
```swift
useIncrementalSync: true // Fast sync, only new activities
```

**Use Case:**
- Quick initial setup
- Fast connection process
- User can manually sync later for full history

---

### 3. Server-Side Automatic Sync ✅ **INCREMENTAL (EFFICIENT)**

**When:** Cron job runs every 6 hours

**Behavior:**
- ✅ Fetches only new activities since last sync
- ✅ Efficient API usage
- ✅ Fast background sync
- ✅ No user interaction needed

**Code:**
```typescript
// Gets last sync timestamp from database
const afterDate = lastWorkout?.start_time || 7 days ago
```

**Use Case:**
- Automatic background sync
- Keeps data up-to-date
- Efficient resource usage

---

## Activity Filtering

**All sync types filter to only:**
- ✅ Running
- ✅ Hiking  
- ✅ Walking
- ✅ Indoor Running
- ✅ Trail Running
- ✅ Treadmill Running

**Filtered out:**
- ❌ Cycling
- ❌ Swimming
- ❌ Other activities

---

## Summary Table

| Sync Type | Activities Fetched | Speed | Use Case |
|-----------|-------------------|-------|----------|
| **Manual "Sync with Device"** | All from past year | Slower | User wants full history |
| **Initial Connection** | Last 7 days or incremental | Fast | Quick setup |
| **Server-Side Auto Sync** | Only new activities | Fast | Background updates |

---

## User Experience

### First Time User
1. Connects Garmin → Gets last 7 days (fast)
2. Clicks "Sync with Device" → Gets all historical activities (complete)

### Returning User
1. Automatic sync runs → Gets only new activities (efficient)
2. Clicks "Sync with Device" → Gets all activities again (complete refresh)

---

## Recommendations

✅ **Keep current behavior:**
- Manual sync = Full historical (user expects complete data)
- Automatic sync = Incremental (efficient, fast)
- Initial connection = Incremental (fast setup)

✅ **Benefits:**
- Fast initial connection
- Efficient automatic syncs
- Complete data when user requests it
- Best of both worlds!

