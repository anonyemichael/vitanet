# app/scripts/simulate_live_vitals.py
"""
Streams realistic vitals into the running app via HTTP, simulating a live device.
Run: python -m app.scripts.simulate_live_vitals <user_id> [--interval 5] [--api http://localhost:8000] [--vitals heart_rate,bp_systolic,...]
"""
import time
import random
import argparse
import requests

ALL_VITALS = ["heart_rate", "bp_systolic", "bp_diastolic", "temperature", "blood_oxygen"]


def make_reading(vital_type: str, value: float, source: str = "simulated_device"):
    return {"vital_type": vital_type, "value": value, "source": source}


def generate_tick(tick: int, enabled: set[str]):
    """Generate one realistic set of readings for this moment in time, filtered to enabled vitals."""
    readings = []

    if "heart_rate" in enabled:
        readings.append(make_reading("heart_rate", round(random.uniform(65, 80), 1)))

    if "bp_systolic" in enabled or "bp_diastolic" in enabled:
        # Dramatic spike every 12 ticks, clearly crossing the urgent alert threshold
        is_spike = tick % 12 == 0 and tick > 0
        systolic_base = 145 if is_spike else 118
        diastolic_base = 92 if is_spike else 76
        if "bp_systolic" in enabled:
            readings.append(make_reading("bp_systolic", round(random.uniform(systolic_base - 2, systolic_base + 4), 1)))
        if "bp_diastolic" in enabled:
            readings.append(make_reading("bp_diastolic", round(random.uniform(diastolic_base - 2, diastolic_base + 2), 1)))

    if "temperature" in enabled:
        readings.append(make_reading("temperature", round(random.uniform(36.4, 37.0), 1)))

    if "blood_oxygen" in enabled:
        readings.append(make_reading("blood_oxygen", round(random.uniform(96, 99), 1)))

    return readings


def run(user_id: str, api_base: str, interval: int, enabled: set[str]):
    tick = 0
    print(f"Streaming simulated vitals ({', '.join(enabled)}) for user {user_id} every {interval}s. Ctrl+C to stop.")
    while True:
        readings = generate_tick(tick, enabled)
        if readings:
            try:
                resp = requests.post(
                    f"{api_base}/vitals/{user_id}/batch",
                    json={"readings": readings},
                    timeout=5,
                )
                if resp.status_code == 200:
                    for r in readings:
                        print(f"[OK] {r['vital_type']}: {r['value']}")
                else:
                    print(f"[FAIL {resp.status_code}] {resp.text}")
            except requests.RequestException as e:
                print(f"[ERROR] batch request: {e}")
        tick += 1
        time.sleep(interval)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("user_id")
    parser.add_argument("--interval", type=int, default=5, help="Seconds between reading batches")
    parser.add_argument("--api", default="http://localhost:8000", help="API base URL")
    parser.add_argument(
        "--vitals",
        default=",".join(ALL_VITALS),
        help=f"Comma-separated list of vitals to simulate. Options: {', '.join(ALL_VITALS)}",
    )
    args = parser.parse_args()

    enabled_set = set(args.vitals.split(","))
    run(args.user_id, args.api, args.interval, enabled_set)