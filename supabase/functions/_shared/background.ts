// ============================================================================
//  Tâches de fond : `EdgeRuntime.waitUntil` si disponible, sinon exécution
//  directe (utile en local avec `supabase functions serve`).
// ============================================================================

export function enArrierePlan(tache: Promise<unknown>): void {
  const securisee = tache.catch((erreur) => {
    console.error("Tâche de fond en échec :", erreur);
  });

  const runtime = (globalThis as {
    EdgeRuntime?: { waitUntil: (promesse: Promise<unknown>) => void };
  }).EdgeRuntime;

  if (runtime?.waitUntil) {
    runtime.waitUntil(securisee);
  }
}
