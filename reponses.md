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
