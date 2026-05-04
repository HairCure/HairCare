-- ============================================================
-- Migration: Add hair_types column to care_tip & home_remedy
-- Run this once in your Supabase SQL editor.
-- ============================================================

-- 1. Add the column (text[] = array of hair-type strings)
ALTER TABLE care_tip
    ADD COLUMN IF NOT EXISTS hair_types text[] NOT NULL DEFAULT '{}';

ALTER TABLE home_remedy
    ADD COLUMN IF NOT EXISTS hair_types text[] NOT NULL DEFAULT '{}';


-- 2. Tag existing care_tip rows
--    Universal tips (empty array) get the default already.
--    Update specific tips that are hair-type-specific:

UPDATE care_tip SET hair_types = ARRAY['straight','wavy']
WHERE title = 'Cold Water Rinse to Seal Shine';

UPDATE care_tip SET hair_types = ARRAY['straight','wavy']
WHERE title = 'Always Apply Heat Protectant Before Styling';

-- (All other existing tips remain universal = '{}')


-- 3. Tag existing home_remedy rows

UPDATE home_remedy SET hair_types = ARRAY['straight','wavy']
WHERE title = 'Egg and Honey Protein Treatment';

UPDATE home_remedy SET hair_types = ARRAY['curly','coily']
WHERE title = 'Coconut Oil Pre-Wash Treatment';

-- (Aloe Vera mask is universal — stays '{}')


-- 4. Insert new tips with hair_types

INSERT INTO care_tip (title, tip_description, media_url, frequency, precautions, research_url, rating, steps, hair_types)
VALUES
(
  'Finger Detangling',
  'Use fingers instead of a brush on dry curly or coily hair to prevent breakage along the curl pattern.',
  NULL,
  'Every wash day',
  'Never detangle dry curly or coily hair — it causes breakage.',
  NULL,
  0,
  ARRAY[
    'Apply a leave-in conditioner or detangling spray to damp hair.',
    'Work in sections, starting from the ends and moving upward.',
    'Gently separate knots with your fingers — never pull.',
    'Follow with a wide-tooth comb only if needed.'
  ],
  ARRAY['curly','coily']
),
(
  'Pineapple Hair at Night',
  'Loosely gathering curls at the top of the head (pineapple) before bed protects the curl pattern and reduces morning frizz.',
  NULL,
  'Every night',
  'Keep the band very loose to avoid a crease at the roots.',
  NULL,
  0,
  ARRAY[
    'Flip hair upside down and gather all curls at the very top of the head.',
    'Secure loosely with a satin scrunchie — never a tight elastic.',
    'Sleep on a satin pillowcase for extra protection.',
    'Release in the morning and scrunch lightly to refresh curls.'
  ],
  ARRAY['curly','coily']
);


-- 5. Insert new home remedies with hair_types

INSERT INTO home_remedy (title, remedy_description, media_url, image_urls, video_duration_seconds, ingredients, steps, benefits, frequency, precautions, research_url, rating, hair_types)
VALUES
(
  'Green Tea Scalp Rinse',
  'A light antioxidant rinse that reduces excess oil and scalp inflammation without stripping moisture.',
  NULL,
  ARRAY[]::text[],
  NULL,
  ARRAY['2 green tea bags','2 cups hot water','1 tsp apple cider vinegar (optional)'],
  ARRAY[
    'Steep 2 green tea bags in 2 cups hot water for 5 minutes. Let cool.',
    'Add apple cider vinegar if using and stir.',
    'After shampooing, pour the tea rinse over your scalp and hair.',
    'Massage gently for 2 minutes.',
    'Leave on for 5 minutes, then rinse with cool water.'
  ],
  'Reduces scalp inflammation, controls excess oil, and adds a subtle shine.',
  'Once a week',
  'Avoid undiluted apple cider vinegar on a sensitive scalp.',
  NULL,
  0,
  ARRAY['straight','wavy']
);
