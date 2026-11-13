# MealWise: Budget-First Healthy Meal Planning App

## 1. Introduction

The main idea of the **MealWise** project is to develop a mobile
application that helps people eat healthier on a tight budget by
planning a full week of affordable, nutritious meals around a fixed
amount of money. The target users are lower-income individuals and
families, members of the Supplemental Nutrition Assistance Program
(SNAP), and young adults and college students who are cooking and
shopping for themselves, often for the first time.

Many people want to eat better, but healthy eating can feel expensive,
time-consuming, and complicated. Planning affordable meals, shopping
efficiently, and using up everything that was bought all take time and
skill. When any of these steps breaks down, people fall back on fast
food or cheap processed meals, even when they would prefer not to.

Unlike traditional meal-planning applications, which usually begin by
asking what a user wants to eat and then calculate what it costs,
MealWise begins with **the money**. The user states how much they can
spend, and the app builds the week around that spending cap.

MealWise is designed for three main groups of users:

-   **Lower-income families and individuals** — Households for whom
    groceries are one of the largest recurring expenses and every
    dollar must be planned.
-   **SNAP recipients** — People who receive a fixed monthly food
    benefit and need it to stretch across the whole month.
-   **Young adults and college students** — New cooks with limited
    time, limited kitchen equipment, and limited experience planning
    meals or shopping for groceries.

These groups overlap, and the app does not ask users to identify which
group they belong to. Instead, it asks for practical information during
setup:

-   Weekly grocery budget
-   Household size
-   Number of days to plan
-   Available cooking time
-   Cooking experience
-   Grocery store or stores where the user shops
-   Dietary restrictions, allergies, and nutritional preferences

From these inputs, MealWise generates a weekly meal plan in which
**every meal fits inside the budget and meals intentionally share
ingredients**. For example, one onion, one bag of rice, or one package
of chicken thighs may be used across three different meals during the
week. This makes each purchase go further and reduces the amount of
food that spoils before it is used.

The user can view the plan, swap out meals they do not like while the
plan stays within budget, and receive a single consolidated grocery
list with estimated prices and quantities. Throughout the week, the
user follows simple, beginner-friendly recipes that tell them exactly
which ingredients to use and what to save for later meals.

The core planning features of MealWise will be free. A future optional
**MealWise PLUS** subscription, priced at approximately $5 per month,
could offer advanced AI personalization, grocery store price
comparison, and other advanced features. MealWise will remain
**always free for SNAP recipients**, so that the people who could
benefit most are never priced out.

------------------------------------------------------------------------

## 2. Significance

Food is one of the few expenses that never goes away. It recurs every
week, and for lower-income households it often consumes a large share
of the monthly budget. When money is tight, people are forced to choose
between eating healthily and staying within their budget, and the
cheapest and most convenient option is frequently the least nutritious.

The difficulty is not only cost. Healthy, affordable eating requires
several skills at once: planning a week of meals, estimating what
groceries will cost, buying the right quantities, and cooking food
before it spoils. Each step takes time and knowledge that many people,
especially busy parents and first-time cooks, do not have.

MealWise aims to address this problem in several ways.

First, it makes the **budget the starting point**. Instead of picking
recipes and discovering at the checkout that the total is too high,
the user knows from the beginning that the entire week fits within the
amount they can spend.

Second, it **gets more value out of every purchase**. Groceries are
sold in fixed package sizes: a whole bag of spinach, a dozen eggs, a
five-pound bag of potatoes. Recipes chosen one at a time often use only
part of each package, and the rest is wasted. By planning meals that
share ingredients, MealWise helps users use what they buy, which saves
money and reduces food waste.

Third, it makes **healthy eating ordinary rather than premium**.
Nutritious meals do not need to rely on expensive specialty ingredients.
MealWise focuses on affordable staples such as beans, eggs, rice, oats,
frozen vegetables, and seasonal produce, and presents healthy eating as
something practical for everyday households, not only for people with
fitness goals.

Fourth, it **reduces the time and stress of planning**. A complete week
of meals, a grocery list, and simple recipes are produced in one step,
removing the repeated daily question of what to eat.

Fifth, it **supports users with limited cooking experience**. Recipes
are matched to the user's available time and skill level and are
written in simple steps, so that a student cooking for the first time
can follow them successfully.

Finally, it is **accessible to the people who need it most**. Many
competing meal planners place budget-based weekly plans behind a paid
subscription. Market evidence supports both the demand for this kind of
app and the cost barrier:

-   **NeatEat**, a budget-oriented meal planner released in July 2026,
    reached an estimated **100K–500K worldwide downloads and
    $50K–$100K revenue last month** (Sensor Tower, worldwide, last
    month) and ranked **17th on the US Top Grossing iPhone Food & Drink
    chart**. This shows strong demand for meal planning built around a
    food budget.
-   At the same time, a featured NeatEat review from October 2026
    points out the contradiction of paying for an app when the reason
    for using it is to spend less on groceries.
-   **Eat This Much**, an established planner released in 2015, has
    **22,188 ratings**, the large majority of them five stars, which
    shows that users value automatic meal plans with grocery lists.
    However, weekly plans and grocery lists are part of its premium
    tier.

The overall goal is to help users eat healthier meals, more often,
without spending more money, and to make that possible for households
that cannot afford another monthly subscription.

------------------------------------------------------------------------

## 3. Innovation

The proposed application combines budget optimization, ingredient
reuse, and accessible design into one focused planning experience. The
competitor analysis in Section 4 shows that several current
state-of-the-art (SOTA) apps already accept a budget as an input, so
MealWise's innovation lies in **how strictly and visibly the budget is
enforced**, **how deliberately ingredients are reused**, and **who the
app is built for**.

### 3.1 Budget-Locked Weekly Planning

**What SOTA apps do today:** Eat This Much, NeatEat, and Cestio all
mention a budget during setup. NeatEat and Cestio build a week of meals
around the user's chosen supermarket and weekly budget, and NeatEat
produces a priced shopping list.

**The gap:** In these apps, the budget is one preference among many.
Their store listings do not describe what happens to the budget when
the user swaps a meal, changes household size, or edits a recipe, and
users have no persistent view of how much of their budget each meal
uses.

**What MealWise does differently:** The budget is a **hard cap that is
enforced on every change**. A persistent **Budget Meter** shows the
estimated total, the amount remaining, and the cost per meal and per
serving. When the user swaps a meal, MealWise only offers replacements
that keep the week within budget, and it shows the effect of each swap
on the total before the user confirms it. If the user lowers the budget,
the plan is re-optimized rather than simply flagged as over budget.

**Why it matters to users:** For a household with $60 for the week,
"about $60" is not good enough. Users need to trust that if they follow
the plan, they will not be surprised at the register. This trust is the
main reason a lower-income user would rely on the app every week.

### 3.2 Whole-Package Ingredient Reuse

**What SOTA apps do today:** NeatEat combines duplicate ingredients
into one shopping list entry. Eat This Much lists "reduce food waste"
as a benefit. Cestio groups its shopping list by aisle.

**The gap:** Combining duplicates on a shopping list happens **after**
meals have been chosen. It does not change which meals are chosen, and
it does not account for the fact that groceries are sold in fixed
package sizes. A plan can still use half a bunch of cilantro once and
leave the rest to spoil.

**What MealWise does differently:** Ingredient reuse is part of **how
the plan is built**. MealWise prices each ingredient by the package the
user actually has to buy and selects meals so that packages are used up
across the week. An **Ingredient Map** shows, for each purchased item,
which meals use it and how much is expected to remain. A **Leftover
Forecast** warns the user about partially used items and suggests a
meal or simple use for them.

**Why it matters to users:** Users can see, within the first few
minutes, that one bag of rice feeds three dinners and that nothing they
buy is wasted. This makes the plan cheaper in practice, not only on
paper, and is harder for competitors to copy because it requires
package-aware pricing and plan-level optimization rather than a simple
list feature.

### 3.3 Free, Accessible Planning for Everyday Households

**What SOTA apps do today:** The three competitors are free to download,
but their weekly plans and smart grocery lists are paid features.
NeatEat requires a Premium subscription for weekly budget plans, Eat
This Much's free tier creates one day's plan while weekly plans and
grocery lists are premium, and Cestio offers its planner as a
subscription with a three-day free trial. Their positioning also leans
toward diet goals, calorie and macro tracking, and convenience features
such as fridge-photo scanning.

**The gap:** The users who most need budget planning are the least able
to pay $30–$85 per year for it. Calorie tracking and fitness positioning
are not the primary concern of a parent feeding a family on a fixed
benefit or a student cooking for the first time.

**What MealWise does differently:** Budget-locked weekly plans, the
grocery list, ingredient reuse, and recipes are **free for everyone**,
and the app remains **always free for SNAP recipients**, including any
future PLUS features. Recipes are matched to cooking time, cooking
experience, and household size, written in simple steps, and built
from affordable staples. Nutrition is presented through simple balance
indicators rather than calorie counting.

**Why it matters to users:** A user can complete their first full week
of planning, shopping, and cooking without paying or encountering a
paywall. This removes the barrier that featured competitor reviews
identify and positions MealWise as a practical tool for everyday
households rather than a diet product.

### 3.4 Beginner-Friendly Cooking Within the Plan — Supporting Innovation

This point overlaps more with existing apps than the three above. Cestio
already matches recipes to cooking time and kitchen appliances, and
NeatEat considers appliances. MealWise's distinguishing angle is that
its recipes are **connected to the rest of the week**: each recipe tells
the user how much of each ingredient to use **now** and how much to
save for a later meal, so that beginners do not accidentally use up an
ingredient another recipe depends on. This supports the ingredient-reuse
innovation rather than standing on its own.

The primary innovation of MealWise is therefore not any single feature,
but the combination of **a hard budget cap, plan-level ingredient
reuse, and free, beginner-friendly access** into one weekly planning
experience designed for households where every dollar counts.

------------------------------------------------------------------------

## 4. Competitive Landscape

The following analysis is based on the Sensor Tower overview pages for
each competitor, viewed on November 6, 2026. Download and revenue
figures are Sensor Tower estimates for **worldwide, last month**;
category rankings are **US, today**. Trend data over time requires a
Sensor Tower login and was not available.

### 4.1 Competitor Comparison

| App | Target users | Key services | Monetization | Key market signals | Main strengths | Main weaknesses |
| --- | --- | --- | --- | --- | --- | --- |
| [NeatEat – Meal Planner](https://app.sensortower.com/overview/6783742855?country=US) | General US/Canada/Australia households that want simple weekly meal plans around a supermarket and budget (Food & Drink, Lifestyle) | Weekly budget-based meal plans; priced smart grocery list that combines duplicates; fridge scan for meal ideas; recipe import and cookbooks; allergy, preference, and appliance settings; nutrition information | Free download; Premium required for core planning: $7.99/week, $12.99/month, $29.99–$39.99/year | 100K–500K downloads and $50K–$100K revenue last month; #158 Food & Drink downloads (US); 17th Top Grossing iPhone Food & Drink (US); 1,437 ratings (1,280 five-star, 73 one-star); released July 17, 2026 | Closest match to the budget-first idea; fast growth; frequent new recipes; handles multiple allergies and diet restrictions (per reviews) | Core budget planning is paywalled; a review notes users trying to save on groceries cannot afford it; a review reports diet preferences being ignored (only keto results for gluten-free) |
| [Eat This Much – Meal Planner](https://app.sensortower.com/overview/981637806?country=US) | Diet- and fitness-focused users who want to hit calorie and macro targets automatically (Health & Fitness, Food & Drink) | Automatic meal plans from diet goals, food likes, budget, and schedule; calorie and macro targets; swapping and recipe personalization; virtual pantry (premium); Apple Health sync (premium); weekly plans and grocery list by email (premium) | Free tier (one day's plan); subscriptions $8.99–$14.99/month, $47.99–$84.99/year | < 5K downloads and $5K–$50K revenue last month; #245 Health & Fitness downloads (US); 22,188 ratings (18,606 five-star, 493 one-star); released June 15, 2015 | Mature product with very high ratings; simple recipes reviewers describe as quick; easy swaps; a daily spending limit option mentioned by a reviewer | Diet/weight-loss positioning; weekly planning and grocery lists are premium; occasional glitches (per review); low current downloads |
| [Cestio: Meal Planner & Recipes](https://app.sensortower.com/overview/6758278666?country=US) | European households (top regions Portugal, Italy, Spain) wanting AI-planned weeks for the whole family (Food & Drink, Shopping) | AI plan of 21 meals/week around budget, diet, allergies, and supermarkets; aisle-grouped shopping list shared with household; cooking time and appliance matching; fridge-photo recipes; plate-photo calorie tracking; 13 languages | Free download; Premium subscription with 3-day trial: $3.49–$4.99/week, $6.99–$9.99/month, $27.99–$39.99/year | < 5K downloads and < $5K revenue last month; no US category ranking; no US ratings or reviews; released March 1, 2026; not advertised actively | Broad feature set; household sharing and item assignment; strong language coverage | Little traction; no user feedback available to verify quality; paywalled; heavy on convenience features rather than affordability |

### 4.2 Key Services

**Table stakes** — services nearly all competitors offer and users
expect by default:

-   Generated weekly meal plan from preferences
-   Dietary restrictions and allergy settings
-   Swapping meals the user does not like
-   Grocery list generated from the plan
-   Budget or supermarket selection as a setup input

**Competitor differentiators** — services offered by only one or two
competitors:

-   Calorie and macro targets, Apple Health sync (Eat This Much)
-   Fridge-photo recipe suggestions (NeatEat, Cestio)
-   Plate-photo calorie tracking (Cestio)
-   Recipe import from websites and social media (NeatEat)
-   Shared household shopping list with assignments (Cestio)
-   Appliance-aware recipes (NeatEat, Cestio)
-   Virtual pantry (Eat This Much)

**Gaps** — needs users complain about, or that the listings do not
address well:

-   **Affordability of the app itself:** budget planning sits behind a
    subscription for users who are trying to save money.
-   **Reliable preference handling:** a NeatEat review reports diet
    filters being ignored.
-   **Budget trust after edits:** no listing describes keeping the plan
    under budget when meals are swapped.
-   **Package-level waste reduction:** existing apps merge duplicates on
    the list but do not describe planning meals to use up whole
    packages.
-   **Low-income and beginner positioning:** all three emphasize diet,
    convenience, or AI rather than stretching a small budget.

### 4.3 Feature Matrix

Competitor cells are based on each app's store-listing description and
featured reviews only; "partial" means the feature is limited, premium
only, or claimed without detail.

| Service / innovation | NeatEat | Eat This Much | Cestio | **MealWise** |
| --- | --- | --- | --- | --- |
| Weekly meal plan generation | ✓ (Premium) | partial (weekly is Premium) | ✓ (Premium) | **✓ (free)** |
| Dietary restriction / allergy settings | ✓ | ✓ | ✓ | ✓ |
| Meal swapping | partial | ✓ | partial | ✓ |
| Grocery list from plan | ✓ | partial (Premium, by email) | ✓ | ✓ |
| Budget as a setup input | ✓ | ✓ | ✓ | ✓ |
| Store selection | ✓ | ✗ | ✓ | ✓ |
| Estimated prices on grocery list | ✓ | ✗ | ✗ | ✓ |
| **Budget enforced as a hard cap on every swap/edit** | partial | partial | partial | **✓** |
| **Persistent budget meter with cost per meal/serving** | ✗ | ✗ | ✗ | **✓** |
| Duplicate ingredients combined on list | ✓ | ✗ | partial | ✓ |
| **Meals chosen to use up whole packages** | ✗ | partial ("reduce food waste") | ✗ | **✓** |
| **Ingredient Map / Leftover Forecast** | ✗ | ✗ | ✗ | **✓** |
| **Recipes tell user what to save for later meals** | ✗ | ✗ | ✗ | **✓** |
| Cooking time / skill matching | partial (appliances) | partial (schedule) | ✓ (time, appliances) | ✓ (time, skill) |
| **Core weekly planning free for everyone** | ✗ | ✗ | ✗ | **✓** |
| **Always free for SNAP recipients** | ✗ | ✗ | ✗ | **✓** |
| Calorie / macro tracking | partial | ✓ | ✓ | ✗ (simple balance indicators instead) |
| Fridge / plate photo AI | ✓ | ✗ | ✓ | ✗ |
| Recipe import | ✓ | ✗ | ✗ | ✗ |
| Household sharing | ✗ | ✗ | ✓ | ✗ (future) |
| Store price comparison | ✗ | ✗ | ✗ | Future (PLUS) |

### 4.4 Positioning

NeatEat proves that budget-led meal planning has strong demand, but it
treats the budget as a starting preference and charges for the very
feature that budget-conscious users need. Eat This Much and Cestio lean
toward diet tracking and AI convenience. MealWise positions itself as
the **free, trustworthy budget planner for households where every
dollar counts**: the budget cannot be exceeded, every package is put to
use, and the full weekly cycle of planning, shopping, and cooking is
available without a subscription.

------------------------------------------------------------------------

## 5. Example Weekly Plan

A generated plan could present information in the following form. The
prices and meals below are illustrative only.

### Week of November 9 — 2 people, 5 days, dinners and lunches

**Budget:** $60.00\
**Estimated total:** $54.80\
**Remaining:** $5.20\
**Average cost per serving:** $2.74\
**Store:** User's selected local supermarket

**Budget Meter:** ████████████████░░ 91% used

| Day | Meal | Est. cost | Shares ingredients with |
| --- | --- | --- | --- |
| Mon | Chicken & vegetable rice bowls | $6.40 | Wed, Fri |
| Tue | Black bean & sweet potato tacos | $5.10 | Thu |
| Wed | Chicken fried rice with frozen peas | $4.20 | Mon, Fri |
| Thu | Bean & cheese quesadillas with salsa | $3.90 | Tue |
| Fri | One-pan chicken, potatoes & onions | $5.60 | Mon, Wed |

**Ingredient Map (excerpt)**

-   **Yellow onions, 3 lb bag ($2.49)** — Mon (1), Tue (1), Wed (1),
    Fri (2). About 2 onions remaining; suggested use: next week's plan.
-   **Long-grain rice, 2 lb bag ($1.99)** — Mon, Wed. About half the bag
    remaining; carried into the pantry.
-   **Chicken thighs, family pack ($7.80)** — Mon, Wed, Fri. Fully used.
-   **Black beans, 2 cans ($1.78)** — Tue, Thu. Fully used.

**Leftover Forecast:** Half a bunch of cilantro will remain after
Tuesday. Suggested use: add it to Thursday's quesadillas.

**Nutrition balance:** Vegetables in every meal ✓ · Protein in every
meal ✓ · Whole grains 2 of 5 meals

The user can tap any meal to see its recipe, tap any ingredient to see
everywhere it is used, or tap **Swap** to choose a replacement that keeps
the week under $60.

------------------------------------------------------------------------

## 6. MVPs

MealWise is developed in sequential MVPs. MVP1 is the smallest version
that is genuinely usable on its own: a user can enter a budget, receive
a plan that fits it, shop from the list, and cook the meals. Each later
MVP deepens a differentiator or adds a new one.

Each task is tagged **[Differentiator]** or **[Table stakes]**.

### MVP1: Budget-Locked Weekly Plan

**Uniqueness highlight:** *Hard budget cap with basic ingredient reuse,
free.* From the very first plan, the user sees a full week that is
guaranteed to fit their budget, a live Budget Meter, and meals that
visibly share ingredients, without creating an account or paying.

**Goal:** Let a user go from "I have $X for groceries this week" to a
complete, affordable meal plan, a priced grocery list, and simple
recipes in a single session.

**Screens introduced:**

-   **Welcome** — Short explanation of the app ("Tell us your budget.
    We'll plan the week.") and a Get Started button. No account
    required.
-   **Budget Setup** (step-by-step onboarding, one question per screen):
    1.  Weekly budget (large numeric input with common presets)
    2.  Household size (adults and children)
    3.  Days to plan and which meals to include (e.g., lunches and
        dinners)
    4.  Cooking time per meal (e.g., 15, 30, 45+ minutes)
    5.  Cooking experience (Beginner, Comfortable, Experienced)
    6.  Store selection
    7.  Dietary restrictions, allergies, and preferences
    8.  Summary screen to review and edit answers
-   **Building Your Plan** — Progress screen while the plan is
    generated, ending with a confirmation that the plan fits the
    budget.
-   **Weekly Plan (Home)** — Day-by-day list of meals with cost per
    meal, cooking time, and a small "shares ingredients" indicator. A
    persistent **Budget Meter** sits at the top.
-   **Budget Meter Detail** — Tapping the meter shows budget, estimated
    total, remaining amount, average cost per serving, and cost per day.
-   **Meal Detail / Recipe** — Ingredients with quantities for this
    meal, simple numbered steps, cooking time, servings, simple
    nutrition balance indicators, and a note listing other meals that
    use the same ingredients.
-   **Grocery List** — One consolidated list grouped by category, with
    package size, quantity to buy, estimated price per item, and the
    estimated total.
-   **Settings** — Edit setup answers, which regenerates the plan.

**Key flows:**

-   *Onboarding → Plan:* Welcome → Budget Setup (8 steps) → Building
    Your Plan → Weekly Plan.
-   *Plan → Cook:* Weekly Plan → Meal Detail.
-   *Plan → Shop:* Weekly Plan → Grocery List.
-   *Change inputs:* Settings → edit budget or household → plan
    regenerates within the new budget.

**Tasks:**

1.  **[Differentiator]** A user enters a weekly budget and receives a
    plan whose estimated total never exceeds it. If no plan can meet
    the budget with the selected settings, the app explains why (for
    example, too many meals for the amount) and suggests adjusting the
    number of days or meals.
2.  **[Differentiator]** A user sees the Budget Meter on the Weekly
    Plan screen at all times, showing the amount used and remaining.
3.  **[Differentiator]** A user sees cost per meal and cost per serving
    on every meal in the plan.
4.  **[Differentiator]** A user receives a plan in which meals
    intentionally share ingredients, and each meal shows which other
    days use the same ingredients.
5.  **[Differentiator]** A user completes setup, receives a plan, views
    the grocery list, and opens recipes without creating an account or
    paying.
6.  **[Table stakes]** A user enters household size, days, meals,
    cooking time, cooking experience, store, and dietary restrictions
    during setup, and changes them later from Settings.
7.  **[Table stakes]** A user with an allergy never receives a meal
    containing that allergen.
8.  **[Table stakes]** A user views a consolidated grocery list in
    which repeated ingredients appear once with the total quantity and
    the package size to buy.
9.  **[Table stakes]** A user opens a meal and follows short, numbered
    recipe steps matched to their cooking experience.

**Representative scenario:** Maria is a single mother of two who
receives SNAP benefits. She opens MealWise, enters a $70 weekly budget,
a household of one adult and two children, five dinners, 30 minutes of
cooking time, and her nearby supermarket. Within a minute she sees five
dinners totaling an estimated $64.30, with $5.70 remaining on the Budget
Meter. She notices that the bag of rice and the package of ground turkey
are each used in three meals. She opens the grocery list and sees
exactly what to buy.

------------------------------------------------------------------------

### MVP2: Swap Within Budget and the Ingredient Map

**Uniqueness highlight:** *Every swap stays under budget, and every
package is accounted for.* The user can change the plan freely while
seeing exactly how each change affects the total and the ingredients
they need to buy, something competitors do not show.

**Goal:** Give users control over the plan without breaking the budget
or the ingredient reuse that makes it affordable.

**Screens introduced:**

-   **Swap Sheet** — Opened from any meal. Shows three to five
    replacement meals, each with:
    -   Its cost and the new weekly total
    -   A **Cart Impact Preview**: ingredients added, removed, or
        reused (e.g., "+ 1 can chickpeas $0.99 · uses your existing
        onions and rice")
    -   A reuse score label such as "Uses 4 ingredients you're already
        buying"
    -   Only replacements that keep the week within budget are shown;
        a toggle can reveal over-budget options with a clear warning.
-   **Ingredient Map** — List of every purchased item showing package
    size, price, which meals use it, how much each meal uses, and the
    expected amount left. Items are labeled **Fully used**, **Some left
    over**, or **Pantry staple** (e.g., rice, oil, spices that last).
-   **Ingredient Detail** — Tapping an item shows a simple timeline of
    the week with each meal that uses it.
-   **Leftover Forecast** — Card on the Weekly Plan screen highlighting
    perishable items expected to be left over, with a suggested meal
    swap or simple use.
-   **Adjust Budget** — Slider or input on the Budget Meter Detail
    screen. Changing the budget re-optimizes the plan and shows a
    before/after comparison.

**Key flows:**

-   *Swap:* Weekly Plan → Meal → Swap → Swap Sheet with Cart Impact
    Preview → Confirm → Budget Meter and Grocery List update.
-   *Explore reuse:* Weekly Plan → Ingredient Map → Ingredient Detail
    → Meal Detail.
-   *Fix a leftover:* Leftover Forecast card → suggested swap → Swap
    Sheet.
-   *Change budget:* Budget Meter → Adjust Budget → before/after view →
    Accept.

**Tasks:**

1.  **[Differentiator]** A user swaps a meal and is only offered
    replacements that keep the week under budget, each showing the new
    weekly total before confirming.
2.  **[Differentiator]** A user sees which ingredients a swap adds,
    removes, or reuses, and how it changes the grocery list.
3.  **[Differentiator]** A user opens the Ingredient Map and sees, for
    every package they will buy, which meals use it and how much will
    remain.
4.  **[Differentiator]** A user receives a Leftover Forecast warning
    about a perishable item that will be partly unused, along with a
    suggested way to use it.
5.  **[Differentiator]** A user lowers their budget mid-week planning
    and receives a re-optimized plan with a before/after comparison.
6.  **[Differentiator]** A user opens a recipe and sees how much of a
    shared ingredient to use now and how much to save for later meals.
7.  **[Table stakes]** A user marks a meal as "Don't show me this again"
    so it is excluded from future plans.
8.  **[Table stakes]** A user regenerates a single day or the whole
    week while keeping the same budget.

**Representative scenario:** Jordan, a college sophomore, has $40 for
the week. He does not like lentils, so he taps Swap on Wednesday's lentil
soup. The Swap Sheet offers a black bean chili for $0.60 more, and the
Cart Impact Preview shows that it uses the onions and canned tomatoes
he is already buying, with a new total of $38.20. He confirms the swap.
The Ingredient Map then shows that the bag of carrots is now only half
used, and the Leftover Forecast suggests adding carrots to Friday's
fried rice.

------------------------------------------------------------------------

### MVP3: Shop and Cook Through the Week

**Uniqueness highlight:** *The plan stays honest in the store and in the
kitchen.* Users check their real spending against the cap while
shopping and are guided day by day so that shared ingredients are not
used up too early, carrying the budget and reuse differentiators past
planning and into real life.

**Goal:** Support the user through the week: shopping efficiently,
tracking actual spending, and cooking each meal while minimizing waste.

**Screens introduced:**

-   **Shopping Mode** — Full-screen checklist version of the Grocery
    List ordered by store section, with large tap targets. Each item
    can be checked off and its actual price entered. A running total
    compares actual spending with the budget.
-   **Price Edit** — Quick input to replace an estimated price with the
    price on the shelf; the app warns if the change would put the trip
    over budget and suggests a cheaper substitute when available.
-   **Today** — The meal or meals planned for today, with a "Before you
    start" note about ingredients to set aside for later meals.
-   **Cook Mode** — Step-by-step recipe, one step per screen, with
    large text, optional timers, and reminders such as "Use half the
    onion; save the other half for Thursday."
-   **Week Wrap-Up** — End-of-week summary of the planned budget,
    actual spending, meals cooked, and items left over.

**Key flows:**

-   *Shop:* Grocery List → Start Shopping → Shopping Mode → check off
    items and edit prices → Finish Shopping → spending summary.
-   *Cook today:* Home → Today → Cook Mode → Mark as Cooked.
-   *Missed a meal:* Today → "Didn't cook this" → app suggests moving
    the meal to another day and flags ingredients at risk of spoiling.
-   *End the week:* Week Wrap-Up → Plan Next Week.

**Tasks:**

1.  **[Differentiator]** A user enters actual shelf prices while
    shopping and sees a running total compared with their budget.
2.  **[Differentiator]** A user who finds an item more expensive than
    estimated is warned if it would exceed the budget and is offered a
    cheaper substitute.
3.  **[Differentiator]** A user cooking a meal is reminded how much of
    a shared ingredient to save for a later meal.
4.  **[Differentiator]** A user who skips a planned meal is told which
    ingredients may spoil and how to rearrange the remaining days.
5.  **[Differentiator]** A user views a Week Wrap-Up comparing the
    planned and actual spending and showing how much food was left
    over.
6.  **[Table stakes]** A user shops from a checklist ordered by store
    section and checks off items as they go.
7.  **[Table stakes]** A user follows a recipe step by step in Cook Mode
    with optional timers and marks the meal as cooked.

**Representative scenario:** Maria takes her list to the store in
Shopping Mode. The chicken thighs are $1.20 more than estimated; after
she enters the new price, the running total is still under her $70
budget. On Tuesday evening, Cook Mode reminds her to use only half the
bag of spinach because the rest is needed for Thursday's pasta. At the
end of the week, the Week Wrap-Up shows that she spent $66.80 and that
only a few green onions were left unused.

------------------------------------------------------------------------

### MVP4: Pantry Carryover and Week-to-Week Savings

**Uniqueness highlight:** *Next week starts with what you already have.*
Leftover packages and pantry staples are carried into the next plan and
subtracted from the budget, so ingredient reuse extends across weeks,
not only within one week.

**Goal:** Turn MealWise into a weekly habit that gets cheaper over time
by remembering what the user already owns and what they liked.

**Screens introduced:**

-   **Pantry** — List of items the user already has, automatically
    filled from the Week Wrap-Up leftovers, with the ability to add,
    edit, or remove items.
-   **Plan Next Week** — Setup summary prefilled from last week, showing
    how many pantry items will be reused and the estimated savings
    (e.g., "Using your rice, onions, and spices saves about $4.50").
-   **Favorites** — Meals the user rated highly, which can be pinned
    into the next plan if the budget allows.
-   **Meal Rating** — Quick thumbs-up or thumbs-down after marking a
    meal as cooked.
-   **Weekly Nutrition Summary** — Simple overview of balance indicators
    for the week, such as the number of meals including vegetables,
    protein, and whole grains.

**Key flows:**

-   *Carry over:* Week Wrap-Up → confirm leftovers → Pantry → Plan Next
    Week → new plan prioritizing pantry items.
-   *Keep what works:* Cook Mode → Mark as Cooked → Meal Rating →
    Favorites.
-   *Add pantry items:* Pantry → Add Item → plan uses the item next
    week.

**Tasks:**

1.  **[Differentiator]** A user's leftover ingredients are added to the
    Pantry and used first in next week's plan, lowering its cost.
2.  **[Differentiator]** A user sees how much money pantry reuse saves
    in the new plan.
3.  **[Differentiator]** A user pins a favorite meal into next week, and
    the rest of the plan is re-optimized to keep the week under budget.
4.  **[Table stakes]** A user rates meals after cooking them, and
    future plans favor highly rated meals.
5.  **[Table stakes]** A user reviews a simple weekly nutrition
    summary.
6.  **[Table stakes]** A user creates an optional account so that their
    pantry, favorites, and history are saved across devices.

**Representative scenario:** After her first week, Jordan's Week
Wrap-Up shows half a bag of rice, two onions, and most of a jar of
peanut butter left over. When he taps Plan Next Week, MealWise builds a
plan that includes peanut noodles and fried rice, uses his leftovers
first, and tells him the week will cost about $3.80 less than it would
have otherwise.

------------------------------------------------------------------------

### Future: MealWise PLUS (Optional Subscription)

**Uniqueness highlight:** *Advanced savings, never a paywall on the
basics.* PLUS adds features that require ongoing data or AI costs, while
the core budget-locked plan, Ingredient Map, and recipes remain free,
and all PLUS features are free for SNAP recipients.

**Planned features:**

-   **[Differentiator]** Grocery store price comparison: compare the
    estimated cost of the same plan across nearby stores.
-   **[Differentiator]** Free PLUS access for SNAP recipients through a
    simple eligibility step.
-   **[Table stakes]** Advanced AI personalization of meals based on
    tastes, ratings, and history.
-   **[Table stakes]** Optional "tip the creator" support as an
    alternative or addition to a subscription.

**Screens introduced:** PLUS overview, Store Comparison, SNAP
eligibility, Tip Jar.

------------------------------------------------------------------------

## 7. Recommended Planning Model

MealWise's weekly cycle can be summarized as:

**Set Budget → Plan → Reuse → Shop → Cook → Wrap Up → Carry Over**

MVP1 delivers the first stages in a basic form. MVP2 strengthens
**Plan** and **Reuse**, MVP3 adds **Shop**, **Cook**, and **Wrap Up**,
and MVP4 completes the cycle with **Carry Over**.

An important design principle is that **the budget is a promise**.
The app should never quietly allow a plan to exceed the user's cap.
When a change would exceed it, MealWise should say so clearly and offer
an alternative, rather than presenting an over-budget plan as normal.

A second principle is that **estimated prices are estimates**. The app
should label them clearly, let users correct them, and use corrected
prices to make future plans more accurate.

------------------------------------------------------------------------

## 8. MVP Scope and Development Priorities

| Feature | Development Phase |
| --- | --- |
| Step-by-step budget and preference setup | MVP1 |
| Budget-locked weekly plan generation | MVP1 |
| Persistent Budget Meter and cost per meal/serving | MVP1 |
| Plans that share ingredients across meals | MVP1 |
| Dietary restriction and allergy filtering | MVP1 |
| Consolidated grocery list with package sizes and estimated prices | MVP1 |
| Simple recipes matched to cooking time and experience | MVP1 |
| Use without an account or payment | MVP1 |
| Swap within budget with Cart Impact Preview | MVP2 |
| Ingredient Map and Ingredient Detail | MVP2 |
| Leftover Forecast | MVP2 |
| Adjust budget and re-optimize | MVP2 |
| "Use now / save for later" recipe notes | MVP2 |
| Shopping Mode with actual price entry | MVP3 |
| Over-budget warnings and cheaper substitutes in store | MVP3 |
| Today view and Cook Mode | MVP3 |
| Skipped-meal handling | MVP3 |
| Week Wrap-Up | MVP3 |
| Pantry and leftover carryover | MVP4 |
| Pantry savings estimate | MVP4 |
| Meal ratings and Favorites | MVP4 |
| Weekly Nutrition Summary | MVP4 |
| Optional account and sync | MVP4 |
| Grocery store price comparison | Future / PLUS |
| Advanced AI personalization | Future / PLUS |
| SNAP eligibility for free PLUS | Future / PLUS |
| Tip the creator | Future |

For the first version, a curated set of affordable recipes with
predefined ingredients, package sizes, and estimated regional prices is
sufficient. This makes plan generation predictable, inexpensive, and
easier to test than relying on live price feeds or an AI service for
every plan.

------------------------------------------------------------------------

## 9. Conclusion

MealWise aims to make healthy eating affordable and practical for
lower-income households, SNAP recipients, and young adults by starting
every plan with the money available rather than with recipes.

The central objective of MVP1 is to demonstrate a complete weekly
cycle:

**enter a budget, receive a week of healthy meals that is guaranteed to
fit it, see how ingredients are shared, shop from a priced list, and
cook simple recipes.**

Later MVPs deepen what makes MealWise different: swaps that never break
the budget, an Ingredient Map that puts every package to use, guidance
that keeps the plan accurate in the store and the kitchen, and pantry
carryover that makes each week cheaper than the last.

By combining **a hard budget cap, plan-level ingredient reuse, and free,
beginner-friendly access**, MealWise can serve the households that
current paid meal planners leave behind.

------------------------------------------------------------------------

## 10. Assumptions & Open Questions

**Assumptions made to fill gaps in the draft**

-   **App name:** The draft names the app "MealWise," so that name is
    used throughout. Before publishing, check the App Store for
    existing apps with the same or a similar name.
-   **Reference template:** The prompt referenced
    `existing_project_description.md`, which is not in the folder. The
    file `idioms_slang_app.md` (LingoLoop) was used as the structural
    template instead.
-   **Meals per day:** The draft does not say whether plans cover
    breakfast, lunch, and dinner. The document assumes the user chooses
    which meals to include.
-   **Cooking experience** was added as a setup input, based on the
    draft's emphasis on people with limited cooking experience.
-   **Nutrition** is represented by simple balance indicators
    (vegetables, protein, whole grains) rather than calorie or macro
    tracking, to stay consistent with the draft's non-fitness
    positioning.
-   **Prices** in MVP1 are assumed to come from a curated dataset of
    estimated regional prices that users can correct.
-   **No account** is assumed to be required in MVP1; optional accounts
    arrive in MVP4.
-   The Shopping Mode, Leftover Forecast, Pantry carryover, and Week
    Wrap-Up features are expansions of the draft's "shop and cook while
    minimizing waste" and "reuse ingredients" ideas.

**Decisions still to make**

-   **Price data source:** Where estimated prices come from, how often
    they are updated, and how regional differences are handled. This is
    the biggest technical risk for the budget-locked promise.
-   **Store selection:** Which stores are supported at launch and
    whether selection changes prices or only the store-section order.
-   **Monetization:** PLUS subscription (around $5/month), "tip the
    creator," or both.
-   **SNAP verification:** If the core is free for everyone, the
    "always free for SNAP" promise mainly applies to PLUS. Decide how
    eligibility is confirmed (self-attestation or another method) while
    protecting user privacy.
-   **Platform:** iOS, Android, or both. Competitor data covers the
    Apple App Store only.
-   **Recipe source:** Who writes, tests, and prices the initial recipe
    set, and how large it needs to be to support different diets.

**Unclear parts of the draft**

-   "Re-use parts of ingredients" could mean reusing ingredients across
    meals or using leftovers from cooked meals. The document focuses on
    ingredients across meals; planned leftovers (cook once, eat twice)
    could be added.
-   The draft lists "grocery stores to shop at" as an MVP input but
    "grocery store price comparisons" as a PLUS feature. The document
    treats store selection as free and cross-store comparison as PLUS.
-   The NeatEat link in the draft was missing `https://`; it opened
    correctly once added.

**Competitor analysis notes**

-   All three Sensor Tower pages opened. Downloads and revenue are
    shown only as ranges for the last month; trends over time, DAU,
    retention, and revenue per download require a Sensor Tower login
    and were not available.
-   Cestio has no US ratings or reviews, so its quality could not be
    assessed.
-   Competitor feature-matrix cells are based on store-listing
    descriptions and three featured reviews per app, not hands-on
    testing. Whether competitors keep swaps within budget should be
    verified by installing each app.
-   **Competitor-inspired additions beyond the draft:** Shopping list
    grouped by store section (Cestio), Pantry (Eat This Much's virtual
    pantry), and meal ratings. These are included as lean table stakes.
    Fridge-photo AI, calorie tracking, recipe import, and household
    sharing were deliberately left out.

**Innovation points that overlap with SOTA apps**

-   **"Budget-first meal optimization"** is not unique on its own:
    NeatEat, Cestio, and Eat This Much all take a budget as input, and
    NeatEat is built around it. It was sharpened into a **hard cap
    enforced on every edit, with a persistent Budget Meter and
    swap previews**. Consider testing the competitors directly to
    confirm this gap.
-   **"Ingredient reuse and food waste reduction"** partly overlaps with
    NeatEat's duplicate-merging list and Eat This Much's "reduce food
    waste" claim. It was sharpened into **package-aware planning with an
    Ingredient Map and Leftover Forecast**, which the competitors do not
    describe.
-   **"Healthy eating accessible to everyone"** overlaps on diet and
    household-size settings, which all competitors offer. Its strongest
    defensible form is **free core planning and always-free access for
    SNAP recipients**, plus beginner recipes tied to the weekly reuse
    plan. Consider adding a feature that is specific to low-income
    users, such as planning a month around a SNAP benefit amount, if it
    fits your vision.
