import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { productId, transactionId, provider, amountPaid } = await req.json()

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )
    
    const { data: { user } } = await supabaseClient.auth.getUser()
    if (!user) throw new Error("Utilisateur non connecté")

    let isValid = false;

    // MODE TEST (Pour que tu puisses tester sans les vraies clés API)
    if (provider === 'test_mode') {
      console.log("Paiement simulé accepté");
      isValid = true; 
    } 
    else if (provider === 'youcan') {
      // Ici tu mettras la vraie vérification YouCan Pay plus tard
      isValid = true; 
    } 
    else if (provider === 'flutterwave') {
      // Ici tu mettras la vraie vérification Flutterwave plus tard
      isValid = true; 
    }

    if (!isValid) throw new Error("Paiement invalide.");

    // Ajouter les crédits avec les droits admin
    const supabaseAdmin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
    const { data: product } = await supabaseAdmin.from('products').select('credits_added').eq('id', productId).single()
    
    const { data: profile } = await supabaseAdmin.from('profiles').select('credits').eq('id', user.id).single()
    await supabaseAdmin.from('profiles').update({ credits: (profile?.credits || 0) + product!.credits_added }).eq('id', user.id)

    return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 })
  }
})