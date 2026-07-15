# ROGUE 6502

### Instruction Manual

---

## The Story

Deep beneath the ruins of an ancient fortress lies the legendary Glowing Goblet — an artifact of immense power sought by adventurers for generations. None who have entered the dungeon's depths have returned. Armed with a mace, leather armor, and your wits, you descend into the darkness. Thirteen floors stand between you and glory.

---

## Getting Started

Press START at the title screen to begin your adventure. You begin on the first floor of the dungeon with basic equipment and a full stomach. Your goal: descend all thirteen floors, survive, and claim the Glowing Goblet.

Every game is different. The dungeon is generated fresh each time you play — room layouts, monster placement, and treasure are never the same twice.

---

## Controls

| Button | Action |
|--------|--------|
| D-Pad | Move (4 directions) |
| A | Use stairs / Pick up items |
| B | Wait one turn (skip your action) |
| START | Pause (view stats and equipment) |
| SELECT | Open inventory |

Moving into a monster attacks it. The game is turn-based — nothing moves until you do.

---

## The Screen

The top two rows display your vital stats at a glance:

- **HP** — Your remaining hit points. When this reaches zero, you die.
- **Fl** — The current dungeon floor.
- **Gold** — Treasure collected along the way.

The bottom two rows display messages about what's happening — combat results, items found, and warnings.

The dungeon map fills the area between. Rooms and corridors are shrouded in darkness until you explore them. Rooms you've visited before appear dimly, while your current surroundings are fully lit.

---

## Symbols

| Symbol | Meaning |
|--------|---------|
| **@** | You, the adventurer |
| **B E H S Z C T W G** | Monsters (see Bestiary) |
| **)** | Weapon |
| **[** | Armor |
| **!** | Potion |
| **/** | Wand |
| **:** | Food |
| **\*** | Gold |
| **>** | Stairs down |
| **<** | Stairs up |

---

## Combat

When you move into a monster, you attack it. Your weapon's power, combined with your strength, determines how much damage you deal. The monster's defense absorbs some of that damage. A small amount of variation keeps each swing unpredictable.

Not every swing connects. Your agility and the monster's quickness determine whether your attack lands. Nimble creatures like bats are harder to hit, while lumbering zombies rarely dodge.

When a monster is adjacent to you, it strikes back on its turn. Monsters always land their blows — your armor and defense bonus are your only protection.

If your HP reaches zero, your adventure is over.

---

## Equipment

### Weapons

You start with a basic Mace. Stronger weapons can be found on dungeon floors.

| Weapon | Power |
|--------|-------|
| Mace | Low |
| Short Sword | Low |
| Long Sword | Medium |
| War Hammer | High |
| Two-Hand Sword | Highest |

Some weapons carry enchantments, shown as a **+1**, **+2**, or higher bonus that increases their power further.

### Armor

You start with Leather Armor. Better armor reduces the damage you take from every hit.

| Armor | Protection |
|-------|-----------|
| Leather Armor | Light |
| Ring Mail | Light |
| Scale Mail | Medium |
| Chain Mail | Heavy |
| Plate Mail | Heaviest |

Enchanted armor provides additional protection beyond its base value.

To equip a weapon or piece of armor, open your inventory with SELECT and use it.

---

## Potions

Potions are single-use. Drink them from your inventory to gain their effect.

| Potion | Effect |
|--------|--------|
| Healing | Restores a portion of your health |
| Extra Healing | Restores a large portion of your health |
| Strength | Permanently increases your attack power |
| Poison | Permanently weakens your attack power |
| Confusion | Your movements become erratic and unpredictable for several turns |
| Blindness | Your surroundings go dark for several turns |

Not all potions are beneficial. Drink with caution — you won't know a potion's nature until you've consumed it.

---

## Wands

Wands are reusable magical items with a limited number of charges. When used, a wand automatically targets the nearest visible monster.

| Wand | Effect |
|------|--------|
| Teleport Away | Banishes the target to a distant room |
| Slow Monster | The target moves at half speed |
| Fire | Hurls a fireball dealing heavy damage |
| Lightning | Strikes with a bolt of lightning dealing very heavy damage |

When a wand's charges are spent, it becomes useless. Use them wisely — wands can turn a desperate fight in your favor.

---

## Food and Hunger

Your hunger steadily decreases as you explore. Keep an eye on the messages at the bottom of the screen for warnings:

- **"You are getting hungry."** — Find food soon.
- **"You feel weak!"** — You are dangerously hungry.
- **"You are starving!"** — You are losing health every turn.

Food rations found on dungeon floors restore your hunger and heal a small amount of health. Don't linger too long on any floor — the dungeon punishes those who dawdle.

---

## Leveling Up

Defeating monsters earns experience. When you've earned enough, you grow stronger:

- Your maximum health increases
- You are fully healed
- Your strength grows, letting you hit harder
- Your defense improves on some levels
- Your agility increases on some levels, making you more accurate

Seek out monsters to grow in power, but pick your battles carefully. A wounded adventurer far from food is a dead one.

---

## Bestiary

The dungeon is home to nine species of creature, encountered at increasing depths.

**Early Floors (1-3)**

- **Bat (B)** — Quick and erratic. Hard to hit but deals little damage. Sleeps until you draw near.
- **Snake (S)** — Fast and evasive. Strikes lightly but can be difficult to pin down.
- **Emu (E)** — Aggressive but clumsy. A straightforward foe.
- **Hobgoblin (H)** — Tougher than it looks. Hits harder than the other early dungeon dwellers.

**Middle Floors (3-7)**

- **Zombie (Z)** — Slow and relentless. High health and impossible to miss, but you'll take steady damage trading blows.
- **Centaur (C)** — A well-rounded and dangerous opponent. Hits hard, takes hits, and is quick enough to dodge.
- **Wraith (W)** — Ghostly and elusive. Dodges frequently and strikes from the shadows.

**Deep Floors (5+)**

- **Troll (T)** — A mountain of muscle. Enormous health, devastating attacks, and hard to bring down.
- **Griffin (G)** — The deadliest creature in the dungeon. If you encounter one, you had better be well-armed.

---

## Tips for Survival

- Equip new weapons and armor as soon as you find upgrades.
- Don't waste healing potions on small wounds — save them for emergencies.
- Wands are rare and powerful. A well-timed Teleport Away can save your life.
- Pay attention to your hunger. Starving kills just as surely as monsters.
- Use the B button to wait. Sometimes letting a monster come to you is smarter than charging in.
- The deeper you go, the stronger the monsters. If you're struggling, you may not be ready for the next floor.

---

## About

Rogue 6502 is a roguelike dungeon crawler for the Nintendo Entertainment System, inspired by the original *Rogue* (1980). Built entirely in 6502 assembly language.

Every playthrough is unique. There are no saves, no continues, and no second chances. Good luck, adventurer.
