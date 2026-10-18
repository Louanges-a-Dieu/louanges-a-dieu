import { nextInstrumentation } from '@lad/observability/next';

/** Erreurs serveur : journal JSON sans donnée personnelle, et Sentry si `SENTRY_DSN` est défini (10.5). */
export const { register, onRequestError } = nextInstrumentation('web');
