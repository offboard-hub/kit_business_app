// ============================================================================
//  verify-payment — vérification du paiement + livraison / activation.
//
//  Sécurité :
//  • Le paiement est TOUJOURS rattaché côté serveur à la commande ou à
//    l'abonnement (session SasPay ou transaction Paddle stockée). Un
//    `payment_id` fourni par le client ne peut jamais désigner un autre
//    paiement ; il est rejeté s'il diffère de celui de la ligne.
//  • Le montant et la devise sont contrôlés avant toute livraison.
//  • La réponse d'un kit est expurgée (jamais d'email / WhatsApp / identifiants
//    de paiement). Le guide Studio n'est renvoyé qu'au propriétaire authentifié.
//  • Idempotent : les mises à jour sont conditionnelles et les index uniques
//    empêchent la réutilisation d'un même paiement.
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders, erreur, json } from "../_shared/cors.ts";
import { OFFRES, type TypeProduit } from "../_shared/config.ts";
import {
  paiementDepuisRequete,
  sessionDepuisRequete,
  statutSession,
  verifierPaiement,
} from "../_shared/saspay.ts";
import {
  adminClient,
  utilisateurCourant,
  type UtilisateurCourant,
} from "../_shared/supabase.ts";
import {
  chargerCommande,
  chargerCommandeParSession,
  livrerCommande,
  type Commande,
  type ResultatLivraison,
} from "../_shared/fulfillment.ts";
import {
  activerAbonnementStudio,
  chargerAbonnement,
  chargerGuide,
  type StudioAbonnement,
} from "../_shared/studio.ts";
import {
  recupererTransactionPaddle,
  transactionPaddlePayee,
} from "../_shared/paddle.ts";

const STATUTS_PAYES = new Set(["SUCCESS", "PAID", "PAYE", "COMPLETED", "SUCCEEDED"]);
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DEVISES_DECIMALES = new Set(["EUR", "USD", "GBP", "CHF", "CAD", "AUD"]);

function nombreCorps(corps: Record<string, unknown>, ...cles: string[]): string | null {
  for (const cle of cles) {
    const valeur = corps[cle];
    if (typeof valeur === "string" && valeur.trim()) return valeur.trim();
  }
  return null;
}

function montantAttendu(commande: Commande): number {
  return Number(commande.montant_local ?? commande.montant_fcfa ?? 0);
}

function deviseAttendue(commande: Commande): string {
  return commande.devise_locale ?? commande.devise ?? "XOF";
}

/** Vérifie devise + montant. Renvoie un message d'erreur ou null. */
function controlerMontant(
  montant: number | null,
  deviseRecue: string | null,
  attendu: number,
  devise: string,
): string | null {
  if (deviseRecue && deviseRecue.toUpperCase() !== devise.toUpperCase()) {
    return `Devise reçue (${deviseRecue}) différente de la devise attendue (${devise}). Contactez le support.`;
  }
  if (montant === null) {
    return "Le montant du paiement n'a pas pu être vérifié. Contactez le support.";
  }
  const tolerance = DEVISES_DECIMALES.has(devise.toUpperCase()) ? 0.02 : 1;
  if (montant + tolerance < attendu) {
    return `Montant reçu insuffisant (${montant} ${devise} pour ${attendu} attendus). Contactez le support.`;
  }
  return null;
}

function proprietaireStudio(
  abonnement: StudioAbonnement,
  utilisateur: UtilisateurCourant | null,
): boolean {
  if (!utilisateur) return false;
  if (abonnement.user_id) return abonnement.user_id === utilisateur.id;
  return !!abonnement.email &&
    !!utilisateur.email &&
    abonnement.email.toLowerCase() === utilisateur.email.toLowerCase();
}

/** Vue publique d'un abonnement : aucune donnée personnelle. */
function abonnementPublic(abonnement: StudioAbonnement): Record<string, unknown> {
  return {
    id: abonnement.id,
    status: abonnement.status,
    provider: abonnement.provider,
    devise: abonnement.devise,
    montant_local: abonnement.montant_local,
    guide_status: abonnement.guide_status,
    expires_at: abonnement.expires_at,
    paid_at: abonnement.paid_at,
    created_at: abonnement.created_at,
  };
}

/** Vue publique d'une commande : jamais email / WhatsApp / identifiants. */
function commandePublique(commande: Commande): Record<string, unknown> {
  return {
    id: commande.id,
    nom_projet: commande.nom_projet,
    metier_code: commande.metier_code,
    metier_label: commande.metier_label,
    produit_type: commande.produit_type,
    montant_fcfa: commande.montant_fcfa,
    montant_local: commande.montant_local ?? null,
    devise_locale: commande.devise_locale ?? null,
    devise: commande.devise,
    pays_label: commande.pays_label,
    statut: commande.statut,
    created_at: commande.created_at,
    paid_at: commande.paid_at,
    delivered_at: commande.delivered_at,
  };
}

function reponseKit(resultat: ResultatLivraison): Response {
  return json({
    success: true,
    paid: true,
    ...resultat,
    commande: commandePublique(resultat.commande),
  });
}

async function reponseStudio(
  abonnement: StudioAbonnement,
  options: {
    paid: boolean;
    source: string;
    proprietaire: boolean;
    message?: string;
    guide?: unknown;
  },
): Promise<Response> {
  if (!options.proprietaire) {
    return json({
      success: true,
      paid: options.paid,
      statut: abonnement.status,
      subscription_id: abonnement.id,
      abonnement: abonnementPublic(abonnement),
      guide: null,
      source: options.source,
      ...(options.message ? { message: options.message } : {}),
    });
  }

  const guide = options.guide ?? await chargerGuide(abonnement.id);
  return json({
    success: true,
    paid: options.paid,
    statut: abonnement.status,
    subscription_id: abonnement.id,
    abonnement,
    guide,
    source: options.source,
    ...(options.message ? { message: options.message } : {}),
  });
}

async function journaliserTransaction(params: {
  userId: string | null;
  provider: "saspay" | "paddle";
  token: string | null;
  produitType: string | null;
  montant: number;
  devise: string;
}): Promise<void> {
  try {
    await adminClient().from("transactions").insert({
      user_id: params.userId,
      provider: params.provider,
      transaction_token: params.token,
      product_id: params.produitType && OFFRES[params.produitType as TypeProduit]
        ? OFFRES[params.produitType as TypeProduit].productId
        : null,
      amount_paid: params.montant,
      currency: params.devise,
      status: "success",
    });
  } catch (erreurJournal) {
    console.error("verify-payment : journal transaction impossible.", erreurJournal);
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST" && req.method !== "GET") return erreur("Méthode non autorisée.", 405);

  try {
    const url = new URL(req.url);
    let corps: Record<string, unknown> = {};

    if (req.method === "POST") {
      try {
        corps = (await req.json()) as Record<string, unknown>;
      } catch {
        corps = {};
      }
    }

    const orderId = nombreCorps(corps, "order_id", "orderId") ??
      url.searchParams.get("order_id");
    const subscriptionId = nombreCorps(corps, "subscription_id", "subscriptionId") ??
      url.searchParams.get("subscription_id") ??
      url.searchParams.get("abonnement");
    const providerParam = (nombreCorps(corps, "provider") ?? url.searchParams.get("provider") ?? "")
      .toLowerCase();
    const sessionId = sessionDepuisRequete(url, corps);
    const paymentIdParam = paiementDepuisRequete(url, corps);

    if (orderId && !UUID.test(orderId)) {
      return erreur("Identifiant de commande invalide.", 400);
    }
    if (subscriptionId && !UUID.test(subscriptionId)) {
      return erreur("Identifiant d'abonnement invalide.", 400);
    }

    const admin = adminClient();
    const utilisateur = await utilisateurCourant(req);

    // ==================================================================
    //  A. STUDIO LIVE
    // ==================================================================
    if (subscriptionId) {
      const abonnement = await chargerAbonnement(String(subscriptionId));
      if (!abonnement) {
        return erreur("Abonnement Studio introuvable. Vérifiez votre lien de paiement.", 404);
      }

      const proprietaire = proprietaireStudio(abonnement, utilisateur);
      const provider = abonnement.provider || providerParam || "saspay";

      if (abonnement.status === "ACTIF") {
        return await reponseStudio(abonnement, {
          paid: true,
          source: "deja_actif",
          proprietaire,
        });
      }

      // ---------------- SasPay ----------------
      if (provider !== "paddle") {
        let paymentId = abonnement.saspay_payment_id ?? null;
        let statutSaspay = "";
        let montantVerifie: number | null = null;
        let deviseVerifiee: string | null = null;
        let source = "payment_verify";

        if (abonnement.saspay_session_id) {
          const session = await statutSession(abonnement.saspay_session_id);
          statutSaspay = session.statut;
          montantVerifie = session.montant;
          deviseVerifiee = session.devise;
          source = "session_status";
          if (session.paymentId) {
            if (paymentId && session.paymentId !== paymentId) {
              return erreur("Paiement non rattaché à cet abonnement.", 409);
            }
            paymentId = session.paymentId;
          }
        }

        if (paymentIdParam && paymentId && paymentIdParam !== paymentId) {
          return erreur("Ce paiement n'est pas rattaché à cet abonnement.", 409);
        }
        if (paymentIdParam && !paymentId) {
          return erreur("Paiement non rattaché à cet abonnement.", 409);
        }

        let paye = false;
        if (paymentId) {
          const verification = await verifierPaiement(paymentId);
          paye = verification.paye;
          montantVerifie = verification.montant;
          deviseVerifiee = verification.devise;
          statutSaspay = verification.statut;
          source = "payment_verify";
        } else {
          paye = STATUTS_PAYES.has(statutSaspay);
        }

        if (!paye) {
          return await reponseStudio(abonnement, {
            paid: false,
            source,
            proprietaire,
            message:
              "Paiement en attente de confirmation. Validez la demande sur votre téléphone.",
          });
        }

        if (montantVerifie === null) {
          if (paymentId) {
            return erreur(
              "Le montant du paiement n'a pas pu être vérifié. Contactez le support.",
              402,
            );
          }
          return await reponseStudio(abonnement, {
            paid: false,
            source,
            proprietaire,
            message:
              "Paiement en cours de confirmation par l'opérateur. Actualisez dans quelques instants.",
          });
        }

        const problemeMontant = controlerMontant(
          montantVerifie,
          deviseVerifiee,
          Number(abonnement.montant_local),
          abonnement.devise,
        );
        if (problemeMontant) return erreur(problemeMontant, 402);

        if (paymentId && paymentId !== abonnement.saspay_payment_id) {
          const { error: erreurPaiement } = await admin
            .from("studio_subscriptions")
            .update({ saspay_payment_id: paymentId })
            .eq("id", abonnement.id);
          if (erreurPaiement) {
            return erreur("Ce paiement a déjà été utilisé pour un autre abonnement.", 409);
          }
        }

        await journaliserTransaction({
          userId: abonnement.user_id,
          provider: "saspay",
          token: paymentId ?? abonnement.saspay_session_id,
          produitType: null,
          montant: Number(abonnement.montant_local),
          devise: abonnement.devise,
        });

        const activation = await activerAbonnementStudio(abonnement.id, {
          attendreGuide: false,
        });
        return await reponseStudio(activation.abonnement, {
          paid: true,
          source,
          proprietaire,
          guide: activation.guide,
        });
      }

      // ---------------- Paddle ----------------
      const transactionId = abonnement.paddle_transaction_id;
      if (!transactionId) {
        return await reponseStudio(abonnement, {
          paid: false,
          source: "paddle",
          proprietaire,
          message: "Transaction Paddle introuvable. Relancez le paiement depuis le Studio Live.",
        });
      }

      const transaction = await recupererTransactionPaddle(transactionId);
      if (!transactionPaddlePayee(transaction.statut)) {
        return await reponseStudio(abonnement, {
          paid: false,
          source: "paddle",
          proprietaire,
          message:
            `Paiement Paddle en attente (statut ${transaction.statut || "draft"}). Terminez le paiement puis actualisez.`,
        });
      }

      const problemeMontant = controlerMontant(
        transaction.montantTotal,
        transaction.devise,
        Number(abonnement.montant_local),
        abonnement.devise,
      );
      if (problemeMontant) return erreur(problemeMontant, 402);

      await journaliserTransaction({
        userId: abonnement.user_id,
        provider: "paddle",
        token: transactionId,
        produitType: null,
        montant: transaction.montantTotal ?? Number(abonnement.montant_local),
        devise: transaction.devise ?? abonnement.devise,
      });

      const activation = await activerAbonnementStudio(abonnement.id, {
        attendreGuide: false,
      });
      return await reponseStudio(activation.abonnement, {
        paid: true,
        source: "paddle",
        proprietaire,
        guide: activation.guide,
      });
    }

    // ==================================================================
    //  B. KIT (commande)
    // ==================================================================
    let commande: Commande | null = null;

    if (orderId) {
      commande = await chargerCommande(String(orderId));
    } else if (sessionId) {
      commande = await chargerCommandeParSession(sessionId);
    }

    if (!commande) {
      return erreur("Commande introuvable. Vérifiez votre lien de paiement.", 404);
    }

    if ((commande.kind ?? "kit") === "studio") {
      return erreur("Cette référence correspond à un abonnement Studio Live.", 409);
    }

    if (commande.statut === "LIVRE" && commande.kit_id) {
      return reponseKit(await livrerCommande(commande.id));
    }

    const provider = (commande.provider ?? providerParam ?? "saspay").toLowerCase();

    // ---------------- Kit Paddle ----------------
    if (provider === "paddle") {
      const transactionId = commande.paddle_transaction_id;
      if (!transactionId) {
        return erreur("Transaction Paddle introuvable. Relancez le paiement.", 400);
      }

      if (commande.statut !== "PAYE" && commande.statut !== "ERREUR" && commande.statut !== "EN_COURS") {
        const transaction = await recupererTransactionPaddle(transactionId);

        if (!transactionPaddlePayee(transaction.statut)) {
          return json({
            success: true,
            paid: false,
            order_id: commande.id,
            statut: commande.statut,
            paddle_status: transaction.statut || "draft",
            source: "paddle",
            message:
              `Paiement Paddle en attente (statut ${transaction.statut || "draft"}). Terminez le paiement puis actualisez.`,
          });
        }

        const problemeMontant = controlerMontant(
          transaction.montantTotal,
          transaction.devise,
          montantAttendu(commande),
          deviseAttendue(commande),
        );
        if (problemeMontant) return erreur(problemeMontant, 402);

        const { data: passagePaye } = await admin
          .from("orders")
          .update({
            statut: "PAYE",
            paid_at: new Date().toISOString(),
            paddle_transaction_id: transactionId,
            ...(transaction.montantTotal !== null
              ? { montant_local: transaction.montantTotal }
              : {}),
            ...(transaction.devise ? { devise_locale: transaction.devise } : {}),
          })
          .eq("id", commande.id)
          .in("statut", ["EN_ATTENTE", "ECHEC"])
          .select("id")
          .maybeSingle();

        if (passagePaye) {
          await journaliserTransaction({
            userId: commande.user_id,
            provider: "paddle",
            token: transactionId,
            produitType: commande.produit_type,
            montant: transaction.montantTotal ?? montantAttendu(commande),
            devise: transaction.devise ?? deviseAttendue(commande),
          });
        }
      }

      try {
        return reponseKit(await livrerCommande(commande.id));
      } catch (erreurLivraison) {
        const message = erreurLivraison instanceof Error
          ? erreurLivraison.message
          : String(erreurLivraison);
        return json(
          {
            success: false,
            paid: true,
            order_id: commande.id,
            error: `Paiement confirmé, mais la génération a échoué : ${message}`,
            retry: true,
          },
          502,
        );
      }
    }

    // ---------------- Kit SasPay ----------------
    let paymentId = commande.saspay_payment_id ?? null;
    let statutSaspay = "";
    let montantVerifie: number | null = null;
    let deviseVerifiee: string | null = null;
    let source = "payment_verify";

    if (commande.saspay_session_id) {
      const session = await statutSession(commande.saspay_session_id);
      statutSaspay = session.statut;
      montantVerifie = session.montant;
      deviseVerifiee = session.devise;
      source = "session_status";
      if (session.paymentId) {
        if (paymentId && session.paymentId !== paymentId) {
          return erreur("Paiement non rattaché à cette commande.", 409);
        }
        paymentId = session.paymentId;
      }
    }

    if (paymentIdParam && paymentId && paymentIdParam !== paymentId) {
      return erreur("Ce paiement n'est pas rattaché à cette commande.", 409);
    }
    if (paymentIdParam && !paymentId) {
      return erreur("Paiement non rattaché à cette commande.", 409);
    }

    let paye = false;
    if (paymentId) {
      const verification = await verifierPaiement(paymentId);
      statutSaspay = verification.statut;
      montantVerifie = verification.montant;
      deviseVerifiee = verification.devise;
      paye = verification.paye;
      source = "payment_verify";
    } else {
      paye = STATUTS_PAYES.has(statutSaspay);
    }

    if (!paye) {
      return json({
        success: true,
        paid: false,
        order_id: commande.id,
        statut: commande.statut,
        saspay_status: statutSaspay || "EN_ATTENTE",
        source,
        message: "Paiement en attente de confirmation. Validez la demande sur votre téléphone.",
      });
    }

    if (montantVerifie === null) {
      if (paymentId) {
        return erreur(
          "Le montant du paiement n'a pas pu être vérifié. Contactez le support.",
          402,
        );
      }
      return json({
        success: true,
        paid: false,
        order_id: commande.id,
        statut: commande.statut,
        source,
        message:
          "Paiement en cours de confirmation par l'opérateur. Actualisez dans quelques instants.",
      });
    }

    const problemeMontant = controlerMontant(
      montantVerifie,
      deviseVerifiee,
      montantAttendu(commande),
      deviseAttendue(commande),
    );
    if (problemeMontant) return erreur(problemeMontant, 402);

    const { data: passagePaye, error: erreurPassage } = await admin
      .from("orders")
      .update({
        statut: "PAYE",
        paid_at: new Date().toISOString(),
        saspay_payment_id: paymentId,
      })
      .eq("id", commande.id)
      .in("statut", ["EN_ATTENTE", "ECHEC"])
      .select("id")
      .maybeSingle();

    if (erreurPassage) {
      return erreur("Ce paiement a déjà été utilisé pour une autre commande.", 409);
    }

    if (passagePaye) {
      await journaliserTransaction({
        userId: commande.user_id,
        provider: "saspay",
        token: paymentId ?? commande.saspay_session_id,
        produitType: commande.produit_type,
        montant: commande.montant_local ?? commande.montant_fcfa,
        devise: deviseAttendue(commande),
      });
    }

    try {
      return reponseKit(await livrerCommande(commande.id));
    } catch (erreurLivraison) {
      const message = erreurLivraison instanceof Error
        ? erreurLivraison.message
        : String(erreurLivraison);
      return json(
        {
          success: false,
          paid: true,
          order_id: commande.id,
          error: `Paiement confirmé, mais la génération a échoué : ${message}`,
          retry: true,
        },
        502,
      );
    }
  } catch (erreurInterne) {
    console.error("verify-payment :", erreurInterne);
    return erreur(
      erreurInterne instanceof Error ? erreurInterne.message : "Vérification du paiement impossible.",
      500,
    );
  }
});
