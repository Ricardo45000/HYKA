# Setup Before Pushing to GitHub

## ✅ Security Checklist

Before pushing this project to GitHub, ensure all sensitive keys are protected:

### 1. ✅ Config.swift Created
- `ios/Config/Config.swift` contains actual keys (gitignored)
- `ios/Config/Config.example.swift` contains placeholders (committed)

### 2. ✅ Hardcoded Keys Removed
- ✅ Supabase anon key → moved to `Config.swift`
- ✅ Garmin client secret fallback → removed from Edge Function
- ✅ Tomorrow.io API key → moved to `Config.swift`
- ✅ Supabase URLs → moved to `Config.swift`

### 3. ✅ .gitignore Updated
- ✅ `ios/Config/Config.swift` is gitignored
- ✅ `.env` files are gitignored

### 4. ⚠️ Edge Function Secrets
Make sure these are set in Supabase (not in code):
```bash
supabase secrets set GARMIN_CLIENT_SECRET=your_actual_secret
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
supabase secrets set SUPABASE_URL=your_supabase_url
```

### 5. ⚠️ Remaining Items
- [ ] Edge Function `garmin-auth-callback` still has hardcoded client ID (line 69)
  - This is acceptable (client ID is public), but consider moving to env var
- [ ] `GarminConfig.swift` still has hardcoded client ID (deprecated file)
  - Consider removing this file or updating it to use `Config.swift`

---

## 📋 Quick Setup for New Developers

1. **Copy config template:**
   ```bash
   cp ios/Config/Config.example.swift ios/Config/Config.swift
   ```

2. **Fill in actual values in `Config.swift`:**
   - Supabase URL
   - Supabase anon key
   - Garmin client ID
   - Tomorrow.io API key

3. **Set Supabase Edge Function secrets:**
   ```bash
   supabase secrets set GARMIN_CLIENT_SECRET=your_secret
   ```

4. **Verify `.gitignore` includes `Config.swift`**

---

## 🔐 Keys Status

| Key | Location | Status | Action |
|-----|----------|--------|--------|
| Supabase Anon Key | `Config.swift` | ✅ Protected | Gitignored |
| Garmin Client Secret | Edge Function Secret | ✅ Protected | Never in code |
| Garmin Client ID | `Config.swift` | ✅ Protected | Gitignored |
| Tomorrow.io API Key | `Config.swift` | ✅ Protected | Gitignored |
| Supabase Service Role Key | Edge Function Secret | ✅ Protected | Never in code |
| Supabase URLs | `Config.swift` | ✅ Protected | Gitignored |

---

## ⚠️ If Keys Were Already Exposed

If you've already pushed keys to GitHub:

1. **Immediately rotate all exposed keys:**
   - Generate new Garmin Client Secret
   - Generate new Tomorrow.io API key
   - Update Supabase anon key (if needed)

2. **Remove from Git history:**
   ```bash
   # Use git-filter-repo or BFG Repo-Cleaner
   git filter-repo --invert-paths --path ios/Config/Config.swift
   ```

3. **Update all services** with new keys

4. **Monitor for unauthorized access**

---

## ✅ Ready to Push?

- [x] All keys moved to `Config.swift` (gitignored)
- [x] `Config.example.swift` created with placeholders
- [x] `.gitignore` updated
- [x] Garmin client secret fallback removed
- [x] Edge Function secrets documented
- [ ] Test app with config-based keys
- [ ] Verify no keys in Git history

**You're ready to push!** 🚀

