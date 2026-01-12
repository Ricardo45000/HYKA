# Removing Sensitive Keys from Git

## ⚠️ IMPORTANT: If you've already pushed to a remote repository

If you've already pushed commits containing sensitive keys to GitHub/GitLab/etc., you need to:

1. **Rotate all exposed keys immediately** - They are compromised
2. **Remove from git history** (see instructions below)
3. **Force push** (coordinate with your team first!)

## Files that contain sensitive information:

1. `ios/Config/Config.swift` - Contains API keys, client IDs, subscription keys
2. `setup_apns_key.sh` - Contains hardcoded path to .p8 key file
3. `setup_apns_quick.sh` - Contains hardcoded path to .p8 key file  
4. `SUUNTO_CREDENTIALS_SETUP.md` - Contains client secret in plain text

## Step 1: Remove files from git tracking (already done)

The following files have been removed from git tracking:
- `setup_apns_key.sh`
- `setup_apns_quick.sh`

## Step 2: Remove from git history (if already pushed)

If these files were already pushed to a remote repository, you need to remove them from git history:

### Option A: Using git filter-branch (for small repos)

```bash
# Remove specific files from entire history
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch setup_apns_key.sh setup_apns_quick.sh SUUNTO_CREDENTIALS_SETUP.md ios/Config/Config.swift" \
  --prune-empty --tag-name-filter cat -- --all
```

### Option B: Using BFG Repo-Cleaner (recommended for large repos)

1. Download BFG: https://rtyley.github.io/bfg-repo-cleaner/
2. Create a file `sensitive-files.txt` with:
   ```
   setup_apns_key.sh
   setup_apns_quick.sh
   SUUNTO_CREDENTIALS_SETUP.md
   ios/Config/Config.swift
   ```
3. Run:
   ```bash
   java -jar bfg.jar --delete-files sensitive-files.txt
   git reflog expire --expire=now --all
   git gc --prune=now --aggressive
   ```

### Option C: Using git-filter-repo (modern approach)

```bash
# Install: pip install git-filter-repo
git filter-repo --path setup_apns_key.sh --path setup_apns_quick.sh --path SUUNTO_CREDENTIALS_SETUP.md --path ios/Config/Config.swift --invert-paths
```

## Step 3: Force push (⚠️ COORDINATE WITH TEAM FIRST!)

```bash
# WARNING: This rewrites history. Make sure your team is aware!
git push origin --force --all
git push origin --force --tags
```

## Step 4: Rotate all exposed keys

### Keys that need to be rotated:

1. **Supabase Anon Key** - In Supabase Dashboard → Settings → API
2. **Tomorrow.io API Key** - In Tomorrow.io Dashboard
3. **Garmin Client ID/Secret** - In Garmin Developer Portal
4. **Strava Client ID/Secret** - In Strava Developer Portal
5. **Suunto Client ID/Secret** - In Suunto Developer Portal
6. **Polar Client ID/Secret** - In Polar Developer Portal
7. **APNs Key** - Generate new key in Apple Developer Portal

### Update Supabase Edge Function Secrets:

```bash
# Update all secrets in Supabase
npx supabase secrets set GARMIN_CLIENT_SECRET="new_secret" --project-ref gvfhtiljkybbrbxoyqsq
npx supabase secrets set STRAVA_CLIENT_SECRET="new_secret" --project-ref gvfhtiljkybbrbxoyqsq
npx supabase secrets set SUUNTO_CLIENT_SECRET="new_secret" --project-ref gvfhtiljkybbrbxoyqsq
npx supabase secrets set POLAR_CLIENT_SECRET="new_secret" --project-ref gvfhtiljkybbrbxoyqsq
```

## Step 5: Update local files

1. Copy `ios/Config/Config.example.swift` to `ios/Config/Config.swift`
2. Fill in new keys (never commit this file)
3. Update shell scripts to use environment variables instead of hardcoded paths

## Prevention for the future:

1. ✅ `.gitignore` has been updated to exclude sensitive files
2. ✅ Use environment variables or Supabase secrets instead of hardcoded keys
3. ✅ Use `Config.example.swift` as a template (committed) and `Config.swift` for actual keys (gitignored)
4. ✅ Never commit files with `.p8`, `.p12`, `.key`, `.pem` extensions
5. ✅ Review commits before pushing: `git log -p` to check for secrets

## Quick check for exposed secrets:

```bash
# Search for common secret patterns
git log -p | grep -E "(password|secret|key|token)" -i
```

