-- Migration 0011 — Droits d'exécution des fonctions (correctif de sécurité)
--
-- Constat (test 01_security_coverage) : PostgreSQL accorde EXECUTE à PUBLIC sur
-- toute nouvelle fonction, et anon hérite de PUBLIC. Les « default privileges »
-- par schéma de la migration 0002 ne pouvaient pas retirer ce droit global
-- (ils ne font qu'en ajouter). Résultat : anon pouvait appeler les RPC de
-- synchronisation et de partage — sans effet, car elles exigent un utilisateur
-- connecté, mais contraire au refus par défaut.
--
-- Correctif : retrait global du droit PUBLIC pour les fonctions futures, puis
-- retrait sur l'existant. Les droits voulus restent accordés explicitement,
-- rôle par rôle, dans chaque migration.

alter default privileges for role postgres revoke execute on functions from public;

revoke execute on all functions in schema public from public;
revoke execute on all functions in schema private from public;
