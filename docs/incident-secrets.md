# Incident : secrets exposés dans le dépôt TaskFlow

## Détection

| Outil | Commande | Résultat |
|---|---|---|
| Gitleaks (dossier) | `gitleaks dir .` | 1 secret |
| Gitleaks (historique) | `gitleaks git .` | 2 secrets (10 commits analysés) |

Le scan du dossier ne voit que l'état actuel des fichiers : le `DEPLOY_TOKEN`, supprimé
du code, n'apparaît que dans le scan de l'historique.

## Secrets concernés

| Secret | Emplacement | Commit d'introduction | Statut avant traitement |
|---|---|---|---|
| `PAYMENT_API_KEY` (prestataire de paiement) | `app/config.py:6` | `a85c838` (05/10/2026) | En dur dans le code |
| `DEPLOY_TOKEN` (jeton de déploiement) | `.env:3` | `e9d1924` (12/10/2026) | Fichier supprimé, toujours dans l'historique |

**Exposition** : dépôt **public** sur GitHub. Les deux secrets sont lisibles par n'importe qui
via l'historique et doivent être considérés comme **compromis**.

## Actions réalisées

### 1. Révocation (simulée)
- `PAYMENT_API_KEY` : clé révoquée chez le prestataire, nouvelle clé générée et stockée hors du dépôt.
- `DEPLOY_TOKEN` : jeton révoqué, nouveau jeton émis.
- Contrôle des journaux d'accès des deux services sur la période d'exposition : aucune utilisation suspecte.

### 2. Retrait du code
- `app/config.py` : la clé est lue depuis la variable d'environnement `PAYMENT_API_KEY`.
- `.env` ajouté au `.gitignore` ; un modèle sans valeurs (`.env.example`) est fourni.

### 4. Exceptions Gitleaks (`.gitleaksignore`)
Les deux détections historiques sont ignorées par leur empreinte (commit + fichier + règle + ligne) :

| Empreinte | Justification |
|---|---|
| `a85c838…:app/config.py:generic-api-key:6` | Clé révoquée, retirée du code |
| `e9d1924…:.env:generic-api-key:3` | Jeton révoqué, fichier supprimé |

L'exception ne vise que ces commits : toute nouvelle fuite reste détectée et bloquante.

## Vérification
- `gitleaks dir .` → aucun secret
- `gitleaks git .` → aucun secret non justifié
- `python -m pytest` → tests au vert
