on open theFiles
    try
        set filePath to POSIX path of (first item of theFiles)
        set appPath to POSIX path of (path to me)
        set scriptPath to appPath & "Contents/Resources/preview.sh"
        do shell script (quoted form of scriptPath) & " " & (quoted form of filePath)
    on error errMsg
        display alert "MarkdownPreview" message "Error: " & errMsg
    end try
end open

on run
    display dialog "Open a .md file using 'Open With… > MarkdownPreview' in Finder or Android Studio." buttons {"OK"} default button "OK" with title "MarkdownPreview"
end run
