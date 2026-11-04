# Recording script for the terminal part of assets/demo.gif. Run it through `make demo`:
# scripts/generate_demo_gif.py swaps the Output line, records this tape with VHS and appends a
# tour of the HTML dashboard. All data is synthetic (scripts/demo_fixture.sh); nothing here
# audits the machine that records it.
Output assets/demo.gif

Set Shell "zsh"
Set FontSize 14
Set Width 1200
Set Height 840
Set Padding 20
Set WindowBar Colorful
Set Theme "Pro"
Set LineHeight 1.25
Set TypingSpeed 28ms
Set CursorBlink true

# Hidden setup: tidy prompt, a scratch working directory, and `macharden` pointed at the fixture.
Hide
Type `export PS1='%F{green}audit-demo@demo-mac%f %F{cyan}~/macharden%f %# '; F="$PWD/scripts/demo_fixture.sh"; cd "$(mktemp -d)"; alias macharden="$F"; clear`
Enter
Sleep 500ms
Show

Sleep 600ms
Type "macharden"
Sleep 200ms
Enter
Sleep 2s
ScrollUp@3ms 58
Sleep 3s

Type "macharden -f html -o report.html"
Sleep 200ms
Enter
Sleep 2500ms
