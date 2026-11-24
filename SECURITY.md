# Politique de sécurité — TaskFlow API




## 1. Périmètre

| Élément | Outil | Moment |
|---|---|---|
| Code applicatif (`app/`) | Semgrep (règles publiques + règle maison) | Chaque PR et push sur `main` |
| Secrets (historique Git complet) | Gitleaks | Chaque PR et push sur `main` |
| Dépendances Python (`requirements.txt`) | Trivy (`trivy fs`) | Chaque PR et push sur `main` |
| Image de conteneur | Trivy (`trivy image`) | Chaque PR et push sur `main` |

## 2. Seuils de blocage

La pipeline **bloque le merge** si l'image construite contient au moins une vulnérabilité :

| Sévérité | Correctif disponible | Décision |
|---|---|---|
| **CRITICAL** | Oui | ❌ Bloquant |
| **HIGH** | Oui | ❌ Bloquant |
| CRITICAL / HIGH | Non | ⚠️ Non bloquant, suivi obligatoire (voir § 4) |
| MEDIUM | — | ⚠️ Non bloquant, traité selon les délais |
| LOW / UNKNOWN | — | ℹ️ Informatif |

**Pourquoi ne pas bloquer sans correctif disponible ?** Le blocage doit déclencher une action.
Une vulnérabilité sans version corrigée ne peut pas être résolue par une mise à jour : la bloquer
paralyserait le projet sans réduire le risque. Elle est suivie et réévaluée chaque semaine.

Commande appliquée par la pipeline :

```bash
trivy image --scanners vuln --severity CRITICAL,HIGH --ignore-unfixed --exit-code 1 taskflow:ci
```

## 3. Délais de correction

Délai maximal entre la détection et la correction (mise à jour, contournement ou exception validée) :

| Sévérité | Correctif disponible | Délai |
|---|---|---|
| CRITICAL | Oui | **Immédiat** : le merge est bloqué |
| HIGH | Oui | **Immédiat** : le merge est bloqué |
| CRITICAL | Non | Réévaluation **hebdomadaire**, correction dans les **7 jours** suivant la sortie du correctif |
| HIGH | Non | Réévaluation **hebdomadaire**, correction dans les **30 jours** suivant la sortie du correctif |
| MEDIUM | — | **90 jours** |
| LOW | — | Au fil des mises à jour, sans délai imposé |

## 4. Exceptions

Une vulnérabilité bloquante ne peut être ignorée que par une **exception** inscrite dans
`.trivyignore`, qui respecte **toutes** les règles suivantes :

1. **Une ligne par CVE** : jamais d'exclusion globale d'un paquet ou d'une sévérité.
2. **Justification** en commentaire, juste au-dessus de la ligne : pourquoi le risque est acceptable
   (code non atteignable, composant inutilisé, mesure compensatoire…).
3. **Date d'expiration** obligatoire (`exp:AAAA-MM-JJ`), **90 jours maximum**. À expiration, Trivy
   bloque de nouveau la CVE, qui doit être corrigée ou réévaluée.
4. **Responsable** nommé dans le commentaire.
5. **Validation** par une pull request dédiée qui référence la CVE.

Format :

```
# CVE-AAAA-NNNNN — <paquet> <version>
# Justification : <pourquoi le risque est acceptable>
# Responsable : <nom> — ajoutée le AAAA-MM-JJ
CVE-AAAA-NNNNN exp:AAAA-MM-JJ
```

## 6. Responsables

| Rôle | Personne | Responsabilités |
|---|---|---|
| Mainteneur et référent sécurité | Alioune Gueye  | Réception des signalements, triage, validation des exceptions, respect des délais |
| Revue des exceptions | Alioune Gueye | Revue mensuelle de `.trivyignore` et `.gitleaksignore` |

## 7. Règles complémentaires

- **Image de base** : version maintenue (hors fin de vie), variante légère (`slim`).
- **Conteneur** : exécution en utilisateur non-root.
- **Dépendances** : versions épinglées dans `requirements.txt`, mises à jour au moins une fois par mois.
- **Secrets** : jamais dans le code ni dans l'image. Exceptions Gitleaks documentées dans
  `docs/incident-secrets.md`.
