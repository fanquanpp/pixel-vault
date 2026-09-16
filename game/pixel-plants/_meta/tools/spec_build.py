# -*- coding: utf-8 -*-
"""Build the pixel-plants spec + Aseprite Lua generator from the txt palette list.

Source of truth: the attached spec txt (130 colour entries across 5 categories,
plus a shared natural palette). Variant tiles are derived per the txt guidance
"copy the same tile, replace only main/accent/dot, keep leaf and stem".

Emits:
  spec.json          structured manifest of every tile to produce
  gen_<cat>.lua      one batch script per category, run through the Aseprite MCP
  slug-map.md        index -> name -> slug table
"""
import json
import os

OUT = os.path.dirname(os.path.abspath(__file__))
REPO_PACK = "C:/Atian/Project/pixel-vault/game/pixel-plants/"

CATS = [
    ("classical", "古典仙气"),
    ("romance", "浪漫花语"),
    ("herbal", "本草清雅"),
    ("trees", "树木佛意"),
    ("succulent", "野趣多肉"),
]
CAT_ZH = dict(CATS)

VAR_LATIN = {"粉": "fen", "白": "bai", "黄": "huang", "蓝": "lan",
             "红": "hong", "紫": "zi", "黄绿": "huang-lv"}

# index, nameZh, slug, category, main, accent, dot, [(variantLabel, hex)], archetype
T = [
 (1,"卷耳","juan-er","classical","#E8F0D8","#B7C9A0","#F6F2E6",[],"cluster"),
 (2,"芣苢","fu-yi","classical","#6FA34A","#3F6B3A","#C9D97A",[],"spike"),
 (3,"薇","wei","classical","#B57EDC","#7E5AA8","#F2C14E",[("白","#F6F2E6")],"floret"),
 (4,"忘忧 / 萱草","xuan-cao","classical","#F28C28","#C75B1A","#FFD84D",[("黄","#F2C14E")],"orchid"),
 (5,"江离","jiang-li","classical","#E8F0D8","#A8CF6A","#F2C14E",[],"umbel"),
 (6,"蕙","hui","classical","#8E7CC3","#5D4E8C","#F2C14E",[("黄绿","#C9D97A")],"spike"),
 (7,"扶桑","fu-sang","classical","#E63946","#A4161A","#FFD84D",[("黄","#F2C14E"),("粉","#F08BB4")],"floret"),
 (8,"若木","ruo-mu","classical","#F2C14E","#C75B1A","#FFF3B0",[],"tree_round"),
 (9,"建木","jian-mu","classical","#4FB3A8","#2E6F96","#F2C14E",[],"tree_conifer"),
 (10,"沙棠","sha-tang","classical","#F6F2E6","#E8D9B8","#F2C14E",[],"berry"),

 (11,"月见草","yue-jian-cao","romance","#FFD84D","#F2A900","#FF8A00",[("粉","#F08BB4")],"floret"),
 (12,"勿忘草","wu-wang-cao","romance","#5B8DEF","#3A5FCD","#FFD84D",[("粉","#F08BB4"),("白","#F6F2E6")],"cluster"),
 (13,"勿忘我 / 星辰花","wu-wang-wo","romance","#8E7CC3","#F08BB4","#F2C14E",[("白","#F6F2E6"),("黄","#F2C14E")],"cluster"),
 (14,"彼岸花 / 曼珠沙华","man-zhu-sha-hua","romance","#D7263D","#8C1C2A","#F2C14E",[("白","#F6F2E6")],"spider"),
 (15,"虞美人","yu-mei-ren","romance","#E63946","#A4161A","#1A1A20",[("粉","#F08BB4"),("白","#F6F2E6"),("黄","#F2C14E")],"floret"),
 (16,"鸢尾","yuan-wei","romance","#6A5ACD","#3F3F8C","#F2C14E",[("黄","#F2C14E"),("白","#F6F2E6")],"orchid"),
 (17,"夕颜","xi-yan","romance","#F6F2E6","#D9D2C0","#F2C14E",[("黄","#FFF3B0")],"bell"),
 (18,"昼颜","zhou-yan","romance","#F6F2E6","#F08BB4","#F2C14E",[],"bell"),
 (19,"雪见","xue-jian","romance","#F6F2E6","#A8CF6A","#B8D97A",[],"floret"),
 (20,"铃兰","ling-lan","romance","#F6F2E6","#D9D2C0","#A8CF6A",[],"bell"),
 (21,"雪滴花","xue-di-hua","romance","#F6F2E6","#A8CF6A","#F2C14E",[],"bell"),
 (22,"雪绒花","xue-rong-hua","romance","#F6F2E6","#E8D9B8","#F2C14E",[],"floret"),
 (23,"琉璃苣","liu-li-ju","romance","#4A90E2","#2E5FA3","#F2C14E",[("粉","#F08BB4")],"daisy"),
 (24,"迷迭香","mi-die-xiang","romance","#6A5ACD","#3F3F8C","#A8CF6A",[],"herb"),
 (25,"薰衣草","xun-yi-cao","romance","#9B7EDE","#6A5ACD","#A8CF6A",[],"spike"),
 (26,"洋甘菊","yang-gan-ju","romance","#F6F2E6","#F2C14E","#FFD84D",[],"daisy"),
 (27,"蒲公英","pu-gong-ying","romance","#FFD84D","#F2A900","#F6F2E6",[],"daisy"),
 (28,"三色堇","san-se-jin","romance","#6A5ACD","#FFD84D","#F6F2E6",[("红","#E63946")],"floret"),
 (29,"紫罗兰","zi-luo-lan","romance","#7E5AA8","#5D4E8C","#F2C14E",[("白","#F6F2E6")],"floret"),
 (30,"矢车菊","shi-che-ju","romance","#4A90E2","#2E5FA3","#F6F2E6",[("粉","#F08BB4"),("白","#F6F2E6")],"daisy"),
 (31,"飞燕草","fei-yan-cao","romance","#5B8DEF","#3F3F8C","#F6F2E6",[("粉","#F08BB4"),("白","#F6F2E6")],"spike"),
 (32,"翠雀","cui-que","romance","#4A90E2","#2E5FA3","#1A1A20",[],"spike"),
 (33,"鲁冰花","lu-bing-hua","romance","#8E7CC3","#F08BB4","#F2C14E",[("蓝","#4A90E2"),("红","#E63946"),("白","#F6F2E6")],"spike"),
 (34,"满天星","man-tian-xing","romance","#F6F2E6","#F08BB4","#A8CF6A",[],"umbel"),
 (35,"情人草","qing-ren-cao","romance","#F08BB4","#9B7EDE","#F6F2E6",[],"umbel"),
 (36,"水晶草","shui-jing-cao","romance","#F6F2E6","#B8D9E8","#A8CF6A",[],"umbel"),
 (37,"麦秆菊","mai-gan-ju","romance","#F2C14E","#C75B1A","#F6F2E6",[("粉","#F08BB4")],"daisy"),
 (38,"千日红","qian-ri-hong","romance","#D7263D","#8C1C2A","#F2C14E",[("紫","#8E7CC3")],"cluster"),
 (39,"荼蘼","tu-mi","romance","#F6F2E6","#D9D2C0","#F2C14E",[],"floret"),
 (40,"合欢","he-huan","romance","#F08BB4","#C75B7A","#F2C14E",[],"cluster"),
 (41,"相思子 / 红豆","hong-dou","romance","#D7263D","#1A1A20","#F6F2E6",[],"berry"),
 (42,"丁香","ding-xiang","romance","#9B7EDE","#6A5ACD","#F6F2E6",[("白","#F6F2E6")],"cluster"),
 (43,"紫薇","zi-wei","romance","#F08BB4","#9B7EDE","#F2C14E",[("白","#F6F2E6")],"cluster"),
 (44,"栀子","zhi-zi","romance","#F6F2E6","#E8D9B8","#F2C14E",[],"floret"),
 (45,"含笑","han-xiao","romance","#F6F2E6","#F2C14E","#A8CF6A",[],"floret"),
 (46,"晚香玉","wan-xiang-yu","romance","#F6F2E6","#D9D2C0","#F2C14E",[],"spike"),
 (47,"夜来香","ye-lai-xiang","romance","#F2C14E","#A8CF6A","#F6F2E6",[],"umbel"),
 (48,"昙花","tan-hua","romance","#F6F2E6","#D9D2C0","#F2C14E",[],"orchid"),
 (49,"优昙婆罗","you-tan-po-luo","romance","#F6F2E6","#FFF3B0","#F2C14E",[],"orchid"),
 (50,"曼陀罗","man-tuo-luo","romance","#F6F2E6","#9B7EDE","#F2C14E",[("紫","#6A5ACD")],"bell"),
 (51,"荷包牡丹","he-bao-mu-dan","romance","#F08BB4","#D7263D","#F6F2E6",[],"bell"),
 (52,"桔梗","jie-geng","romance","#5B8DEF","#3F3F8C","#F6F2E6",[("白","#F6F2E6")],"bell"),
 (53,"风铃草","feng-ling-cao","romance","#6A5ACD","#9B7EDE","#F6F2E6",[("粉","#F08BB4"),("白","#F6F2E6")],"bell"),
 (54,"蓝星花","lan-xing-hua","romance","#4A90E2","#2E5FA3","#F6F2E6",[],"floret"),
 (55,"繁缕","fan-lv","romance","#F6F2E6","#A8CF6A","#F2C14E",[],"cluster"),
 (56,"剪秋萝","jian-qiu-luo","romance","#E63946","#F08BB4","#F6F2E6",[],"floret"),
 (57,"剪春罗","jian-chun-luo","romance","#F08BB4","#D7263D","#F6F2E6",[],"floret"),
 (58,"剪夏罗","jian-xia-luo","romance","#D7263D","#8C1C2A","#F2C14E",[],"floret"),

 (59,"青黛","qing-dai","herbal","#2E4A8C","#1E2E5C","#6A8FD9",[],"herb"),
 (60,"半夏","ban-xia","herbal","#A8CF6A","#3F6B3A","#F6F2E6",[],"herb"),
 (61,"白芷","bai-zhi","herbal","#F6F2E6","#A8CF6A","#F2C14E",[],"umbel"),
 (62,"佩兰","pei-lan","herbal","#9B7EDE","#3F6B3A","#F6F2E6",[],"spike"),
 (63,"泽兰","ze-lan","herbal","#6FA34A","#9B7EDE","#F6F2E6",[],"spike"),
 (64,"木香","mu-xiang","herbal","#F2C14E","#F6F2E6","#A8CF6A",[],"floret"),
 (65,"沉香","chen-xiang","herbal","#5A3F2C","#2E221C","#B88952",[],"tree_round"),
 (66,"苏合香","su-he-xiang","herbal","#8C4A2E","#5A2E1A","#F2C14E",[],"tree_round"),
 (67,"安息香","an-xi-xiang","herbal","#B88952","#7A5A38","#F2C14E",[],"tree_round"),
 (68,"当归","dang-gui","herbal","#C49A5A","#8C6440","#F6F2E6",[],"umbel"),
 (69,"独活","du-huo","herbal","#F6F2E6","#A8CF6A","#5A3F2C",[],"umbel"),
 (70,"远志","yuan-zhi","herbal","#6A5ACD","#3F3F8C","#F2C14E",[],"floret"),
 (71,"使君子","shi-jun-zi","herbal","#E63946","#F08BB4","#F2C14E",[],"cluster"),
 (72,"女贞子","nv-zhen-zi","herbal","#2E4A2A","#1A1A20","#A8CF6A",[],"berry"),
 (73,"夜交藤","ye-jiao-teng","herbal","#6FA34A","#F6F2E6","#F2C14E",[],"vine"),
 (74,"忍冬","ren-dong","herbal","#F6F2E6","#F2C14E","#A8CF6A",[],"vine"),
 (75,"凌霄","ling-xiao","herbal","#F28C28","#C75B1A","#FFD84D",[],"vine"),
 (76,"络石","luo-shi","herbal","#F6F2E6","#A8CF6A","#F2C14E",[],"vine"),
 (77,"石斛","shi-hu","herbal","#9B7EDE","#F6F2E6","#F2C14E",[],"orchid"),
 (78,"玉竹","yu-zhu","herbal","#F6F2E6","#A8CF6A","#B8D97A",[],"bell"),
 (79,"黄精","huang-jing","herbal","#F2C14E","#A8CF6A","#F6F2E6",[],"bell"),
 (80,"灵芝","ling-zhi","herbal","#A4161A","#5A2E1A","#F2C14E",[],"fungus"),
 (81,"茯苓","fu-ling","herbal","#F6F2E6","#B88952","#5A3F2C",[],"fungus"),
 (82,"雪莲","xue-lian","herbal","#F6F2E6","#B8D9E8","#A8CF6A",[],"floret"),
 (83,"红景天","hong-jing-tian","herbal","#D7263D","#3F6B3A","#F2C14E",[],"succ_rosette"),
 (84,"重楼","chong-lou","herbal","#3F6B3A","#6A5ACD","#F2C14E",[],"herb"),
 (85,"白薇","bai-wei","herbal","#F6F2E6","#9B7EDE","#F2C14E",[],"floret"),
 (86,"紫菀","zi-wan","herbal","#9B7EDE","#6A5ACD","#F2C14E",[],"daisy"),
 (87,"款冬","kuan-dong","herbal","#F2C14E","#A8CF6A","#F6F2E6",[],"daisy"),
 (88,"旋覆","xuan-fu","herbal","#FFD84D","#F6F2E6","#A8CF6A",[],"daisy"),
 (89,"飞蓬","fei-peng","herbal","#F6F2E6","#A8CF6A","#F2C14E",[],"daisy"),
 (90,"菖蒲","chang-pu","herbal","#6FA34A","#F2C14E","#5A3F2C",[],"grass"),
 (91,"香蒲","xiang-pu","herbal","#8C6440","#C49A5A","#A8CF6A",[],"grass"),
 (92,"芡实","qian-shi","herbal","#9B7EDE","#F6F2E6","#A8CF6A",[],"aquatic"),
 (93,"莼菜","chun-cai","herbal","#3F6B3A","#6A5ACD","#B8D9E8",[],"aquatic"),
 (94,"水苏","shui-su","herbal","#6FA34A","#F6F2E6","#9B7EDE",[],"spike"),
 (95,"留兰香","liu-lan-xiang","herbal","#A8CF6A","#3F6B3A","#F6F2E6",[],"herb"),
 (96,"马郁兰","ma-yu-lan","herbal","#6FA34A","#F2C14E","#F6F2E6",[],"herb"),
 (97,"蓍草","shi-cao","herbal","#F6F2E6","#A8CF6A","#F2C14E",[],"umbel"),
 (98,"茵陈","yin-chen","herbal","#A8CF6A","#F6F2E6","#3F6B3A",[],"herb"),
 (99,"青蒿","qing-hao","herbal","#3F6B3A","#6FA34A","#A8CF6A",[],"herb"),

 (100,"菩提树","pu-ti-shu","trees","#3F6B3A","#A8CF6A","#F2C14E",[],"tree_round"),
 (101,"无忧树","wu-you-shu","trees","#F28C28","#C75B1A","#FFD84D",[],"tree_broad"),
 (102,"娑罗树","suo-luo-shu","trees","#F6F2E6","#A8CF6A","#F2C14E",[],"tree_round"),
 (103,"凤凰木","feng-huang-mu","trees","#E63946","#F28C28","#FFD84D",[],"tree_broad"),
 (104,"蓝花楹","lan-hua-ying","trees","#6A5ACD","#4A90E2","#B8D9E8",[],"tree_broad"),
 (105,"紫藤","zi-teng","trees","#9B7EDE","#6A5ACD","#A8CF6A",[],"vine"),
 (106,"辛夷","xin-yi","trees","#9B7EDE","#F6F2E6","#F2C14E",[],"tree_round"),
 (107,"木莲","mu-lian","trees","#F6F2E6","#9B7EDE","#F2C14E",[],"tree_round"),
 (108,"白兰","bai-lan","trees","#F6F2E6","#F2C14E","#A8CF6A",[],"tree_round"),
 (109,"深山含笑","shen-shan-han-xiao","trees","#F6F2E6","#F2C14E","#3F6B3A",[],"tree_round"),
 (110,"乐昌含笑","le-chang-han-xiao","trees","#F6F2E6","#F08BB4","#F2C14E",[],"tree_round"),
 (111,"枫香","feng-xiang","trees","#D7263D","#F28C28","#F2C14E",[],"tree_broad"),
 (112,"乌桕","wu-jiu","trees","#A4161A","#D7263D","#F2C14E",[],"tree_broad"),
 (113,"无患子","wu-huan-zi","trees","#F2C14E","#A8CF6A","#F6F2E6",[],"tree_round"),
 (114,"苦楝","ku-lian","trees","#9B7EDE","#F6F2E6","#F2C14E",[],"tree_round"),
 (115,"檀香","tan-xiang","trees","#8C6440","#C49A5A","#F2C14E",[],"tree_round"),
 (116,"降香","jiang-xiang","trees","#8C4A2E","#5A2E1A","#F2C14E",[],"tree_round"),

 (117,"生石花","sheng-shi-hua","succulent","#A8B89A","#F08BB4","#F6F2E6",[("黄","#F2C14E")],"succ_lithops"),
 (118,"熊童子","xiong-tong-zi","succulent","#A8CF6A","#C75B1A","#F6F2E6",[],"succ_paw"),
 (119,"观音莲","guan-yin-lian","succulent","#6FA34A","#9B7EDE","#F6F2E6",[],"succ_rosette"),
 (120,"佛珠","fo-zhu","succulent","#A8CF6A","#F6F2E6","#3F6B3A",[],"succ_beads"),
 (121,"情人泪","qing-ren-lei","succulent","#A8CF6A","#F6F2E6","#B8D9E8",[],"succ_beads"),
 (122,"不死鸟","bu-si-niao","succulent","#6FA34A","#E63946","#F2C14E",[],"succ_rosette"),
 (123,"长生草","chang-sheng-cao","succulent","#3F6B3A","#A4161A","#A8CF6A",[],"succ_rosette"),
 (124,"瓦松","wa-song","succulent","#8A8F98","#A8CF6A","#C75B1A",[],"succ_rosette"),
 (125,"垂盆草","chui-pen-cao","succulent","#A8CF6A","#F2C14E","#F6F2E6",[],"succ_beads"),
 (126,"含羞草","han-xiu-cao","succulent","#A8CF6A","#F08BB4","#F6F2E6",[],"herb"),
 (127,"跳舞草","tiao-wu-cao","succulent","#6FA34A","#A8CF6A","#F2C14E",[],"herb"),
 (128,"雪见草","xue-jian-cao","succulent","#F6F2E6","#A8CF6A","#B8D9E8",[],"herb"),
 (129,"半边莲","ban-bian-lian","succulent","#5B8DEF","#F6F2E6","#F2C14E",[],"floret"),
 (130,"洋桔梗","yang-jie-geng","succulent","#F08BB4","#9B7EDE","#F6F2E6",[("白","#F6F2E6"),("蓝","#5B8DEF"),("黄","#F2C14E")],"floret"),
]


def darken(hexcol, f=0.62):
    r = int(hexcol[1:3], 16); g = int(hexcol[3:5], 16); b = int(hexcol[5:7], 16)
    return "#%02X%02X%02X" % (int(r * f + 0.5), int(g * f + 0.5), int(b * f + 0.5))


def main():
    assert len(T) == 130, len(T)
    items = []
    by_cat = {c: [] for c, _ in CATS}
    base_n = 0
    for (i, zh, slug, cat, main_, acc, dot, variants, arch) in T:
        base_n += 1
        assert i == base_n, (i, base_n)
        w = h = 64
        base = {
            "index": i, "baseIndex": i, "variantOf": None, "variantLabel": None,
            "category": cat, "categoryNameZh": CAT_ZH[cat], "nameZh": zh, "slug": slug,
            "main": main_, "accent": acc, "dot": dot, "canvas": w, "archetype": arch,
            "seed": i * 7 + 3, "inferred": False,
        }
        items.append(base)
        by_cat[cat].append(base)
        for k, (vlab, vhex) in enumerate(variants):
            v = dict(base)
            v.update({
                "index": len(items) + 1, "variantOf": slug, "variantLabel": vlab,
                "nameZh": zh + "（变体" + vlab + "）", "slug": slug + "-" + VAR_LATIN[vlab],
                "main": vhex, "accent": darken(vhex), "dot": dot,
                "seed": 1000 + i * 10 + k, "inferred": True,
            })
            items.append(v)
            by_cat[cat].append(v)

    spec = {
        "count": len(items), "baseCount": len(T),
        "variantCount": len(items) - len(T),
        "categories": [{"id": c, "nameZh": zh,
                        "count": sum(1 for x in items if x["category"] == c)} for c, zh in CATS],
        "palette": {
            "leafLight": "#6FA34A", "leafDark": "#3F6B3A",
            "trunk": "#7A5A38", "trunkDark": "#4A3528",
            "shadow": "#1A1A20", "shadowAlphaPct": [25, 40],
            "glint": "#FFF3B0", "glintAlt": "#F6F2E6",
        },
        "items": items,
    }
    with open(os.path.join(OUT, "plant_spec.json"), "w", encoding="utf-8") as f:
        json.dump(spec, f, ensure_ascii=False, indent=1)

    lib = open(os.path.join(OUT, "plant_lib.lua"), encoding="utf-8").read()
    for cat, _ in CATS:
        rows = []
        for it in by_cat[cat]:
            rows.append(
                '{index=%d,slug="%s",w=%d,h=%d,main="%s",accent="%s",dot="%s",archetype="%s",seed=%d},'
                % (it["index"], it["slug"], it["canvas"], it["canvas"], it["main"],
                   it["accent"], it["dot"], it["archetype"], it["seed"]))
        inject = ("local ITEMS = {\n" + "\n".join(rows) +
                  "\n}\nlocal OUT_DIR = \"" + REPO_PACK + "\"\n")
        out = lib.replace("--@@ITEMS@@", inject)
        with open(os.path.join(OUT, "gen_%s.lua" % cat), "w", encoding="utf-8") as f:
            f.write(out)

    with open(os.path.join(OUT, "slug-map.md"), "w", encoding="utf-8") as f:
        f.write("# pixel-plants 命名映射\n\n| # | 中文名 | slug | 类别 | 画布 | 原型 |\n|---|---|---|---|---|---|\n")
        for it in items:
            f.write("| %d | %s | `%s` | %s | %dx%d | %s |\n" % (
                it["index"], it["nameZh"], it["slug"], it["categoryNameZh"],
                it["canvas"], it["canvas"], it["archetype"]))

    print("plant_spec.json:", len(items), "tiles (", len(T), "base +", len(items) - len(T), "variants )")
    for c, _ in CATS:
        print("  ", c, len(by_cat[c]))
    print("lua files:", ", ".join("gen_%s.lua" % c for c, _ in CATS))


if __name__ == "__main__":
    main()
