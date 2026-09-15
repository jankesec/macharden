Output assets/demo.gif

Set Shell "zsh"
Set FontSize 14
Set Width 1200
Set Height 840
Set Padding 20
Set WindowBar Colorful
Set Theme "Catppuccin Mocha"
Set LineHeight 1.25
Set TypingSpeed 28ms
Set CursorBlink true

Hide
Type "export PS1='%F{cyan}security@macbook-pro%f %F{magenta}~/macharden%f %# '; alias macharden='./scripts/demo_fixture.sh'; clear"
Enter
Sleep 500ms
Show

Sleep 600ms
Type "macharden"
Sleep 200ms
Enter
Sleep 4.5s

Type "macharden -f html -o report.html"
Sleep 200ms
Enter
Sleep 3.8s

