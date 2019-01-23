clear
cd $PSScriptRoot
Import-Module .\Find-PhotographDuplicates.psm1 -Force
#cd "d:\Trash\robyg\"
Find-PhotographDuplicates -PathMaster 'D:\Photographs\Processed\zdjeciaDone\2010.06.28 zakopane\' -PathSlave 'D:\Photographs\Processing\komorska\zdjecia z onedrive\publiczny\2010.06.29 Zakopane - Rysy `[wt`] @\' -DeleteSlaveDuplicates -CompareSize -Verbose
#Find-PhotographDuplicates -PathMaster "d:\Trash\Master\" -PathSlave "d:\Trash\Slave\" -ResultDirectory "d:\trash\resultA\xxx" -Verbose
