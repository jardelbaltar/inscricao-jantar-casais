-- Add payment confirmation support for registrations.

ALTER TABLE public.registrations
  ADD COLUMN IF NOT EXISTS payment_confirmed boolean NOT NULL DEFAULT false;
