-- ============================================================================
--  SUPPRESSION DE LA LIVRAISON WHATSAPP (canal retiré du projet)
--  La livraison automatique passe désormais uniquement par email (Resend).
--  La colonne delivered_whatsapp n'a plus d'usage : on la retire.
--  La colonne orders.whatsapp est conservée : c'est le numéro de contact du
--  client (utile pour l'assistance), pas un canal d'envoi automatique.
-- ============================================================================

do $$
begin
  if to_regclass('public.orders') is not null then
    alter table public.orders drop column if exists delivered_whatsapp;
  end if;
end $$;
