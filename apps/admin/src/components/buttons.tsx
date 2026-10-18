'use client';

import type { ReactNode } from 'react';
import { useFormStatus } from 'react-dom';

import ui from './ui.module.css';

type Variant = 'primary' | 'default' | 'danger' | 'ghost';
const classes: Record<Variant, string | undefined> = {
  primary: ui.buttonPrimary,
  default: ui.button,
  danger: ui.buttonDanger,
  ghost: ui.buttonGhost,
};

/** Bouton d'envoi : désactivé pendant l'envoi ; confirmation éventuelle. */
export function SubmitButton({
  children,
  variant = 'default',
  confirm,
  name,
  value,
  disabled,
}: {
  children: ReactNode;
  variant?: Variant;
  confirm?: string;
  name?: string;
  value?: string;
  disabled?: boolean;
}) {
  const { pending } = useFormStatus();
  return (
    <button
      type="submit"
      className={classes[variant]}
      name={name}
      value={value}
      disabled={pending || disabled}
      onClick={(event) => {
        if (confirm && !window.confirm(confirm)) event.preventDefault();
      }}
    >
      {children}
    </button>
  );
}
