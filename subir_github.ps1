# Subir o projeto CampanhaMT para o GitHub (primeira vez).
# Uso:
#   1. Crie um repositório novo no GitHub (github.com -> + -> New repository).
#      Nome sugerido: MapaPolitico ou CampanhaMT. Pode ser Private. Nao adicione README.
#   2. Rode este script passando a URL do repo OU seu usuario e nome do repo:
#
#   .\subir_github.ps1 -RepoUrl "https://github.com/SEU_USUARIO/MapaPolitico.git"
#   ou
#   .\subir_github.ps1 -Usuario "SEU_USUARIO" -Repo "MapaPolitico"
#
# O Git vai pedir seu usuario/senha do GitHub. Use um Personal Access Token em vez da senha se tiver 2FA.

param(
    [Parameter(ParameterSetName = 'Url')]
    [string] $RepoUrl,
    [Parameter(ParameterSetName = 'UserRepo')]
    [string] $Usuario,
    [Parameter(ParameterSetName = 'UserRepo')]
    [string] $Repo
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if ($RepoUrl) {
    $remote = $RepoUrl
} elseif ($Usuario -and $Repo) {
    $remote = "https://github.com/$Usuario/$Repo.git"
} else {
    Write-Host "Use: .\subir_github.ps1 -RepoUrl 'https://github.com/USUARIO/REPO.git'"
    Write-Host " ou: .\subir_github.ps1 -Usuario USUARIO -Repo REPO"
    exit 1
}

if (git remote get-url origin 2>$null) {
    git remote remove origin
}
git remote add origin $remote
Write-Host "Remote 'origin' definido como: $remote"
Write-Host "Enviando para GitHub (branch main)..."
git push -u origin main
Write-Host "Pronto. Repo: $remote"
