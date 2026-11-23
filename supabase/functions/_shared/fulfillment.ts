// ============================================================================
//  LIVRAISON D'UNE COMMANDE — orchestrée par verify-payment et saspay-webhook.
//  Idempotente : une commande payée ne peut être livrée qu'une seule fois.
//  Seul canal automatique : l'email Resend (les liens restent aussi affichés
//  sur la page de confirmation).
// ============================================================================

import { OFFRES, type TypeProduit } from "./config.ts";
import { adminClient } from "./supabase.ts";
import {
  construireLiens,
  genererContenu,
  type LiensKit,
} from "./kit-engine.ts";
import {
  emailLivraisonHtml,
  envoyerEmail,
  type ResultatEnvoi,
} from "./delivery.ts";

export interface Commande {
  id: string;
  user_id: string | null;
  email: string;
  nom_projet: string;
  metier_code: string;
  metier_label: string | null;
  produit_type: TypeProduit;
  montant_fcfa: number;
  devise: string;
  pays_code: string;
  pays_label: string | null;
  indicatif: string | null;
  whatsapp: string;
  precisions: string | null;
  statut: string;
  saspay_session_id: string | null;
  saspay_payment_id: string | null;
  kit_id: string | null;
  delivered_email: boolean;
  delivery_error: string | null;
  created_at: string;
  paid_at: string | null;
  delivered_at: string | null;
  /** Prestataire de paiement : 'saspay' | 'paddle'. */
  provider: string | null;
  paddle_transaction_id: string | null;
  /** Montant réellement facturé et sa devise (null pour les anciennes lignes). */
  montant_local: number | null;
  devise_locale: string | null;
  /** 'kit' | 'studio' — seuls les kits sont livrés par cette fonction. */
  kind: string | null;
}

export interface ResultatLivraison {
  commande: Commande;
  kitId: string;
  liens: LiensKit;
  livraison: {
    email: { envoye: boolean; error?: string };
  };
  avertissements: string[];
}

/** Charge une commande par son identifiant. */
export async function chargerCommande(id: string): Promise<Commande | null> {
  const admin = adminClient();
  const { data, error } = await admin.from("orders").select("*").eq("id", id).maybeSingle();
  if (error) throw new Error(`Lecture de la commande impossible : ${error.message}`);
  return (data as Commande | null) ?? null;
}

/** Charge une commande à partir d'un identifiant de session SasPay. */
export async function chargerCommandeParSession(sessionId: string): Promise<Commande | null> {
  const admin = adminClient();
  const { data, error } = await admin
    .from("orders")
    .select("*")
    .eq("saspay_session_id", sessionId)
    .maybeSingle();
  if (error) throw new Error(`Lecture de la commande impossible : ${error.message}`);
  return (data as Commande | null) ?? null;
}

function resultatDepuisKit(commande: Commande, kit: Record<string, unknown>): ResultatLivraison {
  const liens = construireLiens(
    String(kit.id),
    String(kit.access_token ?? ""),
    String(kit.sheet_url ?? ""),
    commande.produit_type,
  );
  return {
    commande,
    kitId: String(kit.id),
    liens,
    livraison: {
      email: { envoye: commande.delivered_email },
    },
    avertissements: [],
  };
}

/**
 * Génère le kit complet, enregistre les métadonnées texte, puis envoie
 * immédiatement les liens par email (Resend).
 *
 * Seuls les kits sont traités ici : les abonnements Studio Live passent par
 * `activerAbonnementStudio` (voir _shared/studio.ts).
 */
export async function livrerCommande(
  orderId: string,
  options: { metierLabel?: string } = {},
): Promise<ResultatLivraison> {
  const admin = adminClient();

  let commande = await chargerCommande(orderId);
  if (!commande) throw new Error("Commande introuvable.");
  if ((commande.kind ?? "kit") === "studio") {
    throw new Error("Cette commande est un abonnement Studio Live, pas un kit.");
  }

  // Déjà livrée : on renvoie les liens existants (rechargement de la page de confirmation).
  if (commande.statut === "LIVRE" && commande.kit_id) {
    const { data: kit } = await admin.from("kits").select("*").eq("id", commande.kit_id).maybeSingle();
    if (kit) return resultatDepuisKit(commande, kit as Record<string, unknown>);
  }

  // Verrou atomique anti-double livraison (deux appels simultanés : un seul passe).
  const { data: verrou, error: erreurVerrou } = await admin
    .from("orders")
    .update({ statut: "EN_COURS", delivery_error: null })
    .eq("id", orderId)
    .in("statut", ["PAYE", "ERREUR"])
    .select("*")
    .maybeSingle();

  if (erreurVerrou) throw new Error(`Verrouillage de la commande impossible : ${erreurVerrou.message}`);

  if (!verrou) {
    commande = (await chargerCommande(orderId))!;
    if (commande.statut === "LIVRE" && commande.kit_id) {
      const { data: kit } = await admin.from("kits").select("*").eq("id", commande.kit_id).maybeSingle();
      if (kit) return resultatDepuisKit(commande, kit as Record<string, unknown>);
    }
    throw new Error("Cette commande est déjà en cours de livraison. Réessayez dans quelques instants.");
  }

  commande = verrou as Commande;
  const offre = OFFRES[commande.produit_type];
  const avertissements: string[] = [];
  const metierLabel = options.metierLabel?.trim() || commande.metier_label || commande.metier_code;

  try {
    const contenu = await genererContenu(
      {
        metierCode: commande.metier_code,
        metierLabel,
        nomProjet: commande.nom_projet,
        paysCode: commande.pays_code,
        paysLabel: commande.pays_label ?? commande.pays_code,
        devise: commande.devise_locale ?? commande.devise,
        precisions: commande.precisions,
        emailClient: commande.email,
      },
      commande.produit_type,
    );
    avertissements.push(...contenu.avertissements);

    const { data: kitCree, error: erreurKit } = await admin
      .from("kits")
      .insert({
        user_id: commande.user_id,
        order_id: commande.id,
        secteur_client: metierLabel,
        metier_code: commande.metier_code,
        nom_projet: commande.nom_projet,
        pays_code: commande.pays_code,
        produit_type: commande.produit_type,
        whatsapp: commande.whatsapp,
        livre_html: contenu.livreHtml,
        prompts_html: contenu.promptsTexte,
        sheet_url: contenu.sheetUrl,
        status: "COMPLETED",
      })
      .select("*")
      .single();

    if (erreurKit || !kitCree) {
      throw new Error(`Enregistrement du kit impossible : ${erreurKit?.message ?? "inconnu"}`);
    }

    const liens = construireLiens(
      String(kitCree.id),
      String(kitCree.access_token),
      contenu.sheetUrl,
      commande.produit_type,
    );

    const htmlEmail = emailLivraisonHtml({
      nomProjet: commande.nom_projet,
      metierLabel,
      paysLabel: commande.pays_label ?? commande.pays_code,
      produit: commande.produit_type,
      liens,
      paiement: {
        provider: commande.provider,
        montant: commande.montant_local,
        devise: commande.devise_locale,
        montantFcfa: commande.montant_fcfa,
      },
    });

    const envoiEmail: ResultatEnvoi = commande.delivered_email
      ? { ok: true, canal: "email" }
      : await envoyerEmail({
          to: commande.email,
          subject: `Votre ${offre.titre} est prêt — ${commande.nom_projet}`,
          html: htmlEmail,
        });

    const erreurs = envoiEmail.error ?? null;

    const { data: commandeFinale } = await admin
      .from("orders")
      .update({
        statut: "LIVRE",
        kit_id: kitCree.id,
        delivered_email: envoiEmail.ok,
        delivery_error: erreurs,
        delivered_at: new Date().toISOString(),
        paid_at: commande.paid_at ?? new Date().toISOString(),
      })
      .eq("id", commande.id)
      .select("*")
      .single();

    return {
      commande: (commandeFinale as Commande) ?? commande,
      kitId: String(kitCree.id),
      liens,
      livraison: {
        email: { envoye: envoiEmail.ok, error: envoiEmail.error },
      },
      avertissements,
    };
  } catch (erreur) {
    const message = erreur instanceof Error ? erreur.message : String(erreur);
    await admin
      .from("orders")
      .update({ statut: "ERREUR", delivery_error: message.slice(0, 900) })
      .eq("id", commande.id);
    throw erreur;
  }
}
