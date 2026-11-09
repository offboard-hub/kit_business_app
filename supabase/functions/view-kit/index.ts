import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

serve(async (req) => {
  const url = new URL(req.url)
  const kitId = url.searchParams.get('id')
  const type = url.searchParams.get('type') || 'livre'

  if (!kitId) return new Response("ID manquant", { status: 400 })

  const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
  const { data: kit } = await supabase.from('kits').select('*').eq('id', kitId).single()

  if (!kit) return new Response("Kit introuvable", { status: 404 })

  const isLivre = type === 'livre'
  const title = isLivre ? "Guide Stratégique" : "Prompts Publicitaires"
  const subtitle = isLivre ? kit.secteur_client : "Vos armes secrètes pour vendre plus"
  
  // Images de couverture depuis Unsplash
  const coverImage = isLivre 
    ? "https://images.unsplash.com/photo-1553729459-efe14ef6055d?q=80&w=1000&auto=format&fit=crop" 
    : "https://images.unsplash.com/photo-1677442136019-21780ecad995?q=80&w=1000&auto=format&fit=crop";

  const content = isLivre ? kit.livre_html : kit.prompts_html

  const html = "<!DOCTYPE html><html lang='fr'><head><meta charset='UTF-8'><title>" + title + "</title>" +
    "<style>" +
    "@import url('https://fonts.googleapis.com/css2?family=Merriweather:wght@300;400;700&family=Montserrat:wght@700&display=swap');" +
    "body { margin: 0; padding: 0; background-color: #f8fafc; font-family: 'Merriweather', serif; color: #1e293b; -webkit-print-color-adjust: exact; }" +
    ".cover { height: 100vh; display: flex; flex-direction: column; justify-content: center; align-items: center; background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%); color: white; text-align: center; position: relative; padding: 20px; }" +
    ".cover-img { width: 100%; height: 100%; object-fit: cover; position: absolute; top: 0; left: 0; opacity: 0.2; z-index: 0; }" +
    ".cover-content { position: relative; z-index: 1; max-width: 800px; }" +
    ".cover h1 { font-family: 'Montserrat', sans-serif; font-size: 4em; margin-bottom: 10px; line-height: 1.1; color: #22C55E; }" +
    ".cover h2 { font-size: 1.5em; font-weight: 300; color: #cbd5e1; margin-bottom: 40px; }" +
    ".cover .author { font-size: 1.2em; letter-spacing: 2px; text-transform: uppercase; border-top: 1px solid #334155; padding-top: 20px; }" +
    ".content { max-width: 800px; margin: 0 auto; padding: 60px 20px; background: white; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1); margin-top: -50px; position: relative; z-index: 2; border-radius: 8px; }" +
    "h1, h2, h3 { font-family: 'Montserrat', sans-serif; color: #0f172a; margin-top: 1.5em; page-break-after: avoid; }" +
    "h1 { font-size: 2em; border-bottom: 2px solid #22C55E; padding-bottom: 10px; }" +
    "h2 { font-size: 1.5em; color: #22C55E; }" +
    "p { font-size: 1.1em; line-height: 1.8; text-align: justify; margin-bottom: 1.5em; }" +
    "ul { background: #f1f5f9; padding: 20px 40px; border-radius: 8px; margin-bottom: 2em; }" +
    "li { margin-bottom: 10px; line-height: 1.6; font-family: 'Helvetica', sans-serif; font-size: 0.95em; }" +
    ".print-btn { display: block; width: 250px; margin: 40px auto; padding: 15px; background: #22C55E; color: white; text-align: center; text-decoration: none; font-family: 'Montserrat', sans-serif; font-weight: bold; font-size: 1.1em; border-radius: 8px; cursor: pointer; border: none; }" +
    "@media print { body { background: white; } .print-btn { display: none; } .cover { height: 100vh; page-break-after: always; } .content { box-shadow: none; margin: 0; padding: 0; max-width: 100%; } h1, h2 { page-break-after: avoid; } }" +
    "</style></head><body>" +
    "<div class='cover'><img src='" + coverImage + "' class='cover-img'><div class='cover-content'>" +
    "<h1>" + title + "</h1><h2>" + subtitle + "</h2><div class='author'>Édition Premium • Kit Business</div></div></div>" +
    "<button class='print-btn' onclick='window.print()'>📥 Télécharger en PDF</button>" +
    "<div class='content'>" + content + "</div>" +
    "<button class='print-btn' onclick='window.print()' style='margin-bottom: 60px;'>📥 Télécharger en PDF</button>" +
    "</body></html>";

  return new Response(html, { headers: { "Content-Type": "text/html; charset=utf-8" } })
})