# Fix Missing Profiles Issue

## 🔴 Problem Identified

Your query showed:
- **4 users** in `auth.users`
- **3 matching profiles** in `profiles`
- **1 user missing** from `profiles`

## Why This Causes Issues

When the trigger `sync_garmin_to_health_metrics()` tries to sync data:

1. ✅ Webhook inserts into `garmin_health_metrics` (references `auth.users`) - **Works**
2. ❌ Trigger tries to insert into `health_metrics` (references `profiles`) - **FAILS** if user has no profile
3. ❌ Foreign key constraint violation → entire transaction rolls back
4. ❌ No data stored in either table

## ✅ Solution: Create Missing Profiles

**Recommended approach:** Create profiles for all users.

### Steps:

1. **First, identify the missing user:**
   ```sql
   SELECT 
       u.id as user_id,
       u.email,
       u.created_at as user_created_at
   FROM auth.users u
   LEFT JOIN profiles p ON p.id = u.id
   WHERE p.id IS NULL;
   ```

2. **Create the missing profile:**
   ```sql
   INSERT INTO profiles (id, first_name, last_name, has_completed_onboarding, created_at, updated_at)
   SELECT 
       u.id,
       COALESCE(u.raw_user_meta_data->>'first_name', '') as first_name,
       COALESCE(u.raw_user_meta_data->>'last_name', '') as last_name,
       false as has_completed_onboarding,
       u.created_at,
       NOW() as updated_at
   FROM auth.users u
   LEFT JOIN profiles p ON p.id = u.id
   WHERE p.id IS NULL;
   ```

3. **Verify the fix:**
   ```sql
   SELECT 
       COUNT(*) as total_users,
       COUNT(CASE WHEN p.id = u.id THEN 1 END) as matching_ids
   FROM auth.users u
   LEFT JOIN profiles p ON p.id = u.id;
   ```
   
   Should show: `matching_ids = total_users`

## 🔄 Alternative Solution: Change Foreign Key

If you don't want to create profiles for all users, change `health_metrics` to reference `auth.users` directly:

```sql
ALTER TABLE public.health_metrics
DROP CONSTRAINT IF EXISTS health_metrics_user_id_fkey;

ALTER TABLE public.health_metrics
ADD CONSTRAINT health_metrics_user_id_fkey 
FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
```

**⚠️ Warning:** This means `health_metrics` won't enforce that users have profiles. Only do this if profiles are truly optional.

## 🎯 Recommendation

**Use Solution 1 (Create Missing Profiles)** because:
- ✅ Maintains data consistency
- ✅ Matches your app's design (users should have profiles)
- ✅ No schema changes needed
- ✅ Prevents future issues

## After Fixing

Once you've created the missing profile(s), the trigger should work correctly:
- ✅ Webhook inserts into `garmin_health_metrics` 
- ✅ Trigger syncs to `health_metrics`
- ✅ No foreign key violations
- ✅ Data stored successfully

## Prevention

To prevent this in the future, consider:

1. **Add a database trigger** to auto-create profiles:
   ```sql
   CREATE OR REPLACE FUNCTION create_profile_for_new_user()
   RETURNS TRIGGER AS $$
   BEGIN
     INSERT INTO profiles (id, has_completed_onboarding, created_at, updated_at)
     VALUES (NEW.id, false, NOW(), NOW())
     ON CONFLICT (id) DO NOTHING;
     RETURN NEW;
   END;
   $$ LANGUAGE plpgsql SECURITY DEFINER;

   CREATE TRIGGER on_auth_user_created
   AFTER INSERT ON auth.users
   FOR EACH ROW
   EXECUTE FUNCTION create_profile_for_new_user();
   ```

2. **Or handle it in your app** - Ensure profile creation happens during user registration
