Output assets/demo.gif

Set Shell "zsh"
Set FontSize 13
Set Width 1200
Set Height 800
Set Padding 24
Set WindowBar Colorful
Set Theme "Catppuccin Mocha"
Set LineHeight 1.3
Set TypingSpeed 30ms
Set CursorBlink true

Hide
Type "export PS1='%F{cyan}secops@macos-workstation%f %F{magenta}~/macharden%f %# '; export MACHAR_HOSTNAME=macos-workstation; export MACHAR_USER=secops; alias macharden='./bin/macharden'; clear"
Enter
Sleep 600ms
Show

Sleep 800ms
Type "macharden -c hardening"
Sleep 300ms
Enter
Sleep 5s

Type "macharden -f html -o report.html && open report.html"
Sleep 300ms
Enter
Sleep 3s

