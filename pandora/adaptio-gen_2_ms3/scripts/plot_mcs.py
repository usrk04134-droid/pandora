#!/usr/bin/env python3
import argparse
import json
from typing import List, Tuple, Optional

import matplotlib.pyplot as plt
import matplotlib.colors as mcolors  # for hex→RGB

ZMAX_DEFAULT = 0.0


# Read vertical component from a dict: prefer 'y', then 'z', then 'vertical'.
def _get_vertical_from_point_dict(p: dict) -> Optional[float]:
    for key in ("y", "z", "vertical"):
        v = p.get(key)
        if isinstance(v, (int, float)):
            return float(v)
    return None


# Read horizontal component from a dict: prefer 'x', then 'horizontal'.
def _get_horizontal_from_point_dict(p: dict) -> Optional[float]:
    for key in ("x", "horizontal"):
        v = p.get(key)
        if isinstance(v, (int, float)):
            return float(v)
    return None


# Parse an array of MCS points into (x, z) for plotting.
def _parse_points(arr) -> List[Tuple[float, float]]:
    out: List[Tuple[float, float]] = []
    if isinstance(arr, list):
        for p in arr:
            if isinstance(p, dict):
                x = _get_horizontal_from_point_dict(p)
                v = _get_vertical_from_point_dict(p)
                # ⬇️ FIXED: removed extra ')'
                if isinstance(x, float) and isinstance(v, float):
                    out.append((x, v))
    return out


# Parse mcsProfile into (x, z) pairs (profile uses 'x' and 'z').
def _parse_profile(arr) -> List[Tuple[float, float]]:
    out: List[Tuple[float, float]] = []
    if isinstance(arr, list):
        for p in arr:
            if isinstance(p, dict):
                x = p.get("x")
                z = p.get("z")
                if isinstance(x, (int, float)) and isinstance(z, (int, float)):
                    out.append((float(x), float(z)))
    return out


# Extract slides.actual as a single (x, z) point if present.
def _parse_slides_actual(obj: dict) -> Optional[Tuple[float, float]]:
    slides = obj.get("slides")
    if not isinstance(slides, dict):
        return None
    actual = slides.get("actual")
    if not isinstance(actual, dict):
        return None
    x = _get_horizontal_from_point_dict(actual)
    v = _get_vertical_from_point_dict(actual)
    if isinstance(x, float) and isinstance(v, float):
        return (x, v)
    return None


# Extract weldSystems[1].current.actual as a float if present.
def _parse_ws1_current_actual(obj: dict) -> Optional[float]:
    ws = obj.get("weldSystems")
    if not isinstance(ws, list) or len(ws) < 2:
        return None
    ws1 = ws[1]
    if not isinstance(ws1, dict):
        return None
    cur = ws1.get("current")
    if not isinstance(cur, dict):
        return None
    val = cur.get("actual")
    if isinstance(val, (int, float)):
        return float(val)
    return None


# Extract weldSystems[1].state as a string if present.
def _parse_ws1_state(obj: dict) -> Optional[str]:
    ws = obj.get("weldSystems")
    if not isinstance(ws, list) or len(ws) < 2:
        return None
    ws1 = ws[1]
    if not isinstance(ws1, dict):
        return None
    st = ws1.get("state")
    return st if isinstance(st, str) else None


# Load positions, profiles, mcs, mcsDelayed, slides.actual, and ws1.current.actual.
# If include_arcing_only=True, keep only records with weldSystems[1].state == "arcing".
def load_records(path: str, include_arcing_only: bool):
    positions: List[float] = []
    profiles: List[List[Tuple[float, float]]] = []
    mcs_points: List[List[Tuple[float, float]]] = []
    mcs_delayed_points: List[List[Tuple[float, float]]] = []
    slides_points: List[Optional[Tuple[float, float]]] = []
    ws1_current_actuals: List[Optional[float]] = []

    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except Exception:
                continue

            # Optional filter: include only 'arcing' if requested
            if include_arcing_only:
                st = _parse_ws1_state(obj)
                if not (isinstance(st, str) and st.lower() == "arcing"):
                    continue

            pos = obj.get("weldAxis", {}).get("position")
            prof = obj.get("mcsProfile")
            mcs = obj.get("mcs")
            mcs_delayed = obj.get("mcsDelayed")
            slides_actual = _parse_slides_actual(obj)
            ws1_actual = _parse_ws1_current_actual(obj)

            if not isinstance(pos, (int, float)) or not isinstance(prof, list):
                continue

            prof_pts = _parse_profile(prof)
            mcs_pts = _parse_points(mcs)
            mcs_delayed_pts = _parse_points(mcs_delayed)

            if prof_pts:
                positions.append(float(pos))
                profiles.append(prof_pts)
                mcs_points.append(mcs_pts)
                mcs_delayed_points.append(mcs_delayed_pts)
                slides_points.append(slides_actual)
                ws1_current_actuals.append(ws1_actual)

    return positions, profiles, mcs_points, mcs_delayed_points, slides_points, ws1_current_actuals


# Compute fixed equal-axis limits based on all profile points with z <= zmax.
def compute_fixed_limits(profiles, zmax):
    xs_all: List[float] = []
    zs_all: List[float] = []

    for prof in profiles:
        for x, z in prof:
            if z <= zmax:
                xs_all.append(x)
                zs_all.append(z)

    if not xs_all:
        raise SystemExit("No points remain after z filtering.")

    xmin, xmax = min(xs_all), max(xs_all)
    zmin, zmax2 = min(zs_all), max(zs_all)

    xmid = 0.5 * (xmin + xmax)
    zmid = 0.5 * (zmin + zmax2)
    half_span = 0.5 * max(xmax - xmin, zmax2 - zmin)
    half_span *= 1.05  # padding

    return (xmid - half_span, xmid + half_span), (zmid - half_span, zmid + half_span)


# Python translation of WeldControlImpl::GetHybridGrooveMCS for 7-point grooves.
def hybrid_groove(current: List[Tuple[float, float]],
                  delayed: List[Tuple[float, float]]) -> Optional[List[Tuple[float, float]]]:
    if len(current) != 7 or len(delayed) != 7:
        return None

    idx = 0 if abs(current[0][1] - delayed[0][1]) < abs(current[6][1] - delayed[6][1]) else 6

    dx = current[idx][0] - delayed[idx][0]
    dy = current[idx][1] - delayed[idx][1]

    merged = list(current)
    for i in range(1, 6):
        merged[i] = (delayed[i][0] + dx, delayed[i][1] + dy)
    return merged


# --- Color mapping for weldSystems[1].current.actual ---
# 900 -> dark red, ... -> 500 -> dark blue; outside => black
_COLOR_STOPS_HEX = [
    "#8B0000",  # dark red
    "#FF0000",  # red
    "#FFA500",  # orange
    "#FFFF00",  # yellow
    "#00FF00",  # green
    "#006400",  # dark green
    "#ADD8E6",  # light blue
    "#0000FF",  # blue
    "#00008B",  # dark blue
]
_COLOR_STOPS_RGB = [mcolors.to_rgb(h) for h in _COLOR_STOPS_HEX]
_MIN_ACTUAL = 500.0
_MAX_ACTUAL = 900.0


def _interp_rgb(c0, c1, t: float):
    return (c0[0] + (c1[0] - c0[0]) * t,
            c0[1] + (c1[1] - c0[1]) * t,
            c0[2] + (c1[2] - c0[2]) * t)


def color_for_actual(val: Optional[float]):
    if not isinstance(val, (int, float)) or val < _MIN_ACTUAL or val > _MAX_ACTUAL:
        return "black"
    # Normalize so 900 -> 0.0 (dark red), 500 -> 1.0 (dark blue)
    t = (_MAX_ACTUAL - float(val)) / (_MAX_ACTUAL - _MIN_ACTUAL)
    n_seg = len(_COLOR_STOPS_RGB) - 1
    if t <= 0.0:
        return _COLOR_STOPS_RGB[0]
    if t >= 1.0:
        return _COLOR_STOPS_RGB[-1]
    pos = t * n_seg
    i = int(pos)
    f = pos - i
    c0 = _COLOR_STOPS_RGB[i]
    c1 = _COLOR_STOPS_RGB[i + 1]
    return _interp_rgb(c0, c1, f)


def main():
    ap = argparse.ArgumentParser(
        description="Simple interactive mcsProfile viewer. left/rigth to step one line ctrl+left/ctrl+right to step 10."
    )
    ap.add_argument("file", help="Input weldcontrol log file")
    ap.add_argument(
        "--zmax",
        type=float,
        default=ZMAX_DEFAULT,
        help="Do not plot points with z > zmax"
    )
    ap.add_argument(
        "--source",
        choices=["current", "delayed", "hybrid", "both"],
        default="current",
        help="Choose which MCS array to overlay (current, delayed, hybrid, or both)."
    )
    ap.add_argument(
        "--arcing",
        action="store_true",
        help='Include only records where weldSystems[1].state == "arcing"'
    )
    args = ap.parse_args()

    positions, profiles, mcs_points, mcs_delayed_points, slides_points, ws1_current_actuals = load_records(
        args.file, include_arcing_only=args.arcing
    )
    if not positions:
        raise SystemExit("No valid records found.")

    xlim, zlim = compute_fixed_limits(profiles, args.zmax)

    fig, ax = plt.subplots(figsize=(8, 5), dpi=120)
    current_index = 0

    # Keep a reference to the annotation to avoid duplicates on redraw
    value_ann = {"artist": None}

    def plot_current():
        ax.clear()
        value_ann["artist"] = None

        pos = positions[current_index]
        prof = profiles[current_index]
        mcs = mcs_points[current_index]
        mcs_del = mcs_delayed_points[current_index]
        slides_pt = slides_points[current_index]
        actual_val = ws1_current_actuals[current_index]

        # Plot mcsProfile
        prof_filtered = [(x, z) for (x, z) in prof if z <= args.zmax]
        if prof_filtered:
            xs = [p[0] for p in prof_filtered]
            zs = [p[1] for p in prof_filtered]
            ax.plot(xs, zs, marker="o", markersize=2, linewidth=1, label="mcsProfile")

        # Plot MCS overlay(s)
        label_for_title = args.source
        if args.source == "current":
            if mcs:
                ax.plot([p[0] for p in mcs], [p[1] for p in mcs],
                        marker="s", markersize=5, linestyle="--", label="current")
        elif args.source == "delayed":
            if mcs_del:
                ax.plot([p[0] for p in mcs_del], [p[1] for p in mcs_del],
                        marker="^", markersize=5, linestyle="--", label="delayed")
        elif args.source == "hybrid":
            merged = hybrid_groove(mcs, mcs_del)
            if merged is not None:
                ax.plot([p[0] for p in merged], [p[1] for p in merged],
                        marker="D", markersize=5, linestyle="--", label="hybrid")
            else:
                if mcs_del:
                    ax.plot([p[0] for p in mcs_del], [p[1] for p in mcs_del],
                            marker="^", markersize=5, linestyle="--", label="hybrid (fallback to delayed)")
                label_for_title = "hybrid (fallback)"
        else:  # both
            if mcs:
                ax.plot([p[0] for p in mcs], [p[1] for p in mcs],
                        marker="s", markersize=5, linestyle="--", label="current")
            if mcs_del:
                ax.plot([p[0] for p in mcs_del], [p[1] for p in mcs_del],
                        marker="^", markersize=5, linestyle="--", label="delayed")
            label_for_title = "both"

        # Always plot slides.actual if present, color by ws[1].current.actual, and annotate value
        if slides_pt is not None:
            color = color_for_actual(actual_val)
            ax.plot([slides_pt[0]], [slides_pt[1]],
                    marker="x", color=color, markersize=7, linestyle="None",
                    label="slides.actual")

            val_text = "n/a" if not isinstance(actual_val, (int, float)) else f"{actual_val:.1f}"
            value_ann["artist"] = ax.annotate(
                f"{val_text}",
                xy=(slides_pt[0], slides_pt[1]),
                xytext=(5, 8),  # pixel offset
                textcoords="offset points",
                fontsize=9,
                color=color,
                bbox=dict(boxstyle="round,pad=0.2", fc="white", ec=color, alpha=0.7)
            )

        ax.set_xlabel("x")
        ax.set_ylabel("z")
        title_val = "n/a" if not isinstance(actual_val, (int, float)) else f"{actual_val:.1f}"
        ax.set_title(
            f"Line {current_index+1}/{len(profiles)} | "
            f"Position: {pos:.3f} rad | MCS: {label_for_title} | ws[1].current.actual: {title_val}"
        )
        ax.grid(True)

        # Fixed equal scaling
        ax.set_xlim(*xlim)
        ax.set_ylim(*zlim)
        ax.set_aspect("equal", adjustable="box")

        # Deduplicate legend labels
        handles, labels = ax.get_legend_handles_labels()
        uniq = dict(zip(labels, handles))
        ax.legend(uniq.values(), uniq.keys())

        fig.canvas.draw_idle()

    def step(delta: int):
        nonlocal current_index
        current_index = max(0, min(len(profiles) - 1, current_index + delta))
        plot_current()

    def on_key(event):
        k = (event.key or "").lower()
        if k in ("right", "arrowright"):
            step(+1)
        elif k in ("left", "arrowleft"):
            step(-1)
        elif k in ("ctrl+right", "control+right", "ctrl+arrowright", "control+arrowright"):
            step(+10)
        elif k in ("ctrl+left", "control+left", "ctrl+arrowleft", "control+arrowleft"):
            step(-10)

    fig.canvas.mpl_connect("key_press_event", on_key)

    plot_current()
    plt.show()


if __name__ == "__main__":
    main()
