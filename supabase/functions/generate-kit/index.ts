import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.1/mod.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { secteurClient, emailClient, typeProduit } = await req.json()
    
    // 1. VÉRIFICATION DES CRÉDITS
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )
    const { data: { user } } = await supabaseClient.auth.getUser()
    if (!user) throw new Error("Veuillez vous connecter.")

    const { data: profile } = await supabaseClient.from('profiles').select('credits').eq('id', user.id).single()
    
    // Combien de crédits faut-il pour ce type ?
    const creditsNeeded = typeProduit === 'pack' ? 3 : 1;
    if (!profile || profile.credits < creditsNeeded) throw new Error("Crédits insuffisants.")

    const deepseekApiKey = Deno.env.get('DEEPSEEK_API_KEY')
    const geminiApiKey = Deno.env.get('GEMINI_API_KEY')
    const googleCredsRaw = Deno.env.get('GOOGLE_WORKSPACE_CREDENTIALS')

    let livre = "";
    let prompts = "";
    let sheetUrl = "";
    let sheetData = null;

    // --- APPEL 1 : DEEPSEEK (Le Livre) ---
    if (typeProduit === 'livre' || typeProduit === 'pack') {
      const dsRes = await fetch("https://api.deepseek.com/chat/completions", {
        method: "POST",
        headers: { "Content-Type": "application/json", "Authorization": "Bearer " + deepseekApiKey },
        body: JSON.stringify({
          model: "deepseek-chat",
          max_tokens: 4000,
          messages: [{ role: "user", content: "Tu es un consultant McKinsey. Rédige un guide de 4000 mots pour : " + secteurClient + ". Utilise du HTML (<h1>, <h2>, <p>)." }],
        })
      })
      const dsData = await dsRes.json()
      if(dsData.choices) livre = dsData.choices[0].message.content;
    }

    // --- APPEL 2 : GEMINI (Prompts et/ou Sheet) ---
    if (typeProduit === 'prompt' || typeProduit === 'sheet' || typeProduit === 'pack') {
      const promptDemande = typeProduit === 'prompt' ? "un tableau 'prompts' (15 prompts HTML)" : 
                            (typeProduit === 'sheet' ? "un tableau 'sheetData' (données financières)" : 
                            "un JSON avec 'prompts' (HTML) et 'sheetData'");

      const gRes = await fetch("https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent?key=" + geminiApiKey, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: "Pour " + secteurClient + ", génère " + promptDemande + ". Ne renvoie que le JSON." }] }],
          generationConfig: { responseMimeType: "application/json" }
        })
      })
      const gData = await gRes.json()
      if(gData.candidates) {
        const parsed = JSON.parse(gData.candidates[0].content.parts[0].text);
        if(parsed.prompts) prompts = parsed.prompts;
        if(parsed.sheetData) sheetData = parsed.sheetData;
      }
    }

    // --- APPEL 3 : GOOGLE SHEETS ---
    if ((typeProduit === 'sheet' || typeProduit === 'pack') && sheetData) {
      const creds = JSON.parse(googleCredsRaw)
      const privateKey = await crypto.subtle.importKey("pkcs8", pemToArrayBuffer(creds.private_key), { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"])
      const jwt = await create({ alg: "RS256", typ: "JWT" }, { iss: creds.client_email, scope: "https://www.googleapis.com/auth/spreadsheets https://www.googleapis.com/auth/drive.file", aud: creds.token_uri, exp: getNumericDate(3600) }, privateKey)
      const tokenRes = await fetch(creds.token_uri, { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: jwt }) })
      const { access_token } = await tokenRes.json()

      const createSheetRes = await fetch("https://sheets.googleapis.com/v4/spreadsheets", {
        method: "POST", headers: { "Authorization": "Bearer " + access_token, "Content-Type": "application/json" },
        body: JSON.stringify({ properties: { title: "Business - " + secteurClient } })
      })
      const sheet = await createSheetRes.json()
      
      if (sheet.spreadsheetId) {
        await fetch("https://sheets.googleapis.com/v4/spreadsheets/" + sheet.spreadsheetId + "/values/A1?valueInputOption=USER_ENTERED", {
          method: "PUT", headers: { "Authorization": "Bearer " + access_token, "Content-Type": "application/json" },
          body: JSON.stringify({ values: sheetData })
        })
        
        // 👇 La correction est ici : on utilise bien les backticks
        sheetUrl = "https://docs.google.com/spreadsheets/d/" + sheet.spreadsheetId + "/edit";
      }
    }

    // --- SAUVEGARDE EN BASE ---
    const { data: newKit } = await supabaseClient.from('kits').insert({
      user_id: user.id, secteur_client: secteurClient, livre_html: livre, prompts_html: prompts, sheet_url: sheetUrl
    }).select().single()

    // --- DEDUIRE LES CREDITS ---
    await supabaseClient.from('profiles').update({ credits: profile.credits - creditsNeeded }).eq('id', user.id)

    return new Response(JSON.stringify({ success: true, livre, prompt: prompts, sheetUrl }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200,
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 })
  }
})

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem.replace(/-----BEGIN PRIVATE KEY-----/, "").replace(/-----END PRIVATE KEY-----/, "").replace(/\s+/g, "");
  const binary = atob(b64); const buffer = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) buffer[i] = binary.charCodeAt(i);
  return buffer.buffer;
}