clear
cd $PSScriptRoot
Import-Module .\Find-PhotographDuplicates.psm1 -Force
cd "d:\Trash\robyg\"
Find-PhotographDuplicates -PathMaster "d:\Trash\Master\" -PathSlave "d:\Trash\Slave\" -ResultDirectory "d:\trash\resultA\xxx" -Verbose
