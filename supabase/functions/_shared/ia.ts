// ============================================================================
//  Passerelle IA commune — DeepSeek (raisonnement) et Gemini (rédaction).
//  Tous les modèles sont configurables par secret, avec des valeurs par défaut.
// ============================================================================

const DEEPSEEK_URL = "https://api.deepseek.com/chat/completions";

export interface OptionsIA {
  json?: boolean;
  temperature?: number;
  maxTokens?: number;
  systeme?: string;
}

/** Appel DeepSeek (chat) — renvoie le texte brut du modèle. */
export async function appelDeepSeek(prompt: string, options: OptionsIA = {}): Promise<string> {
  const cle = Deno.env.get("DEEPSEEK_API_KEY");
  if (!cle) throw new Error("DEEPSEEK_API_KEY n'est pas configurée.");

  const messages: Array<Record<string, string>> = [];
  if (options.systeme) messages.push({ role: "system", content: options.systeme });
  messages.push({ role: "user", content: prompt });

  const reponse = await fetch(DEEPSEEK_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${cle}` },
    body: JSON.stringify({
      model: Deno.env.get("DEEPSEEK_MODEL") ?? "deepseek-chat",
      temperature: options.temperature ?? 0.7,
      max_tokens: options.maxTokens ?? 4096,
      messages,
      ...(options.json ? { response_format: { type: "json_object" } } : {}),
    }),
    signal: AbortSignal.timeout(150_000),
  });

  if (!reponse.ok) {
    const detail = await reponse.text();
    throw new Error(`DeepSeek a renvoyé ${reponse.status} : ${detail.slice(0, 300)}`);
  }

  const donnees = await reponse.json();
  const contenu = donnees?.choices?.[0]?.message?.content;
  if (!contenu) throw new Error("Réponse DeepSeek vide.");
  return String(contenu);
}

/** Appel Gemini (generateContent) — renvoie le texte concaténé. */
export async function appelGemini(prompt: string, options: OptionsIA = {}): Promise<string> {
  const cle = Deno.env.get("GEMINI_API_KEY");
  if (!cle) throw new Error("GEMINI_API_KEY n'est pas configurée.");
  const modele = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash";

  const reponse = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${modele}:generateContent?key=${cle}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: options.temperature ?? 0.85,
          maxOutputTokens: options.maxTokens ?? 8192,
          ...(options.json ? { responseMimeType: "application/json" } : {}),
        },
      }),
      signal: AbortSignal.timeout(180_000),
    },
  );

  if (!reponse.ok) {
    const detail = await reponse.text();
    throw new Error(`Gemini a renvoyé ${reponse.status} : ${detail.slice(0, 300)}`);
  }

  const donnees = await reponse.json();
  const morceaux = donnees?.candidates?.[0]?.content?.parts ?? [];
  const texte = morceaux.map((partie: { text?: string }) => partie.text ?? "").join("");
  if (!texte.trim()) throw new Error("Réponse Gemini vide.");
  return texte;
}

/** Retire les fences Markdown et isole le premier objet JSON exploitable. */
export function extraireJson<T>(texte: string): T {
  let propre = (texte ?? "").trim();
  propre = propre.replace(/^```(?:json|html)?/i, "").replace(/```$/i, "").trim();

  try {
    return JSON.parse(propre) as T;
  } catch {
    const debut = propre.indexOf("{");
    const fin = propre.lastIndexOf("}");
    if (debut >= 0 && fin > debut) {
      const candidat = propre.slice(debut, fin + 1);
      try {
        return JSON.parse(candidat) as T;
      } catch {
        const repare = candidat.replace(/,\s*$/, "") + "}";
        return JSON.parse(repare) as T;
      }
    }
    throw new Error("Impossible d'interpréter la réponse JSON de l'IA.");
  }
}

/** Nettoie le HTML produit par un modèle (fences, préambules). */
export function nettoyerHtml(texte: string): string {
  let html = (texte ?? "").trim();
  html = html.replace(/^```(?:html)?/i, "").replace(/```$/i, "").trim();
  const debut = html.toLowerCase().indexOf("<!doctype");
  if (debut > 0) html = html.slice(debut);
  return html;
}

/** Extrait le premier objet texte d'une réponse Gemini (sécurisé). */
export function premierTexte(donnees: Record<string, unknown>): string {
  const candidats = (donnees?.candidates as Array<Record<string, unknown>>) ?? [];
  const morceaux = (candidats[0]?.content as { parts?: Array<{ text?: string }> })?.parts ?? [];
  return morceaux.map((p) => p.text ?? "").join("");
}
