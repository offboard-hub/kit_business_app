// ============================================================================
//  view-kit — lecture éditoriale d'un kit (livre, prompts, tableau de gestion).
//  Accès protégé par le jeton non devinable `kits.access_token`.
//
//  Rendu magazine : couverture bleu nuit / or / émeraude, illustrations SVG,
//  encadrés « Conseil Pro », checklists, prompts copiables, tableau Sheet
//  téléchargeable en CSV et copiable pour Google Sheets.
//
//  En-têtes volontairement explicites : text/html; charset=utf-8 + inline.
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
      body{margin:0;background:#07101F;color:#F3E9D2;font-family:Arial,Helvetica,sans-serif;
      display:flex;align-items:center;justify-content:center;min-height:100vh;padding:24px;text-align:center}
      .carte{max-width:520px;background:#111827;border:1px solid rgba(231,184,75,.35);border-radius:20px;padding:32px}
      h1{color:#E7B84B;font-size:22px;margin:0 0 12px}
      p{color:#A7B0C0;line-height:1.6;margin:0 0 20px}
      a{color:#07101F;background:#E7B84B;text-decoration:none;font-weight:700;padding:12px 20px;border-radius:12px;display:inline-block}
    </style></head><body><div class="carte"><h1>${echapper(titre)}</h1>
    <p>${echapper(message)}</p><a href="${SITE_URL}">Retour au site</a></div></body></html>`,
    { status: 200, headers: { "Content-Type": "text/html; charset=utf-8" } },
  );
}

function illustration(index: number): string {
  const svg = [
    `<svg viewBox="0 0 800 150" role="img" aria-label="Schéma de stratégie">
      <defs><linearGradient id="g1" x1="0" x2="1"><stop stop-color="#E7B84B" stop-opacity=".9"/><stop offset="1" stop-color="#34D399" stop-opacity=".7"/></linearGradient></defs>
      <rect x="20" y="24" width="220" height="100" rx="14" fill="#0B1B33" stroke="#E7B84B" stroke-opacity=".5"/>
      <rect x="58" y="50" width="144" height="12" rx="6" fill="url(#g1)" opacity=".85"/>
      <rect x="58" y="74" width="104" height="8" rx="4" fill="#34D399" opacity=".5"/>
      <rect x="58" y="94" width="126" height="8" rx="4" fill="#E7B84B" opacity=".45"/>
      <path d="M270 74 H360" stroke="#E7B84B" stroke-width="2" stroke-dasharray="7 7"/>
      <circle cx="390" cy="74" r="26" fill="#0B1B33" stroke="#34D399" stroke-width="2"/>
      <path d="M380 74 l8 8 l16 -18" fill="none" stroke="#34D399" stroke-width="4"/>
      <rect x="445" y="24" width="160" height="100" rx="14" fill="#0B1B33" stroke="#34D399" stroke-opacity=".45"/>
      <path d="M470 96 l24 -24 l22 16 l34 -34" fill="none" stroke="#34D399" stroke-width="4"/>
      <circle cx="550" cy="54" r="5" fill="#E7B84B"/>
      <rect x="635" y="34" width="135" height="80" rx="12" fill="#0B1B33" stroke="#E7B84B" stroke-opacity=".35"/>
      <rect x="655" y="54" width="95" height="7" rx="3" fill="#A7B0C0" opacity=".6"/>
      <rect x="655" y="70" width="72" height="7" rx="3" fill="#34D399" opacity=".7"/>
      <rect x="655" y="86" width="84" height="7" rx="3" fill="#E7B84B" opacity=".65"/>
    </svg>`,
    `<svg viewBox="0 0 800 150" role="img" aria-label="Caméra et direct">
      <rect x="70" y="30" width="250" height="100" rx="18" fill="#0B1B33" stroke="#E7B84B" stroke-opacity=".5"/>
      <circle cx="195" cy="80" r="30" fill="none" stroke="#34D399" stroke-width="3"/>
      <circle cx="195" cy="80" r="12" fill="#E7B84B"/>
      <circle cx="335" cy="48" r="7" fill="#F87171"><animate attributeName="opacity" values="1;.25;1" dur="1.4s" repeatCount="indefinite"/></circle>
      <rect x="352" y="39" width="90" height="18" rx="9" fill="#111827" stroke="#F87171" stroke-opacity=".4"/>
      <text x="364" y="52" fill="#F87171" font-family="Arial" font-size="10" font-weight="bold">EN DIRECT</text>
      <path d="M405 80 H490" stroke="#E7B84B" stroke-width="2" stroke-dasharray="6 6"/>
      <rect x="510" y="28" width="220" height="104" rx="16" fill="#0B1B33" stroke="#34D399" stroke-opacity=".45"/>
      <rect x="532" y="48" width="176" height="9" rx="4" fill="#34D399" opacity=".8"/>
      <rect x="532" y="68" width="135" height="8" rx="4" fill="#A7B0C0" opacity=".55"/>
      <rect x="532" y="86" width="150" height="8" rx="4" fill="#E7B84B" opacity=".55"/>
      <rect x="532" y="106" width="88" height="12" rx="6" fill="#E7B84B" opacity=".9"/>
    </svg>`,
    `<svg viewBox="0 0 800 150" role="img" aria-label="Graphique de croissance">
      <defs><linearGradient id="g3" x1="0" x2="0" y1="1" y2="0"><stop stop-color="#34D399" stop-opacity=".35"/><stop offset="1" stop-color="#34D399" stop-opacity="0"/></linearGradient></defs>
      <path d="M50 120 H750" stroke="#E7B84B" stroke-opacity=".35"/>
      <path d="M50 120 L180 96 L310 104 L440 72 L570 54 L700 26 L750 20 L750 130 L50 130 Z" fill="url(#g3)"/>
      <path d="M50 120 L180 96 L310 104 L440 72 L570 54 L700 26 L750 20" fill="none" stroke="#34D399" stroke-width="4"/>
      <path d="M50 120 L180 110 L310 86 L440 92 L570 70 L700 62 L750 48" fill="none" stroke="#E7B84B" stroke-width="2" stroke-dasharray="6 5"/>
      <circle cx="440" cy="72" r="6" fill="#E7B84B"/>
      <circle cx="700" cy="26" r="6" fill="#34D399"/>
    </svg>`,
    `<svg viewBox="0 0 800 150" role="img" aria-label="Checklist et objectifs">
      <rect x="60" y="22" width="310" height="106" rx="16" fill="#0B1B33" stroke="#E7B84B" stroke-opacity=".45"/>
      <g fill="none" stroke="#34D399" stroke-width="3"><circle cx="94" cy="52" r="8"/><circle cx="94" cy="80" r="8"/><circle cx="94" cy="108" r="8"/></g>
      <path d="M89 52 l4 4 l8 -9 M89 80 l4 4 l8 -9" stroke="#34D399" stroke-width="3" fill="none"/>
      <rect x="118" y="46" width="180" height="9" rx="4" fill="#A7B0C0" opacity=".65"/>
      <rect x="118" y="74" width="140" height="9" rx="4" fill="#A7B0C0" opacity=".5"/>
      <rect x="118" y="102" width="165" height="9" rx="4" fill="#E7B84B" opacity=".6"/>
      <rect x="430" y="30" width="300" height="90" rx="18" fill="#0B1B33" stroke="#34D399" stroke-opacity=".4"/>
      <path d="M470 104 L540 48 L600 82 L690 36" fill="none" stroke="#E7B84B" stroke-width="3"/>
      <circle cx="690" cy="36" r="7" fill="#E7B84B"/>
    </svg>`,
  ];
  return `<figure class="illu" aria-hidden="true">${svg[index % svg.length]}</figure>`;
}

function illustrerChapitres(html: string): string {
  let index = 0;
  return html.replace(/<h2(\s|>)/gi, (correspondance) => {
    const illustrationHtml = illustration(index++);
    return `${illustrationHtml}${correspondance}`;
  });
}

function tableauSheet(donnees: string[][]): string {
  if (donnees.length === 0) return "";
  const entetes = donnees[0];
  const lignes = donnees.slice(1);
  return `<div class="tableau-enveloppe"><table id="sheet-table" class="tableau">
    <thead><tr>${entetes.map((cellule) => `<th>${echapper(cellule)}</th>`).join("")}</tr></thead>
    <tbody>${lignes.map((ligne) => `<tr>${entetes.map((_, index) => `<td>${echapper(ligne[index] ?? "")}</td>`).join("")}</tr>`).join("")}</tbody>
  </table></div>`;
}

serve(async (req) => {
  const url = new URL(req.url);
  const kitId = url.searchParams.get("id") ?? "";
  const jeton = url.searchParams.get("token") ?? "";
  const type = (url.searchParams.get("type") ?? "livre").toLowerCase();

  // Supabase réécrit les réponses GET `text/html` en `text/plain` sur le
  // domaine functions.supabase.co (sécurité de la plateforme). On passe donc
  // par une petite page statique qui POSTe vers cette fonction : le POST
  // conserve `text/html; charset=utf-8` et `Content-Disposition: inline`.
  if (req.method === "GET") {
    const base = SITE_URL.replace(/\/$/, "");
    return Response.redirect(`${base}/kit.html?${url.searchParams.toString()}`, 302);
  }

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
      "Ce lien est personnel. Utilisez le lien reçu par email après le paiement.",
    );
  }

  const estLivre = type === "livre";
  const estPrompts = type === "prompt" || type === "prompts";
  const estSheet = type === "sheet";
  const donneesSheet = Array.isArray(kit.sheet_data) ? (kit.sheet_data as string[][]) : [];

  if (estSheet && donneesSheet.length === 0) {
    if (kit.sheet_url) return Response.redirect(String(kit.sheet_url), 302);
    return pageErreur(
      "Tableau indisponible",
      "Le tableau de gestion n'est pas encore prêt. Patientez quelques instants puis rechargez cette page.",
    );
  }

  let contenu = estLivre ? kit.livre_html : estPrompts ? kit.prompts_html : tableauSheet(donneesSheet);
  if (!contenu && !estSheet) contenu = kit.livre_html || kit.prompts_html;
  if (!contenu) {
    return pageErreur(
      "Document indisponible",
      "Ce document n'est pas encore prêt. Patientez quelques instants puis rechargez cette page.",
    );
  }

  if (!estSheet) contenu = illustrerChapitres(String(contenu));

  const titreDocument = estLivre
    ? "Votre plan stratégique"
    : estPrompts
      ? "Vos prompts qui vendent"
      : "Votre tableau de gestion";
  const sousTitre = String(kit.nom_projet ?? kit.secteur_client ?? "Votre activité");
  const secteur = String(kit.secteur_client ?? kit.metier_label ?? "Votre métier");
  const pays = String(kit.pays_code ?? "Afrique");
  const date = new Date().toLocaleDateString("fr-FR");
  const fichier = `e-booklive-${estLivre ? "livre" : estPrompts ? "prompts" : "sheet"}-${String(kit.id).slice(0, 8)}.html`;

  const boutonsSheet = estSheet
    ? `<button class="bouton" onclick="telechargerCsv()">⬇️ Télécharger le Sheet (.csv / Excel)</button>
       <button class="bouton secondaire" onclick="copierTableau()">📋 Copier pour Google Sheets</button>`
    : `<button class="bouton" onclick="window.print()">🖨️ Imprimer / Enregistrer en PDF</button>
       <button class="bouton secondaire" onclick="telechargerHtml()">⬇️ Télécharger ${estLivre ? "le livre" : "les prompts"} (.html)</button>`;

  const html = `<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>${echapper(titreDocument)} — ${echapper(sousTitre)}</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;600;700;800&family=Playfair+Display:ital,wght@0,600;0,800;1,600&display=swap" rel="stylesheet">
<style>
  :root{--nuit:#07101F;--nuit2:#0B1B33;--or:#E7B84B;--or-soft:#F6D98A;--emeraude:#34D399;--sable:#F3E9D2;--brume:#A7B0C0;--papier:#FBF8F1}
  *{box-sizing:border-box}
  body{margin:0;background:var(--nuit);color:#17233B;font-family:'DM Sans',Arial,sans-serif}
  .couverture{min-height:94vh;display:flex;flex-direction:column;justify-content:center;align-items:center;text-align:center;padding:56px 24px;color:var(--sable);background:
    radial-gradient(circle at 15% 15%,rgba(52,211,153,.18),transparent 35%),
    radial-gradient(circle at 85% 10%,rgba(231,184,75,.22),transparent 36%),
    linear-gradient(145deg,#07101F 0%,#0B1B33 54%,#0D2A27 100%);position:relative;overflow:hidden}
  .couverture::before{content:"";position:absolute;inset:0;background-image:linear-gradient(rgba(231,184,75,.055) 1px,transparent 1px),linear-gradient(90deg,rgba(231,184,75,.055) 1px,transparent 1px);background-size:48px 48px;opacity:.8}
  .couverture>*{position:relative;z-index:1}
  .etiquette{letter-spacing:.3em;text-transform:uppercase;font-size:11px;color:var(--emeraude);font-weight:800}
  .couverture h1{font-family:'Playfair Display',Georgia,serif;font-size:clamp(40px,7vw,76px);line-height:1.02;margin:20px 0 16px;color:#fff;max-width:930px}
  .couverture h1 em{color:var(--or);font-style:normal}
  .couverture h2{font-weight:400;font-size:clamp(18px,2.5vw,25px);color:var(--brume);margin:0 0 24px;max-width:720px}
  .badges{display:flex;gap:8px;flex-wrap:wrap;justify-content:center;margin:0 0 28px}
  .badge{border:1px solid rgba(231,184,75,.4);background:rgba(231,184,75,.08);color:var(--or-soft);padding:7px 13px;border-radius:999px;font-size:11px;font-weight:700;letter-spacing:.03em}
  .badge.vert{border-color:rgba(52,211,153,.4);background:rgba(52,211,153,.08);color:#9FF3D0}
  .auteur{font-size:11px;letter-spacing:.18em;text-transform:uppercase;border-top:1px solid rgba(231,184,75,.3);padding-top:20px;color:var(--brume)}
  .actions{display:flex;gap:10px;flex-wrap:wrap;justify-content:center;margin:10px 0 28px}
  .bouton{display:inline-block;background:var(--or);color:#07101F;text-decoration:none;font-weight:800;padding:13px 20px;border-radius:12px;border:0;cursor:pointer;font-size:14px;font-family:'DM Sans',Arial,sans-serif;transition:transform .15s ease,box-shadow .15s ease}
  .bouton:hover{transform:translateY(-1px);box-shadow:0 10px 24px rgba(231,184,75,.18)}
  .bouton.secondaire{background:transparent;color:var(--or-soft);border:1px solid rgba(231,184,75,.45)}
  .contenu{max-width:860px;margin:-56px auto 0;background:var(--papier);padding:58px 48px;border-radius:20px;box-shadow:0 30px 70px rgba(0,0,0,.35);position:relative}
  .contenu h1{font-family:'Playfair Display',Georgia,serif;font-size:34px;color:var(--nuit);border-bottom:3px solid var(--or);padding-bottom:12px;margin-top:0}
  .contenu h2{font-family:'Playfair Display',Georgia,serif;font-size:27px;color:#173B35;margin:2em 0 .7em;line-height:1.2}
  .contenu h3{font-size:18px;color:var(--nuit2);margin-top:1.5em}
  .contenu p{font-family:'Playfair Display',Georgia,serif;font-size:17px;line-height:1.85;text-align:justify;color:#25304A}
  .contenu li{font-family:'Playfair Display',Georgia,serif;font-size:16px;line-height:1.75;margin-bottom:8px;color:#25304A}
  .contenu ul{background:#F4EFE3;padding:18px 20px 18px 22px;border-radius:14px;list-style:none}
  .contenu ul li::before{content:"✓";color:#0E8F6B;font-weight:900;display:inline-block;width:22px}
  .contenu strong{color:#10231F}
  .contenu table{width:100%;border-collapse:collapse;margin:24px 0;font-size:14px;background:#fff;border-radius:12px;overflow:hidden}
  .contenu th{background:var(--nuit);color:var(--sable);text-align:left;padding:11px 12px;font-size:12px;letter-spacing:.04em}
  .contenu td{border-bottom:1px solid #E8E1D2;padding:10px 12px;color:#2B3650}
  .contenu tr:nth-child(even) td{background:#FCFAF5}
  .contenu pre,.contenu code{background:#F1EBDD;border:1px solid #E3D8C1;border-radius:10px;padding:3px 7px;font-size:14px;white-space:pre-wrap;word-break:break-word}
  .contenu pre{padding:18px;line-height:1.65;font-family:ui-monospace,Consolas,monospace;overflow:auto;position:relative}
  .illu{margin:34px 0 8px;padding:0;border-radius:16px;overflow:hidden;background:#0B1B33;border:1px solid rgba(231,184,75,.18)}
  .illu svg{display:block;width:100%;height:auto}
  .conseil-pro{margin:20px 0 26px;padding:16px 18px;border-left:4px solid var(--or);background:#FFF8E7;border-radius:0 12px 12px 0;color:#3D3522;font-size:14px;line-height:1.65}
  .conseil-pro strong{color:#8A5A1F;text-transform:uppercase;letter-spacing:.08em;font-size:10px;display:block;margin-bottom:5px}
  .prompt-carte{background:#fff;border:1px solid #E5DCC9;border-radius:16px;padding:20px;margin:22px 0;box-shadow:0 10px 24px rgba(20,18,58,.05)}
  .prompt-carte h2{font-size:21px;margin:0 0 10px;border-bottom:1px solid #E8E1D2;padding-bottom:10px}
  .prompt-carte pre{background:#0B1B33;color:#D9F5E8;border:0}
  .bouton-copier{background:#0B1B33;color:#E7B84B;border:1px solid rgba(231,184,75,.35);border-radius:10px;padding:9px 13px;font-weight:800;cursor:pointer;font-size:12px}
  .bouton-copier:hover{background:#102A4A}
  .tableau-enveloppe{overflow:auto;border:1px solid #DED3BF;border-radius:14px;background:#fff}
  .tableau{width:100%;border-collapse:collapse;font-size:13px;min-width:680px;margin:0}
  .tableau th{background:#0B1B33;color:#F3E9D2;text-align:left;padding:12px;position:sticky;top:0;font-size:11.5px}
  .tableau td{border-bottom:1px solid #EFE8DA;padding:10px 12px;color:#2B3650;white-space:nowrap}
  .tableau tr:nth-child(even) td{background:#FCFAF5}
  .note{font-size:12px;color:#6B6785;line-height:1.6;margin-top:12px}
  .pied{max-width:860px;margin:30px auto 60px;text-align:center;color:var(--brume);font-size:12px;line-height:1.8}
  .pied a{color:var(--or);font-weight:700}
  @media print{
    body{background:#fff}
    .couverture{min-height:100vh;page-break-after:always}
    .actions,.pied,.bouton,.bouton-copier{display:none!important}
    .contenu{box-shadow:none;margin:0;padding:0;max-width:100%;border-radius:0;background:#fff}
    .contenu h2{page-break-after:avoid}
    .illu{page-break-inside:avoid}
  }
  @media (max-width:680px){.contenu{margin:-28px 10px 0;padding:30px 20px;border-radius:15px}.contenu p{font-size:16px}.actions{flex-direction:column;align-items:stretch}.bouton{width:100%}}
</style>
</head>
<body>
  <section class="couverture">
    <div class="etiquette">Édition premium · e-booklive</div>
    <h1>${estLivre ? "Votre plan<br><em>stratégique</em>" : estPrompts ? "Vos <em>prompts</em><br>qui vendent" : "Votre <em>tableau</em><br>de gestion"}</h1>
    <h2>${echapper(sousTitre)}</h2>
    <div class="badges">
      <span class="badge">${echapper(secteur)}</span>
      <span class="badge vert">${echapper(pays)}</span>
      <span class="badge">Édition ${date}</span>
    </div>
    <div class="actions">${boutonsSheet}</div>
    <div class="auteur">Généré pour vous · e-booklive</div>
  </section>

  <main class="contenu">
    ${estSheet ? `<p class="note" style="margin-top:0">Tableau prêt à l'emploi : ventes, stocks, marges et seuil de rentabilité. Téléchargez le CSV pour Excel ou copiez-le dans Google Sheets.</p>` : ""}
    ${contenu}
  </main>

  <footer class="pied">
    <p>Ce document est personnel et nominatif. Aide : <a href="${lienAideWhatsApp()}">WhatsApp</a> · <a href="${SITE_URL}">e-booklive</a></p>
    <p>Astuce : « Imprimer » puis « Enregistrer au format PDF » pour garder une copie hors ligne.</p>
  </footer>

  <script>
    function telechargerHtml() {
      const html = '<!DOCTYPE html>' + document.documentElement.outerHTML;
      const blob = new Blob([html], {type: 'text/html;charset=utf-8'});
      const lien = document.createElement('a');
      lien.href = URL.createObjectURL(blob);
      lien.download = ${JSON.stringify(fichier)};
      document.body.appendChild(lien);
      lien.click();
      lien.remove();
      setTimeout(() => URL.revokeObjectURL(lien.href), 3000);
    }

    function donneesTableau() {
      const table = document.getElementById('sheet-table');
      if (!table) return [];
      return Array.from(table.rows).map((ligne) =>
        Array.from(ligne.cells).map((cellule) => cellule.innerText.trim())
      );
    }

    function csvCellule(valeur) {
      return '"' + String(valeur).replace(/"/g, '""') + '"';
    }

    function telechargerCsv() {
      const lignes = donneesTableau();
      const csv = '\uFEFF' + lignes.map((ligne) => ligne.map(csvCellule).join(';')).join('\r\n');
      const blob = new Blob([csv], {type: 'text/csv;charset=utf-8'});
      const lien = document.createElement('a');
      lien.href = URL.createObjectURL(blob);
      lien.download = ${JSON.stringify(fichier.replace(/\.html$/, ".csv"))};
      document.body.appendChild(lien);
      lien.click();
      lien.remove();
      setTimeout(() => URL.revokeObjectURL(lien.href), 3000);
    }

    async function copierTableau() {
      const lignes = donneesTableau();
      if (!lignes.length) return;
      const tsv = lignes.map((ligne) => ligne.join('\t')).join('\n');
      try {
        await navigator.clipboard.writeText(tsv);
        alert('Tableau copié. Dans Google Sheets : Ctrl+V (ou ⌘+V).');
      } catch (_) {
        const zone = document.createElement('textarea');
        zone.value = tsv;
        document.body.appendChild(zone);
        zone.select();
        document.execCommand('copy');
        zone.remove();
        alert('Tableau copié. Dans Google Sheets : Ctrl+V (ou ⌘+V).');
      }
    }

    function habillerPrompts() {
      const contenu = document.querySelector('.contenu');
      if (!contenu) return;
      contenu.querySelectorAll('h2').forEach((titre) => {
        const section = document.createElement('section');
        section.className = 'prompt-carte';
        titre.parentNode.insertBefore(section, titre);
        section.appendChild(titre);
        let suivant = titre.nextElementSibling;
        while (suivant && suivant.tagName !== 'H2') {
          const apres = suivant.nextElementSibling;
          section.appendChild(suivant);
          suivant = apres;
        }
        const bouton = document.createElement('button');
        bouton.className = 'bouton-copier';
        bouton.textContent = '📋 Copier le prompt';
        bouton.addEventListener('click', async () => {
          const pre = section.querySelector('pre');
          const texte = pre ? pre.innerText : section.innerText;
          try {
            await navigator.clipboard.writeText(texte);
            bouton.textContent = '✅ Prompt copié';
          } catch (_) {
            const zone = document.createElement('textarea');
            zone.value = texte;
            document.body.appendChild(zone);
            zone.select();
            document.execCommand('copy');
            zone.remove();
            bouton.textContent = '✅ Prompt copié';
          }
        });
        section.appendChild(bouton);
      });
    }

    ${estPrompts ? "habillerPrompts();" : ""}
  </script>
</body>
</html>`;

  return new Response(html, {
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Content-Disposition": `inline; filename="${fichier}"`,
      "Cache-Control": "private, max-age=60",
      "X-Robots-Tag": "noindex",
    },
  });
});
