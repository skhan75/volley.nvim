# With no agent window in sight, volley runs the command instead and puts
# the answer in a split.
Output assets/reply.gif
Source demo/tapes/_settings.tape

Hide
Type "cd ~/app" Enter
Type "cp ~/steps/billing.py ~/steps/routes.py ~/steps/settings.py src/" Enter
Type "clear && nvim -u $VOLLEY_ROOT/demo/init.lua src/billing.py" Enter
Sleep 2500ms
Type "15G"
Sleep 300ms
Type " va"
Sleep 300ms
Type "where does 0.1 come from?"
Enter
Sleep 1s
Show

Sleep 1500ms
Type " vs"
Sleep 4s
Sleep 3s
