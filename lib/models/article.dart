class Article {
  final String id;
  final String title;
  final String category;
  final String summary;
  final String content;
  final String emoji;
  final int readMinutes;

  Article({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.content,
    required this.emoji,
    required this.readMinutes,
  });

  /// Static education content — replace with Firestore stream for dynamic CMS.
  static List<Article> all = [
    Article(
      id: '1',
      title: 'Understanding Equine Gut Health',
      category: 'Gut Health',
      emoji: '🫁',
      summary:
          'The equine digestive system is uniquely complex. Learn what keeps it healthy.',
      readMinutes: 5,
      content: '''
The horse digestive system is a hindgut fermenter, meaning most fiber digestion happens in the cecum and large colon. This makes horses uniquely susceptible to digestive upset when diet or routine changes occur suddenly.

**Key principles for gut health:**

1. **Forage first.** Horses evolved to eat small amounts continuously. Aim for at least 1.5–2% of body weight in forage daily.

2. **Slow diet transitions.** Any feed change should happen over 7–14 days. Sudden changes disrupt the microbial population in the hindgut.

3. **Consistent feeding times.** The horse's stomach produces acid constantly, even when empty. Consistent feeding schedules reduce acid buildup.

4. **Monitor manure.** Changes in consistency, frequency, or odor are early signals of digestive imbalance.

5. **Minimize starch.** High-starch meals (over 1g/kg body weight per meal) can overwhelm the small intestine and pass to the hindgut, causing fermentation and acidosis.

**Signs your horse may need gut support:**
- Girthiness or sensitivity around the flank
- Changes in appetite or water intake
- Loose or hard manure without dietary change
- Behavioral changes like irritability or reluctance to work
- Poor coat condition despite adequate nutrition

**NutriEquine supplement tip:** Gut-support supplements work best when given consistently at the same time each day, ideally with a small amount of hay to buffer stomach acid.
      ''',
    ),
    Article(
      id: '2',
      title: 'Colic Prevention: What Every Owner Should Know',
      category: 'Gut Health',
      emoji: '⚠️',
      summary:
          'Colic is the leading cause of death in horses. Here is how to reduce your horse\'s risk.',
      readMinutes: 6,
      content: '''
Colic — abdominal pain in horses — ranges from mild gas discomfort to life-threatening intestinal displacement. Most colic cases are preventable with good management.

**Top risk factors:**
- Sudden feed changes
- Limited water access (especially in cold weather)
- Long periods without forage
- High-concentrate diets
- Recent travel or stress
- Dental problems preventing proper chewing
- Infrequent deworming

**Daily prevention checklist:**
✓ Fresh, clean water available at all times
✓ Feed hay before grain
✓ Consistent feeding schedule
✓ Daily turnout and movement
✓ Regular dental exams (every 6–12 months)
✓ Appropriate deworming program

**When to call your vet immediately:**
- Horse shows no interest in food for over 2 hours
- Pawing, looking at flank, or rolling repeatedly
- No manure for 12+ hours
- Heart rate above 48 bpm at rest
- Pale or tacky gums
- Swollen abdomen

**Using the NutriEquine app:** Log any appetite changes, manure changes, or behavior flags in the Wellness tab. These logs help you spot patterns early and give your vet a clear history.
      ''',
    ),
    Article(
      id: '3',
      title: 'Joint Support for Performance Horses',
      category: 'Performance',
      emoji: '🦵',
      summary:
          'Hard-working horses put enormous stress on their joints. Here is what the science says about support.',
      readMinutes: 4,
      content: '''
Joint health is critical for any horse in regular work. Cartilage has limited ability to repair itself, so prevention and early support are far more effective than waiting for visible lameness.

**Key joint-support nutrients:**

- **Glucosamine** — building block for cartilage and synovial fluid; most studied equine joint supplement
- **Chondroitin sulfate** — helps maintain cartilage structure and retain water within cartilage
- **MSM (methylsulfonylmethane)** — sulfur compound with anti-inflammatory properties
- **Hyaluronic acid** — key component of joint fluid; helps lubrication
- **Omega-3 fatty acids** — systemic anti-inflammatory effect

**Management tips:**
1. Warm up and cool down consistently before and after work
2. Footing quality matters enormously — avoid hard or deep footing where possible
3. Maintain healthy body weight — excess weight stresses joints significantly
4. Regular farrier care to maintain correct hoof angle and balance
5. Consider joint supplements before signs of stiffness appear in high-mileage horses

**Tracking tip:** Use the Training Log in NutriEquine to note any stiffness, shortened stride, or reluctance to work. Patterns over weeks can reveal early joint issues before they become serious.
      ''',
    ),
    Article(
      id: '4',
      title: 'Senior Horse Nutrition Guide',
      category: 'Senior Care',
      emoji: '🐎',
      summary:
          'Horses over 20 have unique nutritional needs that most owners underestimate.',
      readMinutes: 5,
      content: '''
Senior horses — generally defined as 20 years and older — often look healthy on the outside while silently struggling with issues that affect how well they absorb nutrients from their food.

**Common changes in senior horses:**

- **Dental wear and loss** — reduces ability to grind hay effectively; soaked hay cubes or pellets may be needed
- **Reduced gut motility** — slows digestion and increases impaction risk
- **Decreased protein absorption** — muscle wasting (topline loss) even with adequate protein intake
- **Immune changes** — more susceptible to infection and slower to recover
- **PPID (Cushing's disease)** — affects over 20% of horses over 15; watch for a long wavy coat, excessive drinking, and delayed shedding

**Feeding adjustments:**
- Move to a senior-formulated complete feed if hay intake drops
- Increase meal frequency; smaller, more frequent meals are easier on aging digestive systems
- Add digestible protein sources (alfalfa, soy, beet pulp) to support topline
- Ensure fat-soluble vitamin supplementation (A, D, E)
- Soak hay if dental issues are present

**Monitoring checklist for seniors:**
✓ Body condition score monthly (aim for 4–6)
✓ Topline assessment — loss is often the first sign of protein deficiency
✓ Water intake — dehydration risk is higher in seniors
✓ Manure quality and frequency
✓ Annual bloodwork to check metabolic function

Use the Wellness tab to track BCS and notes every month to catch changes early.
      ''',
    ),
    Article(
      id: '5',
      title: 'Coat, Hoof and Skin: The Nutrition Connection',
      category: 'Nutrition',
      emoji: '✨',
      summary:
          'A dull coat or brittle hooves are often nutrition signals, not grooming problems.',
      readMinutes: 4,
      content: '''
The quality of a horse's coat, skin, and hooves reflects internal health more than any grooming product can address. If these are consistently poor, look first at nutrition.

**Key nutrients for coat and hoof quality:**

- **Biotin** — most researched for hoof quality; takes 6–9 months to show full effect since hooves grow slowly
- **Zinc and copper** — enzyme cofactors essential for keratin production in hooves and hair
- **Omega-3 fatty acids (flaxseed, fish oil)** — improve coat shine and reduce skin inflammation
- **Methionine** — sulfur-containing amino acid critical for keratin; often limiting in grass hay diets
- **Vitamin E** — antioxidant; also supports skin immune function

**What a dull coat might mean:**
- Mineral imbalance (often zinc/copper deficiency)
- Parasite burden reducing nutrient absorption
- Underlying health issue (hypothyroidism, Cushing's)
- Low-fat diet

**What poor hoof quality might mean:**
- Biotin deficiency (most common)
- Wet-dry cycle stress (environment, not nutrition)
- Copper or zinc imbalance
- Protein deficiency

**Timeline expectations:** Most supplement effects on coat and hoof are visible at 90 days (coat) and 6–12 months (hooves). Log hoof condition and coat score in the Wellness tab monthly so you can see real progress rather than guessing.
      ''',
    ),
    Article(
      id: '6',
      title: 'Reading Manure: What Your Horse Is Telling You',
      category: 'Gut Health',
      emoji: '💩',
      summary:
          'Manure is one of the best daily health indicators available. Here is how to read it.',
      readMinutes: 3,
      content: '''
Experienced horse owners and vets check manure daily — it is one of the fastest signals of digestive health, hydration, and diet appropriateness.

**Normal manure characteristics:**
- Formed balls that break on impact
- Moist but not wet
- Olive-green to brownish color depending on diet
- Mild, grassy smell
- 8–12 piles per day in an adult horse

**What changes mean:**

**Loose or watery:** Stress, diet change, too much grass, antibiotic use, infection, or hindgut upset. If accompanied by fever or appetite loss, call your vet.

**Hard/dry balls:** Dehydration, insufficient forage, reduced gut motility. Increase water access; check for dental issues preventing proper chewing.

**Very dark color:** Diet change (alfalfa makes darker manure), reduced gut transit time, or potential internal bleeding if very dark and tarry.

**Mucus coating:** The intestinal lining is irritated. Usually related to diet or stress, but warrants monitoring.

**Undigested grain:** Feed is moving through too fast or teeth are not grinding properly. Reduce meal size or soak feed.

**Parasites visible:** Indicates deworming protocol needs review.

**Using the Wellness Log:** Record manure observations daily in the app. Patterns over days and weeks are far more meaningful than any single observation, and the log helps your vet understand what's been happening when you call.
      ''',
    ),
    Article(
      id: '7',
      title: 'Recovery Nutrition After Hard Work',
      category: 'Performance',
      emoji: '⚡',
      summary:
          'What you feed in the 2 hours after exercise affects recovery more than most owners realize.',
      readMinutes: 4,
      content: '''
The window immediately after exercise is when the horse's body is most receptive to replenishing glycogen, repairing muscle tissue, and restoring electrolyte balance.

**Post-exercise priorities:**

1. **Rehydration first.** Offer water immediately after cooling down. Horses can lose 5–10 liters of sweat per hour in hard work. Electrolytes should follow water, not replace it.

2. **Electrolyte replacement.** Sodium, chloride, potassium, calcium, and magnesium are lost in sweat. Commercial electrolyte supplements or salt added to feed helps restore balance.

3. **Forage before grain.** After exercise, offer hay before any concentrate feeding. Forage helps buffer stomach acid that has built up and supports hindgut function.

4. **Protein for muscle repair.** Quality protein (especially leucine-rich sources) supports muscle repair in the hours after exercise. High-quality forage and well-balanced concentrate provide this for most horses.

5. **Anti-inflammatory support.** Omega-3 fatty acids and certain herbal ingredients may help moderate normal exercise-related inflammation.

**Signs of inadequate recovery:**
- Persistent muscle soreness or stiffness
- Reluctance to work after rest days
- Poor topline despite adequate feeding
- Slow heart rate recovery after exercise

**Tracking tip:** Log training intensity and duration in NutriEquine alongside wellness notes. Comparing training load to wellness scores over time reveals your horse's individual recovery patterns.
      ''',
    ),
    Article(
      id: '8',
      title: 'Building a Supplement Protocol That Actually Works',
      category: 'Nutrition',
      emoji: '🧪',
      summary:
          'More supplements is not better. Here is how to build a logical, effective stack.',
      readMinutes: 5,
      content: '''
The supplement industry is enormous, and it is easy to end up feeding five or six products with overlapping ingredients, gaps in coverage, or combinations that work against each other. A logical protocol starts with what your horse actually needs.

**Step 1: Start with the diet foundation.**
No supplement fixes a nutritionally inadequate base diet. Ensure your hay or pasture is analyzed, your forage quantity is appropriate, and your concentrate (if any) matches your horse's workload before adding supplements.

**Step 2: Identify your horse's specific needs.**
Common goals:
- Gut health and ulcer support
- Joint support for performance horses
- Coat and hoof quality
- Weight gain or loss
- Immune support for older horses
- Electrolyte replacement for hard workers

**Step 3: Choose one product per goal.**
Feeding multiple gut supplements, for example, rarely does more than one good one would, and costs more. Pick the product with the best evidence for your horse's specific situation.

**Step 4: Give each supplement time.**
Most supplements take 30–90 days to show measurable effects. Switching products before this window passes means you will never know if anything worked.

**Step 5: Track and evaluate.**
This is where most owners fall short — they add a supplement and then never systematically evaluate whether it helped. Log specific, measurable observations: BCS, coat score, manure quality, behavior during work.

**Using the NutriEquine protocol quiz:** Answer a few questions about your horse's goals, and the app will suggest a logical starting protocol based on your horse's age, discipline, and health focus.
      ''',
    ),
  ];

  static List<String> get categories =>
      all.map((a) => a.category).toSet().toList()..sort();
}
