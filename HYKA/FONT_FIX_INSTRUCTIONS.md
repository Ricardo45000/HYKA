# Font Fix Instructions

The font files are not being copied to the app bundle. Follow these steps to fix:

## Quick Fix Steps:

1. **Extract fonts (if needed):**
   - If you have `Plus_Jakarta_Sans.zip`, extract it
   - You should have an `Inter,Plus_Jakarta_Sans` folder with the font files

2. **Add fonts to Xcode project:**
   - Open your Xcode project
   - In the Project Navigator, right-click on your project root
   - Select "Add Files to [Project Name]..."
   - Navigate to the font files
   - **Select ALL font files** (both variable and static fonts)
   - **IMPORTANT:** Check "Copy items if needed" ✅
   - **IMPORTANT:** Select your app target (HYKA) ✅
   - Click "Add"

3. **Verify fonts are in "Copy Bundle Resources":**
   - Select your project in Xcode
   - Select your app target (HYKA)
   - Go to "Build Phases" tab
   - Expand "Copy Bundle Resources"
   - **Verify all .ttf font files are listed there**
   - If any are missing, click the "+" button and add them

4. **Font file names to add:**
   - `PlusJakartaSans-VariableFont_wght.ttf`
   - `PlusJakartaSans-Italic-VariableFont_wght.ttf`
   - `PlusJakartaSans-Regular.ttf`
   - `PlusJakartaSans-Medium.ttf`
   - `PlusJakartaSans-SemiBold.ttf`
   - `PlusJakartaSans-Bold.ttf`
   - `PlusJakartaSans-ExtraBold.ttf`
   - `Inter-VariableFont_opsz,wght.ttf`
   - `Inter-Italic-VariableFont_opsz,wght.ttf`
   - `Inter_18pt-Regular.ttf`
   - `Inter_18pt-Medium.ttf`
   - `Inter_18pt-SemiBold.ttf`
   - `Inter_18pt-Bold.ttf`
   - `Inter_18pt-Light.ttf`

5. **Clean and rebuild:**
   - In Xcode: Product → Clean Build Folder (Shift+Cmd+K)
   - Product → Build (Cmd+B)
   - Run the app

## Alternative: Simplify Font Structure

If you want to keep fonts in folders, you can:
1. Create a `Fonts` folder in your Xcode project
2. Add the font files there
3. Update `Info.plist` paths to match (e.g., `Fonts/PlusJakartaSans-VariableFont_wght.ttf`)

But the simplest approach is to add fonts directly to the project root (as shown above).

## Verification

After adding fonts, you can verify they're in the bundle:
1. Build the app
2. Right-click the .app file in Products
3. Select "Show in Finder"
4. Right-click the .app → "Show Package Contents"
5. You should see all the .ttf files in the root

The `Info.plist` has been updated to use simple filenames (no folder paths), which is the standard iOS approach.

