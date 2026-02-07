### [How to install patches](https://koreader.rocks/user_guide/#L2-userpatches)

Tested on KOReader 2025.10

### [2-screensaver-presets](2-screensaver-presets.lua)
Adds the ability to save sleep screen settings as presets which can be activated by the Profiles plugin

Plus new options under Screen ▷ Sleep Screen ▷
- Close all the widgets before showing the screensaver
- Prevent the sleep screen message from overlapping the image
- Center the image
- Wallpaper ▷ Custom Images ▷ Update Frequency ▷
    - Caches the random image and only gets a new one if enough time has elapsed
    - Directory specific. Each directory has its own record of when the random image was last cached. Useful for presets.
    - Always update (same as default random image behavior) or after n minutes/hours/days
- Sleep screen message ▷ Container, position, and color ▷
  - Menu renamed from "Container and position"
  - Color ▷
    - Follow night mode
    - Follow wallpaper background fill
    - Invert
  - Show icon (uncheck to hide icon in box sleep screen message container)
- Sleep screen presets ▷
  - Works the same as status bar or dictionary presets

\* Credit to [sebdelsol's](https://github.com/sebdelsol/KOReader.patches) 2-screensaver-cover patch as the basis for many of these new options as well as some helper utilities.

#### Example Usage
How to set a custom sleep screen for a specific book
- Configure your sleep screen preferences
- Under Screen ▷ Sleep Screen ▷ Sleep screen presets ▷ select "Create new preset from current settings" or long press an existing preset to update or rename it.
- Under the Tools menu ▷ Profiles ▷ New
- Enable Auto-execute
  - on book opening
  - if book metadata contains
  - title
  - current book
  - Save
- Edit actions
  - Screen and lights
  - Load screensaver preset
  - Select your preset

Default book sleep screen
- Repeat the same steps as above, except select "always" for "on book opening"
- You may need to set this up before specific book, author, etc. profiles. Or specific metadata triggers may always take precedence over "always". I'm not 100% sure how the order of execution is determined.

### [2-profile-actions](2-profile-actions.lua)
Adds new actions that can be triggered by the Profiles plugin.
In the future may add new events to trigger profile auto-execute.
#### New Actions
- General ▷ Set starts with location
  - Sets the start location after a restart (not wake from sleep).
  - Use case: Set to last file when opening a book and set to file browser when opening the file browser. This way, you always return where you last were after a restart instead of automatically opening the last file even if you were finished with it.
#### New Auto-execute Events
- None

### [29-screensaver-blur](29-screensaver-blur.lua)
Blur the screen behind the sleep screen widget or blur the book cover.

Screen ▷ Sleep Screen ▷ Blur ▷
- Blur screen
- Blur cover

Each has strength and quality settings. Higher strength or quality will take longer to apply before going to sleep.

I would not recommend quality above 7. You get diminishing returns and it takes forever (at least on my old Kindle Oasis). But I kept the max higher in case a newer device could take advantage

Applying blur to both screen and cover will also take longer.
