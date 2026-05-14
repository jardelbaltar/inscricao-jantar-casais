-- Allow events with requires_dish = false to register without a dish.

ALTER TABLE public.registrations
  ALTER COLUMN dish_id DROP NOT NULL;

DROP FUNCTION IF EXISTS public.register_couple(uuid,text,date,text,uuid);
DROP FUNCTION IF EXISTS public.register_couple(uuid,text,date,text);

CREATE FUNCTION public.register_couple(
  p_event_id uuid,
  p_couple_name text,
  p_wedding_date date,
  p_phone text,
  p_dish_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_event record;
  v_dish record;
  v_registration_id uuid;
  v_registered_count integer;
  v_entered_waitlist boolean := false;
BEGIN
  SELECT id, max_couples, is_open, requires_dish
    INTO v_event
  FROM public.events
  WHERE id = p_event_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'EVENT_NOT_FOUND');
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.registrations r
    WHERE r.event_id = p_event_id
      AND r.phone = p_phone
  ) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'PHONE_ALREADY_REGISTERED');
  END IF;

  IF coalesce(v_event.requires_dish, true) THEN
    IF p_dish_id IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'error', 'DISH_NOT_FOUND');
    END IF;

    SELECT id, remaining, is_active
      INTO v_dish
    FROM public.dishes d
    WHERE d.id = p_dish_id
      AND d.event_id = p_event_id;

    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'error', 'DISH_NOT_FOUND');
    END IF;

    IF coalesce(v_dish.is_active, false) = false OR coalesce(v_dish.remaining, 0) <= 0 THEN
      RETURN jsonb_build_object('ok', false, 'error', 'DISH_SOLD_OUT');
    END IF;
  ELSE
    p_dish_id := NULL;
  END IF;

  SELECT count(*)::int INTO v_registered_count
  FROM public.registrations r
  WHERE r.event_id = p_event_id;

  IF coalesce(v_event.max_couples, 0) > 0 AND v_registered_count >= v_event.max_couples THEN
    RETURN jsonb_build_object('ok', false, 'error', 'EVENT_FULL');
  END IF;

  INSERT INTO public.registrations (event_id, couple_name, wedding_date, phone, dish_id)
  VALUES (p_event_id, p_couple_name, p_wedding_date, p_phone, p_dish_id)
  RETURNING id INTO v_registration_id;

  IF coalesce(v_event.requires_dish, true) THEN
    UPDATE public.dishes
      SET remaining = remaining - 1
    WHERE id = p_dish_id
      AND event_id = p_event_id;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'registration_id', v_registration_id,
    'entered_waitlist', v_entered_waitlist
  );
END;
$$;
