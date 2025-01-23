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

function Load-PhotographDataFromFile {
	[cmdletbinding()]
	param(
		[Parameter(Mandatory=$true)]
		[string]$FilePath
	)

	Write-Verbose "Loading photograph data from CSV file: $FilePath"
	try {
		$importedData = Import-Csv -Path $FilePath
		$photographDetailsArray = @()
		foreach ($row in $importedData) {
			$details = [PhotographDetails]::new()
			$details.path = $row.path
			$details.dateTaken = $row.dateTaken
			# Ensure 'size' is converted to integer, as Import-Csv might read it as string
			$details.size = [int]$row.size 
			$details.fileBaseName = $row.fileBaseName
			$details.extension = $row.extension
			$photographDetailsArray += $details
		}
		return $photographDetailsArray
	}
	catch {
		Write-Error "Failed to load or parse photograph data from '$FilePath'. Error: $($_.Exception.Message)"
		throw "Failed to load master data from file '$FilePath'." # Re-throw to stop execution in ProcessDuplicates
	}
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

function CreateResultDirectory{
	[CmdletBinding()]
	param([string]$resultDirectory)

	If (Test-Path -Path $resultDirectory -PathType Container)
	{
		throw "Result directory [$resultDirectory] exists, please remove it."		
	}
	else
	{
		New-Item -Path $resultDirectory -ItemType directory |Out-Null
	}
}

function CopyFilesToResultDirectory{
	[cmdletbinding()]
	param($duplicatesFromSlaveTable,[string]$resultDirectory,[switch]$compareFileName)

	CreateResultDirectory -resultDirectory $resultDirectory

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
	param(
		[switch]$CompareSize,
		[switch]$CompareFileName,
		[string]$PathMaster,
		[string]$PathMasterDuplicateFile, # New parameter
		[string]$PathSlave,
		[string]$resultDirectory,
		[switch]$DeleteSlaveDuplicates
	)

	$masterTable = $null
	if (-not [string]::IsNullOrEmpty($PathMasterDuplicateFile)) {
        if (Test-Path -LiteralPath $PathMasterDuplicateFile -PathType Leaf) {
            Write-Verbose "Loading master table from file: $PathMasterDuplicateFile"
            $masterTable = Load-PhotographDataFromFile -FilePath $PathMasterDuplicateFile
        } else {
            throw "Master duplicate file specified ('$PathMasterDuplicateFile') but not found or is not a file."
        }
    } elseif (-not [string]::IsNullOrEmpty($PathMaster)) {
        Write-Verbose "Loading master table from directory: $PathMaster"
        $masterTable = LoadTable $PathMaster
    } else {
        throw "Internal error: Neither -PathMaster nor -PathMasterDuplicateFile was effectively provided to ProcessDuplicates."
    }
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
	[reflection.assembly]::loadfile( "c:\Windows\Microsoft.NET\Framework\v4.0.30319\System.Drawing.dll") |Out-Null
}

function Find-PhotographDuplicates {
	[cmdletbinding(DefaultParameterSetName='PathInput')]
	param(
		[Parameter(ParameterSetName='PathInput')]
		[Parameter(ParameterSetName='FileInput')]
		[switch]$CompareSize,

		[Parameter(ParameterSetName='PathInput')]
		[Parameter(ParameterSetName='FileInput')]
		[switch]$CompareFileName,

		[Parameter(Mandatory=$true, ParameterSetName='PathInput', HelpMessage="Path to the master directory of photographs.")]
		[string]$PathMaster,

		[Parameter(Mandatory=$true, ParameterSetName='FileInput', HelpMessage="Path to the file containing master photograph data (e.g., from Prepare-PhotographDuplicateFile).")]
		[string]$PathMasterDuplicateFile,

		[Parameter(Mandatory=$true, ParameterSetName='PathInput')]
		[Parameter(Mandatory=$true, ParameterSetName='FileInput')]
		[string]$PathSlave,

		[Parameter(ParameterSetName='PathInput')]
		[Parameter(ParameterSetName='FileInput')]
		[string]$ResultDirectory,

		[Parameter(ParameterSetName='PathInput')]
		[Parameter(ParameterSetName='FileInput')]
		[switch]$DeleteSlaveDuplicatess
	)

	LoadSystemDrawing

	$result=ProcessDuplicates -CompareSize:$CompareSize -CompareFileName:$CompareFileName -PathMaster $PathMaster -PathMasterDuplicateFile $PathMasterDuplicateFile -PathSlave $PathSlave -resultDirectory $ResultDirectory -DeleteSlaveDuplicates:$DeleteSlaveDuplicatess
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
	CreateResultDirectory -resultDirectory $ResultDirectory
	
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

function Prepare-PhotographDuplicateFile {
	[cmdletbinding()]
	param(
		[Parameter(Mandatory=$true, ValueFromPipeline=$true, HelpMessage="Path to the directory containing photographs.")]
		[string]$Path
	)

	LoadSystemDrawing # Ensure System.Drawing is loaded, as LoadTable indirectly uses it.

	Write-Verbose "Preparing photograph data from path: $Path"
	$photographData = LoadTable -Path $Path

	if ($photographData -and $photographData.Count -gt 0) {
		$outputFileName = "$Path\PhotographDuplicateCompareFile.txt"
		Write-Verbose "Saving photograph data to $outputFileName (current directory)"
		$photographData | ConvertTo-Csv -NoTypeInformation | Out-File -FilePath $outputFileName -Encoding UTF8
		Write-Host "Photograph data for $($photographData.Count) items saved to $outputFileName"
	} else {
		Write-Warning "No photograph data found or generated from path: $Path. '$outputFileName' was not created."
	}
}




Export-ModuleMember Find-PhotographDuplicates
Export-ModuleMember Find-PhotographDuplicatesInDirectory
Export-ModuleMember Prepare-PhotographDuplicateFile