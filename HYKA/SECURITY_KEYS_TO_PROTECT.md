# Security: Keys and Secrets to Protect

## ⚠️ CRITICAL: Before Pushing to GitHub

This document lists all keys, secrets, and sensitive information that **MUST** be protected before pushing to GitHub.

---

## 🔴 HIGH PRIORITY - Must Remove/Protect

### 1. Supabase Anon Key (Public but should be in config)
**Location:**
- `ios/Auth/SupabaseClient.swift` (line 8)
- `ios/Integrations/DeviceOAuthManager.swift` (line 280)
- `ios/Features/RacePlan/RacePlanView.swift` (line 3292)

**Current Value:**
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2Zmh0aWxqa3liYnJieG95cXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3NjYyNTgsImV4cCI6MjA3NjM0MjI1OH0.pOSv9o4_xIg-GCozVMEocp2K27fTDzP_-aG2WPm9j1w
```

**Status:** ⚠️ **Anon key is public by design** (used in client-side code), but should be in a config file, not hardcoded.

**Action:** Move to `Config.swift` or environment variable.

---

### 2. Garmin Client Secret (CRITICAL - Must Protect!)
**Location:**
- `supabase/functions/garmin-auth-callback/index.ts` (line 70)

**Current Value:**
```typescript
const clientSecret = Deno.env.get('GARMIN_CLIENT_SECRET') || "0Bn115Wfjb9RrWvHIro3PB2Sfg0Wq2VTzXiT/yuQ1+Q"
```

**Status:** 🔴 **CRITICAL** - This is a fallback hardcoded secret. **MUST BE REMOVED!**

**Action:** 
- Remove the hardcoded fallback value
- Ensure `GARMIN_CLIENT_SECRET` is set as Supabase Edge Function secret
- Never commit this value

---

### 3. Tomorrow.io API Key
**Location:**
- `ios/Features/RacePlan/RacePlanView.swift` (line 2238)

**Current Value:**
```swift
let apiKey = "xMalLIZRYQo1E8lDsPXA8xZKwUI15pxX"
```

**Status:** 🔴 **CRITICAL** - API key should not be hardcoded.

**Action:** Move to `Config.swift` or environment variable.

---

## 🟡 MEDIUM PRIORITY - Should Protect

### 4. Supabase URLs
**Location:**
- Multiple files

**Current Values:**
- `https://gvfhtiljkybbrbxoyqsq.supabase.co`
- `https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/...`

**Status:** 🟡 These are public endpoints, but should be in config for easier environment switching.

**Action:** Move to `Config.swift`.

---

## ✅ Already Protected (Edge Functions)

### Edge Function Secrets (Already Using Environment Variables)
These are already using `Deno.env.get()` and should be set as Supabase secrets:
- `SUPABASE_URL` ✅
- `SUPABASE_SERVICE_ROLE_KEY` ✅ (CRITICAL - never expose!)
- `GARMIN_CLIENT_SECRET` ✅ (but has hardcoded fallback - needs fixing)

---

## 📋 Action Items

### Before Pushing to GitHub:

1. **Remove Garmin Client Secret fallback:**
   ```typescript
   // ❌ REMOVE THIS:
   const clientSecret = Deno.env.get('GARMIN_CLIENT_SECRET') || "0Bn115Wfjb9RrWvHIro3PB2Sfg0Wq2VTzXiT/yuQ1+Q"
   
   // ✅ REPLACE WITH:
   const clientSecret = Deno.env.get('GARMIN_CLIENT_SECRET')
   if (!clientSecret) {
     throw new Error('GARMIN_CLIENT_SECRET environment variable is required')
   }
   ```

2. **Create Config.swift for iOS:**
   - Move Supabase anon key
   - Move Tomorrow.io API key
   - Move Supabase URLs
   - Add to `.gitignore`

3. **Create .env.example:**
   - Document required environment variables
   - Show format without actual values

4. **Verify .gitignore:**
   - Ensure `.env` files are ignored
   - Ensure `*_config.swift` is ignored (if you create one)

---

## 🔐 How to Set Supabase Edge Function Secrets

```bash
# Set Garmin client secret
supabase secrets set GARMIN_CLIENT_SECRET=your_actual_secret_here

# Verify secrets are set (won't show values)
supabase secrets list
```

---

## 📝 Recommended File Structure

```
HYKA/
├── ios/
│   ├── Config/
│   │   ├── Config.swift (gitignored)
│   │   └── Config.example.swift (committed, with placeholders)
│   └── ...
├── supabase/
│   └── functions/
│       └── ... (secrets via environment variables)
├── .gitignore ✅
└── SECURITY_KEYS_TO_PROTECT.md ✅
```

---

## ⚠️ If Keys Are Already Exposed

If you've already pushed keys to GitHub:

1. **Immediately rotate all exposed keys:**
   - Generate new Garmin Client Secret in Garmin Developer Portal
   - Generate new Tomorrow.io API key
   - Update Supabase anon key (if needed)

2. **Remove from Git history:**
   ```bash
   # Use git-filter-repo or BFG Repo-Cleaner
   # This removes sensitive data from entire Git history
   ```

3. **Update all services** with new keys

4. **Monitor for unauthorized access**

---

## ✅ Checklist Before First Commit

- [ ] Remove Garmin Client Secret hardcoded fallback
- [ ] Move Supabase anon key to Config.swift
- [ ] Move Tomorrow.io API key to Config.swift
- [ ] Create Config.example.swift with placeholders
- [ ] Add Config.swift to .gitignore
- [ ] Verify .gitignore includes .env files
- [ ] Set all Supabase Edge Function secrets
- [ ] Test that app works with config-based keys
- [ ] Document required environment variables

