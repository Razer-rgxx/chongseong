"""플레이 기록 요약: python3 docs/playlog_report.py <playlog.jsonl>
판(언덕)마다 도달 구역·시간·뽑기·처치, 들판·무덤에서 쓰러진 곳과 때린 적, 우두머리를 잡을 때 남은 체력을 모아 보여 준다.
숫자를 고칠 때(26단계 균형, 5단계 손맛) 근거로 쓴다."""
import json, sys, collections

def main(path):
    rows = [json.loads(l) for l in open(path, encoding="utf-8") if l.strip()]
    hills = [r for r in rows if r["kind"] == "hill_end"]
    downs = [r for r in rows if r["kind"] == "down"]
    chiefs = [r for r in rows if r["kind"] == "chief"]
    print(f"기록 {len(rows)}줄 · 언덕 {len(hills)}판 · 쓰러짐 {len(downs)} · 우두머리 {len(chiefs)}")
    if hills:
        avg = lambda k: sum(r[k] for r in hills) / len(hills)
        print(f"\n[언덕] 이긴 판 {sum(r['won'] for r in hills)}/{len(hills)} · 평균 구역 {avg('zone'):.1f} · 평균 {avg('secs')/60:.1f}분 · 뽑기 {avg('pulls'):.1f} · 처치 {avg('kills'):.0f} · 조각 {avg('shards'):.0f}")
        print("  한 판 처치 수로 본 검의 기억 1000마리까지: 약 %.0f판" % (1000 / max(1, avg('kills'))))
        print("  도달 구역:", dict(sorted(collections.Counter(r["zone"] for r in hills).items())))
        print("  마지막에 때린 적:", collections.Counter(r["killer"] for r in hills if not r["won"]).most_common(5))
    if downs:
        print("\n[쓰러짐] 곳:", collections.Counter((r["place"], r["area"]) for r in downs).most_common(8))
        print("  때린 적:", collections.Counter(r["killer"] for r in downs).most_common(8))
        print("  밤에:", sum(r["night"] for r in downs), "/", len(downs))
    if chiefs:
        print("\n[우두머리] 잡을 때 남은 체력 비율:")
        for r in chiefs:
            print(f"  {r['id']}: {r['hp_left']}/{r['hp_max']} ({100*r['hp_left']/max(1,r['hp_max']):.0f}%){' · 밤' if r['night'] else ''}")

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "playlog.jsonl")
