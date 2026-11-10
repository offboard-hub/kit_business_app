import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')

serve(async (req) => {
  try {
    const payload = await req.json()
    
    // Supabase nous envoie l'email et le lien magique dans le payload du hook
    const email = payload.user.email
    const magicLink = payload.email_data?.email_action_link || payload.email_data?.token_hash_link || "Lien introuvable"

    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + RESEND_API_KEY,
      },
      body: JSON.stringify({
        from: 'Kit Business <contact@e-booklive.offboard-hub.com>',
        to: [email],
        subject: "✨ Votre lien de connexion Kit Business",
        html: `
          <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; text-align: center; padding: 40px; background: #14123A; color: #F6EBD4;">
            <h1 style="color: #E8B04B;">Votre lien est prêt</h1>
            <p>Cliquez sur le bouton ci-dessous pour accéder à votre espace.</p>
            <a href="${magicLink}" style="display: inline-block; background: #E8B04B; color: #14123A; padding: 15px 30px; text-decoration: none; border-radius: 8px; font-weight: bold; margin-top: 20px;">Me connecter</a>
          </div>
        `,
      }),
    })

    if (!res.ok) throw new Error(await res.text())

    return new Response(JSON.stringify({ success: true }), { status: 200 })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 400 })
  }
})