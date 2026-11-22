// ============================================================================
//  view-kit — Consultation et téléchargement (PDF via impression) d'un kit.
//  Accès protégé par un jeton non devinable (kits.access_token).
//  Aucune donnée n'est servie sans jeton : les liens sont personnels.
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SITE_URL, lienAideWhatsApp } from "../_shared/config.ts";

function echapper(valeur: unknown): string {
  return String(valeur ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function pageErreur(titre: string, message: string): Response {
  return new Response(
    `<!DOCTYPE html><html lang="fr"><head><meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="robots" content="noindex"><title>${echapper(titre)}</title>
    <style>
      body{margin:0;background:#14123A;color:#F6EBD4;font-family:Arial,Helvetica,sans-serif;
      display:flex;align-items:center;justify-content:center;min-height:100vh;padding:24px;text-align:center}
      .carte{max-width:520px;background:#1F1B55;border:1px solid rgba(232,176,75,.35);border-radius:20px;padding:32px}
      h1{color:#E8B04B;font-size:22px;margin:0 0 12px}
      p{color:#B9B4D6;line-height:1.6;margin:0 0 20px}
      a{color:#14123A;background:#E8B04B;text-decoration:none;font-weight:700;padding:12px 20px;border-radius:12px;display:inline-block}
    </style></head><body><div class="carte"><h1>${echapper(titre)}</h1>
    <p>${echapper(message)}</p><a href="${SITE_URL}">Retour au site</a></div></body></html>`,
    { status: 200, headers: { "Content-Type": "text/html; charset=utf-8" } },
  );
}

serve(async (req) => {
  const url = new URL(req.url);
  const kitId = url.searchParams.get("id") ?? "";
  const jeton = url.searchParams.get("token") ?? "";
  const type = (url.searchParams.get("type") ?? "livre").toLowerCase();

  if (!kitId) return pageErreur("Lien incomplet", "Ce lien de consultation est incomplet.");

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: kit } = await supabase.from("kits").select("*").eq("id", kitId).maybeSingle();
  if (!kit) return pageErreur("Kit introuvable", "Ce kit n'existe pas ou a été supprimé.");

  if (kit.access_token && jeton !== String(kit.access_token)) {
    return pageErreur(
      "Lien protégé",
      "Ce lien est personnel. Utilisez le lien reçu sur votre WhatsApp ou par email après le paiement.",
    );
  }

  if (type === "sheet" && kit.sheet_url) {
    return Response.redirect(String(kit.sheet_url), 302);
  }

  const estLivre = type === "livre";
  let contenu = estLivre ? kit.livre_html : kit.prompts_html;

  // Si l'offre achetée ne contient pas ce document, on affiche celui qui existe.
  if (!contenu) {
    contenu = kit.livre_html || kit.prompts_html;
  }

  if (!contenu) {
    return pageErreur(
      "Document indisponible",
      "Ce document n'est pas encore prêt. Patientez quelques instants puis rechargez cette page.",
    );
  }

  const titre = estLivre ? "Guide Stratégique" : "Prompts Publicitaires";
  const sousTitre = String(kit.nom_projet ?? kit.secteur_client ?? "Votre activité");
  const meta = [
    kit.secteur_client ? `Secteur : ${kit.secteur_client}` : "",
    kit.pays_code ? `Pays : ${kit.pays_code}` : "",
  ]
    .filter(Boolean)
    .join(" • ");

  const html = `<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>${echapper(titre)} — ${echapper(sousTitre)}</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@600;800&family=Source+Serif+4:opsz,wght@8..60,400;8..60,600&display=swap" rel="stylesheet">
<style>
  :root{--nuit:#14123A;--profond:#1F1B55;--or:#E8B04B;--sable:#F6EBD4;--brume:#B9B4D6}
  *{box-sizing:border-box}
  body{margin:0;background:#f4f1ea;color:#1e1b45;font-family:'Source Serif 4',Georgia,serif}
  .couverture{min-height:92vh;display:flex;flex-direction:column;justify-content:center;align-items:center;
    text-align:center;padding:48px 24px;color:var(--sable);
    background:radial-gradient(circle at 20% 20%,#2a2568 0%,var(--nuit) 55%,#0d0b25 100%);position:relative;overflow:hidden}
  .couverture::after{content:"";position:absolute;inset:0;
    background-image:linear-gradient(45deg,rgba(232,176,75,.08) 25%,transparent 25%,transparent 75%,rgba(232,176,75,.08) 75%);
    background-size:56px 56px;opacity:.6}
  .couverture>*{position:relative;z-index:1}
  .etiquette{letter-spacing:.28em;text-transform:uppercase;font-size:12px;color:var(--or);font-family:'Montserrat',sans-serif}
  .couverture h1{font-family:'Montserrat',sans-serif;font-size:clamp(32px,6vw,58px);line-height:1.05;margin:18px 0 12px;color:#fff}
  .couverture h1 span{color:var(--or)}
  .couverture h2{font-weight:400;font-size:clamp(17px,2.4vw,22px);color:var(--brume);margin:0 0 28px}
  .auteur{font-family:'Montserrat',sans-serif;font-size:13px;letter-spacing:.18em;text-transform:uppercase;
    border-top:1px solid rgba(232,176,75,.35);padding-top:20px;color:var(--sable)}
  .actions{display:flex;gap:12px;flex-wrap:wrap;justify-content:center;margin:12px 0 28px}
  .bouton{display:inline-block;background:var(--or);color:var(--nuit);text-decoration:none;font-weight:800;
    font-family:'Montserrat',sans-serif;padding:14px 24px;border-radius:12px;border:0;cursor:pointer;font-size:15px}
  .bouton.secondaire{background:transparent;color:var(--or);border:1px solid var(--or)}
  .contenu{max-width:820px;margin:-60px auto 0;background:#fff;padding:56px 40px;border-radius:18px;
    box-shadow:0 24px 60px rgba(20,18,58,.18);position:relative}
  .contenu h1{font-family:'Montserrat',sans-serif;font-size:30px;color:var(--nuit);border-bottom:3px solid var(--or);
    padding-bottom:12px;margin-top:0}
  .contenu h2{font-family:'Montserrat',sans-serif;font-size:22px;color:#8a5a1f;margin-top:2em}
  .contenu h3{font-family:'Montserrat',sans-serif;font-size:18px;color:var(--nuit)}
  .contenu p{font-size:17px;line-height:1.8;text-align:justify}
  .contenu li{font-size:16px;line-height:1.7;margin-bottom:8px}
  .contenu ul,.contenu ol{background:#faf7f0;padding:18px 18px 18px 38px;border-radius:12px}
  .contenu table{width:100%;border-collapse:collapse;margin:24px 0;font-size:15px}
  .contenu th{background:var(--nuit);color:var(--sable);text-align:left;padding:10px}
  .contenu td{border-bottom:1px solid #e6e0d2;padding:10px}
  .contenu pre,.contenu code{background:#f3ede1;border-radius:8px;padding:2px 6px;font-size:14px;white-space:pre-wrap}
  .contenu pre{padding:16px;overflow:auto}
  .pied{max-width:820px;margin:32px auto 60px;text-align:center;color:#6b6785;font-size:13px;
    font-family:'Montserrat',sans-serif}
  .pied a{color:#8a5a1f;font-weight:700}
  @media print{
    body{background:#fff}
    .couverture{min-height:100vh;page-break-after:always}
    .actions,.pied{display:none}
    .contenu{box-shadow:none;margin:0;padding:0;max-width:100%;border-radius:0}
    .contenu h2{page-break-after:avoid}
  }
  @media (max-width:640px){.contenu{margin:-30px 12px 0;padding:28px 20px;border-radius:14px}}
</style>
</head>
<body>
  <section class="couverture">
    <div class="etiquette">Édition Premium • Kit Business</div>
    <h1>${echapper(estLivre ? "Votre plan<br><span>stratégique</span>" : "Vos <span>prompts</span><br>qui vendent")}</h1>
    <h2>${echapper(sousTitre)}</h2>
    ${meta ? `<p style="color:#B9B4D6;font-size:14px;margin:0 0 24px">${echapper(meta)}</p>` : ""}
    <div class="actions">
      <button class="bouton" onclick="window.print()">⬇️ Télécharger en PDF</button>
      <a class="bouton secondaire" href="${lienAideWhatsApp()}" target="_blank" rel="noopener">Aide WhatsApp</a>
    </div>
    <div class="auteur">Généré pour vous • ${new Date().toLocaleDateString("fr-FR")}</div>
  </section>

  <main class="contenu">${contenu}</main>

  <footer class="pied">
    <p>Ce document est personnel. Pour toute question : <a href="${lienAideWhatsApp()}">WhatsApp</a> • <a href="${SITE_URL}">Kit Business</a></p>
    <p>Astuce : sur téléphone, utilisez « Imprimer » puis « Enregistrer au format PDF ».</p>
  </footer>
</body>
</html>`;

  return new Response(html, {
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "private, max-age=300",
      "X-Robots-Tag": "noindex",
    },
  });
});
