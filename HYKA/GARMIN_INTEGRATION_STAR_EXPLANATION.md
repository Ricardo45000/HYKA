# Garmin Integration in HYKA App - STAR Method Explanation

## STAR Method Overview
- **Situation**: The context and background
- **Task**: What needed to be accomplished
- **Action**: What was implemented
- **Result**: The outcome and benefits

---

## Situation

**Context:**
HYKA is an iOS ultra-running race planning app that helps athletes prepare for and execute race strategies. To provide accurate pacing and nutrition recommendations, the app needs real-time access to users' training data from their fitness devices.

**Challenge:**
- Users connect their Garmin devices via OAuth 2.0
- Need to sync ALL activities with complete details (GPS tracks, heart rate, pace, elevation)
- Need to sync health metrics (VO2 max, fitness age, etc.)
- Garmin's API is webhook-based (asynchronous), not direct fetch
- Activities must be stored in Supabase for the iOS app to read
- Users expect seamless, automatic syncing

**Technical Constraints:**
- Garmin remembers backfill requests for weeks/months (409 duplicate errors)
- Maximum 3 hours per request to avoid duplicates
- Webhook-based architecture (no synchronous data fetching)
- Only Running/Hiking/Walking activities are relevant for ultra-running
- Token expiration requires automatic refresh

---

## Task

**Primary Objectives:**
1. **OAuth Integration**: Allow users to authorize HYKA to access their Garmin data
2. **Activity Sync**: Automatically sync all activities with full details (summary, GPS samples, FIT files)
3. **Health Data Sync**: Sync health metrics (VO2 max, fitness age, etc.)
4. **Historical Data**: Retrieve activities from before user connection (backfill)
5. **Real-time Updates**: Receive new activities automatically via webhooks
6. **Data Storage**: Store all data in Supabase for iOS app access
7. **User Experience**: Provide "Sync with Device" button for manual sync

**Requirements:**
- Activities must include: GPS track, heart rate samples, pace, elevation, distance, duration
- Health data must include: VO2 max, fitness age, daily metrics
- Must handle token expiration automatically
- Must handle permission revocation
- Must filter activities (only Running/Hiking/Walking)
- Must avoid duplicate requests (3-hour max window)

---

## Action

### 1. **OAuth Authentication Flow**

**Implementation:**
- Created `garmin-auth-callback` edge function
- iOS app initiates OAuth flow via `DeviceOAuthManager`
- User authorizes in Garmin Connect
- Edge function exchanges code for tokens
- Fetches Garmin user ID from `/rest/user/id`
- Stores connection in `garmin_connections` table:
  - `user_id` (HYKA user)
  - `garmin_user_id` (Garmin identifier)
  - `access_token` & `refresh_token`
  - `token_expires_at`
  - `connected_at` timestamp

**Result:** Users can securely connect their Garmin account with one tap.

---

### 2. **Webhook-Based Activity Sync**

**PING Webhook Flow:**
- Garmin → `garmin-activity-ping` (notification)
- Extracts `callbackUrl` from webhook
- Forwards to → `garmin-activity-pull`
- Pull function fetches:
  - Activity summary
  - Activity details (GPS samples, heart rate)
  - FIT file
- Forwards to → `garmin-activity-store`

**PUSH Webhook Flow (Faster):**
- Garmin → `garmin-activity-push` (full data included)
- Processes activity summaries directly
- Fetches details/FIT file if needed
- Forwards to → `garmin-activity-store`

**Storage:**
- `garmin_activities` table: Summary data (type, distance, pace, elevation, HR)
- `garmin_activity_samples` table: GPS track points with timestamps
- `garmin_fit_files` table: Raw FIT file data
- Triggers `garmin-fit-processor` for FIT file parsing

**Result:** Activities automatically sync when created in Garmin Connect.

---

### 3. **Health Data Sync**

**Implementation:**
- `garmin-health-webhook` receives health webhooks
- Handles multiple types:
  - User Metrics (fitness age, VO2 max)
  - Health Snapshots
  - Body Composition
- Stores in `garmin_health_metrics` table
- Includes full `raw_data` JSON for future use

**Result:** Health metrics sync automatically with daily updates.

---

### 4. **Historical Data (Backfill)**

**Implementation:**
- `garmin-activity-backfill` edge function
- iOS app calls via "Sync with Device" button
- Requests last 3 hours (to avoid duplicates)
- Edge function:
  - Validates 3-hour maximum
  - Checks/refreshes access token
  - Calls Garmin backfill API
  - Records request in `garmin_backfill_requests` table
- Garmin processes asynchronously
- Activities arrive via webhooks

**Result:** Users can manually trigger sync for recent activities.

---

### 5. **Token Management**

**Implementation:**
- `garmin-token-refresh` shared utility
- All functions check token expiration before API calls
- Automatic refresh using refresh token
- Updates `garmin_connections` with new tokens
- Handles refresh failures gracefully

**Result:** Seamless operation without user intervention.

---

### 6. **iOS App Integration**

**Data Reading:**
- `SupabaseService.fetchGarminActivities()` - Fetch activities with date filtering
- `SupabaseService.fetchGarminActivitySamples()` - Fetch GPS track points
- `SupabaseService.fetchGarminHealthMetrics()` - Fetch health data
- `SupabaseService.hasGarminConnection()` - Check connection status

**User Interface:**
- "Sync with Device" button in RacePlanView
- Shows sync status and progress
- Detects stuck requests (no activities after 5+ days)
- Provides diagnostic information

**Result:** App can display activities and health data from Supabase.

---

### 7. **Error Handling & Diagnostics**

**Implementation:**
- Checks for existing activities when 409 (duplicate) occurs
- Detects stuck requests (no activities after 5+ days)
- Provides diagnostic messages:
  - Webhook URL configuration
  - Edge function logs
  - Activity type filtering
- Handles permission revocation via `garmin-permission-webhook`

**Result:** Users get clear feedback when issues occur.

---

## Result

### **Success Metrics:**

✅ **OAuth Flow**: Users can connect Garmin with one tap
✅ **Activity Sync**: All activities sync automatically with full details
✅ **Health Data**: Health metrics sync daily
✅ **Historical Data**: Users can request recent activities (3-hour window)
✅ **Token Management**: Automatic refresh, no user intervention needed
✅ **Data Storage**: All data in Supabase, accessible to iOS app
✅ **User Experience**: Clear sync status and error messages

### **Technical Achievements:**

1. **Complete Data Pipeline:**
   ```
   Garmin Connect → Webhooks → Edge Functions → Supabase → iOS App
   ```

2. **Comprehensive Data Capture:**
   - Activity summaries (distance, pace, elevation, HR)
   - GPS track points (lat, lon, elevation, timestamps)
   - Heart rate samples throughout activity
   - FIT files (raw Garmin data)
   - Health metrics (VO2 max, fitness age)

3. **Robust Architecture:**
   - 11 active edge functions
   - Webhook-based (scalable, real-time)
   - Automatic token refresh
   - Duplicate detection and handling
   - Activity filtering (Running/Hiking/Walking only)

4. **User-Friendly:**
   - One-tap OAuth connection
   - Automatic background syncing
   - Manual sync option
   - Clear status messages
   - Diagnostic error messages

### **Benefits for Users:**

- **Seamless Integration**: Connect once, sync automatically
- **Complete Data**: All activity details available in app
- **Real-time Updates**: New activities appear automatically
- **Historical Access**: Can request past activities
- **Health Insights**: VO2 max and fitness age for training planning
- **Reliable**: Automatic token refresh, error handling

### **Benefits for Development:**

- **Scalable**: Webhook-based architecture handles growth
- **Maintainable**: Clear separation of concerns
- **Debuggable**: Comprehensive logging and diagnostics
- **Flexible**: Easy to add new data types or filters
- **Secure**: OAuth 2.0, token encryption, RLS policies

---

## Summary

**Situation**: Ultra-running app needs Garmin data for accurate race planning
**Task**: Sync all activities and health data automatically
**Action**: Built webhook-based architecture with 11 edge functions, OAuth flow, and iOS integration
**Result**: Complete, automatic, reliable Garmin data sync with full activity details and health metrics

The integration successfully provides users with seamless access to their Garmin training data, enabling HYKA to deliver accurate pacing and nutrition recommendations for ultra-running races.

