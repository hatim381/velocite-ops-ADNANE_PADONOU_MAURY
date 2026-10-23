<#
.SYNOPSIS
  Sauvegarde la base PostgreSQL d'un environnement dans un fichier .sql, sur
  votre poste, dans le dossier sauvegardes/ (ignoré par Git).

.DESCRIPTION
  1. pg_dump tourne dans le pod postgres et écrit /tmp/sauvegarde.sql
     (options --clean --if-exists : la restauration remplace les tables
     existantes au lieu de se heurter à elles).
  2. kubectl cp rapatrie ce fichier sur le poste, horodaté.
  3. Le fichier est effacé du pod : son /tmp est un petit volume (64 Mi).
  Le fichier ne passe jamais par un pipe PowerShell : Windows PowerShell 5.1
  y abîmerait les accents. Il contient des données personnelles : il ne va
  jamais dans Git.

.EXAMPLE
  .\scripts\sauvegarder.ps1
  .\scripts\sauvegarder.ps1 -Env prod
  pwsh ./scripts/sauvegarder.ps1          # macOS, Linux
#>
param([ValidateSet("dev", "prod")][string]$Env = "dev")
. "$PSScriptRoot/commun.ps1"

$ns = "velocite-$Env"
$dossier = Join-Path $Racine "sauvegardes"
New-Item -ItemType Directory -Force -Path $dossier | Out-Null
$horodatage = Get-Date -Format "yyyyMMdd-HHmmss"
$fichier = "sauvegardes/velocite-$Env-$horodatage.sql"

$dump = 'PGPASSWORD=$(cat /run/secrets/postgres_password) pg_dump -U postgres -d velocite --clean --if-exists -f /tmp/sauvegarde.sql'

Invoke-Etape "Export PostgreSQL dans le pod" {
    Invoke-Commande kubectl -n $ns exec statefulset/postgres '--' sh -c $dump
}
Invoke-Etape "Copie de la sauvegarde sur le poste" {
    Push-Location $Racine
    try {
        Invoke-Commande kubectl cp "$ns/postgres-0:/tmp/sauvegarde.sql" $fichier
    } finally {
        Pop-Location
    }
}
Invoke-Etape "Nettoyage du fichier temporaire du pod" {
    Invoke-Commande kubectl -n $ns exec statefulset/postgres '--' rm -f /tmp/sauvegarde.sql
}

$taille = (Get-Item (Join-Path $Racine $fichier)).Length
Write-Host ""
Write-Host ("Sauvegarde créée : {0} ({1:n0} octets)" -f $fichier, $taille) -ForegroundColor Green
Show-Releve
