Output assets/demo.gif

Set Shell "zsh"
Set FontSize 15
Set Width 1200
Set Height 800
Set Padding 24
Set WindowBar Colorful
Set Theme "Catppuccin Mocha"
Set LineHeight 1.2
Set TypingSpeed 24ms
Set CursorBlink true

Hide
Type "export PS1='%F{cyan}audit-demo@demo-mac%f %F{magenta}~/macharden%f %# '; alias macharden='./scripts/demo_fixture.sh'; clear"
Enter
Sleep 600ms
Show

Sleep 600ms
Type "macharden --check HARD-01,HARD-02,HARD-18,NET-01,NET-10,SEC-03"
Sleep 240ms
Enter
Sleep 5.2s
