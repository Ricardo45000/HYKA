# Font Setup Instructions

The HYKA app now uses the same fonts as the website (https://hyka.app/):
- **Plus Jakarta Sans** - for headings and UI elements
- **Inter** - for body text

## Fonts Location

Fonts are located in: `Inter,Plus_Jakarta_Sans/`

## Steps to Add Fonts to Xcode:

1. **Open Xcode project**

2. **Add fonts to the project:**
   - In Xcode, right-click on your project in the navigator
   - Select "Add Files to [Project Name]..."
   - Navigate to the `Inter,Plus_Jakarta_Sans` folder
   - Select the following font files:
     - **Variable fonts (recommended - iOS 13+):**
       - `Inter,Plus_Jakarta_Sans/Plus_Jakarta_Sans/PlusJakartaSans-VariableFont_wght.ttf`
       - `Inter,Plus_Jakarta_Sans/Inter/Inter-VariableFont_opsz,wght.ttf`
     - **Static fonts (fallback):**
       - `Inter,Plus_Jakarta_Sans/Plus_Jakarta_Sans/static/PlusJakartaSans-Regular.ttf`
       - `Inter,Plus_Jakarta_Sans/Plus_Jakarta_Sans/static/PlusJakartaSans-Medium.ttf`
       - `Inter,Plus_Jakarta_Sans/Plus_Jakarta_Sans/static/PlusJakartaSans-SemiBold.ttf`
       - `Inter,Plus_Jakarta_Sans/Plus_Jakarta_Sans/static/PlusJakartaSans-Bold.ttf`
       - `Inter,Plus_Jakarta_Sans/Plus_Jakarta_Sans/static/PlusJakartaSans-ExtraBold.ttf`
       - `Inter,Plus_Jakarta_Sans/Inter/static/Inter_18pt-Regular.ttf`
       - `Inter,Plus_Jakarta_Sans/Inter/static/Inter_18pt-Medium.ttf`
       - `Inter,Plus_Jakarta_Sans/Inter/static/Inter_18pt-SemiBold.ttf`
       - `Inter,Plus_Jakarta_Sans/Inter/static/Inter_18pt-Bold.ttf`
       - `Inter,Plus_Jakarta_Sans/Inter/static/Inter_18pt-Light.ttf`
   - **Important:** Check "Copy items if needed"
   - **Important:** Select your app target
   - Click "Add"

3. **Verify fonts are in the bundle:**
   - Select your project in Xcode
   - Go to your app target → "Build Phases"
   - Expand "Copy Bundle Resources"
   - Verify all font files are listed there
   - If not, add them manually

4. **Info.plist is already configured:**
   - The `UIAppFonts` array in `Info.plist` has been pre-configured with the correct paths
   - The paths match the folder structure: `Inter,Plus_Jakarta_Sans/...`

5. **Test the fonts:**
   - Build and run the app
   - The app will automatically use the custom fonts if available
   - Variable fonts will be used first (iOS 13+), with fallback to static fonts
   - If fonts aren't found, it will fallback to system fonts (SF Pro)

## Font Detection

The app automatically detects fonts using these PostScript names:
- **Plus Jakarta Sans:** `PlusJakartaSans` (variable) or `PlusJakartaSans-{Weight}` (static)
- **Inter:** `Inter` (variable) or `Inter_18pt-{Weight}` / `Inter-{Weight}` (static)

## Notes:

- Variable fonts are preferred (iOS 13+) as they support all weights in a single file
- Static fonts are used as fallback for older iOS versions or if variable fonts fail
- The app will gracefully fallback to system fonts if custom fonts aren't available
- Font names in code are case-sensitive
- Make sure font files are included in the app target's "Copy Bundle Resources" build phase

