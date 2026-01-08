# Race Date Update Flow

## When `race_date` is Set or Updated

### ✅ Currently: Only When Manually Editing

**The race_date is ONLY saved to the database when:**
1. User clicks the **pencil icon** (edit button) in the race details card
2. User changes the race date in the edit modal
3. User saves the changes
4. `saveRaceNameAndDate()` is called → `updateRacePlanDate()` saves to database

**Location:** `RacePlanView.swift` → `saveRaceNameAndDate()` (line ~3059)

---

### ❌ Missing: During Race Creation

**The race_date is NOT saved to the database when:**
- Creating a new race plan through `RaceCreationFlowView`
- User enters a race date during the creation flow
- The date is only saved to local metadata store, not the database

**Location:** `RaceCreationFlowView.swift` → `finishCreation()` (line ~182)
- Creates metadata with `raceDate: raceDetails.date`
- But only saves to local store via `onComplete` callback
- Never calls `updateRacePlanDate()` to save to database

---

## Current Flow

### Race Creation Flow:
```
User creates race → Enters race date → 
Race plan created in DB (without race_date) → 
Metadata saved locally (with race_date) → 
❌ race_date NOT in database
```

### Race Edit Flow:
```
User clicks pencil → Edits race date → 
saveRaceNameAndDate() → 
updateRacePlanDate() → 
✅ race_date saved to database
```

---

## The Problem

**Race date entered during creation is lost** because:
1. It's only stored locally in `RacePlanMetadataStore` (UserDefaults)
2. It's never saved to the `race_plans.race_date` column in the database
3. When the app reloads or user switches devices, the date is missing

---

## Solution: Save Race Date During Creation

We need to update the race creation flow to also save the race_date to the database.

### Option 1: Add race_date to initial insert (Recommended)

Modify `saveRacePlan()` to include race_date in the initial insert.

### Option 2: Update race_date after creation

After creating the race plan, immediately call `updateRacePlanDate()` if a date was provided.

---

## Current Code Locations

1. **Race Creation:**
   - `RaceCreationFlowView.swift` line 182-188: Creates metadata with race date
   - `SupabaseService.swift` line 815-828: `saveRacePlan()` - doesn't include race_date

2. **Race Edit:**
   - `RacePlanView.swift` line 3059-3070: `saveRaceNameAndDate()` - saves to database
   - `SupabaseService.swift` line 622-634: `updateRacePlanDate()` - database update function

3. **Race Loading:**
   - `RacePlanView.swift` line 2202-2224: Loads race_date from database if not in metadata
   - `RacePlanView.swift` line 2418-2450: Loads race_date when selecting a race

---

## Recommendation

**Fix the race creation flow** to save the race_date to the database immediately when the race is created, not just when manually edited later.
