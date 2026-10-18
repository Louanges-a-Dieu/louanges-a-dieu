import { nextInstrumentation } from '../src/next.ts';

export const { register, onRequestError } = nextInstrumentation('test');
