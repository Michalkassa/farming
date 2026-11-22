#!/usr/bin/env python3
"""Rough pacing simulation of the farm economy, read straight from
resources/items/*.tres. A greedy player clicks once a second: harvests ripe
plots, tills, waters, plants the most profitable seed they can afford, and
buys tool upgrades, animals and the dog once they have a comfortable margin.
Prints when each milestone is reached, so you can check pacing after changing
prices (target: everything in roughly 35-45 simulated minutes, which is about
an hour for a real player).

    python3 tools/balance_sim.py [minutes]
"""
import re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

PLOTS, COLS = 42, 7
CLICK = 1.0          # seconds per click
WATER_SPEED = 2.0
START_MONEY, START_WHEAT = 40, 30


def run(cfg, minutes=120, verbose=False):
    crops, animals, tools, dog = cfg["crops"], cfg["animals"], cfg["tools"], cfg["dog"]
    money = START_MONEY
    seeds = {"wheat": START_WHEAT}
    # plot: stage 0 bare, 1 tilled, 2 watered, 3 planted(crop, ready_at)
    plots = [[0, None, 0.0] for _ in range(PLOTS)]
    hoe = can = 1
    pen = {k: 0 for k in animals}
    has_dog = False
    t = 0.0
    milestones = {}
    next_click = 0.0
    animal_acc = 0.0
    log = []

    def best_crop():
        best, best_rate = None, -1
        for name, c in crops.items():
            if c["seed"] > money and seeds.get(name, 0) == 0:
                continue
            rate = (c["yield"] * c["sell"] - c["seed"]) / (c["grow"] / WATER_SPEED)
            if rate > best_rate:
                best, best_rate = name, rate
        return best

    def mark(name):
        if name not in milestones:
            milestones[name] = t / 60

    while t < minutes * 60:
        # passive animal income per second
        for k, n in pen.items():
            a = animals[k]
            money += n * a["sell"] / a["every"]
        income_rate = sum(n * animals[k]["sell"] / animals[k]["every"] for k, n in pen.items())
        speed = WATER_SPEED * (1 + dog["bonus"] if has_dog else 1)
        if t >= next_click:
            next_click = t + CLICK
            acted = False
            # harvest
            for p in plots:
                if p[0] == 3 and t >= p[2]:
                    c = crops[p[1]]
                    money += c["yield"] * c["sell"]
                    p[0], p[1] = 0, None
                    acted = True
                    break
            if not acted:
                bare = [i for i, p in enumerate(plots) if p[0] == 0]
                tilled = [i for i, p in enumerate(plots) if p[0] == 1]
                watered = [i for i, p in enumerate(plots) if p[0] == 2]
                if watered:
                    crop = best_crop()
                    if crop:
                        if seeds.get(crop, 0) > 0:
                            seeds[crop] -= 1
                        else:
                            money -= crops[crop]["seed"]
                        i = watered[0]
                        plots[i] = [3, crop, t + crops[crop]["grow"] / speed]
                        mark("plant_" + crop)
                        acted = True
                if not acted and tilled:
                    for i in tilled[:can * can]:
                        plots[i][0] = 2
                    acted = True
                if not acted and bare:
                    for i in bare[:hoe * hoe]:
                        plots[i][0] = 1
                    acted = True
            # purchases (free actions)
            for name, tool in sorted(tools.items(), key=lambda kv: kv[1]["price"]):
                level = tool["area"]
                kind = tool["kind"]
                cur = hoe if kind == "hoe" else can
                if level == cur + 1 and money >= tool["price"] * 1.5:
                    money -= tool["price"]
                    if kind == "hoe":
                        hoe = level
                    else:
                        can = level
                    mark(name)
            for k in sorted(animals, key=lambda k: animals[k]["price"]):
                a = animals[k]
                if pen[k] < 5 and money >= a["price"] * 2:
                    money -= a["price"]
                    pen[k] += 1
                    mark(f"{k}_first" if pen[k] == 1 else f"{k}_{pen[k]}")
            if not has_dog and money >= dog["price"] * 2:
                money -= dog["price"]
                has_dog = True
                mark("dog")
            if hoe == 4 and can == 4:
                mark("gold_tools")
            if all(n == 5 for n in pen.values()) and has_dog:
                mark("full_pen")
        if int(t) % 300 == 0 and t == int(t) and verbose:
            log.append((int(t / 60), int(money), hoe, can, dict(pen)))
        t += 1.0
    return milestones, money, log


def load_items():
    items = {}
    for path in (ROOT / "resources/items").glob("*.tres"):
        fields = dict(re.findall(r'^(\w+) = (.+)$', path.read_text(), re.M))
        clean = {k: v.strip().lstrip("&").strip('"') for k, v in fields.items()}
        items[clean.get("id", path.stem)] = clean
    return items


def config_from_items():
    items = load_items()
    num = lambda d, k, default=0: float(d.get(k, default))
    crops, animals, tools, dog = {}, {}, {}, {"price": 0, "bonus": 0.5}
    for item_id, d in items.items():
        if d.get("seed_for"):
            crop = items[d["seed_for"]]
            crops[d["seed_for"]] = {"seed": num(d, "buy_price"), "grow": num(d, "grow_time"),
                                    "yield": num(d, "harvest_amount", 1), "sell": num(crop, "sell_price")}
        elif d.get("animal_kind") == "dog":
            dog["price"] = num(d, "buy_price")
        elif d.get("animal_kind"):
            product = items[d["product_id"]]
            animals[d["animal_kind"]] = {"price": num(d, "buy_price"), "sell": num(product, "sell_price"),
                                         "every": num(d, "produce_time")}
        elif d.get("tool_kind") and d.get("for_sale") == "true":
            tools[item_id] = {"kind": "hoe" if d["tool_kind"] == "hoe" else "can",
                              "area": int(num(d, "tool_area", 1)), "price": num(d, "buy_price")}
    return {"crops": crops, "animals": animals, "tools": tools, "dog": dog}


if __name__ == "__main__":
    minutes = int(sys.argv[1]) if len(sys.argv) > 1 else 120
    ms, money, log = run(config_from_items(), minutes=minutes, verbose=True)
    for k, v in sorted(ms.items(), key=lambda kv: kv[1]):
        print(f"{v:6.1f} min  {k}")
    print(f"money at {minutes} min:", int(money))
    for row in log:
        print(row)
