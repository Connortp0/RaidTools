@echo off
chcp 65001
del RaidTools.lua
echo Writing to file
echo BList = {>> RaidTools.lua
for /f "tokens=*" %%a in (input.txt) do (
  echo ["%%a"] = true,>> RaidTools.lua
  echo Added %%a
)
echo }>> RaidTools.lua
echo Completed
pause