#!/bin/bash
# A shipping-quote service with a year of history. Every carrier rule lands in
# rates/quote.py's quote(), one long function nested six deep, which changes in
# 31 of the 35 commits; the other modules are small and change rarely.
# Each commit writes every file at its step: a line ending in "#@N" exists from
# step N on, and one ending in "#@N-M" from step N until step M.
set -euo pipefail
git init -q -b main
git config user.name "Priya Natarajan"
git config user.email "priya@example.com"
now=$(date +%s)
mkdir -p rates tests

reveal() { # <step> <file>, the marked text on stdin
	awk -v k="$1" '
	match($0, / +#@[0-9]+(-[0-9]+)?$/) {
		m = substr($0, RSTART); sub(/^ +#@/, "", m); line = substr($0, 1, RSTART - 1)
		n = split(m, r, "-"); if (k + 0 >= r[1] + 0 && (n == 1 || k + 0 < r[2] + 0)) print line
		next
	}
	{ print }' > "$2"
}

commit() { # <step> <days ago> <who> <message>
	local ts=$((now - $2 * 86400 - 3600 * ($2 % 7))) name email
	case $3 in
	priya) name="Priya Natarajan" email=priya@example.com ;;
	jonas) name="Jonas Weber" email=jonas@example.com ;;
	marta) name="Marta Silva" email=marta@example.com ;;
	esac
	printf '%s' "$QUOTE" | reveal "$1" rates/quote.py
	printf '%s' "$MODELS" | reveal "$1" rates/models.py
	printf '%s' "$ZONES" | reveal "$1" rates/zones.py
	printf '%s' "$API" | reveal "$1" rates/api.py
	printf '%s' "$ZONETESTS" | reveal "$1" tests/test_zones.py
	printf '%s' "$README" | reveal "$1" README.md
	printf '%s' "$PYPROJECT" | reveal "$1" pyproject.toml
	git add -A
	GIT_AUTHOR_NAME=$name GIT_AUTHOR_EMAIL=$email GIT_COMMITTER_NAME=$name GIT_COMMITTER_EMAIL=$email \
		GIT_AUTHOR_DATE="$ts +0000" GIT_COMMITTER_DATE="$ts +0000" git commit -qm "$4"
}

IFS= read -r -d '' QUOTE <<'PY' || true
"""Shipping quotes: prices a shipment with each carrier's rate card."""

from decimal import ROUND_HALF_UP, Decimal

from rates.models import Quote, QuoteError
from rates.zones import is_remote, zone_for  #@8
from rates.zones import zone_for  #@1-8

CENT = Decimal("0.01")
DIM_DIVISOR = {"ups": 5000, "fedex": 5000}  #@1-4
DIM_DIVISOR = {"ups": 5000, "fedex": 5000, "dhl": 5000}  #@4-10
DIM_DIVISOR = {"ups": 5000, "fedex": 5000, "dhl": 5000, "postnord": 6000}  #@10
MAX_FUEL_PCT = Decimal(25)  #@30


def billable_weight(parcel, divisor):
    """The greater of the actual and the dimensional weight, in kg."""
    volume = parcel.length_cm * parcel.width_cm * parcel.height_cm
    return max(parcel.weight_kg, Decimal(volume) / divisor)


def quote(shipment, cards, today):
    """Return a Quote for each carrier that can take the whole shipment, cheapest first."""
    quotes = []
    for carrier, card in sorted(cards.items()):
        total = Decimal(0)
        notes = []
        rejected = None
        zone = zone_for(carrier, shipment.origin, shipment.destination)
        if zone is None:
            raise QuoteError(f"{carrier} has no zone for this route")  #@1-33
            continue  #@33
        for parcel in shipment.parcels:
            weight = billable_weight(parcel, DIM_DIVISOR.get(carrier, 5000))
            if carrier == "ups":
                if weight > 70:
                    rejected = "UPS takes parcels up to 70 kg"
                    break
                price = card.base[zone] + card.per_kg[zone] * weight
                if parcel.length_cm > 274:  #@2
                    rejected = "UPS takes parcels up to 274 cm long"  #@2
                    break  #@2
                elif parcel.length_cm > 122:  #@7-35
                elif parcel.length_cm > 122 or weight > 32:  #@35
                    price += card.surcharge["additional_handling"]  #@7
                    notes.append("additional handling")  #@7
                if parcel.length_cm + 2 * (parcel.width_cm + parcel.height_cm) > 300:  #@24
                    price += card.surcharge["large_package"]  #@24
                    notes.append("large package")  #@24
                if shipment.saturday:  #@19
                    price += card.surcharge["saturday"]  #@19
            elif carrier == "fedex":
                if weight > 70:  #@1-16
                if weight > 68:  #@16
                    rejected = "FedEx takes parcels up to 70 kg"  #@1-16
                    rejected = "FedEx takes parcels up to 68 kg"  #@16
                    break
                price = card.base[zone] + card.per_kg[zone] * weight  #@1-27
                if parcel.envelope and zone != "world":  #@27
                    price = card.base["one_rate_envelope"]  #@27
                else:  #@27
                    price = card.base[zone] + card.per_kg[zone] * weight  #@27
                if parcel.length_cm > 122:  #@6
                    price += card.surcharge["additional_handling"]  #@6
                    notes.append("additional handling")  #@6
                if parcel.dangerous_goods:  #@25
                    price += card.surcharge["dangerous_goods"]  #@25
                    notes.append("dangerous goods")  #@25
            elif carrier == "dhl":  #@4
                if shipment.destination.country != shipment.origin.country:  #@5
                    if shipment.customs_value is None:  #@5
                        rejected = "DHL needs a customs value for international shipments"  #@5
                        break  #@5
                    if shipment.customs_value > 2500:  #@14
                        if not shipment.eori:  #@14
                            rejected = "DHL needs an EORI number above 2500 customs value"  #@14
                            break  #@14
                if weight > 70:  #@4
                    rejected = "DHL takes parcels up to 70 kg"  #@4
                    break  #@4
                price = card.base[zone] + card.per_kg[zone] * weight  #@4
                if parcel.dangerous_goods:  #@25
                    if zone == "world":  #@25
                        rejected = "DHL doesn't fly dangerous goods outside the EU"  #@25
                        break  #@25
                    price += card.surcharge["dangerous_goods"]  #@25
                    notes.append("dangerous goods")  #@25
                if shipment.saturday:  #@19
                    if is_remote(shipment.destination):  #@32
                        rejected = "DHL has no Saturday delivery to remote areas"  #@32
                        break  #@32
                    price += card.surcharge["saturday"]  #@19
            elif carrier == "postnord":  #@9
                if parcel.dangerous_goods:  #@26
                    rejected = "PostNord doesn't take dangerous goods"  #@26
                    break  #@26
                if weight > 20:  #@9
                    rejected = "PostNord takes parcels up to 20 kg"  #@9
                    break  #@9
                if parcel.length_cm > 150:  #@22
                    rejected = "PostNord takes parcels up to 150 cm long"  #@22
                    break  #@22
                price = card.base[zone] + card.per_kg[zone] * weight  #@9
            else:
                raise QuoteError(f"no pricing rules for {carrier}")
            if shipment.destination.residential:  #@3-29
            if shipment.destination.residential and not parcel.envelope:  #@29
                price += card.surcharge["residential"]  #@3
                if today.month == 12:  #@13
                    price += card.surcharge["peak_residential"]  #@13
                    notes.append("peak season")  #@13
            if is_remote(shipment.destination):  #@8
                if carrier in ("ups", "fedex"):  #@8
                    price += card.surcharge["remote_area"]  #@8
                elif carrier == "dhl":  #@20
                    price += card.surcharge["remote_area_per_kg"] * weight  #@20
                elif carrier == "postnord":  #@18
                    if shipment.destination.country != "SE":  #@18
                        price += card.surcharge["remote_area"]  #@18
            total += price
        if rejected:
            continue
        if shipment.insured_value and shipment.insured_value > 500:  #@12
            premium = (shipment.insured_value - 500) / 100  #@12-34
            premium = ((shipment.insured_value - 500) / 100).quantize(CENT, ROUND_HALF_UP)  #@34
            premium = max(premium, card.surcharge["insurance_minimum"])  #@28
            total += premium  #@12
            notes.append("insured")  #@12
        fuel = card.fuel_pct.get(today.month, card.default_fuel_pct)  #@1-15
        fuel = card.fuel_pct.get(today.strftime("%Y-%m"), card.default_fuel_pct)  #@15
        fuel = min(fuel, MAX_FUEL_PCT)  #@30
        total += total * fuel / 100
        quotes.append(Quote(carrier, total.quantize(CENT, ROUND_HALF_UP), zone, notes))
    return sorted(quotes, key=lambda q: q.price)  #@1-21
    return sorted(quotes, key=lambda q: (q.price, q.carrier))  #@21
PY

IFS= read -r -d '' MODELS <<'PY' || true
"""Shipments, parcels, rate cards and quotes."""

from dataclasses import dataclass, field
from decimal import Decimal


class QuoteError(Exception):
    """A shipment can't be priced with the rate cards we have."""


@dataclass(frozen=True)
class Address:
    country: str
    postcode: str
    residential: bool = False


@dataclass(frozen=True)
class Parcel:
    weight_kg: Decimal
    length_cm: int
    width_cm: int
    height_cm: int
    dangerous_goods: bool = False  #@25
    envelope: bool = False  #@27


@dataclass(frozen=True)
class Shipment:
    origin: Address
    destination: Address
    parcels: tuple
    customs_value: Decimal | None = None
    eori: str | None = None
    insured_value: Decimal | None = None
    saturday: bool = False


@dataclass(frozen=True)
class RateCard:
    """One carrier's prices: base and per-kg prices by zone, named surcharges, fuel by month."""

    base: dict
    per_kg: dict
    surcharge: dict
    fuel_pct: dict = field(default_factory=dict)
    default_fuel_pct: Decimal = Decimal(0)


@dataclass(frozen=True)
class Quote:
    carrier: str
    price: Decimal
    zone: str
    notes: list
PY

IFS= read -r -d '' ZONES <<'PY' || true
"""Which pricing zone a route falls in, per carrier."""

NORDICS = {"DK", "FI", "NO", "SE"}  #@9
EU = {"AT", "BE", "DE", "DK", "ES", "FI", "FR", "IE", "IT", "NL", "PL", "PT", "SE"}
REMOTE_PREFIXES = {  #@8
    "FI": ("96", "97", "98", "99"),  #@8
    "GB": ("HS", "KW15", "KW16", "KW17", "ZE"),  #@8
    "NO": ("90", "91", "92", "93", "94", "95", "96", "97", "98", "99"),  #@8
    "SE": ("93", "94", "95", "96", "97", "98"),  #@8
}  #@8


def zone_for(carrier, origin, destination):
    """Return the carrier's zone for the route, or None when the carrier doesn't serve it."""
    if carrier == "postnord" and (origin.country not in NORDICS or destination.country not in NORDICS):  #@9
        return None  #@9
    if origin.country == destination.country:
        return "domestic"
    if origin.country in EU and destination.country in EU:
        return "eu"
    return "world"
  #@8
  #@8
def is_remote(address):  #@8
    """Whether carriers charge extra to reach the address."""  #@8
    prefixes = REMOTE_PREFIXES.get(address.country, ())  #@8
    return address.postcode.replace(" ", "").upper().startswith(prefixes)  #@8
PY

IFS= read -r -d '' API <<'PY' || true
"""POST /quotes: a shipment in, a price per carrier out."""

import json
import logging  #@17
from datetime import date
from decimal import Decimal, InvalidOperation
from http.server import BaseHTTPRequestHandler

from rates.models import Address, Parcel, QuoteError, Shipment
from rates.quote import quote

log = logging.getLogger(__name__)  #@17


class BadRequest(Exception):
    pass


def _number(raw, name, required=True):
    if raw is None and not required:
        return None
    try:
        return Decimal(str(raw))
    except (InvalidOperation, ValueError):
        raise BadRequest(f"{name} must be a number") from None


def _address(raw, name):
    if not isinstance(raw, dict) or not isinstance(raw.get("country"), str) or not isinstance(raw.get("postcode"), str):
        raise BadRequest(f"{name} needs a country and a postcode")
    return Address(raw["country"].upper(), raw["postcode"], raw.get("residential") is True)


def _parcel(raw, i):
    if not isinstance(raw, dict):
        raise BadRequest(f"parcel {i} must be an object")
    return Parcel(
        weight_kg=_number(raw.get("weight_kg"), f"parcel {i} weight_kg"),
        length_cm=int(_number(raw.get("length_cm"), f"parcel {i} length_cm")),
        width_cm=int(_number(raw.get("width_cm"), f"parcel {i} width_cm")),
        height_cm=int(_number(raw.get("height_cm"), f"parcel {i} height_cm")),
        dangerous_goods=raw.get("dangerous_goods") is True,  #@25
        envelope=raw.get("envelope") is True,  #@27
    )


def parse_shipment(body):
    try:
        raw = json.loads(body)
    except json.JSONDecodeError:
        raise BadRequest("the body is not JSON") from None
    if not isinstance(raw, dict) or not isinstance(raw.get("parcels"), list) or not raw["parcels"]:
        raise BadRequest("a shipment needs at least one parcel")
    eori = raw.get("eori")
    if eori is not None and not isinstance(eori, str):
        raise BadRequest("eori must be a string")
    return Shipment(
        origin=_address(raw.get("origin"), "origin"),
        destination=_address(raw.get("destination"), "destination"),
        parcels=tuple(_parcel(p, i) for i, p in enumerate(raw["parcels"])),
        customs_value=_number(raw.get("customs_value"), "customs_value", required=False),
        eori=eori,
        insured_value=_number(raw.get("insured_value"), "insured_value", required=False),
        saturday=raw.get("saturday") is True,
    )


class QuoteHandler(BaseHTTPRequestHandler):
    cards = {}

    def do_POST(self):
        if self.path != "/quotes":
            self.send_error(404)
            return
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        try:
            shipment = parse_shipment(body)
            quotes = quote(shipment, self.cards, date.today())
        except (BadRequest, QuoteError) as e:
            log.info("quote rejected: %s", e)  #@17
            self.send_error(400, str(e))
            return
        log.info("quoted %d carriers for %s", len(quotes), shipment.destination.country)  #@17
        out = [{"carrier": q.carrier, "price": str(q.price), "zone": q.zone, "notes": q.notes} for q in quotes]
        payload = json.dumps(out).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)
PY

IFS= read -r -d '' ZONETESTS <<'PY' || true
import unittest

from rates.models import Address
from rates.zones import zone_for


class ZoneTest(unittest.TestCase):
    def test_domestic(self):
        self.assertEqual(zone_for("ups", Address("DE", "10115"), Address("DE", "80331")), "domestic")

    def test_eu(self):
        self.assertEqual(zone_for("dhl", Address("DE", "10115"), Address("FR", "75001")), "eu")

    def test_world(self):
        self.assertEqual(zone_for("fedex", Address("DE", "10115"), Address("US", "10001")), "world")
  #@11
    def test_postnord_serves_nordic_routes_only(self):  #@11
        self.assertEqual(zone_for("postnord", Address("SE", "11122"), Address("NO", "0150")), "world")  #@11
        self.assertIsNone(zone_for("postnord", Address("SE", "11122"), Address("DE", "10115")))  #@11


if __name__ == "__main__":
    unittest.main()
PY

IFS= read -r -d '' README <<'MD' || true
# parcelrate

Prices a shipment with every carrier we have a rate card for, cheapest first.

    POST /quotes
    {"origin": {"country": "DE", "postcode": "10115"},
     "destination": {"country": "FR", "postcode": "75001", "residential": true},
     "parcels": [{"weight_kg": 2.5, "length_cm": 40, "width_cm": 30, "height_cm": 20}]}

Each carrier's pricing rules live in `rates/quote.py`.

## Running it locally  #@31
  #@31
Python 3.11 or later, standard library only:  #@31
  #@31
    python3 -m unittest discover -s tests  #@31
MD

IFS= read -r -d '' PYPROJECT <<'TOML' || true
[project]
name = "parcelrate"
version = "1.0.0"
requires-python = ">=3.11"  #@1-23
requires-python = ">=3.12"  #@23
TOML

commit 1 340 priya "Quote shipments with UPS and FedEx rate cards"
commit 2 331 priya "Reject UPS parcels over the length limit"
commit 3 322 jonas "Residential delivery surcharge"
commit 4 314 jonas "Add DHL Express"
commit 5 305 jonas "DHL: international shipments need a customs value"
commit 6 297 priya "FedEx additional handling over 122 cm"
commit 7 290 priya "UPS additional handling over 122 cm"
commit 8 281 marta "Remote area surcharge for UPS and FedEx"
commit 9 270 marta "Add PostNord"
commit 10 265 marta "PostNord prices dimensional weight with a 6000 divisor"
commit 11 258 jonas "Test zone lookup for Nordic routes"
commit 12 250 priya "Insure declared value above 500"
commit 13 241 jonas "December peak surcharge for residential deliveries"
commit 14 233 jonas "DHL: EORI number required above 2500 customs value"
commit 15 226 marta "Fix fuel surcharge lookup by month"
commit 16 219 priya "FedEx weight limit is 68 kg"
commit 17 212 marta "Log quote requests"
commit 18 204 marta "PostNord: no remote area surcharge inside Sweden"
commit 19 195 jonas "Saturday delivery for UPS and DHL"
commit 20 187 jonas "DHL remote area surcharge is charged per kg"
commit 21 176 priya "Sort quotes by price, then carrier"
commit 22 168 priya "PostNord: reject parcels over 150 cm"
commit 23 160 marta "Require Python 3.12"
commit 24 151 marta "UPS large package surcharge"
commit 25 140 jonas "Dangerous goods with FedEx and DHL"
commit 26 133 jonas "PostNord doesn't take dangerous goods"
commit 27 121 priya "FedEx One Rate envelopes"
commit 28 110 priya "Minimum insurance charge"
commit 29 96 marta "No residential surcharge on envelopes"
commit 30 82 marta "Cap fuel surcharge at 25%"
commit 31 70 jonas "README: how to run the tests"
commit 32 54 jonas "DHL: no Saturday delivery to remote areas"
commit 33 33 priya "Skip carriers that don't serve the route instead of failing the quote"
commit 34 19 priya "Round the insurance premium to the cent"
commit 35 6 marta "UPS additional handling also applies over 32 kg"
