@echo off

REM Navigate to the repository folder
cd "C:\Users\Admin\Desktop\rl\Eduflex"

REM Fetch the latest changes from upstream (original repository)
git fetch upstream

REM Checkout the main branch
git checkout main

REM Merge upstream changes into your local main branch
git merge upstream/main --allow-unrelated-histories

REM Push the changes to your fork (if needed)
git push origin main

REM Log the last commit to verify merge
git log -1 --oneline

REM Optional: Log output to a file (optional)
>> "C:\Users\Admin\Desktop\rl\Eduflex\pull.log"
