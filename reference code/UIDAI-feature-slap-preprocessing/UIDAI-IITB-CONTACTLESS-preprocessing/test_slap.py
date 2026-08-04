"""
Quick smoke test for the multi-finger service.

Usage:
    python test_slap.py path/to/slap_image.jpg [right|left]

Starts nothing — assumes `python slap_app.py` is already running on :5010.
"""
import sys
import requests

URL = "http://127.0.0.1:5010"


def main():
    if len(sys.argv) < 2:
        print("usage: python test_slap.py <image> [right|left]")
        sys.exit(1)
    img_path = sys.argv[1]
    hand = sys.argv[2] if len(sys.argv) > 2 else "right"

    print("health:", requests.get(f"{URL}/health").json())

    with open(img_path, "rb") as fh:
        r = requests.post(
            f"{URL}/process_slap",
            files={"image": fh},
            data={"hand_side": hand, "vis": "0"},
            timeout=120,
        )
    data = r.json()
    print(f"\nfinger_count = {data.get('finger_count')}")
    for f in data.get("fingers", []):
        print(
            f"  {f['finger_position']:<14} iso={f['iso_code']} "
            f"conf={f['detection_conf']} "
            f"minutiae={f.get('minutiae_count')} "
            f"live={f.get('liveness', {}).get('is_live')} ok={f.get('ok')}"
        )


if __name__ == "__main__":
    main()
