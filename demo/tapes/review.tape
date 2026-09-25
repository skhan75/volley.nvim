# The agent has finished. Open the review, walk the files it touched, and
# land on the first change in the one you pick.
Output assets/review.gif
Source demo/tapes/_settings.tape

Hide
Type "cd ~/app" Enter
Type "cp ~/steps/billing.py ~/steps/routes.py ~/steps/settings.py src/" Enter
Type "clear && nvim -u $VOLLEY_ROOT/demo/init.lua src/billing.py" Enter
Sleep 2500ms
Show

Sleep 1500ms
Type " v"
Sleep 2500ms
Down
Sleep 2s
Down
Sleep 2s
Up
Sleep 1500ms
Enter
Sleep 3s
