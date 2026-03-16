const String accessPointStatusVarName = "ACCESSPOINT_ABS";

class PSScriptRepo {
  static String accessPointStatus = """
  [Windows.System.UserProfile.LockScreen,Windows.System.UserProfile,ContentType=WindowsRuntime] | Out-Null
  Add-Type -AssemblyName System.Runtime.WindowsRuntime

\$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | ? { \$_.Name -eq 'AsTask' -and \$_.GetParameters().Count -eq 1 -and \$_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]

  # gets connection profile starting with "Ethernet"
\$connectionProfile = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetConnectionProfiles() | where {\$_.profilename -match "Ethernet"} | Select-Object -last 1
\$tetheringManager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager,Windows.Networking.NetworkOperators,ContentType=WindowsRuntime]::CreateFromConnectionProfile(\$connectionProfile)


    \$tetheringManager.TetheringOperationalState -eq 1
  """;

  static String hotspotActivate = """
  [Windows.System.UserProfile.LockScreen,Windows.System.UserProfile,ContentType=WindowsRuntime] | Out-Null

Add-Type -AssemblyName System.Runtime.WindowsRuntime

\$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | ? { \$_.Name -eq 'AsTask' -and \$_.GetParameters().Count -eq 1 -and \$_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]

Function Await(\$WinRtTask, \$ResultType) {
    \$asTask = \$asTaskGeneric.MakeGenericMethod(\$ResultType)
    \$netTask = \$asTask.Invoke(\$null, @(\$WinRtTask))
    \$netTask.Wait(-1) | Out-Null
    \$netTask.Result
}

Function AwaitAction(\$WinRtAction) {
    \$asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | ? { \$_.Name -eq 'AsTask' -and \$_.GetParameters().Count -eq 1 -and !\$_.IsGenericMethod })[0]
    \$netTask = \$asTask.Invoke(\$null, @(\$WinRtAction))
    \$netTask.Wait(-1) | Out-Null
}

# gets connection profile starting with "Ethernet"
\$connectionProfile = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetConnectionProfiles() | where {\$_.profilename -match "Ethernet"} | Select-Object -last 1

# Creates a thetering manager that shares the Ethernet connectionProfile
\$tetheringManager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager,Windows.Networking.NetworkOperators,ContentType=WindowsRuntime]::CreateFromConnectionProfile(\$connectionProfile)

# Configures the hotspot
\$configuration = new-object Windows.Networking.NetworkOperators.NetworkOperatorTetheringAccessPointConfiguration
\$configuration.Ssid = <YOUR SSID HERE>
\$configuration.Passphrase = <PASSWORD HERE>
\$configuration.Band = 1 # number 1 enables 2.4 Ghz Hotspot

# Check whether Mobile Hotspot is enabled
\$tetheringManager.TetheringOperationalState

# Set Hotspot configuration
AwaitAction (\$tetheringManager.ConfigureAccessPointAsync(\$configuration))


# Start Mobile Hotspot
Await (\$tetheringManager.StartTetheringAsync()) ([Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult])
  """;


}