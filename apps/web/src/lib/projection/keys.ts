export type KeyAction = 'next' | 'previous' | 'blank' | 'first' | 'last';

/**
 * Raccourcis clavier de la console, compatibles avec les télécommandes de
 * présentation (qui envoient Page suivante / Page précédente et « . » ou B
 * pour l'écran noir).
 */
export function keyAction(key: string): KeyAction | null {
  switch (key) {
    case 'ArrowRight':
    case 'ArrowDown':
    case 'PageDown':
    case ' ':
      return 'next';
    case 'ArrowLeft':
    case 'ArrowUp':
    case 'PageUp':
      return 'previous';
    case 'b':
    case 'B':
    case '.':
      return 'blank';
    case 'Home':
      return 'first';
    case 'End':
      return 'last';
    default:
      return null;
  }
}
