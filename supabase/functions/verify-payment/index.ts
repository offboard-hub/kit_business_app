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
    
    const { data: { user }, error: authError } = await supabaseClient.auth.getUser()
    if (authError || !user) throw new Error("Utilisateur non connecté")

    let isValid = false;
    if (provider === 'test_mode') {
      isValid = true; 
    } 
    
    if (!isValid) throw new Error("Paiement invalide.");

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!, 
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )
    
    const { data: product, error: productError } = await supabaseAdmin
      .from('products')
      .select('credits_added, name')
      .eq('id', productId)
      .single()

    if (productError || !product) {
      throw new Error("Produit introuvable avec l'ID: " + productId);
    }

    const { data: profile } = await supabaseAdmin
      .from('profiles')
      .select('credits')
      .eq('id', user.id)
      .single()

    const currentCredits = profile?.credits || 0;
    
    await supabaseAdmin
      .from('profiles')
      .update({ credits: currentCredits + product.credits_added })
      .eq('id', user.id)

    await supabaseAdmin.from('transactions').insert({
      user_id: user.id, 
      provider: provider, 
      transaction_token: transactionId, 
      product_id: productId, 
      amount_paid: amountPaid, 
      status: 'success'
    })

    return new Response(JSON.stringify({ success: true, added: product.credits_added }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 200 
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 400 
    })
  }
})