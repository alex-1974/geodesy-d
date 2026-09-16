#!/usr/bin/env python3
"""
Cross-check the analytic spherical Transverse Mercator oracle against:

  * PROJ `proj +proj=tmerc +R=...`
  * GeographicLib `TransverseMercatorProj -s -e R 0`

This validates the analytic oracle used by the geodesy-d sphere corpus.  It does
not call geodesy-d.

GeographicLib is the strict numerical oracle cross-check.  PROJ is an
independent compatibility/reference cross-check.  A narrowly scoped, versioned
exception is recorded for PROJ < 9.8.0 spherical-equator issue #4673; the
exception is accepted only when GeographicLib still independently agrees with
the analytic oracle.

Important details:
* GeographicLib's default geographic input order is latitude, longitude.
* GeographicLib's angle parser also accepts E/W hemisphere designators, so
  scientific notation such as "1e-09" is unsafe for geographic input.  Angles
  are therefore always emitted in fixed-point decimal form.
* Reverse comparisons use projected-space residuals in metres rather than raw
  longitude/latitude differences.  Longitude is ill-conditioned near the
  geographic poles, whereas the projected point remains well-conditioned for
  the validation purpose.
"""

from __future__ import annotations

import argparse
import math
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from typing import List, Sequence, Tuple


# This is an oracle/reference validation, not the public geodesy-d accuracy
# contract.  GeographicLib is the tight spherical reference.  PROJ is a
# secondary independent implementation whose documented tmerc accuracy is
# sub-millimetre through the range covered here, but whose inverse becomes less
# angularly stable extremely close to the poles.
GEOGRAPHICLIB_FORWARD_TARGET_M = 1.0e-6
PROJ_FORWARD_TARGET_M = 1.0e-4
PAIR_FORWARD_TARGET_M = 1.0e-4

GEOGRAPHICLIB_REVERSE_PROJECTED_TARGET_M = 1.0e-6
PROJ_REVERSE_PROJECTED_TARGET_M = 5.0e-2

RANDOM_SEED = 0x544D5F5350485246  # "TM_SPHRF"

# PROJ issue #4673 ("Transverse Mercator discrepancy at Equator") was
# fixed by commit ca23885da621269333eb00c5010e2ff2ac3423f0 and released
# in PROJ 9.8.0.  Earlier versions can produce a spurious spherical TM
# northing when cos(phi) rounds exactly to 1.0 because the forward path
# evaluates acos() of a value numerically just below 1.
PROJ_SPHERICAL_EQUATOR_FIX_VERSION = (9, 8, 0)


@dataclass(frozen=True)
class Profile:
    name: str
    radius: float
    lat0: float
    lon0: float
    k0: float
    fe: float
    fn: float


PROFILES: Sequence[Profile] = (
    Profile("Sphere-R6378137-equatorial",
            6378137.0, 0.0, 15.0, 1.0, 0.0, 0.0),
    Profile("Sphere-R6371000-OSGB-origin",
            6371000.0, 49.0, -2.0, 0.9996, 500000.0, -100000.0),
    Profile("Sphere-R6378137-antimeridian-north",
            6378137.0, -35.0, 179.75, 0.9999, -2.0, 3.0),
    Profile("Sphere-R6371000-high-north-origin",
            6371000.0, 80.0, -179.75, 1.1, 12742000.0, -12742000.0),
    Profile("Sphere-R6371000-high-south-origin",
            6371000.0, -80.0, 123.0, 0.9, -12742000.0, 12742000.0),
    Profile("Sphere-R6000000-profile-min",
            6000000.0, -35.0, 40.0, 0.9, -12000000.0, 12000000.0),
    Profile("Sphere-R7000000-profile-max",
            7000000.0, 35.0, -123.0, 1.1, 14000000.0, -14000000.0),
    Profile("Sphere-R6378137-UTM-like",
            6378137.0, 0.0, -123.0, 0.9996, 500000.0, 10000000.0),
)


def normalize_degrees(value: float) -> float:
    result = math.fmod(value + 180.0, 360.0)
    if result < 0.0:
        result += 360.0
    return result - 180.0


def normalize_radians(value: float) -> float:
    result = math.fmod(value + math.pi, 2.0 * math.pi)
    if result < 0.0:
        result += 2.0 * math.pi
    return result - math.pi


def angle_text(value: float) -> str:
    # Never use scientific notation for GeographicLib geographic input:
    # the DMS parser recognizes E/e as an east hemisphere designator.
    if value == 0.0:
        value = 0.0
    return f"{value:.17f}"


def number_text(value: float) -> str:
    return f"{value:.17g}"


def analytic_forward(
    profile: Profile,
    lat_deg: float,
    lon_deg: float,
) -> Tuple[float, float]:
    phi = math.radians(lat_deg)
    lam = normalize_radians(math.radians(lon_deg - profile.lon0))

    # Canonical exact public poles.
    if lat_deg == 90.0:
        return (
            profile.fe,
            profile.fn
            + profile.k0 * profile.radius
            * (math.pi / 2.0 - math.radians(profile.lat0)),
        )
    if lat_deg == -90.0:
        return (
            profile.fe,
            profile.fn
            + profile.k0 * profile.radius
            * (-math.pi / 2.0 - math.radians(profile.lat0)),
        )

    s = math.sin(phi)
    c = math.cos(phi)
    q = math.hypot(s, c * math.cos(lam))

    xi = math.atan2(s, c * math.cos(lam))
    eta = math.asinh(c * math.sin(lam) / q)

    e = profile.fe + profile.k0 * profile.radius * eta
    n = (
        profile.fn
        + profile.k0 * profile.radius
        * (xi - math.radians(profile.lat0))
    )
    return e, n


def run_command(args: Sequence[str], stdin_text: str) -> List[str]:
    result = subprocess.run(
        args,
        input=stdin_text,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(
            "command failed:\n"
            + " ".join(args)
            + "\nstdout:\n"
            + result.stdout
            + "\nstderr:\n"
            + result.stderr
        )

    lines = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    errors = [line for line in lines if line.startswith("ERROR:")]
    if errors:
        raise RuntimeError(
            "external reference emitted input errors:\n"
            + "\n".join(errors[:20])
        )
    return lines


def parse_two_floats(line: str) -> Tuple[float, float]:
    fields = line.replace("\t", " ").split()
    if len(fields) < 2:
        raise RuntimeError(
            f"expected at least two numeric fields, got: {line!r}"
        )
    try:
        return float(fields[0]), float(fields[1])
    except ValueError as exc:
        raise RuntimeError(
            f"cannot parse numeric output line: {line!r}"
        ) from exc


def parse_four_floats(
    line: str,
) -> Tuple[float, float, float, float]:
    fields = line.split()
    if len(fields) < 4:
        raise RuntimeError(
            f"expected at least four numeric fields, got: {line!r}"
        )
    try:
        values = tuple(float(x) for x in fields[:4])
    except ValueError as exc:
        raise RuntimeError(
            f"cannot parse GeographicLib output line: {line!r}"
        ) from exc
    return values  # type: ignore[return-value]


def proj_args(
    profile: Profile,
    inverse: bool = False,
) -> List[str]:
    args = ["proj"]
    if inverse:
        args.append("-I")

    args += [
        "-f", "%.17g",
        "+proj=tmerc",
        f"+R={number_text(profile.radius)}",
        f"+lat_0={number_text(profile.lat0)}",
        f"+lon_0={number_text(profile.lon0)}",
        f"+k_0={number_text(profile.k0)}",
        f"+x_0={number_text(profile.fe)}",
        f"+y_0={number_text(profile.fn)}",
    ]
    return args


def geographiclib_args(
    profile: Profile,
    inverse: bool = False,
) -> List[str]:
    args = [
        "TransverseMercatorProj",
        "-s",
        "-e", number_text(profile.radius), "0",
        "-l", number_text(profile.lon0),
        "-k", number_text(profile.k0),
        "-p", "12",
    ]
    if inverse:
        args.append("-r")
    return args


def proj_forward(
    profile: Profile,
    points: Sequence[Tuple[float, float]],
) -> List[Tuple[float, float]]:
    # proj expects longitude, latitude unless -r is supplied.
    input_text = "".join(
        f"{angle_text(lon)} {angle_text(lat)}\n"
        for lat, lon in points
    )
    lines = run_command(proj_args(profile), input_text)
    if len(lines) != len(points):
        raise RuntimeError(
            f"PROJ returned {len(lines)} lines for {len(points)} points"
        )
    return [parse_two_floats(line) for line in lines]


def proj_reverse(
    profile: Profile,
    projected: Sequence[Tuple[float, float]],
) -> List[Tuple[float, float]]:
    input_text = "".join(
        f"{number_text(e)} {number_text(n)}\n"
        for e, n in projected
    )
    lines = run_command(proj_args(profile, inverse=True), input_text)
    if len(lines) != len(projected):
        raise RuntimeError(
            "PROJ inverse returned "
            f"{len(lines)} lines for {len(projected)} points"
        )

    result = []
    # proj inverse output is longitude, latitude.
    for line in lines:
        lon, lat = parse_two_floats(line)
        result.append((lat, normalize_degrees(lon)))
    return result


def geographiclib_origin_y(profile: Profile) -> float:
    lines = run_command(
        geographiclib_args(profile),
        f"{angle_text(profile.lat0)} {angle_text(profile.lon0)}\n",
    )
    if len(lines) != 1:
        raise RuntimeError(
            "unexpected GeographicLib origin output count"
        )
    _, y, _, _ = parse_four_floats(lines[0])
    return y


def geographiclib_forward(
    profile: Profile,
    points: Sequence[Tuple[float, float]],
) -> List[Tuple[float, float]]:
    origin_y = geographiclib_origin_y(profile)

    # GeographicLib defaults to latitude, longitude.  Fixed-point formatting is
    # intentional; scientific notation is unsafe for its geographic parser.
    input_text = "".join(
        f"{angle_text(lat)} {angle_text(lon)}\n"
        for lat, lon in points
    )
    lines = run_command(
        geographiclib_args(profile),
        input_text,
    )
    if len(lines) != len(points):
        raise RuntimeError(
            "GeographicLib returned "
            f"{len(lines)} lines for {len(points)} points"
        )

    result = []
    for line in lines:
        x, y, _, _ = parse_four_floats(line)
        result.append(
            (
                profile.fe + x,
                profile.fn + (y - origin_y),
            )
        )
    return result


def geographiclib_reverse(
    profile: Profile,
    projected: Sequence[Tuple[float, float]],
) -> List[Tuple[float, float]]:
    origin_y = geographiclib_origin_y(profile)

    # Undo arbitrary latitude-of-origin and false-offset translation before
    # giving x/y to GeographicLib's equatorial-origin TM.
    input_text = "".join(
        f"{number_text(e - profile.fe)} "
        f"{number_text(n - profile.fn + origin_y)}\n"
        for e, n in projected
    )
    lines = run_command(
        geographiclib_args(profile, inverse=True),
        input_text,
    )
    if len(lines) != len(projected):
        raise RuntimeError(
            "GeographicLib inverse returned "
            f"{len(lines)} lines for {len(projected)} points"
        )

    result = []
    for line in lines:
        lat, lon, _, _ = parse_four_floats(line)
        result.append((lat, normalize_degrees(lon)))
    return result


def structured_delta_points() -> List[Tuple[float, float]]:
    latitudes = (
        -90.0,
        -89.999999,
        -89.999,
        -89.0,
        -85.0,
        -80.0,
        -65.0,
        -45.0,
        -1.0e-9,
        -0.0,
        0.0,
        1.0e-9,
        45.0,
        65.0,
        80.0,
        85.0,
        89.0,
        89.999,
        89.999999,
        90.0,
    )
    deltas = (
        -60.0,
        -59.999999,
        -45.0,
        -10.2,
        -3.0,
        -1.0e-9,
        0.0,
        1.0e-9,
        3.0,
        10.2,
        45.0,
        59.999999,
        60.0,
    )

    return [
        (lat, delta)
        for lat in latitudes
        for delta in deltas
    ]


class SplitMix64:
    def __init__(self, seed: int):
        self.state = seed & 0xFFFFFFFFFFFFFFFF

    def next_u64(self) -> int:
        self.state = (
            self.state + 0x9E3779B97F4A7C15
        ) & 0xFFFFFFFFFFFFFFFF
        z = self.state
        z = (
            (z ^ (z >> 30))
            * 0xBF58476D1CE4E5B9
        ) & 0xFFFFFFFFFFFFFFFF
        z = (
            (z ^ (z >> 27))
            * 0x94D049BB133111EB
        ) & 0xFFFFFFFFFFFFFFFF
        return z ^ (z >> 31)

    def unit(self) -> float:
        return (
            (self.next_u64() >> 11)
            * (1.0 / (1 << 53))
        )


def random_delta_points(
    count: int,
) -> List[Tuple[float, float]]:
    rng = SplitMix64(RANDOM_SEED)
    result = []

    for _ in range(count):
        lat = (
            -89.999999
            + 179.999998 * rng.unit()
        )
        delta = -60.0 + 120.0 * rng.unit()
        result.append((lat, delta))

    return result


@dataclass
class Worst:
    value: float = 0.0
    label: str = ""

    def update(
        self,
        value: float,
        label: str,
    ) -> None:
        if not math.isfinite(value):
            raise RuntimeError(
                f"non-finite error for {label}: {value}"
            )
        if value > self.value:
            self.value = value
            self.label = label


@dataclass
class Metrics:
    oracle_proj_forward: Worst
    oracle_geo_forward: Worst
    proj_geo_forward: Worst
    proj_reverse_projected: Worst
    geo_reverse_projected: Worst

    proj_forward_failures: int = 0
    geo_forward_failures: int = 0
    pair_forward_failures: int = 0
    proj_reverse_failures: int = 0
    geo_reverse_failures: int = 0

    # Version-bounded external-reference limitation, not an oracle failure.
    proj_known_spherical_equator_deviations: int = 0


def make_metrics() -> Metrics:
    return Metrics(
        Worst(),
        Worst(),
        Worst(),
        Worst(),
        Worst(),
    )


def maybe_print_failure(
    count: int,
    kind: str,
    label: str,
    value: float,
    target: float,
) -> None:
    if count <= 12:
        print(
            f"{kind}: {label} "
            f"error={value:.12g} m "
            f"target={target:.12g} m"
        )


def validate_profile(
    profile: Profile,
    delta_points: Sequence[Tuple[float, float]],
    mode_label: str,
    metrics: Metrics,
    proj_version: Tuple[int, int, int] | None,
) -> None:
    points = [
        (
            lat,
            normalize_degrees(profile.lon0 + delta),
        )
        for lat, delta in delta_points
    ]

    oracle_xy = [
        analytic_forward(profile, lat, lon)
        for lat, lon in points
    ]
    proj_xy = proj_forward(profile, points)
    geo_xy = geographiclib_forward(
        profile,
        points,
    )

    proj_ll = proj_reverse(
        profile,
        oracle_xy,
    )
    geo_ll = geographiclib_reverse(
        profile,
        oracle_xy,
    )

    for i, (
        (lat, lon),
        (oe, on),
        (pe, pn),
        (ge, gn),
        (plat, plon),
        (glat, glon),
    ) in enumerate(
        zip(
            points,
            oracle_xy,
            proj_xy,
            geo_xy,
            proj_ll,
            geo_ll,
        )
    ):
        label = (
            f"{profile.name} {mode_label}[{i}] "
            f"lat={lat:.12f} lon={lon:.12f}"
        )

        oracle_proj = math.hypot(
            oe - pe,
            on - pn,
        )
        oracle_geo = math.hypot(
            oe - ge,
            on - gn,
        )
        proj_geo = math.hypot(
            pe - ge,
            pn - gn,
        )

        metrics.oracle_proj_forward.update(
            oracle_proj,
            label,
        )
        metrics.oracle_geo_forward.update(
            oracle_geo,
            label,
        )
        metrics.proj_geo_forward.update(
            proj_geo,
            label,
        )

        known_legacy_proj_equator_case = (
            is_known_legacy_proj_spherical_equator_case(
                proj_version,
                lat,
            )
            and oracle_geo <= GEOGRAPHICLIB_FORWARD_TARGET_M
        )

        if oracle_proj > PROJ_FORWARD_TARGET_M:
            if known_legacy_proj_equator_case:
                metrics.proj_known_spherical_equator_deviations += 1
                maybe_print_failure(
                    metrics.proj_known_spherical_equator_deviations,
                    "KNOWN PROJ <9.8.0 SPHERICAL EQUATOR DEVIATION",
                    label,
                    oracle_proj,
                    PROJ_FORWARD_TARGET_M,
                )
            else:
                metrics.proj_forward_failures += 1
                maybe_print_failure(
                    metrics.proj_forward_failures,
                    "PROJ FORWARD OUTSIDE TARGET",
                    label,
                    oracle_proj,
                    PROJ_FORWARD_TARGET_M,
                )

        if oracle_geo > GEOGRAPHICLIB_FORWARD_TARGET_M:
            metrics.geo_forward_failures += 1
            maybe_print_failure(
                metrics.geo_forward_failures,
                "GEOGRAPHICLIB FORWARD OUTSIDE TARGET",
                label,
                oracle_geo,
                GEOGRAPHICLIB_FORWARD_TARGET_M,
            )

        if proj_geo > PAIR_FORWARD_TARGET_M:
            if not known_legacy_proj_equator_case:
                metrics.pair_forward_failures += 1
                maybe_print_failure(
                    metrics.pair_forward_failures,
                    "PROJ/GEOGRAPHICLIB FORWARD OUTSIDE TARGET",
                    label,
                    proj_geo,
                    PAIR_FORWARD_TARGET_M,
                )

        proj_roundtrip = analytic_forward(
            profile,
            plat,
            plon,
        )
        geo_roundtrip = analytic_forward(
            profile,
            glat,
            glon,
        )

        proj_reverse_residual = math.hypot(
            proj_roundtrip[0] - oe,
            proj_roundtrip[1] - on,
        )
        geo_reverse_residual = math.hypot(
            geo_roundtrip[0] - oe,
            geo_roundtrip[1] - on,
        )

        metrics.proj_reverse_projected.update(
            proj_reverse_residual,
            label,
        )
        metrics.geo_reverse_projected.update(
            geo_reverse_residual,
            label,
        )

        if (
            proj_reverse_residual
            > PROJ_REVERSE_PROJECTED_TARGET_M
        ):
            metrics.proj_reverse_failures += 1
            maybe_print_failure(
                metrics.proj_reverse_failures,
                "PROJ REVERSE OUTSIDE TARGET",
                label,
                proj_reverse_residual,
                PROJ_REVERSE_PROJECTED_TARGET_M,
            )

        if (
            geo_reverse_residual
            > GEOGRAPHICLIB_REVERSE_PROJECTED_TARGET_M
        ):
            metrics.geo_reverse_failures += 1
            maybe_print_failure(
                metrics.geo_reverse_failures,
                "GEOGRAPHICLIB REVERSE OUTSIDE TARGET",
                label,
                geo_reverse_residual,
                GEOGRAPHICLIB_REVERSE_PROJECTED_TARGET_M,
            )


def parse_proj_version(version_line: str) -> Tuple[int, int, int] | None:
    match = re.search(r"(\d+)\.(\d+)\.(\d+)", version_line)
    if match is None:
        return None
    return tuple(int(part) for part in match.groups())


def is_known_legacy_proj_spherical_equator_case(
    proj_version: Tuple[int, int, int] | None,
    latitude_degrees: float,
) -> bool:
    if proj_version is None:
        return False
    if proj_version >= PROJ_SPHERICAL_EQUATOR_FIX_VERSION:
        return False

    # This mirrors the branch condition in the affected PROJ spherical tmerc
    # implementation: cos(phi) rounds exactly to 1.0 in binary64.
    return math.cos(math.radians(latitude_degrees)) == 1.0


def tool_version_lines() -> Tuple[str, str]:
    proj_result = subprocess.run(
        ["proj"],
        input="",
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    proj_line = (
        proj_result.stderr.splitlines()[0]
        if proj_result.stderr.splitlines()
        else "(unknown)"
    )

    geographiclib_result = subprocess.run(
        ["TransverseMercatorProj", "--version"],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    geographiclib_line = (
        geographiclib_result.stdout
        or geographiclib_result.stderr
    ).strip()

    return proj_line, geographiclib_line


def main() -> int:
    parser = argparse.ArgumentParser()

    group = parser.add_mutually_exclusive_group(
        required=True
    )
    group.add_argument(
        "--structured",
        action="store_true",
    )
    group.add_argument(
        "--random",
        type=int,
        metavar="COUNT",
    )

    args = parser.parse_args()

    missing = [
        tool
        for tool in (
            "proj",
            "TransverseMercatorProj",
        )
        if shutil.which(tool) is None
    ]
    if missing:
        print(
            "ERROR: missing required external tool(s): "
            + ", ".join(missing),
            file=sys.stderr,
        )
        return 2

    if args.structured:
        delta_points = structured_delta_points()
        mode_label = "structured"
    else:
        if args.random is None or args.random <= 0:
            parser.error(
                "--random COUNT requires COUNT > 0"
            )
        delta_points = random_delta_points(
            args.random
        )
        mode_label = "random"

    metrics = make_metrics()

    proj_version_line, geographiclib_version = (
        tool_version_lines()
    )
    proj_version = parse_proj_version(proj_version_line)

    print(
        "analytic spherical TM oracle "
        "external cross-check"
    )
    print("PROJ:", proj_version_line)
    print(
        "GeographicLib:",
        geographiclib_version,
    )
    if not args.structured:
        print(
            "random seed: "
            f"0x{RANDOM_SEED:016X}"
        )

    total = 0

    for profile in PROFILES:
        validate_profile(
            profile,
            delta_points,
            mode_label,
            metrics,
            proj_version,
        )
        total += len(delta_points)

        print(
            f"completed {profile.name}: "
            f"{len(delta_points)} points"
        )

    total_failures = (
        metrics.proj_forward_failures
        + metrics.geo_forward_failures
        + metrics.pair_forward_failures
        + metrics.proj_reverse_failures
        + metrics.geo_reverse_failures
    )

    print()
    print(
        "suite:",
        f"{mode_label} spherical oracle "
        "vs PROJ + GeographicLib series",
    )
    print("profiles:", len(PROFILES))
    print("source points:", total)

    print()
    print("forward targets:")
    print(
        "  oracle vs GeographicLib:",
        f"{GEOGRAPHICLIB_FORWARD_TARGET_M:.12g} m",
    )
    print(
        "  oracle vs PROJ:",
        f"{PROJ_FORWARD_TARGET_M:.12g} m",
    )
    print(
        "  PROJ vs GeographicLib:",
        f"{PAIR_FORWARD_TARGET_M:.12g} m",
    )

    print("reverse projected-space targets:")
    print(
        "  GeographicLib:",
        f"{GEOGRAPHICLIB_REVERSE_PROJECTED_TARGET_M:.12g} m",
    )
    print(
        "  PROJ:",
        f"{PROJ_REVERSE_PROJECTED_TARGET_M:.12g} m",
    )

    print()
    print("failure counts:")
    print(
        "  PROJ forward:",
        metrics.proj_forward_failures,
    )
    print(
        "  GeographicLib forward:",
        metrics.geo_forward_failures,
    )
    print(
        "  PROJ/GeographicLib forward pair:",
        metrics.pair_forward_failures,
    )
    print(
        "  PROJ reverse:",
        metrics.proj_reverse_failures,
    )
    print(
        "  GeographicLib reverse:",
        metrics.geo_reverse_failures,
    )
    print(
        "  known PROJ <9.8.0 spherical-equator deviations:",
        metrics.proj_known_spherical_equator_deviations,
    )
    print("  gating total:", total_failures)

    if metrics.proj_known_spherical_equator_deviations:
        print()
        print(
            "note: these PROJ deviations match upstream issue #4673, "
            "fixed in PROJ 9.8.0; they are reported but do not fail "
            "the oracle gate because GeographicLib independently "
            "matches the analytic oracle within its strict target."
        )

    print()
    print(
        "worst oracle vs PROJ forward:",
        f"{metrics.oracle_proj_forward.value:.12g} m",
    )
    print(
        "  case:",
        metrics.oracle_proj_forward.label,
    )

    print(
        "worst oracle vs GeographicLib forward:",
        f"{metrics.oracle_geo_forward.value:.12g} m",
    )
    print(
        "  case:",
        metrics.oracle_geo_forward.label,
    )

    print(
        "worst PROJ vs GeographicLib forward:",
        f"{metrics.proj_geo_forward.value:.12g} m",
    )
    print(
        "  case:",
        metrics.proj_geo_forward.label,
    )

    print(
        "worst PROJ reverse projected residual:",
        f"{metrics.proj_reverse_projected.value:.12g} m",
    )
    print(
        "  case:",
        metrics.proj_reverse_projected.label,
    )

    print(
        "worst GeographicLib reverse "
        "projected residual:",
        f"{metrics.geo_reverse_projected.value:.12g} m",
    )
    print(
        "  case:",
        metrics.geo_reverse_projected.label,
    )

    print(
        "RESULT:",
        "PASS" if total_failures == 0 else "FAIL",
    )

    return 0 if total_failures == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
