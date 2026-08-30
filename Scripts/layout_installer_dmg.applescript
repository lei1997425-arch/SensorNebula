on run argv
    set volumeName to item 1 of argv
    set backgroundFile to POSIX file (item 2 of argv) as alias
    tell application "Finder"
        tell disk volumeName
            open
            tell container window
                set current view to icon view
                set toolbar visible to false
                set statusbar visible to false
                set pathbar visible to false
                set bounds to {180, 140, 880, 580}
                set theViewOptions to the icon view options
                set background picture of theViewOptions to backgroundFile
            end tell
            set position of item "传感星云.app" to {198, 202}
            set position of item "应用程序" to {502, 202}
            update
            delay 2
            close
            open
        end tell
    end tell
end run
