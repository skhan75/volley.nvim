# Comment on a selection and on a single line, then look at the queue.
Output assets/comment.gif
Source demo/tapes/_settings.tape

Hide
Type "cd ~/app" Enter
Type "cp ~/steps/billing.py ~/steps/routes.py ~/steps/settings.py src/" Enter
Type "clear && nvim -u $VOLLEY_ROOT/demo/init.lua src/billing.py" Enter
Sleep 2500ms
Type "15G"
Sleep 500ms
Show

Sleep 1s
Type "Vj"
Sleep 1s
Type " va"
Sleep 800ms
Type "where does 0.1 come from?"
Sleep 600ms
Enter
Sleep 2500ms
Type "21G"
Sleep 800ms
Type " va"
Sleep 800ms
Type "is code=None the right default?"
Sleep 600ms
Enter
Sleep 2500ms
Type " vq"
Sleep 3s
Escape
Sleep 1s
