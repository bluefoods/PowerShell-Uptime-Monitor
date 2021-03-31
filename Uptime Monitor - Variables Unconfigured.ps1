# Create an array that contains hostnames.
$names = @("host1","host2","host3","etc")

# Define email address to send and receive alerts
$fromAddress = "from@whatever.org"
$toAddress = "to@whatever.org"

# Define smtp server and port to send alerts using the $fromAddress
$smtpServer = "smtpServerHostname"
$smtpPort = 587

$hostDownEmailBody=@"
<head>
   <style type='text/css'>
       body {
           font-family: Calibri;
           font-size: 11pt;
           color: red;
       }
       span{
           font-family: Calibri;
           font-size: 11pt;
           color: black;
       }
   </style>
</head>
<body>
    <p><span>$name </span><b>has gone down!</b></p>
</body>
"@

# Create an empty array that data will be added to in the loop below, the resulting array will be used to push ping and uptime results too and is needed for the XAML GUI.
$ResultsTableArray = @()

# Create an empty array that stored ping result data will be added to later on, [System.Collections.ArrayList] allows the size to not be fixed.
# Create intial ping data, true 6x, to begin the stored ping data
# Create a sample DownStatus array to compare with PingData for confirmation that a host has been down.
[System.Collections.ArrayList]$PingData = @()
[System.Collections.ArrayList]$InitialData = 1,1,1,1,1,1
[System.Collections.ArrayList]$DownStatus = 0,0,0,0,0,0


# Loop through each hostname provided in $names and add properties to $array that will be displayed as columns in a table in the GUI.
foreach ($name in $names) {
    $object = New-Object System.Object
    #$object | Add-Member -type NoteProperty -name Index -Value $index1
    $object | Add-Member -type NoteProperty -name Host -Value $name
    $object | Add-Member -type NoteProperty -name IP -Value "x.x.x.x"
    $object | Add-Member -type NoteProperty -name PingStatus -Value "?"
    $object | Add-Member -type NoteProperty -name Uptime -Value "dhms"
    $ResultsTableArray += $object
    $PingData.Add($InitialData) #this line causes print output of 0-18 on start of script run
}


while ($true) {   # Endless while loop
    
    # Define index variable for second loop (ping test loop)
    $index2 = 0 

    foreach ($name in $names) { 

        #Write-Host $index2

            if ( Test-Connection -ComputerName $name -Count 1 -ErrorAction SilentlyContinue )  { 
                
                # Get-CimInstance needs to be run with domain admin privileges

                #$wmi = Get-CimInstance Win32_OperatingSystem -computer $name 
                #$LBTime = $wmi.Lastbootuptime
                #[TimeSpan]$uptime = New-TimeSpan $LBTime $(get-date)

                $ResultsTableArray[$index2].IP = Test-Connection -ComputerName $name -Count 1 | Select-Object -ExpandProperty IPV4Address
                $ResultsTableArray[$index2].PingStatus = "Up"
                $ResultsTableArray[$index2].Uptime = "$($uptime.days)d$($uptime.hours)h$($uptime.minutes)m$($uptime.seconds)s"

                # Build the ping data storage arrays
                $null, $rest = $PingData[$index2]
                [System.Collections.ArrayList]$PingData[$index2] = $rest
                [void]$PingData[$index2].Add(1)

            } else { 
                $ResultsTableArray[$index2].IP = Test-Connection -ComputerName $name -Count 1 | Select-Object IPV4Address
                $ResultsTableArray[$index2].PingStatus = "Down"
                $ResultsTableArray[$index2].Uptime = "n/a"

                # Build the ping data storage arrays
                $null, $rest = $PingData[$index2]
                [System.Collections.ArrayList]$PingData[$index2] = $rest
                [void]$PingData[$index2].Add(0)
            } 

            # Compare-Object will return $null when comparing arrays that are equal but indexed in different order, i.e. it returns $null for (0,0,1) vs (0,1,0), but here the array we compare with is (0,0,0,0,0,0) so order does not matter anyway.
            # Define conditions for excluding particular hosts from Send-Mailmessage action if they do not warrant an email alert when down.
            if (($name -eq "host1") -And ((Compare-Object -ReferenceObject $PingData[$index2] -DifferenceObject $DownStatus) -eq $null)) {
                Write-Host "host1 down"
            }

            elseif (($name -eq "host2") -And ((Compare-Object -ReferenceObject $PingData[$index2] -DifferenceObject $DownStatus) -eq $null)) {
                Write-Host "host2 down"
            }

            elseif (($name -ne "host1" -or $name -ne "host2") -And ((Compare-Object -ReferenceObject $PingData[$index2] -DifferenceObject $DownStatus) -eq $null))  { 
                Send-Mailmessage -smtpServer $smtpServer -Port $smtpPort -from $fromAddress -to $toAddress -subject "$name has gone down!" -body $hostDownEmailBody -BodyAsHTML -priority High
            }

            else {

            } 


        $index2 ++
    } 

    #Write-Host "";

    $ResultsTableArray | Format-Table
    Start-Sleep -s 60

}