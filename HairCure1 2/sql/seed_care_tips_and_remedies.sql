-- ============================================================
-- STEP 1: Add hair_types column if not already done
-- (Safe to run even if column already exists)
-- ============================================================

ALTER TABLE care_tip
    ADD COLUMN IF NOT EXISTS hair_types text[] NOT NULL DEFAULT '{}';

ALTER TABLE home_remedy
    ADD COLUMN IF NOT EXISTS hair_types text[] NOT NULL DEFAULT '{}';


-- ============================================================
-- STEP 2: Clear old data
-- ============================================================

TRUNCATE TABLE care_tip, home_remedy RESTART IDENTITY CASCADE;


-- ============================================================
-- CARE TIPS
-- hair_types: '{}' = universal (all hair types)
-- ============================================================

INSERT INTO care_tip (
  title,
  tip_description,
  media_url,
  frequency,
  precautions,
  research_url,
  rating,
  steps,
  hair_types
) VALUES

-- 1. Scalp Massage — Universal
(
  'Daily Scalp Massage for Hair Growth',
  'Regular scalp massage stimulates blood circulation to the hair follicles, delivering more oxygen and nutrients to the roots. A 2019 clinical study published in ePlasty found that 4 minutes of daily scalp massage over 24 weeks significantly increased hair thickness in participants.',
  'https://res.cloudinary.com/dfdnhdj0m/image/upload/v1777303363/WhatsApp_Image_2026-04-27_at_15.02.19_jrriuc.jpg',
  'Daily, 4–5 minutes',
  'Use fingertip pads — never nails. Avoid massage on an actively inflamed, broken, or infected scalp. Reduce pressure if you experience pain or soreness.',
  'https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6380979/',
  0,
  ARRAY[
    'Sit or stand comfortably and relax your shoulders.',
    'Place all ten fingertips on your scalp starting at the hairline.',
    'Apply gentle, firm pressure and make small circular motions.',
    'Slowly work your way from the front hairline toward the crown, then down to the nape.',
    'Move to the sides — temples, behind the ears — covering the full scalp.',
    'Continue for 4–5 minutes. You can do this on dry hair or while shampooing.'
  ],
  '{}'                          -- universal
),

-- 2. Cold Water Rinse — Straight + Wavy
(
  'Cold Water Rinse to Seal Shine',
  'Finishing your hair wash with a brief cold-water rinse causes the outer cuticle layer to lie flat. A smooth cuticle reflects light more evenly, making hair appear shinier, and resists tangling and frizz — without any product.',
  'https://res.cloudinary.com/dfdnhdj0m/image/upload/v1777272686/WhatsApp_Image_2026-04-27_at_12.19.46_wnbjpf.jpg',
  'Every wash day, as the final rinse',
  'If you have a cold or respiratory condition, limit the duration to 10–15 seconds. Avoid if your scalp is highly sensitive to temperature changes.',
  'https://www.ncbi.nlm.nih.gov/books/NBK537321/',
  0,
  ARRAY[
    'Complete your regular conditioning step and let it sit for the recommended time.',
    'Rinse out the conditioner thoroughly with lukewarm water first.',
    'Gradually lower the water temperature to cool or cold.',
    'Direct the cold stream from roots to tips, following the direction of the cuticle.',
    'Rinse for 20–30 seconds, ensuring all sections are reached.',
    'Gently squeeze out excess water — do not rub — and wrap in a microfibre towel.'
  ],
  ARRAY['straight', 'wavy']
),

-- 3. Heat Protectant — Straight + Wavy
(
  'Always Apply Heat Protectant Before Styling',
  'Heat styling tools typically reach 150–230 °C. Above 150 °C, the hydrogen bonds in the hair cortex begin to break down, causing progressive structural damage. A thermal protectant product forms a barrier that distributes heat more evenly and raises the temperature threshold at which damage occurs.',
  'https://res.cloudinary.com/dummy/image/upload/v1/placeholder.jpg',
  'Every time a heat styling tool is used',
  'Do not apply protectant to dripping-wet hair — it dilutes the product and causes steam burns. Ensure hair is towel-dried or 70–80% dry before applying. Do not skip even on low heat settings.',
  'https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4387693/',
  0,
  ARRAY[
    'Wash and condition hair as usual, then gently towel-dry until no longer dripping.',
    'Hold the heat protectant spray or cream 15–20 cm from your hair.',
    'Apply evenly in sections — mid-lengths and ends first, then a lighter layer near the roots.',
    'Use a wide-tooth comb to distribute the product from root to tip.',
    'Allow 1–2 minutes for the product to absorb before touching the hair with any tool.',
    'Style with your blow dryer, flat iron, or curling wand at the lowest effective temperature.'
  ],
  ARRAY['straight', 'wavy']
),

-- 4. Silk Pillowcase — Universal
(
  'Silk Pillowcase',
  'Sleeping on silk reduces friction, preventing hair breakage, tangles, and split ends overnight compared to standard cotton pillowcases.',
  'https://res.cloudinary.com/demo/image/upload/c_fill,h_400,w_400/v1/pillows_demo.jpg',
  'Every night',
  NULL,
  'https://www.triprinceton.org/post/everyone-is-talking-about-silk-pillowcases',
  4.8,
  ARRAY[
    'Replace your cotton pillowcase with a 100% mulberry silk pillowcase.',
    'Loosely braid or tie hair in a low ponytail before sleeping.',
    'Wash the silk pillowcase weekly with a gentle detergent.'
  ],
  '{}'                          -- universal
),

-- 5. Finger Detangling — Curly + Coily
(
  'Finger Detangling',
  'Use fingers instead of a brush on dry curly or coily hair to prevent breakage along the curl pattern.',
  'https://res.cloudinary.com/dummy/image/upload/v1/placeholder.jpg',
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
  ARRAY['curly', 'coily']
),

-- 6. Pineapple Hair at Night — Curly + Coily
(
  'Pineapple Hair at Night',
  'Loosely gathering curls at the top of the head (pineapple) before bed protects the curl pattern and reduces morning frizz.',
  'https://res.cloudinary.com/dummy/image/upload/v1/placeholder.jpg',
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
  ARRAY['curly', 'coily']
);


-- ============================================================
-- HOME REMEDIES
-- hair_types: '{}' = universal (all hair types)
-- ============================================================

INSERT INTO home_remedy (
  title,
  remedy_description,
  media_url,
  image_urls,
  video_duration_seconds,
  video_url,
  ingredients,
  steps,
  benefits,
  frequency,
  precautions,
  research_url,
  rating,
  hair_types
) VALUES

-- 1. Coconut Oil Pre-Wash — Curly + Coily (high-moisture hair types)
(
  'Coconut Oil Pre-Wash Treatment',
  'Coconut oil is one of the only oils proven by mass-spectrometry studies to penetrate the hair shaft rather than just coat the surface. Applied before shampooing, it pre-fills the cortex so the swelling caused by water absorption is reduced, limiting protein loss during the wash.',
  'https://res.cloudinary.com/dummy/image/upload/v1/placeholder.jpg',
  ARRAY['https://res.cloudinary.com/dummy/image/upload/v1/placeholder.jpg'],
  NULL,
  NULL,
  ARRAY[
    '2–3 tablespoons virgin or cold-pressed coconut oil',
    '3–4 drops rosemary essential oil (optional, for added scalp stimulation)'
  ],
  ARRAY[
    'Scoop the coconut oil into a small bowl. If it is solid, sit the bowl in warm water for a few minutes until it melts to a liquid.',
    'Add rosemary essential oil if using and stir to combine.',
    'Divide dry hair into 4 sections using clips.',
    'Starting at the ends, work the oil upward toward the mid-length, then lightly coat the scalp.',
    'Massage the scalp for 3–4 minutes using circular fingertip motions.',
    'Cover hair with a shower cap and leave for 30–60 minutes (or overnight for very dry hair).',
    'Shampoo twice to remove all oil residue, focusing the second lather on the scalp.',
    'Condition mid-lengths and ends as usual, then rinse with cool water.'
  ],
  'Reduces protein loss during washing; deeply moisturises the hair cortex; adds natural lustre; soothes and nourishes the scalp.',
  'Once a week for dry or damaged hair; every 2 weeks for normal hair',
  'Can cause buildup on fine or low-porosity hair — use a clarifying shampoo monthly if you notice heaviness. Apply oil sparingly at the scalp if you are prone to greasiness. Do not use if you have a coconut allergy.',
  'https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4387693/',
  0,
  ARRAY['curly', 'coily']
),

-- 2. Aloe Vera Scalp Soothing Mask — Universal
(
  'Aloe Vera Scalp Soothing Mask',
  'Fresh aloe vera gel contains proteolytic enzymes that repair dead scalp cells, along with salicylic acid which acts as a mild antifungal to reduce dandruff-causing Malassezia yeast. Its humectant polysaccharides also draw moisture into the hair shaft, reducing dryness and itch.',
  'https://res.cloudinary.com/demo/image/upload/v1615560931/docs/plant.jpg',
  ARRAY['https://res.cloudinary.com/demo/image/upload/v1615560931/docs/plant.jpg'],
  120,
  NULL,
  ARRAY[
    '4–5 tablespoons fresh aloe vera gel (scraped from a leaf) or pure store-bought gel',
    '2–3 drops tea tree essential oil'
  ],
  ARRAY[
    'If using a fresh aloe leaf, slice it lengthwise and scoop out the clear inner gel with a spoon into a bowl.',
    'Add tea tree essential oil and stir well. Do not increase the tea tree quantity — it is potent.',
    'Do a patch test: apply a small amount behind the ear and wait 10 minutes before proceeding.',
    'Part clean, damp hair into sections.',
    'Apply the mixture directly to the scalp using fingertips or an applicator brush, working section by section.',
    'Gently massage in for 2–3 minutes to improve absorption.',
    'Leave on for 20–30 minutes.',
    'Rinse thoroughly with lukewarm water, then follow with a gentle shampoo if needed.'
  ],
  'Soothes itchy and irritated scalp; reduces dandruff and flaking; balances scalp pH; hydrates the hair shaft; promotes a healthier scalp environment.',
  '1–2 times per week for scalp issues; once a week for maintenance',
  'Always patch-test first — some people are allergic to aloe vera. Avoid use on open wounds or severely inflamed scalp. Do not substitute tea tree oil with other essential oils without checking dilution safety. Rinse completely — residue can cause white flaking.',
  'https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4158629/',
  0,
  '{}'                          -- universal
),

-- 3. Egg and Honey Protein Treatment — Straight + Wavy
(
  'Egg and Honey Protein Treatment',
  'Eggs are rich in complete protein (albumen and keratin precursors) as well as biotin and fatty acids in the yolk. When applied to hair, the protein molecules temporarily bond to damaged areas of the cuticle and cortex, improving tensile strength and reducing breakage. Honey adds humectant moisture to offset the drying effect of protein.',
  'https://res.cloudinary.com/demo/image/upload/c_crop,h_400,w_400/v1/egg_demo.jpg',
  ARRAY['https://res.cloudinary.com/demo/image/upload/c_crop,h_400,w_400/v1/egg_demo.jpg'],
  150,
  NULL,
  ARRAY[
    '2 whole eggs (or 2 yolks only for very dry hair)',
    '2 tablespoons raw honey',
    '1 tablespoon olive oil'
  ],
  ARRAY[
    'Crack the eggs into a bowl and whisk until the yolk and white are fully combined with no streaks.',
    'Add honey and olive oil to the egg mixture and whisk again until smooth.',
    'Lightly dampen hair with water — do not soak, just mist.',
    'Apply the mixture in sections from root to tip, ensuring full coverage.',
    'Put on a shower cap and leave the treatment on for 20–30 minutes.',
    'Rinse out COMPLETELY with cool water — hot water will cook the egg proteins and leave white residue in the hair.',
    'Follow with a moisturising conditioner, as protein can temporarily stiffen the hair.',
    'Shampoo gently if any egg scent remains.'
  ],
  'Temporarily fills and repairs damaged cuticle gaps; improves hair elasticity and tensile strength; reduces breakage; adds moisture and shine; delivers biotin and fatty acids to the hair shaft.',
  'Once every 2–3 weeks — overuse of protein treatments causes brittleness (protein overload)',
  'CRITICAL: Always rinse with cool or cold water — hot water denatures and solidifies the egg inside the hair. Do not use if you have an egg allergy. Do not use more than once every two weeks. If hair feels stiff or brittle after the treatment, follow with a deep moisture mask the next wash.',
  'https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6164340/',
  0,
  ARRAY['straight', 'wavy']
),

-- 4. Green Tea Scalp Rinse — Straight + Wavy
(
  'Green Tea Scalp Rinse',
  'A light antioxidant rinse that reduces excess oil and scalp inflammation without stripping moisture.',
  'https://res.cloudinary.com/dummy/image/upload/v1/placeholder.jpg',
  ARRAY[]::text[],
  NULL,
  NULL,
  ARRAY[
    '2 green tea bags',
    '2 cups hot water',
    '1 tsp apple cider vinegar (optional)'
  ],
  ARRAY[
    'Steep 2 green tea bags in 2 cups hot water for 5 minutes. Let cool completely.',
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
  ARRAY['straight', 'wavy']
);
