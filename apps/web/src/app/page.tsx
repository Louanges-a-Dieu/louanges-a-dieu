import styles from './page.module.css';

/** Page provisoire (squelette Phase 1). */
export default function Home() {
  return (
    <main className={styles.main}>
      <h1 className={styles.title}>Louanges à Dieu</h1>
      <p className={styles.lead}>Projection et programmes partagés</p>
    </main>
  );
}
