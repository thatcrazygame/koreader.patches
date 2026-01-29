### [2-screensaver-presets](2-screensaver-presets.lua)
Tested on KOReader 2025.10

Adds the ability to save sleep screen settings as presets which can be activated by the Profiles plugin

Plus new options under Screen 🞂 Sleep Screen  🞂
- Close all the widgets before showing the screensaver
- Prevent the sleep screen message from overlapping the image
- Center the image
- Wallpaper 🞂 Custom Images 🞂 Update Frequency 🞂
    - Caches the random image and only gets a new one if enough time has elapsed
    - Directory specific. Each directory has its own record of when the random image was last cached. Useful for presets.
    - Always update (same as default random image behavior) or after n minutes/hours/days
- Sleep screen message 🞂 Container, position, and color 🞂
  - Menu renamed from "Container and position"
  - Color 🞂
    - Follow night mode
    - Follow wallpaper background fill
    - Invert
  - Show icon (uncheck to hide icon in box sleep screen message container)
- Sleep screen presets 🞂
  - Works the same as status bar or dictionary presets

\* Credit to [sebdelsol's](https://github.com/sebdelsol/KOReader.patches) 2-screensaver-cover patch as the basis for many of these new options as well as some helper utilities.
