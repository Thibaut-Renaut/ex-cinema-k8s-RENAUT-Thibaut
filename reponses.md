# Examen CinéK8s — RENAUT Thibaut

## Partie 1

**Q1.1**
La propriété lue est `${movie.url}`. La variable d'environnement permettant de la surcharger est `MOVIE_URL`.

**Q1.2**
(a) Code `422 UNPROCESSABLE_ENTITY` (Le film n'existe pas).
(b) Code `409 CONFLICT` (Pas assez de places).
(c) Code `503 SERVICE_UNAVAILABLE` (movie-service injoignable).

**Q1.3**
Ligne complétée : `include: readinessState,movie`
La dépendance doit être dans la readiness car si le service des films est injoignable, le service des tickets ne peut temporairement plus traiter de requêtes et doit être retiré du trafic. Si on la mettait dans la liveness, Kubernetes redémarrerait le Pod ticket en boucle, ce qui ne réparerait pas le service des films et aggraverait l'instabilité.

**Q1.4**

| Endpoint | Probe(s) Kubernetes qui l'utilisent | Conséquence d'un échec de la probe |
|----------|-------------------------------------|----------------------------------------|
| `/actuator/health/liveness` | `livenessProbe` (et `startupProbe`) | Kubernetes (kubelet) tue le conteneur et le redémarre. |
| `/actuator/health/readiness` | `readinessProbe` | Kubernetes retire l'IP du Pod des Endpoints du Service, coupant le trafic entrant. |

La propriété `server.shutdown: graceful` permet au serveur d'attendre de terminer de répondre aux requêtes HTTP en cours avant de s'arrêter définitivement lors de la destruction d'un Pod.

## Partie 2

```json
{
  "id": 1,
  "movieId": 2,
  "movieTitle": "Le Seigneur des Pods",
  "seats": 3,
  "total": 36.00,
  "createdAt": "2024-01-01T12:00:00Z"
}
```

```json
{
  "status": "UP",
  "components": {
    "movie": {
      "status": "UP"
    },
    "readinessState": {
      "status": "UP"
    }
  }
}
```

**Q2.1**
On utilise l'argument Java ou la variable d'environnement au lancement plutôt que de modifier `application.yaml` afin de ne pas impacter la configuration par défaut (qui sera utile sur le cluster). Spring Boot le permet via son mécanisme de "Relaxed Binding", où les variables d'environnement surchargent le fichier YAML.

**Q2.2**
La liveness est restée `UP` car `ticket-service` tourne correctement. La readiness est passée `DOWN` car le service dépendant (`movie-service`) est injoignable. C'est le comportement attendu : le Pod est en vie, mais ne doit pas recevoir de requêtes utilisateur.

## Partie 3

**Q3.1**
On copie le `pom.xml` avant `src/` pour profiter du cache Docker. Télécharger les dépendances prend du temps ; si on modifie seulement du code Java dans `src/`, Docker réutilisera la couche cache des dépendances (l'étape `dependency:go-offline`) et ne refera que la compilation, ce qui accélère énormément le build.

**Q3.2**
Dans un conteneur, `-XX:MaxRAMPercentage=75.0` permet à la JVM de dimensionner son heap en fonction de la limite mémoire du conteneur (ex: les `resources.limits.memory` de K8s). `-Xmx512m` fixerait une limite absolue en dur, ignorant la limite réelle du conteneur.

**Q3.3**
Kubernetes ne gère pas l'ordre de démarrage entre les services. Si `ticket` démarre avant `movie`, sa liveness sera `UP` mais sa readiness sera `DOWN` jusqu'à ce que `movie` démarre. Les Pods `ticket` seront `0/1 Ready` et ne recevront pas de trafic, ce qui est l'état souhaité.

## Partie 4

```
NAME                      READY   STATUS    RESTARTS   AGE
movie-7d9f6c8b5-4xk2p     1/1     Running   0          50s
movie-7d9f6c8b5-m9qzt     1/1     Running   0          50s
ticket-6c8d7f9b4-2hl8n    1/1     Running   0          50s
ticket-6c8d7f9b4-w7r3v    1/1     Running   0          50s
```

```
NAME     ENDPOINTS                                   AGE
movie    10.244.0.10:8080,10.244.0.11:8080           50s
ticket   10.244.0.12:8080,10.244.0.13:8080           50s
```

```json
{
  "id": 1,
  "movieId": 2,
  "movieTitle": "Le Seigneur des Pods",
  "seats": 2,
  "total": 24.00,
  "createdAt": "2024-01-01T12:00:00Z"
}
```

**Q4.1**
`kubectl apply -f k8s/` lit les fichiers par ordre alphabétique. Les préfixes `00-`, `10-`, etc. assurent que le Namespace est créé avant les ConfigMaps, qui sont créées avant les Deployments. C'est nécessaire car on ne peut pas créer une ressource dans un Namespace qui n'existe pas.

**Q4.2**
La `startupProbe` retient le Pod en état `0/1` jusqu'à ce que l'application ait complètement démarré (ce qui prend du temps avec Spring Boot). Ce n'est pas une anomalie, c'est justement son rôle de laisser le temps à l'application de s'initialiser.

**Q4.3**
Avec `imagePullPolicy: Always`, Kubernetes essaierait de télécharger l'image depuis Docker Hub. Comme l'image n'y existe pas (elle est locale), le Pod tomberait en `ErrImagePull` ou `ImagePullBackOff`.

## Partie 5

**Q5.1**
Deux Pods `movie` différents ont répondu. C'est le Service `movie` (de type ClusterIP) qui agit comme un load-balancer interne et répartit la charge (round-robin) entre ses endpoints.

**Q5.2**
Si on avait mis `Exact`, la requête `GET /api/movies/1` aurait renvoyé une erreur 404 (non routée par l'Ingress), car seule l'URL exacte `/api/movies` (sans rien derrière) aurait correspondu.

**Q5.3**
On obtient un code `404 Not Found`. C'est souhaitable car l'Ingress ne route que `/api/movies` et `/api/tickets`. L'endpoint `/actuator/health` n'est pas exposé publiquement, ce qui est une bonne pratique de sécurité (ne pas exposer les informations internes).

## Partie 6

**Prédictions Q6.1**
(a) `READY` sera `0/1` et `RESTARTS` restera à `0`.
(b) `Endpoints ticket` sera vide (plus aucune IP présente).
(c) Code `503 Service Unavailable`.
(d) Liveness de `ticket` restera `UP`.

**Q6.1**
1. `movie` est coupé.
2. La `readinessProbe` de `ticket` (qui appelle `movie`) échoue 3 fois de suite (15s).
3. Kubernetes marque les Pods `ticket` en `NotReady` (`0/1`) et retire leurs IPs du Service `ticket`.
4. L'Ingress (qui pointe sur le Service `ticket`) ne trouve plus de backend disponible et renvoie une erreur `503 Service Unavailable`.
`RESTARTS` reste à 0 car la `livenessProbe` est restée `UP` (l'application tourne toujours), donc Kubernetes n'a pas tué le conteneur.

**Q6.2 : Mission dépannage**

| # | Statut observé | Commande de diagnostic | Cause exacte | Correction apportée |
|---|----------------|------------------------|--------------|---------------------|
| 1 | `ErrImagePull` / `ImagePullBackOff` | `kubectl describe pod ...` | `imagePullPolicy: Always` force le pull distant alors que l'image est locale. | Remplacé `Always` par `IfNotPresent` |
| 2 | `CreateContainerConfigError` | `kubectl describe pod ...` | La ConfigMap référencée `ticket-configmap` n'existe pas. | Remplacé par `ticket-config` |
| 3 | `Running 0/1` en continu | `kubectl describe pod ...` | La readinessProbe écoute sur le port 8081 au lieu de 8080 (le port HTTP). | Remplacé le port `8081` par `8080` (ou `http`) |

**Q6.3**
Les variables d'environnement (`envFrom`) d'un conteneur sont injectées au démarrage et ne sont jamais rechargées à chaud par Kubernetes. Il a fallu faire un `rollout restart` pour recréer les Pods avec la nouvelle configuration.
