$fileContentBytes = Get-Content -Path 'C:\Users\admin.GAW00\Desktop\CurrentCerts\StaticSite.cer' -AsByteStream # -7 , for 5.1 - "-Encoding Byte"

[System.Convert]::ToBase64String($fileContentBytes) | Out-File "C:\Users\admin.GAW00\Desktop\CurrentCerts\Staticcert.txt"
