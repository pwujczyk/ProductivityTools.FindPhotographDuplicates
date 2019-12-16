class PhotographDetails{
	[string]$path
	[string]$dateTaken
	[int]$size
	[string]$fileBaseName
	[string]$extension
}

class Duplicate{
	[PhotographDetails]$master
	[PhotographDetails]$slave
}

function GetDateAndTimeFromImage($photographPath)
{
    $image = New-Object System.Drawing.Bitmap("$photographPath")
    try{
	    $date = $image.GetPropertyItem(36867).value[0..9]
	    $arYear = [Char]$date[0],[Char]$date[1],[Char]$date[2],[Char]$date[3]  
	    $arMonth = [Char]$date[5],[Char]$date[6]  
	    $arDay = [Char]$date[8],[Char]$date[9]  
	    $strYear = [String]::Join('',$arYear)  
	    $strMonth = [String]::Join('',$arMonth)   
	    $strDay = [String]::Join('',$arDay)  
	    $DateTaken =$strYear+"."+$strMonth + "." + $strDay
	    
	    $time = $image.GetPropertyItem(36867).value[11..18]
	    $arHour = [Char]$time[0],[Char]$time[1]
	    $arMinute = [Char]$time[3],[Char]$time[4]  
	    $arSecond = [Char]$time[6],[Char]$time[7]  
	    $strHour = [String]::Join('',$arHour)  
	    $strMinute = [String]::Join('',$arMinute)   
	    $strSecond = [String]::Join('',$arSecond)  
	    $TimeTaken = $strHour + "." + $strMinute + "." + $strSecond
	    $FullDate = $DateTaken + "_" + $TimeTaken
     }
	catch
	{
		$FullDate=(Get-ChildItem $photographPath).BaseName
		Write-Error "Date taken haven't been found, probably picture is image (doesn't have the date taken property) Name set as [$FullDate] ($photographPath)"
	}

	$image.Dispose()
     
	return $FullDate
}

function GetPhotographSize{
	[cmdletbinding()]
	param([string]$photographPath)
	
	$file=Get-ChildItem -LiteralPath $photographPath
	$size=$file.Length
	return $size;
}


function GetPhotographFileBaseName{
	[cmdletbinding()]
	param([string]$photographPath)

	$file=Get-ChildItem -LiteralPath $photographPath
	$fileName=$file.BaseName
	return $fileName
}


function GetPhotographExtension{
	[cmdletbinding()]
	param([string]$photographPath)

	$file=Get-ChildItem -LiteralPath $photographPath
	$extension=$file.Extension
	return $extension
}


function LoadTable{
	[cmdletbinding()]
	param([string]$path)

	Write-Verbose "Searching for Photographs in directory $path"

	$photographDetailsArray=@()

	$items=Get-ChildItem -Path $path -Recurse -Filter *.jpg | select FullName
	foreach($item in $items)
	{
		$photographDetails=New-Object PhotographDetails

		$photographDetails.path=$item.FullName
		$photographDetails.dateTaken=GetDateAndTimeFromImage -photographPath $photographDetails.path
		$photographDetails.size=GetPhotographSize -photographPath $photographDetails.path
		$photographDetails.fileBaseName=GetPhotographFileBaseName -photographPath $photographDetails.path
		$photographDetails.extension=GetPhotographExtension -photographPath $photographDetails.path
		Write-Verbose "Found photograph in directory $($photographDetails.path). DateTaken: $($photographDetails.dateTaken), Size: $($photographDetails.size), FileName $($photographDetails.fileBaseName),  Extension $($photographDetails.extension)"
		$photographDetailsArray+=$photographDetails
	}

	return $photographDetailsArray
}

function CompareTables{
	[cmdletbinding()]
	param($MasterTable,$SlaveTable,[switch]$CompareSize,[switch]$CompareFileName)

	Write-Verbose "Comparing Photographs"
	
	$duplicatesFromSlaveTable=@()

	foreach($master in $MasterTable)
	{
		foreach($slave in $SlaveTable)
		{
			[bool]$dateTimeEqual=$false
			[bool]$sizeEqual=$false
			[bool]$nameEqual=$false
			if ($master.dateTaken -eq $slave.dateTaken)
			{
				$dateTimeEqual=$true
			}

			if ($CompareSize.IsPresent -and $master.size -eq $slave.size)
			{
				$sizeEqual=$true
			}

			if($CompareFileName.IsPresent -and $master.fileBaseName -eq $slave.fileBaseName)
			{
				$nameEqual=$true
			}

			if ($dateTimeEqual -eq $true -and 
			($CompareSize.IsPresent -eq $false -or $sizeEqual -eq $true) -and
			($CompareFileName.IsPresent -eq $false -or $nameEqual -eq $true))
			{
				Write-Verbose "File $($slave.Path) the same as $($master.Path). Compared by DateTaken: True, Size: $($CompareSize.IsPresent) FileName $($CompareFileName.IsPresent)"
				$duplicate=New-Object Duplicate
				$duplicate.master=$master
				$duplicate.slave=$slave
				$duplicatesFromSlaveTable+=$duplicate
			}
		}
	}
	return $duplicatesFromSlaveTable
}

function CopyFilesToResultDirectory{
	[cmdletbinding()]
	param($duplicatesFromSlaveTable,[string]$resultDirectory,[switch]$compareFileName)

	If (Test-Path -Path $resultDirectory -PathType Container)
	{
		throw "Result directory [$resultDirectory] exists, please remove it."		
	}
	else
	{
		New-Item -Path $resultDirectory -ItemType directory |Out-Null
	}

	[int]$id=0;
	foreach($duplicate in $duplicatesFromSlaveTable)
	{
		$id++
		if ($compareFileName.IsPresent)
		{
			$sourcePath=$duplicate.master.path
			$resultPath="$resultDirectory\$id" + "_" + $($duplicate.master.fileBaseName) +"_master"+$($duplicate.master.extension)
			Copy-Item -Path $sourcePath -Destination $resultPath

			$sourcePath=$duplicate.master.path
			$resultPath="$resultDirectory\$id" + "_" + $($duplicate.slave.fileBaseName) +"_slave"+$($duplicate.slave.extension)
			Copy-Item -Path $sourcePath -Destination $resultPath
		}
		else {
			$sourcePath=$duplicate.master.path
			$resultPath="$resultDirectory\$id" + "_" + $($duplicate.master.dateTaken) +"_master"+$($duplicate.master.extension)
			Copy-Item -Path $sourcePath -Destination $resultPath

			$sourcePath=$duplicate.master.path
			$resultPath="$resultDirectory\$id" + "_" + $($duplicate.slave.dateTaken) +"_slave"+$($duplicate.slave.extension)
			Copy-Item -Path $sourcePath -Destination $resultPath
		}
	}
}

function ProcessDuplicates{
	[cmdletbinding()]
	param([switch]$CompareSize,[switch]$CompareFileName,[string]$PathMaster,[string]$PathSlave,[string]$resultDirectory,[switch]$DeleteSlaveDuplicates)

	$masterTable=LoadTable $PathMaster
	$slaveTable=LoadTable $PathSlave

	$duplicatesFromSlaveTable=CompareTables -MasterTable $masterTable -SlaveTable $slaveTable -CompareSize:$CompareSize -CompareFileName:$CompareFileName

	if ([string]::IsNullOrEmpty($resultDirectory) -eq $false)
	{
		Write-Verbose "Result Directory is present, copying files to result directory"
		CopyFilesToResultDirectory -duplicatesFromSlaveTable $duplicatesFromSlaveTable -resultDirectory $resultDirectory -compareFileName:$CompareFileName
	}
	else
	{
		Write-Verbose "ResultDirectory is not present"
	}

	
	if($DeleteSlaveDuplicates.IsPresent)
	{
		Write-Verbose "DeleteSlaveDuplicate is present, removing files"
		foreach($duplicate in $duplicatesFromSlaveTable)
		{
			$path=$duplicate.slave.path
			Write-Verbose "Removing $path"
			Remove-Item -LiteralPath $path -Force -Verbose
		}
	}
	else
	{
		Write-Verbose "DeleteSlaveDuplicate is not present not deleting"
	}

	$result=$duplicatesFromSlaveTable |ForEach-Object {$_.slave.path}
	return $result
}

function LoadSystemDrawing()
{
	Write-Verbose "Loading system drawing assembly"
	[reflection.assembly]::loadfile( "C:\Windows\Microsoft.NET\Framework\v2.0.50727\System.Drawing.dll") |Out-Null
}

function Find-PhotographDuplicates {
	[cmdletbinding()]
	param([switch]$CompareSize,[switch]$CompareFileName,[string]$PathMaster,[string]$PathSlave,[string]$ResultDirectory,[switch]$DeleteSlaveDuplicatess)

	LoadSystemDrawing

	$result=ProcessDuplicates -CompareSize:$CompareSize -CompareFileName:$CompareFileName -PathMaster $PathMaster -PathSlave $PathSlave -resultDirectory $ResultDirectory -DeleteSlaveDuplicates:$DeleteSlaveDuplicatess
	return $result
}

function ProcessDuplicatesInDirectory
{
	[cmdletbinding()]
	param([switch]$CompareSize,[switch]$CompareFileName,[string]$Path)

}

function GenerateKey {

	[cmdletbinding()]
	param($photo,[switch]$CompareSize,[switch]$CompareFileName)
	
	$key = $photo.DateTaken
	if ($CompareSize.IsPresent)
	{
		$key+=$photo.Size
	}
	if ($CompareFileName.IsPresent)
	{
		$key+=$photo.FileName
	}
	return $key
}

function Find-PhotographDuplicatesInDirectory {
	[cmdletbinding()]
	param([switch]$CompareSize,[switch]$CompareFileName,[string]$Path, [string]$ResultDirectory,[switch]$DeleteDuplicates)

	LoadSystemDrawing
	
	$photoTable=LoadTable $Path
	
	$uniqueElements=@{}
	
	$id=0
	foreach($photo in $photoTable)
	{
		Write-Progress -Activity "Process found photographs" 
		$key=GenerateKey $photo -CompareSize:$CompareSize -CompareFileName:$CompareFileName
		if ($uniqueElements.ContainsKey($key))
		{			
			Write-Verbose "Found duplicate"
			Write-Verbose "$($uniqueElements[$key])"
			Write-Verbose "$($photo.path)"
			$pathToDuplicate=$uniqueElements[$key]
			$photoFullname=$($photo.Path)
			Write-Verbose "Duplicate found $photoFullname"
			if ($ResultDirectory -ne "")
			{
				$resultPathFirst="$ResultDirectory\$id" + "_fristPhoto"+$($photo.Extension)
				$resultPathSecond="$ResultDirectory\$id" +"_secondPhoto"+$($photo.Extension)
				Copy-Item -Path $photoFullname -Destination $resultPathFirst
				Copy-Item -Path $photoFullname -Destination $resultPathSecond
			}
			
			if ($DeleteDuplicates.IsPresent)
			{

				Write-Verbose "Removing duplicate $photoFullname"
				Remove-Item $photoFullname
			}
		}
		else
		{
			$uniqueElements.Add($key, $($photo.Path))
		}
		$id++;
	}
}

Export-ModuleMember Find-PhotographDuplicates
Export-ModuleMember Find-PhotographDuplicatesInDirectory