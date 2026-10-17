# ADR-012 — Jetons de partage

**Décision.** Jeton aléatoire ≥ 128 bits encodé base64url, révocable, expirable, régénérable.
Lecture uniquement via la RPC `get_shared_program(token)` qui ne renvoie ni identifiant ni e-mail
du créateur. Réponse identique pour un jeton inexistant, révoqué ou expiré.
