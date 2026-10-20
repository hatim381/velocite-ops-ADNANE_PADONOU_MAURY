# Déployer VéloCité depuis zéro

A FAIRE, commencé le mardi, complété chaque jour. Le test : un binôme qui
n'a jamais vu ce dépôt monte la plateforme en suivant ce document, sans
vous poser de question. Toutes les commandes pour PowerShell (Windows, macOS
ou Linux), depuis la racine du dépôt.

## 1. Ce qu'il faut sur le poste

Le module marche sous Windows, sous macOS (processeur Intel ou Apple) et
sous Linux (processeur Intel ou AMD). Les scripts du dépôt se lancent dans
PowerShell : Windows PowerShell 5.1, fourni avec Windows, ou PowerShell 7
(commande `pwsh`) sous macOS et Linux. Les chemins s'écrivent avec des barres obliques
(`./scripts/up.ps1`) : c'est la forme qui marche sur les deux.

| Outil | Version | Rôle |
|---|---|---|
| Docker | Windows, macOS : Docker Desktop à jour (Windows : moteur WSL 2) ; Linux : Docker Engine et le plugin Compose | construit les images, fait tourner les nodes kind |
| PowerShell | Windows : 5.1, fourni ; macOS : 7, `brew install --cask powershell` ; Linux : 7, learn.microsoft.com, "Installer PowerShell sur Linux" | les scripts |
| Git | Windows : Git pour Windows ; macOS : `xcode-select --install` ; Linux : `sudo apt install git` | versionne le dépôt ; fournit le `diff` de `kubectl diff` sous Windows |
| kind | 0.33.0 | le cluster Kubernetes local |
| OpenTofu | 1.13.1 | l'infrastructure décrite en code |
| kubectl | 1.37.1 | le client Kubernetes |
| argo | 4.1.5 | le client Argo Workflows |

Les quatre derniers s'installent d'un coup, à version fixe et hash
vérifié, depuis la racine du dépôt (sous macOS et Linux : `pwsh
./scripts/installer-outils.ps1`) :

```powershell
./scripts/installer-outils.ps1
# fermez puis rouvrez PowerShell, puis :
kind version ; tofu version ; kubectl version --client ; argo version --short
(Get-Command kubectl).Source     # doit contenir velocite-outils
```

Le script ajoute aussi une ligne à votre profil PowerShell (et, sous macOS
et Linux, à `~/.zshrc` ou `~/.bashrc`) : sans elle, le `kubectl` de Docker
Desktop, plus ancien, passerait avant le vôtre. Hors de PowerShell, la
vérification s'écrit `command -v kubectl`.

Mémoire : 8 Go alloués à Docker Desktop au minimum, 12 Go conseillés.
Réglage : Docker Desktop, Settings, Resources. Sous Linux, Docker Engine
utilise directement la mémoire du poste.

Différences entre les deux systèmes :

| | Windows | macOS et Linux |
|---|---|---|
| Dossier de travail conseillé | `C:\cours` | `~/cours` |
| Appel HTTPS en ligne de commande | `curl.exe` (dans PowerShell 5.1, `curl` désigne autre chose) | `curl` |
| Scripts refusés ("l'exécution de scripts est désactivée") | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`, une fois | sans objet |
| La phrase du state, hors PowerShell | sans objet | `read -rs TF_VAR_phrase_etat; export TF_VAR_phrase_etat` |

Kubernetes ne démarre que si Docker tourne en cgroup v2. Vérification :
`docker info --format '{{.CgroupVersion}}'` doit répondre `2`. Sous
macOS, c'est toujours le cas avec un Docker Desktop à jour ; sous Linux,
avec toute distribution de moins de trois ans. Sous Windows,
s'il répond `1`, mettez d'abord Docker Desktop à jour ; si c'est toujours
`1`, créez `%USERPROFILE%\.wslconfig` avec ces deux lignes, puis
`wsl --shutdown` et relancez Docker Desktop :

```
[wsl2]
kernelCommandLine = cgroup_no_v1=all
```

`up.ps1` fait ce contrôle et s'arrête avec ce message plutôt qu'avec
une erreur de kubeadm.

## 2. La phrase de passe du state

```powershell
$env:TF_VAR_phrase_etat = Read-Host "0123456789012345"
```

Choisissez une phrase de passe et conservez-la hors du dépôt. Elle chiffre les
states OpenTofu des couches `10-outils` et `20-env`, qui peuvent contenir des
secrets. La variable ne vaut que dans le terminal courant : il faut la définir
à nouveau dans chaque nouveau terminal avant une commande `tofu` sur ces
couches. Ne l'écrivez jamais dans un fichier, une commande sauvegardée ou Git.

## 3. Tout monter, en une commande

À ce stade du mardi, le script automatise la création ou la remise en état du
cluster kind. Les autres étapes seront ajoutées au fil des ateliers. Après
avoir défini la phrase de passe :

```powershell
./scripts/up.ps1 -Env dev -SansImages
```

Le script vérifie les prérequis, initialise la couche `infra/00-cluster`,
applique le code du cluster puis sélectionne le contexte `kind-velocite`.
Avec la configuration actuelle, il doit laisser un control-plane et un worker
prêts. L'option `-SansImages` évite le chargement des images VéloCité tant que
les applications ne sont pas encore déployées sur Kubernetes.

## 4. Les étapes, une par une

Pour chaque étape : la commande, ce qu'on doit voir, comment le vérifier.

### 1. Libérer le port HTTPS local

Depuis le dossier `app`, arrêtez la plateforme Docker Compose du lundi avant
de créer le cluster :

```powershell
docker compose down
```

Le cluster kind publie ensuite son port de développement sur `127.0.0.1:8443`.
Cette commande arrête les conteneurs Compose mais conserve leurs volumes.

### 2. Créer le cluster kind avec OpenTofu

```powershell
cd ./infra/00-cluster
tofu init
tofu plan
tofu apply
```

Lors du premier passage, le plan annonce la création d'une ressource
`kind_cluster.velocite`. Lisez le plan avant de répondre `yes` : il crée un
control-plane et un worker, avec Kubernetes v1.36.4. Le cluster actuel est
conforme au code : un nouveau `tofu plan` répond `No changes. Your
infrastructure matches the configuration.`

Vérifiez le résultat :

```powershell
kubectl config current-context
kubectl get nodes
```

Le contexte attendu est `kind-velocite`. Deux nœuds sont `Ready` :
`velocite-control-plane` et `velocite-worker`.

### 3. Prouver que le second passage ne change rien

```powershell
tofu plan
```

La réponse attendue et obtenue est `No changes.` Cela prouve que le cluster
existant correspond toujours à la description versionnée.

### 4. Installer les outils partagés du cluster

Définissez d'abord la phrase de passe (section 2), puis :

```powershell
cd ../10-outils
tofu init
tofu apply
kubectl get namespaces
kubectl get pods -A
```

Les namespaces `argo` et `observabilite` doivent être `Active`. Les pods Argo,
Grafana, Loki, Prometheus, Alloy et metrics-server doivent être en état
`Running` (ou tous leurs conteneurs prêts). Ils constituent les outils
partagés par les futurs environnements `dev` et `prod`.

## 5. Accéder à la plateforme

## 6. Tout détruire

## 7. Quand ça bloque

| Symptôme | Cause probable | Que faire |
|---|---|---|
| | | |
