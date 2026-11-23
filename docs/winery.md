# Winery — brewing design

You load ingredients into a **barrel** to try out recipes, the way cooking works in Breath of the Wild.
Every ingredient adds effect points **per unit**, and the points **combine**. The same effect from
different ingredients stacks into a stronger buff, and different effects sit side by side in one
bottle. After mixing you **ferment** and then **bottle**. Each step can be waited out or played as
a short minigame for a better result.

Fruit comes from a separate **Orchard** screen (§7).
The data and resolver live in `scripts/brewing.gd`. Keep the numbers in sync.

---

## 1. The three steps

| Step | Wait it out | …or play | Playing well gives |
|---|---|---|---|
| **1. Mix** — load the barrel, then stir | Let it settle (10 s) | **Stir:** trace circles around the barrel in time with a ring. Too fast splashes, too slow loses the rhythm. | ⭐ 1 star |
| **2. Ferment** | The yeast's ferment time (45–180 s) | **Airlock:** keep the temperature needle in the green band (tap to warm, it drifts cold) and pop the CO₂ bubbles before they stack up. About 20 s, and it **replaces** the wait. | ⭐ 1 star |
| **3. Bottle** | Auto-fill, 5 s per bottle. Always safe. | **Pour:** hold to pour and release at the fill line. A near-perfect fill counts toward the star, and **an overflow loses that bottle**. | ⭐ 1 star if every bottle is filled cleanly |

Each star (0–3) gives **+10% buff duration** and **+5% Vintage chance**.
The brew is resolved when the last bottle is corked.

**Recipe Book:** each new result gets saved with its barrel contents, so you can refill the barrel in one click later.
Like BotW, nothing tells you a result in advance. You find recipes by experimenting.

---

## 2. Rules for combining

| Rule | |
|---|---|
| **Barrel** | **Yeast slot**, **fruit slot** and **5 extra slots** (any fruit or farm product). **Nothing stacks: one item per slot.** Adding the same ingredient again takes the next free slot, and once all 7 slots are taken nothing more goes in. The screen has no text, so players work it out. |
| **Yeast base** | The yeast always adds its own base effect: **2 pts**, +1 per extra scoop. This is why **plain wine always does something.** |
| **Combine** | For each effect, add up `points per unit × amount` across every ingredient. Nothing cancels. |
| **Level** | 2–4 pts → **I** · 5–8 pts → **II** · 9+ pts → **III**. 1 pt is only a *trace*, with no buff. |
| **Effect limit** | A bottle keeps its **3 strongest** effects. The rest are crowded out. Ties go to the yeast's base, then to whichever went in first. |
| **Sugar → duration** | Duration = `(60 s + 15 s × total sugar) × yeast multiplier × modifiers`. Max 15 min. All effects in a bottle share it. |
| **Spoiling** | Under **2 sugar per yeast scoop**, the yeast starves and you get **Vinegar**. Wild Yeast also has a 10% chance of going bad. |
| **Vintage** | 5% base + bonuses. **+1 level to every effect** (max III) and **×1.5 sell value**. |
| **Bottles** | 1 bottle per 3 units in the barrel (minimum 1). |
| **Drinking** | Each effect is one buff slot. Drinking an effect you already have keeps the **higher level** and the **longer remaining time**. Different effects stack. |
| **Sell value** | per bottle = `ingredient value ÷ bottles × (1 + 0.1 × sum of levels)`, ×1.5 if Vintage. Vinegar sells for 5. Wine sells for a little more than its ingredients; the buffs are the real reward. |
| **Name** | `[Vintage] <Strength> <Strongest effect> <Main fruit> <Style>` → *Grand Bountiful Fig Mead*. Strength: I Light · II Fine · III Grand. |

---

## 3. Effects (the buffs)

| | Effect | Name adjective | Lv I | Lv II | Lv III | Hooks into |
|---|---|---|---|---|---|---|
| 🌱 | **Growth** | Verdant | crops grow +15% | +30% | +50% | `GameState.growth_multiplier()` |
| 💧 | **Rain** | Rainkeeper's | watered speed ×2.5 | ×3.0 | ×4.0 | `growing_zone.watered_speed` (base ×2.0) |
| 🧺 | **Bounty** | Bountiful | 20% chance of +1 crop per harvest | 40% | 70% | harvest in `growing_zone.gd` |
| 🐄 | **Herd** | Shepherd's | animals produce 15% faster | 30% | 50% | `animal.gd` produce timer |
| 💰 | **Haggle** | Merchant's | sell prices +10% | +20% | +35% | `GameState` sell path |
| 🍀 | **Luck** | Lucky | 8% chance a harvest drops coins (3× crop price) | 15% | 25% | harvest |
| 🪓 | **Reach** | Far-Reaching | tool area +1 | +1 | +2 | `GameState.tool_area_owned()` |

---

## 4. Ingredient table

The numbers are **points per unit**. A blank cell means no points for that effect.

### Yeasts (6) — pick one, 1–3 scoops

| Yeast | Style | Base effect (2 pts) | Ferment | Duration × | Special | Buy |
|---|---|---|---|---|---|---|
| Baker's Yeast | Rustic Wine | 🌱 Growth | 60 s | ×1.0 | Cheap starter | 20 |
| Wine Yeast | Wine | 💰 Haggle | 120 s | ×1.0 | The classic. Plain grape wine makes you a better seller. | 150 |
| Kveik Ale Yeast | Farmhouse Ale | 🐄 Herd | 45 s | ×0.75 | Fastest ferment, shorter buffs | 300 |
| Mead Yeast | Mead | 🧺 Bounty | 150 s | ×1.0 | Wheat feeds the base effect **+2** instead of +1 | 600 |
| Champagne Yeast | Sparkling Wine | 🍀 Luck | 180 s | ×1.5 | Long-lasting buffs | 1 500 |
| Wild Yeast | Country Wine | **random each brew** | 90 s | ×1.0 | Free. +10% Vintage, 10% chance of Vinegar. | free (forage) |

### Fruits (22)

| Fruit | Grows on | Sugar | 🌱 Growth | 💧 Rain | 🧺 Bounty | 🐄 Herd | 💰 Haggle | 🍀 Luck | 🪓 Reach | Value |
|---|---|---|---|---|---|---|---|---|---|---|
| Grape | vine | **4** | | | | | | | | 50 |
| Apple | tree | 3 | 1 | | | | | | | 40 |
| Pear | tree | 3 | | | | 1 | | | | 45 |
| Tomato | field *(existing)* | 1 | 1 | | | | | | | 75 |
| Lemon | tree | 1 | **2** | | | | | | | 90 |
| Raspberry | bush | 2 | 1 | | | 1 | | | | 100 |
| Blueberry | bush | 2 | | 1 | | | | | | 60 |
| Elderberry | bush | 1 | | 1 | | 1 | | | | 110 |
| Watermelon | field *(existing)* | 3 | | **3** | | | | | | 750 |
| Plum | tree | 3 | | | 1 | | | | | 70 |
| Fig | tree | 3 | | | **2** | | | | | 230 |
| Pomegranate | tree | 2 | | | **2** | | | 1 | | 600 |
| Strawberry | field *(existing)* | 2 | | | 1 | | 1 | | | 240 |
| Blackberry | bush | 2 | | | | **2** | | | | 220 |
| Cherry | tree | 2 | | | | | 1 | 1 | | 120 |
| Peach | tree | 3 | | | | | **2** | | | 260 |
| Orange | tree | 2 | | | | | | 1 | | 70 |
| Mango | tree | 3 | | | | | | **2** | | 280 |
| Passionfruit | vine | 2 | | | | | | 1 | 1 | 200 |
| Pineapple | bush | 3 | | | | | | | **2** | 450 |
| Dragonfruit | vine | 2 | | | | | | | **3** | 800 |
| **Golden Apple** | tree (rare) | 4 | | | | | | | | 3 000 |

**Golden Apple:** each one adds **+1 to every effect already in the barrel**.
**Grape** adds no effect but has the most sugar. It's the base for long-lasting brews.

### Additions: the farm's other produce

The shop's Wine tab sells **only yeast**. Everything else that goes in the barrel is produce you already grow or collect.

| Ingredient | Sugar | 🌱 | 💧 | 🧺 | 🐄 | 💰 | 🍀 | 🪓 | Special | Sells |
|---|---|---|---|---|---|---|---|---|---|---|
| Wheat | 2 | | | | | | | | **Feeds the yeast:** +1 to its base effect (+2 with Mead Yeast) | 3 |
| Carrot | 1 | 1 | 1 | | | | | | | 12 |
| Corn | **3** | | | 1 | | | | | Lots of sugar, so longer buffs and no Vinegar | 36 |
| Egg | | | | | | | | | **Clarify:** each one drops the weakest effect, to focus a brew | 20 |
| Milk | 1 | | | | 1 | | | | +20% duration per unit | 500 |
| Bacon | | | | | | | | | **Smoke:** +1 to every effect already in the barrel, per unit | 150 |

Tomato, Strawberry and Watermelon (§4 Fruits) can go in the fruit slot or in an extra slot.

---

## 5. Worked examples

These outputs come from `Brewing.brew()` in headless Godot, using only items the game has today, with 0 stars and no Vintage.

| Barrel | Result | Buffs | Duration | Bottles × value |
|---|---|---|---|---|
| Wine Yeast + Strawberry ×3 (**normal wine**) | *Fine Merchant's Strawberry Wine* | Haggle II, Bounty I | 150 s | 1 × €936 |
| Wine Yeast + Strawberry ×5 + Bacon ×2 | *Grand Merchant's Strawberry Wine* | Haggle III, Bounty II | 210 s | 2 × €1 125 |
| Mead Yeast + Strawberry ×3 + Corn ×4 + Wheat ×3 | *Grand Bountiful Strawberry Mead* | Bounty III, Haggle I | 420 s | 3 × €407 |
| Baker's Yeast + Tomato ×4 + Carrot ×3 | *Grand Verdant Tomato Rustic Wine* | Growth III, Rain I | 165 s | 2 × €235 |
| Kveik + Watermelon ×2 + Milk ×2 | *Fine Rainkeeper's Watermelon Farmhouse Ale* | Rain II, Herd I | 189 s | 1 × €3 250 |
| Champagne Yeast + Strawberry ×4 + Corn ×2 | *Fine Bountiful Strawberry Sparkling Wine* | Bounty II, Haggle I, Luck I | 405 s | 2 × €722 |
| Wine Yeast + Tomato ×3 + Carrot + Corn + Milk + Egg ×2 | *Light Verdant Tomato Wine* | Growth I (eggs cleared the rest) | 216 s | 3 × €298 |
| Wine Yeast ×4 + Tomato ×2 | **Vinegar** (2 sugar for 4 scoops) | — | — | 2 × €5 |

---

## 6. Strategy this creates

- **Focus vs. spread:** stack one effect to reach III, or spread across three effects at I–II. Eggs trim away the junk.
- **Sugar is fuel:** Corn, Wheat (and Grape, once the orchard exists) keep buffs running longer and prevent Vinegar.
- **Yeast choice:** Kveik for speed, Champagne for long buffs, Mead + Wheat for big Bounty, Wild for gambling.
- **Minigames are optional:** waiting is safe. Playing saves time and adds stars, and in bottling it risks spilling a bottle.

---

## 7. Orchard (separate screen)

A new screen, reached from the farm the same way the barn interior is. It holds permanent fruit
plants: plant once, then harvest whenever they ripen. Tomato, Strawberry and Watermelon stay on the
farm's existing field plots. These are first-pass numbers to tune with `tools/balance_sim.py`.

| Plant | Fruits | Sapling | Fruits every | Yield |
|---|---|---|---|---|
| Vine (trellis) | Grape · Passionfruit · Dragonfruit | 300 · 900 · 4 000 | 90 s · 90 s · 120 s | 3 · 3 · 2 |
| Bush | Blueberry · Raspberry · Elderberry · Blackberry · Pineapple | 250 · 400 · 450 · 900 · 1 800 | 60 s (Blackberry 75 s, Pineapple 90 s) | 3 (Pineapple 2) |
| Tree | Apple · Pear · Orange · Plum · Lemon · Cherry · Fig · Peach | 250 · 280 · 400 · 400 · 550 · 700 · 1 300 · 1 500 | 120 s | 4 |
| Tree (exotic) | Mango · Pomegranate | 1 600 · 3 500 | 150 s | 4 |
| Golden Apple tree | Golden Apple | 30 000 | 600 s | 1 |

---

## 8. Still to build

- **Orchard screen:** scene, plant slots, sapling items in the shop, fruit items and art.
- ~~**Winery screen:** the barrel~~ ✅ built (`ui/winery_screen.gd`, `scripts/winery.gd`): yeast, fruit and extra slots, seal → ferment timer → bottle. Still to do: the stir, airlock and pour minigames.
- **Items:** ✅ yeasts are in the shop's Wine tab (the only thing it sells), the farm's produce is the additions, and bottles become items. Still to do: drinking them from the hotbar.
- **`GameState`:** a buff list (effect → level, time left), the hooks from §3 reading from it, and save/load.
- **HUD:** a buff tray with timers.
- **Recipe Book:** stores discovered pots.
