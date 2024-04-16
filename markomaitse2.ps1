# Funktsioon diakriitikumide eemaldamiseks
function Remove-Diacritics {
    param ([String]$src = [String]::Empty)
    $normalized = $src.Normalize([Text.NormalizationForm]::FormD)
    $sb = New-Object Text.StringBuilder
    $normalized.ToCharArray() | ForEach-Object { 
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$sb.Append($_)
        }
    }
    $sb.ToString()
  }
  
  # Funktsioon logifaili kirjutamiseks
  function Write-LogEntry {
      param (
          [string]$logFilePath,
          [string]$entry
      )
      $timestamp = Get-Date -Format "dd.MM.yyyy HH:mm:ss"
      Add-Content -Path $logFilePath -Value "$timestamp;$entry"
  }
  
  # Kontrollime, kas skripti käivitatakse administraatori õigustes
  if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
      Write-Host "Skripti käivitamiseks on vajalikud administraatori õigused!" -ForegroundColor Red
      exit
  }
  
  # Kontrollime, kas csv fail on olemas
  if (-not (Test-Path "new_users_accounts.csv")) {
      Write-Host "Fail new_users_accounts.csv puudub!" -ForegroundColor Red
      exit
  }
  
  # Loeme csv failist andmed
  $accounts = Import-Csv "new_users_accounts.csv" -Delimiter ";" | Select-Object -Property Eesnimi, Perenimi, Kasutajanimi, Parool, Kirjeldus
  
  # Kustutame kasutajakontod
  function Remove-UserAccounts {
      foreach ($account in $accounts) {
          $existingUser = Get-LocalUser -Name $account.Kasutajanimi -ErrorAction SilentlyContinue
          if ($existingUser) {
              Remove-LocalUser -Name $account.Kasutajanimi -Confirm:$false
              Write-Host "Kasutaja $($account.Kasutajanimi) kustutatud."
              $userProfilePath = Join-Path -Path "C:\Users" -ChildPath $account.Kasutajanimi
              if (Test-Path $userProfilePath) {
                  Remove-Item -Path $userProfilePath -Recurse -Force
                  Write-Host "Kasutaja kodukaust $($account.Kasutajanimi) kustutatud."
              }
          } else {
              Write-Host "Kasutajat $($account.Kasutajanimi) ei leitud, seega ei saa seda kustutada."
          }
      }
  }
  
  # Lisame kasutajakontod
  function Add-UserAccounts {
      foreach ($account in $accounts) {
          # Kontrollime kasutajanime pikkust
          if ($account.Kasutajanimi.Length -gt 20) {
              Write-Host "Kasutajat $($account.Kasutajanimi) ei lisatud, kuna kasutajanimi on liiga pikk (üle 20 märgi)."
              Write-LogEntry -logFilePath "accounts_exists.log" -entry "KONTONIMI;$($account.Eesnimi);$($account.Perenimi);$($account.Kasutajanimi);$($account.Parool);$($account.Kirjeldus)"
              continue
          }
          # Kontrollime kirjelduse pikkust
          $description = $account.Kirjeldus
          if ($description.Length -gt 48) {
              $description = $description.Substring(0, 40) + "..."
          }
          $existingUser = Get-LocalUser -Name $account.Kasutajanimi -ErrorAction SilentlyContinue
          if (-not $existingUser) {
              $password = ConvertTo-SecureString -String $account.Parool -AsPlainText -Force
              $displayName = "$($account.Eesnimi) $($account.Perenimi)"
              New-LocalUser -Name $account.Kasutajanimi -FullName $displayName -Password $password -Description $description -PasswordNeverExpires:$true -AccountNeverExpires:$true -UserMayNotChangePassword:$false
              Write-Host "Kasutaja $($account.Kasutajanimi) lisatud."
          } else {
              Write-Host "Kasutajat $($account.Kasutajanimi) ei lisatud, kuna kasutaja on juba olemas."
              Write-LogEntry -logFilePath "accounts_exists.log" -entry "DUPLIKAAT;$($account.Eesnimi);$($account.Perenimi);$($account.Kasutajanimi);$($account.Parool);$($account.Kirjeldus)"
          }
      }
  }
  
  # Küsime kasutajalt, kas soovitakse kasutajaid lisada või kustutada
  $action = Read-Host "Mida soovite kasutajakontodega teha?`n(L) Lisada`n(K) Kustutada"
  
  # Käivitame vastava tegevuse sõltuvalt valikust
  if ($action -eq "L") {
      Add-UserAccounts
  } elseif ($action -eq "K") {
      Remove-UserAccounts
  } else {
      Write-Host "Tundmatu valik! Valige kas L (lisamine) või K (kustutamine)." -ForegroundColor Red
  }
