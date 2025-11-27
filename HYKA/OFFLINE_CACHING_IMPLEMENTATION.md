# Offline Caching Implementation

## Overview

The app now supports offline mode with automatic caching of data. When the user goes offline, the app will:
1. Display cached data automatically
2. Show an offline alert banner
3. Show an alert dialog when going offline

## Components Created

### 1. **NetworkMonitor** (`ios/Services/NetworkMonitor.swift`)
- Monitors network connectivity in real-time
- Provides `isConnected` published property
- Detects connection type (WiFi, Cellular, Ethernet)
- Automatically updates when network status changes

### 2. **DataCache** (`ios/Services/DataCache.swift`)
- Caches data locally in the app's documents directory
- Supports caching any `Codable` type
- Automatic cache key management
- Cache size tracking

### 3. **OfflineAlertView** (`ios/Views/OfflineAlertView.swift`)
- Banner that appears at the top when offline
- Alert dialog when connection is lost
- View modifier: `.withOfflineAlert()`

## Updated Functions

### SupabaseService Functions (with caching):

1. **`fetchRacePlans(userId:)`**
   - ✅ Caches race plans after fetching
   - ✅ Returns cached data when offline
   - ✅ Falls back to cache if fetch fails

2. **`fetchWorkouts(userId:)`**
   - ✅ Caches workouts after fetching
   - ✅ Returns cached data when offline
   - ✅ Falls back to cache if fetch fails (including fallback path)

3. **`fetchGarminActivities(userId:startDate:endDate:limit:)`**
   - ✅ Caches Garmin activities after fetching
   - ✅ Returns cached data when offline (with date filtering)
   - ✅ Falls back to cache if fetch fails

4. **`fetchRacePlanSegments(racePlanId:)`**
   - ✅ Caches race plan segments after fetching
   - ✅ Returns cached data when offline
   - ✅ Falls back to cache if fetch fails

## Usage

### Adding Offline Alert to Views

```swift
import SwiftUI

struct MyView: View {
    var body: some View {
        VStack {
            // Your content
        }
        .withOfflineAlert()  // Add offline banner
    }
}
```

### Using NetworkMonitor

```swift
@StateObject private var networkMonitor = NetworkMonitor.shared

if networkMonitor.isConnected {
    // Show online UI
} else {
    // Show offline UI
}
```

### Manual Cache Management

```swift
// Save to cache
DataCache.shared.saveArray(myData, key: .workouts, userId: userId)

// Load from cache
if let cached = DataCache.shared.loadArray(WorkoutSummary.self, key: .workouts, userId: userId) {
    // Use cached data
}

// Clear cache
DataCache.shared.clear(key: .workouts, userId: userId)
DataCache.shared.clearAll(userId: userId)
```

## Cache Keys

Available cache keys in `DataCache.CacheKey`:
- `.racePlans` - Race plans list
- `.workouts` - Workouts/activities list
- `.garminActivities` - Garmin activities
- `.racePlanSegments` - Race plan segments (requires `additionalId`)
- `.racePlanTrackPoints` - Race plan track points (requires `additionalId`)
- `.userProfile` - User profile

## How It Works

### Online Flow:
1. User opens app → NetworkMonitor detects online
2. App fetches data from Supabase
3. Data is automatically cached to local storage
4. Data is displayed to user

### Offline Flow:
1. User goes offline → NetworkMonitor detects offline
2. Offline alert banner appears
3. App tries to fetch data → Fails
4. App automatically loads from cache
5. Cached data is displayed to user

### Cache Location:
- Cache files stored in: `Documents/DataCache/`
- Files named: `{cache_key}_{user_id}_{additional_id}.json`
- Automatic cleanup on app uninstall

## Features

✅ **Automatic Caching**: All data is cached after successful fetch
✅ **Offline Support**: App works offline with cached data
✅ **Visual Feedback**: Banner and alert show offline status
✅ **Fallback**: If fetch fails, cache is used automatically
✅ **Date Filtering**: Cached Garmin activities are filtered by date range
✅ **Type Safety**: Uses Codable for type-safe caching

## Testing

### Test Offline Mode:

1. **Enable Airplane Mode** on your device
2. Open the app
3. You should see:
   - Orange banner at top: "You're offline. Showing cached data."
   - Alert dialog: "No Internet Connection"
   - Cached data displayed (if available)

### Test Cache:

1. **Load data online** (race plans, workouts, etc.)
2. **Go offline** (Airplane Mode)
3. **Open app** → Should show cached data
4. **Go online** → Should fetch fresh data and update cache

## Limitations

⚠️ **New Data**: Cannot fetch new data when offline
⚠️ **Updates**: Cannot update/create data when offline
⚠️ **First Launch**: No cached data available on first app launch offline
⚠️ **Cache Size**: Cache grows over time (consider implementing cache size limits)

## Future Enhancements

- [ ] Queue write operations when offline, sync when online
- [ ] Cache expiration (e.g., cache valid for 24 hours)
- [ ] Cache size limits and automatic cleanup
- [ ] Background sync when connection restored
- [ ] Cache statistics in settings

---

**The app now fully supports offline mode with automatic caching!** 🎉

