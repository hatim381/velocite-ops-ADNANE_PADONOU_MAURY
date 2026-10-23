<#
.SYNOPSIS
  Restaure la base PostgreSQL d'un environnement depuis un fichier .sql de
  sauvegardes/ (écrit par sauvegarder.ps1).

.DESCRIPTION
  1. kubectl cp envoie le fichier dans le /tmp du pod postgres.
  2. psql le rejoue, en s'arrêtant à la première erreur (ON_ERROR_STOP) :
     les tables sont supprimées puis recréées avec leurs lignes.
  3. Le fichier est effacé du pod.
  Sans -Fichier, la sauvegarde la plus récente de l'environnement est prise.
  La durée affichée est votre RTO mesuré, pour la restauration seule.

.EXAMPLE
  .\scripts\restaurer.ps1
  .\scripts\restaurer.ps1 -Fichier sauvegardes/velocite-dev-20261023.sql
  pwsh ./scripts/restaurer.ps1            # macOS, Linux
#>
param(
    [ValidateSet("dev", "prod")][string]$Env = "dev",
    [string]$Fichier
)
. "$PSScriptRoot/commun.ps1"

$ns = "velocite-$Env"
Push-Location $Racine
try {
    if (-not $Fichier) {
        $dernier = Get-ChildItem -Path "sauvegardes" `
            -Filter "velocite-$Env-*.sql" -ErrorAction SilentlyContinue |
            Sort-Object Name | Select-Object -Last 1
        if (-not $dernier) {
            throw ("Aucune sauvegarde de $ns dans sauvegardes/ : " +
                   "lancez d'abord scripts/sauvegarder.ps1.")
        }
        $Fichier = "sauvegardes/$($dernier.Name)"
    }
    if (-not (Test-Path $Fichier)) {
        throw "Fichier introuvable : $Fichier"
    }
} finally { Pop-Location }

$chrono = [System.Diagnostics.Stopwatch]::StartNew()
try {
    Invoke-Etape "Attente de PostgreSQL" {
        Invoke-Commande kubectl -n $ns rollout status statefulset/postgres --timeout=300s
        Invoke-Commande kubectl -n $ns exec statefulset/postgres '--' pg_isready -U postgres -d velocite
    }
    Invoke-Etape "Copie de la sauvegarde dans le pod" {
        Push-Location $Racine
        try {
            Invoke-Commande kubectl cp $Fichier "$ns/postgres-0:/tmp/restauration.sql"
        } finally {
            Pop-Location
        }
    }
    $restore = 'PGPASSWORD=$(cat /run/secrets/postgres_password) psql -U postgres -d velocite -v ON_ERROR_STOP=1 -f /tmp/restauration.sql'
    Invoke-Etape "Restauration PostgreSQL" {
        Invoke-Commande kubectl -n $ns exec statefulset/postgres '--' sh -c $restore
    }
} finally {
    $chrono.Stop()
}

Invoke-Etape "Nettoyage du fichier temporaire du pod" {
    Invoke-Commande kubectl -n $ns exec statefulset/postgres '--' rm -f /tmp/restauration.sql
}
Write-Host ""
Write-Host ("Restauration terminée en {0:n0} s : RTO mesuré." -f $chrono.Elapsed.TotalSeconds) -ForegroundColor Green
Show-Releve
