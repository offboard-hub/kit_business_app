// ============================================================================
//  generate-kit — RÉGÉNÉRATION MANUELLE D'UN KIT (consomme des crédits).
//  La livraison automatique après paiement se fait dans verify-payment.
//  Conserve la logique existante : Gemini + DeepSeek + Google Sheets.
//  ⚠️ Les écritures passent par la clé service_role : la RLS des kits interdit
//  toute modification depuis le client, même authentifié.
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders, erreur, json } from "../_shared/cors.ts";
import {
  OFFRES,
  kitParCode,
  paysParCode,
  type TypeProduit,
} from "../_shared/config.ts";
import { construireLiens, genererContenu } from "../_shared/kit-engine.ts";
import { adminClient, utilisateurCourant } from "../_shared/supabase.ts";

interface CorpsRequete {
  typeProduit?: string;
  // Nouveau tunnel (kits métiers)
  metierCode?: string;
  nomProjet?: string;
  paysCode?: string;
  precisions?: string;
  // Compatibilité avec l'ancien écran
  secteurClient?: string;
  problemeClient?: string;
  emailClient?: string;
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return erreur("Méthode non autorisée.", 405);

  let kitId: string | null = null;
  let cout = 0;
  let utilisateurId: string | null = null;
  const admin = adminClient();

  try {
    const utilisateur = await utilisateurCourant(req);
    if (!utilisateur) throw new Error("Veuillez vous connecter.");
    utilisateurId = utilisateur.id;

    const corps = (await req.json()) as CorpsRequete;
    const typeProduit = String(corps.typeProduit ?? "pack") as TypeProduit;
    if (!OFFRES[typeProduit]) throw new Error("Type de produit inconnu.");

    const metier = kitParCode(String(corps.metierCode ?? corps.secteurClient ?? ""));
    const libelleMetier = metier?.label ?? String(corps.secteurClient ?? "Activité locale").trim();
    const pays = paysParCode(String(corps.paysCode ?? "CI")) ?? paysParCode("CI")!;

    const nomProjet = String(corps.nomProjet ?? corps.secteurClient ?? libelleMetier).trim().slice(0, 120);
    const precisions = String(corps.precisions ?? corps.problemeClient ?? "").trim().slice(0, 1000);
    if (nomProjet.length < 2) throw new Error("Renseignez le nom de votre projet.");

    cout = typeProduit === "pack" ? 3 : 1;

    // Débit atomique des crédits + création de la ligne kit (fonction SQL).
    const { data: rpcData, error: rpcError } = await admin.rpc("use_credits", {
      p_user_id: utilisateurId,
      p_metier: libelleMetier,
      p_product_type: typeProduit,
      p_cost: cout,
    });
    if (rpcError) throw new Error(rpcError.message);
    kitId = String(rpcData);

    const contenu = await genererContenu(
      {
        metierCode: metier?.code ?? "agence",
        metierLabel: libelleMetier,
        nomProjet,
        paysCode: pays.code,
        paysLabel: pays.nom,
        devise: pays.devise,
        precisions,
        emailClient: corps.emailClient ?? utilisateur.email,
      },
      typeProduit,
    );

    const { data: kitMisAJour, error: erreurMaj } = await admin
      .from("kits")
      .update({
        livre_html: contenu.livreHtml,
        prompts_html: contenu.promptsTexte,
        sheet_url: contenu.sheetUrl,
        metier_code: metier?.code ?? null,
        nom_projet: nomProjet,
        pays_code: pays.code,
        produit_type: typeProduit,
        status: "COMPLETED",
        error_message: null,
      })
      .eq("id", kitId)
      .select("id, access_token, sheet_url")
      .single();

    if (erreurMaj || !kitMisAJour) {
      throw new Error(erreurMaj?.message ?? "Enregistrement du kit impossible.");
    }

    const liens = construireLiens(
      String(kitMisAJour.id),
      String(kitMisAJour.access_token),
      contenu.sheetUrl,
      typeProduit,
    );

    return json({
      success: true,
      kitId,
      livre: contenu.livreHtml,
      prompt: contenu.promptsTexte,
      sheetUrl: contenu.sheetUrl,
      liens,
      avertissements: contenu.avertissements,
    });
  } catch (erreurInterne) {
    // Remboursement automatique en cas d'échec de génération.
    if (kitId && utilisateurId && cout > 0) {
      try {
        await admin.from("kits").update({ status: "ECHEC" }).eq("id", kitId);
        await admin.rpc("refund_credits", { p_user_id: utilisateurId, p_amount: cout });
      } catch (erreurRemboursement) {
        console.error("Remboursement impossible :", erreurRemboursement);
      }
    }

    console.error("generate-kit :", erreurInterne);
    return erreur(
      erreurInterne instanceof Error ? erreurInterne.message : "Génération impossible.",
      400,
    );
  }
});
