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
    const { secteurClient, emailClient } = await req.json()
    
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )
    const { data: { user } } = await supabaseClient.auth.getUser()
    if (!user) throw new Error("Veuillez vous connecter.")

    const { data: profile } = await supabaseClient.from('profiles').select('credits').eq('id', user.id).single()
    if (!profile || profile.credits < 1) throw new Error("Crédits insuffisants.")

    const deepseekApiKey = Deno.env.get('DEEPSEEK_API_KEY')
    const geminiApiKey = Deno.env.get('GEMINI_API_KEY')
    const resendApiKey = Deno.env.get('RESEND_API_KEY')
    const googleCredsRaw = Deno.env.get('GOOGLE_WORKSPACE_CREDENTIALS')

    const [deepseekRes, geminiRes] = await Promise.all([
      fetch("https://api.deepseek.com/chat/completions", {
        method: "POST",
        headers: { "Content-Type": "application/json", "Authorization": "Bearer " + deepseekApiKey },
        body: JSON.stringify({
          model: "deepseek-chat",
          max_tokens: 4000,
          messages: [{ 
            role: "user", 
            content: "Tu es un consultant McKinsey. Rédige un guide de 4000 mots pour : " + secteurClient + ". Structure avec 5 chapitres. Utilise du HTML pur (<h1>, <h2>, <p>, <ul>)." 
          }],
        })
      }),
      fetch("https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent?key=" + geminiApiKey, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: "Pour " + secteurClient + ", génère un JSON strict : { 'prompts': 'un long texte HTML avec 15 prompts ultra-détaillés', 'sheetData': [['Catégorie', 'Description', 'Montant'], ['Revenu', 'Ventes', '=SUM(C3:C10)'], ['Dépense', 'Achats', '5000'], ['BÉNÉFICE', '', '=C2-C3']] }" }] }],
          generationConfig: { responseMimeType: "application/json" }
        })
      })
    ])

    const deepseekData = await deepseekRes.json()
    const geminiData = await geminiRes.json()
    
    const livreHtml = deepseekData.choices[0].message.content
    const kitData = JSON.parse(geminiData.candidates[0].content.parts[0].text)

    // Google Sheets
    const creds = JSON.parse(googleCredsRaw)
    const privateKey = await crypto.subtle.importKey("pkcs8", pemToArrayBuffer(creds.private_key), { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"])
    const jwt = await create({ alg: "RS256", typ: "JWT" }, { iss: creds.client_email, scope: "https://www.googleapis.com/auth/spreadsheets https://www.googleapis.com/auth/drive.file", aud: creds.token_uri, exp: getNumericDate(3600) }, privateKey)
    const tokenRes = await fetch(creds.token_uri, { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: jwt }) })
    const { access_token } = await tokenRes.json()

    const createSheetRes = await fetch("https://sheets.googleapis.com/v4/spreadsheets", {
      method: "POST",
      headers: { "Authorization": "Bearer " + access_token, "Content-Type": "application/json" },
      body: JSON.stringify({ properties: { title: "Business - " + secteurClient } })
    })
    const sheetId = (await createSheetRes.json()).spreadsheetId
    await fetch("https://sheets.googleapis.com/v4/spreadsheets/" + sheetId + "/values/A1?valueInputOption=USER_ENTERED", {
      method: "PUT", headers: { "Authorization": "Bearer " + access_token, "Content-Type": "application/json" },
      body: JSON.stringify({ values: kitData.sheetData })
    })
    await fetch("https://www.googleapis.com/drive/v3/files/" + sheetId + "/permissions", {
      method: "POST", headers: { "Authorization": "Bearer " + access_token, "Content-Type": "application/json" },
      body: JSON.stringify({ role: "reader", type: "anyone" })
    })
    const sheetUrl = "https://docs.google.com/spreadsheets/d/" + sheetId + "/edit"

    // Sauvegarde en Base de Données
    const { data: newKit, error: dbError } = await supabaseClient.from('kits').insert({
      user_id: user.id,
      secteur_client: secteurClient,
      livre_html: livreHtml,
      prompts_html: kitData.prompts,
      sheet_url: sheetUrl
    }).select().single()

    if (dbError) throw dbError;

    // Envoi de l'email
    const kitId = newKit.id;
    const baseUrl = "https://ynephuutnazdnjhsdlsy.supabase.co/functions/v1/view-kit";
    
    const emailHtml = "<div style='font-family: Arial; text-align: center; padding: 40px; background: #f4f4f5;'>" +
      "<h1 style='color: #111;'>🎉 Votre Kit Business est prêt</h1>" +
      "<p>Secteur : <strong>" + secteurClient + "</strong></p>" +
      "<div style='margin-top: 40px;'>" +
      "<a href='" + baseUrl + "?id=" + kitId + "&type=livre' style='display: inline-block; background: #22C55E; color: white; padding: 15px 30px; text-decoration: none; border-radius: 8px; font-weight: bold; margin: 10px;'>📘 Lire le Livre (PDF)</a>" +
      "<a href='" + baseUrl + "?id=" + kitId + "&type=prompts' style='display: inline-block; background: #111; color: white; padding: 15px 30px; text-decoration: none; border-radius: 8px; font-weight: bold; margin: 10px;'>🤖 Lire les Prompts (PDF)</a>" +
      "</div>" +
      "<p style='margin-top: 40px;'><a href='" + sheetUrl + "' style='color: #22C55E;'>Accéder à mon Tableau Financier</a></p>" +
      "</div>";
    
    await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': "Bearer " + resendApiKey },
      body: JSON.stringify({ from: 'Kit Business <contact@e-booklive.offboard-hub.com>', to: [emailClient], subject: "📘 Vos documents PDF sont prêts", html: emailHtml })
    })

    // Déduire le crédit
    await supabaseClient.from('profiles').update({ credits: profile.credits - 1 }).eq('id', user.id)

    return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 })

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