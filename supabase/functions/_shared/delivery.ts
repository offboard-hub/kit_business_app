// ============================================================================
//  LIVRAISON PAR EMAIL (Resend) — les liens du kit sont envoyés au client
//  après validation du paiement SasPay, et affichés sur la page de confirmation.
//  Aucun autre canal d'envoi automatique n'est utilisé.
// ============================================================================

import { SITE_URL, formaterFcfa, lienAideWhatsApp, OFFRES, type TypeProduit } from "./config.ts";
import { formaterMontant } from "./pricing.ts";
import { type LiensKit } from "./kit-engine.ts";

export interface ResultatEnvoi {
  ok: boolean;
  id?: string;
  error?: string;
  canal: "email";
}

export interface PaiementEmail {
  provider?: string | null;
  montant?: number | null;
  devise?: string | null;
  montantFcfa?: number | null;
}

/** Ligne « Payé via SasPay — 23 000 NGN » (ou montant FCFA de référence). */
function lignePaiement(paiement: PaiementEmail | undefined): string {
  if (!paiement) return "";
  const fournisseur = (paiement.provider ?? "").toLowerCase() === "paddle"
    ? "Paddle"
    : "SasPay";
  if (paiement.montant && paiement.devise) {
    return `Payé via ${fournisseur} — ${formaterMontant(paiement.montant, paiement.devise)}.`;
  }
  if (paiement.montantFcfa) {
    return `Payé via ${fournisseur} — ${formaterFcfa(paiement.montantFcfa)}.`;
  }
  return "";
}

function echapperHtml(valeur: string): string {
  return (valeur ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

// ----------------------------------------------------------------------------
//  RESEND
// ----------------------------------------------------------------------------

export async function envoyerEmail(params: {
  to: string;
  subject: string;
  html: string;
  replyTo?: string;
}): Promise<ResultatEnvoi> {
  const cle = Deno.env.get("RESEND_API_KEY");
  const from = Deno.env.get("RESEND_FROM_EMAIL") ?? "Kit Business <bonjour@kit-business.africa>";

  if (!cle) {
    return { ok: false, canal: "email", error: "RESEND_API_KEY non configurée." };
  }
  if (!params.to) {
    return { ok: false, canal: "email", error: "Adresse email du client manquante." };
  }

  try {
    const reponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${cle}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from,
        to: [params.to],
        subject: params.subject,
        html: params.html,
        reply_to: params.replyTo ?? Deno.env.get("SUPPORT_EMAIL") ?? undefined,
      }),
      signal: AbortSignal.timeout(30_000),
    });

    const donnees = await reponse.json().catch(() => ({}));
    if (!reponse.ok) {
      return {
        ok: false,
        canal: "email",
        error: donnees?.message ?? `Resend a renvoyé HTTP ${reponse.status}`,
      };
    }
    return { ok: true, canal: "email", id: String(donnees?.id ?? "") };
  } catch (erreur) {
    return {
      ok: false,
      canal: "email",
      error: erreur instanceof Error ? erreur.message : String(erreur),
    };
  }
}

// ----------------------------------------------------------------------------
//  GABARITS D'EMAILS
// ----------------------------------------------------------------------------

export function emailLivraisonHtml(params: {
  nomProjet: string;
  metierLabel: string;
  paysLabel: string;
  produit: TypeProduit;
  liens: LiensKit;
  paiement?: PaiementEmail;
}): string {
  const offre = OFFRES[params.produit];
  const paiement = lignePaiement(params.paiement);
  const bouton = (url: string, libelle: string, couleur: string) =>
    `<p style="margin:0 0 12px 0;"><a href="${url}" style="display:inline-block;background:${couleur};color:#14123A;font-weight:800;text-decoration:none;padding:14px 22px;border-radius:12px;">${libelle}</a></p>`;

  return `<!DOCTYPE html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;background:#14123A;font-family:Arial,Helvetica,sans-serif;color:#F6EBD4;">
  <div style="max-width:600px;margin:0 auto;padding:32px 20px;">
    <p style="font-size:20px;font-weight:800;color:#E8B04B;margin:0 0 24px 0;">🚀 Kit Business</p>
    <h1 style="font-size:26px;line-height:1.2;margin:0 0 12px 0;">Votre kit est prêt</h1>
    <p style="font-size:16px;line-height:1.6;color:#B9B4D6;margin:0 0 24px 0;">
      Bonjour, votre kit <strong style="color:#F6EBD4;">${echapperHtml(offre.titre)}</strong> pour le projet
      <strong style="color:#F6EBD4;">${echapperHtml(params.nomProjet)}</strong>
      (${echapperHtml(params.metierLabel)} — ${echapperHtml(params.paysLabel)}) vient d'être généré.
    </p>
    ${paiement ? `<p style="font-size:13px;line-height:1.6;color:#E8B04B;margin:0 0 20px 0;">${echapperHtml(paiement)}</p>` : ""}

    <div style="background:#1F1B55;border:1px solid rgba(232,176,75,0.35);border-radius:18px;padding:22px;margin-bottom:24px;">
      ${params.liens.livre ? bouton(params.liens.livre, "📘 Ouvrir mon livre stratégique", "#E8B04B") : ""}
      ${params.liens.prompts ? bouton(params.liens.prompts, "🤖 Ouvrir mes prompts IA", "#F3D38F") : ""}
      ${params.liens.sheet ? bouton(params.liens.sheet, "📊 Ouvrir mon tableau de gestion", "#B8643C") : ""}
    </div>

    <p style="font-size:14px;line-height:1.6;color:#B9B4D6;margin:0 0 8px 0;">
      Livre, prompts et tableau de gestion sont lisibles directement dans le navigateur.
      Le tableau se télécharge en CSV (Excel) et se copie en un clic dans Google Sheets.
    </p>
    <p style="font-size:14px;line-height:1.6;color:#B9B4D6;margin:0 0 24px 0;">
      Besoin d'aide ? <a href="${lienAideWhatsApp()}" style="color:#E8B04B;">Écrivez-nous sur WhatsApp</a>.
    </p>
    <p style="font-size:12px;color:#6F6A8A;">© Kit Business — ${SITE_URL}</p>
  </div>
</body></html>`;
}

export function emailBienvenueHtml(params: {
  email: string;
  prenom?: string;
  essai?: boolean;
}): string {
  const nom = params.prenom?.trim() ? ` ${echapperHtml(params.prenom.trim())}` : "";
  const estEssai = params.essai === true;
  return `<!DOCTYPE html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;background:#090D16;font-family:Arial,Helvetica,sans-serif;color:#F6EBD4;">
  <div style="max-width:600px;margin:0 auto;padding:32px 20px;">
    <p style="font-size:20px;font-weight:800;color:#E8B04B;margin:0 0 24px 0;">🚀 e-booklive</p>
    <h1 style="font-size:26px;line-height:1.2;margin:0 0 12px 0;">${estEssai ? `Votre essai Studio Live est activé${nom} 🎬` : `Bienvenue${nom} 👋`}</h1>
    <p style="font-size:16px;line-height:1.7;color:#B9B4D6;">
      ${estEssai
        ? `Votre essai gratuit de <strong style="color:#F6EBD4;">3 jours</strong> est actif.
           Vous avez accès à la régie live, au co-animateur, à la salle et au chat IA
           (20 messages par jour). Aucune carte n'a été demandée et aucun prélèvement
           ne sera effectué à la fin de l'essai.`
        : `Voici ce que nous faisons, simplement : nous transformons votre métier en un
           <strong style="color:#F6EBD4;">kit business clés en main</strong> — livre stratégique,
           prompts IA et Google Sheet de gestion — rédigé pour votre pays et votre activité,
           avec tous les montants en FCFA.`}
    </p>

    ${estEssai
      ? `<div style="background:#111827;border:1px solid rgba(52,211,153,.4);border-radius:18px;padding:20px 22px;margin:24px 0;">
           <p style="margin:0 0 8px 0;font-size:15px;color:#F6EBD4;"><strong>🎬 Votre essai en pratique</strong></p>
           <p style="margin:0;line-height:1.9;font-size:14px;color:#B9B4D6;">
             ✅ Régie live complète et salle Jitsi<br>
             ✅ Chat IA commercial : 20 messages / jour<br>
             ✅ Co-animateur par lien d'invitation<br>
             🔒 Livre Guide : disponible après l'abonnement à 10 USD / 30 jours
           </p>
         </div>
         <p style="margin:0 0 24px 0;">
           <a href="${SITE_URL}/studio-live" style="display:inline-block;background:#34D399;color:#06140F;font-weight:800;text-decoration:none;padding:14px 24px;border-radius:12px;">Ouvrir ma régie</a>
         </p>`
      : ""}

    <div style="background:#1F1B55;border:1px solid rgba(232,176,75,0.35);border-radius:18px;padding:20px 22px;margin:24px 0;">
      <p style="margin:0 0 10px 0;font-size:15px;color:#F6EBD4;"><strong>Nos offres</strong></p>
      <p style="margin:0;line-height:1.9;font-size:14px;color:#B9B4D6;">
        🤖 Prompts IA — ${formaterFcfa(3000)}<br>
        📊 Sheet Automatisé — ${formaterFcfa(3500)}<br>
        📘 Livre Stratégique — ${formaterFcfa(5000)}<br>
        💎 Pack Complet (le plus choisi) — ${formaterFcfa(9000)}
      </p>
    </div>

    <p style="margin:0 0 12px 0;font-size:15px;color:#F6EBD4;"><strong>Vos 8 kits métiers + Autre métier</strong></p>
    <p style="margin:0 0 24px 0;line-height:1.9;font-size:14px;color:#B9B4D6;">
      🛍️ E-commerce &amp; Mode · 🏠 Immobilier · 🍲 Restauration · 💅 Beauté &amp; Bien-être<br>
      🎓 Formation &amp; Éducation · 🚚 Transport &amp; Logistique · 💼 Services B2B · 🩺 Santé · ✍️ Autre métier
    </p>

    <div style="background:#1F1B55;border:1px solid rgba(52,211,153,0.35);border-radius:18px;padding:20px 22px;margin:24px 0;">
      <p style="margin:0 0 10px 0;font-size:15px;color:#F6EBD4;"><strong>🎬 Studio Live — 10 USD / 30 jours</strong></p>
      <p style="margin:0;line-height:1.7;font-size:14px;color:#B9B4D6;">
        La régie live complète : structure du direct, chat IA commercial, salle pour vos
        co-animateurs et votre Livre Guide Live personnalisé offert.
        <a href="${SITE_URL}/studio-live" style="color:#E8B04B;">Découvrir le Studio Live</a>
      </p>
    </div>

    <p style="margin:0 0 24px 0;">
      <a href="${SITE_URL}/boutique" style="display:inline-block;background:#E8B04B;color:#14123A;font-weight:800;text-decoration:none;padding:14px 24px;border-radius:12px;">Choisir mon kit</a>
    </p>

    <p style="font-size:14px;line-height:1.7;color:#B9B4D6;margin:0 0 8px 0;">
      Paiement mobile money ou carte via <strong style="color:#F6EBD4;">SasPay</strong> dans 23 pays,
      ou via <strong style="color:#F6EBD4;">Paddle</strong> en USD partout ailleurs. Les montants locaux sont
      indicatifs ; le prix facturé est recalculé côté serveur.
      Livraison immédiate par email après le paiement, et liens affichés directement à l'écran.
    </p>
    <p style="font-size:14px;line-height:1.7;color:#B9B4D6;margin:0 0 24px 0;">
      Pour toute question : <a href="${lienAideWhatsApp()}" style="color:#E8B04B;">notre WhatsApp</a>
      ou répondez simplement à cet email.
    </p>
    <p style="font-size:12px;color:#6F6A8A;">${estEssai ? "Vous recevez cet email car vous avez activé l'essai gratuit Studio Live." : "Vous recevez cet email car vous avez créé un compte sur e-booklive."}<br>© e-booklive — ${SITE_URL}</p>
  </div>
</body></html>`;
}
