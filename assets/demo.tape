Output assets/demo.gif

Set Shell "zsh"
Set FontSize 13
Set Width 1100
Set Height 780
Set Padding 24
Set WindowBar Colorful
Set Theme "Catppuccin Mocha"
Set LineHeight 1.25
Set TypingSpeed 40ms
Set CursorBlink true

Hide
Type "export MACHAR_HOSTNAME=macos-workstation; export MACHAR_USER=secops; alias macharden='./bin/macharden'; clear"
Enter
Sleep 500ms
Show

Sleep 800ms
Type "macharden -c hardening"
Sleep 400ms
Enter
Sleep 6s

Type "macharden -f html -o report.html"
Sleep 400ms
Enter
Sleep 3s

Sleep 2s
