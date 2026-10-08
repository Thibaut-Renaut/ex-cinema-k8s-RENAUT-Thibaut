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
