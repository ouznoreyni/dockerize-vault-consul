# Configuration Docker pour Consul et Vault

Ce projet fournit une configuration Docker pour exécuter HashiCorp Consul et Vault ensemble. Il offre un moyen rapide et facile de démarrer avec ces puissants outils pour la découverte de services, la gestion de configuration et la gestion des secrets.

## Prérequis

- Docker
- Docker Compose
- bash
- curl
- jq

## Structure du projet

```
docker-consul-vault/
│
├── docker-compose.yml
├── start_vault_consul.sh
│
├── consul/
│   ├── Dockerfile
│   ├── config/
│   │   └── consul-config.json
│   └── policies/
│       └── consul-acl-policy.json
│
├── vault/
│   ├── Dockerfile
│   ├── config/
│   │   └── vault-config.json
│   └── policies/
│       └── app-policy.json
│
└── README.md
```

## Utilisation

1. Clonez ce dépôt :
   ```
   git clone https://github.com/ouznoreyni/dockerize-vault-consul
   cd docker-consul-vault
   ```

2. Assurez-vous que le script de démarrage a les bonnes permissions :
   ```
   chmod +x start_vault_consul.sh
   ```

3. Démarrez les services :
   ```
   ./start_vault_consul.sh
   ```

   Ce script va :
   - Démarrer les conteneurs Consul et Vault
   - Initialiser et déverrouiller Vault
   - Configurer les ACL de Consul
   - Activer le moteur de secrets KV dans Vault
   - Créer un secret d'exemple
   - Créer et appliquer des politiques

4. Les jetons et clés importants seront affichés à la fin du script et sauvegardés dans `tokens.txt`.

## Accès aux interfaces utilisateur

- Interface Consul : http://localhost:8500
- Interface Vault : http://localhost:8200

Utilisez les jetons appropriés fournis par le script pour vous connecter.

## Exemples d'utilisation de Vault

### Création d'un secret

Pour créer un nouveau secret dans Vault :

```bash
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='votre-token-root-vault'

vault kv put secret/monapp/config api_key=ma_cle_secrete
```

### Récupération d'un secret

Pour récupérer un secret de Vault :

```bash
vault kv get secret/monapp/config
```

## Considérations de sécurité

- Cette configuration est destinée au développement et aux tests. Pour une utilisation en production, des mesures de sécurité supplémentaires sont nécessaires.
- Les jetons et clés sont affichés en clair et sauvegardés dans `tokens.txt`. Dans un environnement de production, gérez ces secrets de manière sécurisée.

## Dépannage

- Si les services ne démarrent pas, vérifiez les logs Docker :
  ```
  docker-compose logs
  ```
- Assurez-vous que tous les ports requis sont libres sur votre machine hôte.

## Auteur
Ousmane Diop.
