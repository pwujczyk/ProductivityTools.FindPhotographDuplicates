clear
cd $PSScriptRoot
Import-Module .\ProductivityTools.FindPhotographDuplicates.psm1 -Force
#cd "d:\Trash\robyg\"
#Find-PhotographDuplicates -PathMaster 'D:\Photographs\Processed\zdjeciaDone\2010.06.28 zakopane\' -PathSlave 'D:\Photographs\Processing\komorska\zdjecia z onedrive\publiczny\2010.06.29 Zakopane - Rysy `[wt`] @\' -DeleteSlaveDuplicates -CompareSize -Verbose
#Find-PhotographDuplicates -PathMaster "e:\prism" -PathSlave "d:\Photographs\ToValidateWithPrism\" -ResultDirectory "d:\trash\x3" -Verbose -CompareSize -DeleteSlaveDuplicatess
#Find-PhotographDuplicatesInDirectory -Path d:\Photographs\processing2\ -CompareSize -ResultDirectory "d:\Trash\a1" -DeleteDuplicates -Verbose
#Find-PhotographDuplicatesInDirectory -Path d:\Photographs\processing2\ -CompareSize -ResultDirectory "d:\Trash\a1" -Verbose


Prepare-PhotographDuplicateFile -Verbose -Path "d:\Photographs\Wyjazd krakow\"