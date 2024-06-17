# Kontrollime, kas csv fail on olemas
$scriptDir = $PSScriptRoot
$csvFilePath = Join-Path -Path $scriptDir -ChildPath "new_users_accounts.csv"
if (-not (Test-Path $csvFilePath)) {
    Write-Host "Fail new_users_accounts.csv puudub!" -ForegroundColor Red
    exit
}

# Loeme csv failist andmed

$accounts = Import-Csv $csvFilePath -Delimiter ";" | Select-Object -Property Eesnimi, Perenimi, Kasutajanimi, Parool, Kirjeldus -Skip 1


# Funktsioon kasutaja kustutamiseks
function Remove-User {
    param ([PSCustomObject]$account)
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

# Küsime kasutajalt, kas soovitakse kasutajaid lisada või kustutada
$action = Read-Host "Mida soovite kasutajakontodega teha?`n(L) Lisada`n(K) Kustutada"

# Käivitame vastava tegevuse sõltuvalt valikust
if ($action -eq "L") {
    foreach ($account in $accounts) {
        New-User -account $account
    }
} elseif ($action -eq "K") {
    # Loome massiiv, kus on loodud kasutajad
    $createdUsers = @()
    foreach ($account in $accounts) {
        $existingUser = Get-LocalUser -Name $account.Kasutajanimi -ErrorAction SilentlyContinue
        if ($existingUser) {
            $createdUsers += $account
        }
    }

    # Näitame loodud kasutajad, keda saab kustutada
    Write-Host "Loodud kasutajad, keda saab kustutada:"
    for ($i = 0; $i -lt $createdUsers.Count; $i++) {
        Write-Host "  $($i + 1). $($createdUsers[$i].Kasutajanimi)"
    }

    # Küsime kasutajalt, millise kasutaja kustutada
    $userNumber = Read-Host "Sisesta kustutatava kasutaja number"
    $account = $createdUsers[$userNumber - 1]
    Remove-User -account $account
} else {
    Write-Host "Tundmatu valik! Valige kas L (lisamine) või K (kustutamine)." -ForegroundColor Red
}
