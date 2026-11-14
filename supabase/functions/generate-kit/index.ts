import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { google } from "npm:googleapis@126.0.1"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  // 👇 ON DÉCLARE LES VARIABLES ICI POUR QUE LE CATCH PUISSE LES VOIR
  let kitId: string | null = null;
  let user: any = null;
  let cost = 0;
  let supabaseClient: any = null;

  try {
    const { secteurClient, emailClient, typeProduit } = await req.json()
    
    // 1. VÉRIFICATION DES CRÉDITS
    supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )
    
    const { data: { user: authUser }, error: authError } = await supabaseClient.auth.getUser()
    if (authError || !authUser) throw new Error("Veuillez vous connecter.")
    user = authUser;

    cost = typeProduit === 'pack' ? 3 : 1;

    // Appel de ta fonction SQL
    const { data: rpcData, error: rpcError } = await supabaseClient.rpc('use_credits', {
      p_user_id: user.id,
      p_metier: secteurClient,
      p_product_type: typeProduit,
      p_cost: cost
    });
    if (rpcError) throw new Error(rpcError.message);
    kitId = rpcData; // On récupère l'ID du kit créé

    const deepseekApiKey = Deno.env.get('DEEPSEEK_API_KEY')
    const geminiApiKey = Deno.env.get('GEMINI_API_KEY')
    const googleCredsRaw = Deno.env.get('GOOGLE_WORKSPACE_CREDENTIALS')

    let livreHtml = "";
    let promptsTexte = "";
    let sheetUrl = "";

    // ==============================================================
    // ÉTAPE 1 : DEEPSEEK - LE STRATÈGE
    // ==============================================================
    const promptDeepSeek = `Rôle : Stratège d'affaires d'élite (First Principles). Cible : "${secteurClient}".
    INTERDICTION : Pas de conseils génériques. Identifie l'hémorragie invisible, les leviers asymétriques, et l'architecture du Sheet.
    Réponds UNIQUEMENT en JSON valide avec cette structure :
    {
      "diagnostic_brutal": "...",
      "leviers_secret": [{"nom_levier": "...", "mecanisme": "...", "action_immediate": "..."}],
      "plan_livre_anti_blabla": "...",
      "architecture_sheet_intelligent": "..."
    }`;

    const dsResponse = await fetch("https://api.deepseek.com/chat/completions", {
      method: "POST",
      headers: { "Content-Type": "application/json", "Authorization": "Bearer " + deepseekApiKey },
      body: JSON.stringify({
        model: "deepseek-chat",
        response_format: { type: "json_object" },
        messages: [{ role: "user", content: promptDeepSeek }],
      })
    })
    const dsData = await dsResponse.json()
    if (!dsData.choices) throw new Error("Erreur API DeepSeek");
    const strategieJSON = JSON.parse(dsData.choices[0].message.content);

    // ==============================================================
    // ÉTAPE 2 : GEMINI - LE RÉDACTEUR (Livre)
    // ==============================================================
    if (typeProduit === 'livre' || typeProduit === 'pack') {
      const promptGeminiLivre = `Rôle : Rédacteur opérationnel. Cible : "${secteurClient}".
      Source stratégique : ${JSON.stringify(strategieJSON)}
      Règles : Ton chirurgical, preuve par les chiffres, scripts exacts, plan d'action 48h.
      Rédige le livre complet en HTML propre (<h1>, <h2>, <p>, <ul>).`;

      const gmLivreRes = await fetch("https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent?key=" + geminiApiKey, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ contents: [{ parts: [{ text: promptGeminiLivre }] }] })
      });
      const gmLivreData = await gmLivreRes.json();
      if (gmLivreData.candidates) livreHtml = gmLivreData.candidates[0].content.parts[0].text;
    }

    // ==============================================================
    // ÉTAPE 3 : GEMINI - LES PROMPTS D'ÉLITE
    // ==============================================================
    if (typeProduit === 'prompt' || typeProduit === 'pack') {
      const promptGeminiPrompts = `Rôle : Ingénieur en systèmes IA. Cible : "${secteurClient}".
      Basé sur ces leviers : ${JSON.stringify(strategieJSON.leviers_secret)}
      Crée 10 prompts d'élite avec Chain-of-Thought. Format : Nom, Problème résolu, Prompt à copier.
      Rédige en texte brut HTML (<b>, <br>).`;

      const gmPromptsRes = await fetch("https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent?key=" + geminiApiKey, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ contents: [{ parts: [{ text: promptGeminiPrompts }] }] })
      });
      const gmPromptsData = await gmPromptsRes.json();
      if (gmPromptsData.candidates) promptsTexte = gmPromptsData.candidates[0].content.parts[0].text;
    }

    // ==============================================================
    // ÉTAPE 4 : GEMINI - ARCHITECTE GOOGLE SHEETS
    // ==============================================================
    let sheetData = null;
    if (typeProduit === 'sheet' || typeProduit === 'pack') {
      const promptGeminiSheet = `Rôle : CFO / Architecte Google Sheets. Cible : "${secteurClient}".
      Contexte : ${strategieJSON.architecture_sheet_intelligent}
      Renvoie UNIQUEMENT un objet JSON pur de cette forme : {"values": [["Colonne 1", "Colonne 2"], ["Donnée 1", "=FORMULE"]]}.
      Inclus des formules =IF(), =SUM() et le calcul du Point Mort.`;

      const gmSheetRes = await fetch("https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent?key=" + geminiApiKey, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
          contents: [{ parts: [{ text: promptGeminiSheet }] }],
          generationConfig: { responseMimeType: "application/json" } 
        })
      });
      const gmSheetData = await gmSheetRes.json();
      try {
        const parsedSheet = JSON.parse(gmSheetData.candidates[0].content.parts[0].text);
        sheetData = parsedSheet.values;
      } catch(e) { console.log("Erreur parsing Sheet JSON"); }
    }

    // ==============================================================
    // ÉTAPE 5 : CRÉATION DU GOOGLE SHEET
    // ==============================================================
    if (sheetData && sheetData.length > 0) {
      const creds = JSON.parse(googleCredsRaw)
      const auth = new google.auth.JWT({
        email: creds.client_email,
        key: creds.private_key,
        scopes: ["https://www.googleapis.com/auth/spreadsheets", "https://www.googleapis.com/auth/drive"],
      });
      const sheets = google.sheets({ version: "v4", auth });
      const drive = google.drive({ version: "v3", auth });

      const createRes = await sheets.spreadsheets.create({ requestBody: { properties: { title: "Business - " + secteurClient } } });
      const spreadsheetId = createRes.data.spreadsheetId;
      
      if (spreadsheetId) {
        await sheets.spreadsheets.values.update({
          spreadsheetId: spreadsheetId,
          range: "A1",
          valueInputOption: "USER_ENTERED",
          requestBody: { values: sheetData },
        });
        await drive.permissions.create({
          fileId: spreadsheetId,
          requestBody: { role: "writer", type: "anyone" },
        });
        sheetUrl = "https://docs.google.com/spreadsheets/d/" + spreadsheetId + "/edit";
      }
    }

    // ==============================================================
    // ÉTAPE 6 : SAUVEGARDE FINALE
    // ==============================================================
    await supabaseClient.from('kits').update({
      livre_html: livreHtml, 
      prompts_html: promptsTexte, 
      sheet_url: sheetUrl,
      status: 'COMPLETED'
    }).eq('id', kitId);

    return new Response(JSON.stringify({ success: true, livre: livreHtml, prompt: promptsTexte, sheetUrl }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200,
    })

  } catch (error) {
    // 👇 SI ÇA PLANTE, ON REMBOURSE LE CLIENT
    if (kitId && user && cost > 0) {
      await supabaseClient.from('kits').delete().eq('id', kitId);
      await supabaseClient.rpc('refund_credits', {
        p_user_id: user.id,
        p_amount: cost
      });
    }

    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : String(error) }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 400 
    })
  }
})