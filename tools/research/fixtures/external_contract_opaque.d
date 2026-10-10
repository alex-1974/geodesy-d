// External consumer qualification: opaque DMD -X function types.
// This module intentionally lives outside the geodesy package.
// Compile independently using: dmd -o- -Isource tools/research/fixtures/external_contract_opaque.d
//                            ldc2 -o- -Isource tools/research/fixtures/external_contract_opaque.d
module external_contract_opaque;

import geodesy;

static assert(is(typeof(GeodesicIntersectionEnumeration.init.isValid) == bool));
static assert(is(typeof(GeodesicIntersectionEnumeration.init.minimumFoundCapacity) == size_t));
static assert(is(typeof(GeodesicIntersectionEnumeration.init.requiredTiles) == size_t));
static assert(is(typeof(GeodesicIntersectionEnumeration.init.status) ==
                 GeodesicIntersectionEnumerationStatus));
static assert(is(typeof(GeodesicIntersectionEnumeration.init.total) == size_t));
static assert(is(typeof(GeodesicIntersectionEnumeration.init.truncated) == bool));
static assert(is(typeof(GeodesicIntersectionEnumeration.init.written) == size_t));

static assert(is(typeof(UtmZone.init.centralMeridianDegrees) == int));
static assert(is(typeof(UtmZone.init.isValid) == bool));
static assert(is(typeof(UtmZone.init.number) == uint));
static assert(is(typeof(UtmZone.fromNumber(33u)) == UtmZone));
static assert(is(typeof(UtmZone.tryFromNumber(33u, UtmZone.init)) == bool) == false);
// Positive checked-factory call below uses an lvalue for the out parameter.

@safe pure nothrow @nogc
void inspectReadOnlyProperties()
{
    GeodesicIntersectionEnumeration e;
    bool valid = e.isValid;
    size_t capacity = e.minimumFoundCapacity;
    size_t tiles = e.requiredTiles;
    GeodesicIntersectionEnumerationStatus status = e.status;
    size_t total = e.total;
    bool truncated = e.truncated;
    size_t written = e.written;

    UtmZone zone;
    bool zoneValid = zone.isValid;
    uint number = zone.number;
    int meridian = zone.centralMeridianDegrees;
}

@safe pure nothrow @nogc
void inspectCheckedFactory()
{
    UtmZone zone;
    bool ok = UtmZone.tryFromNumber(33u, zone);
}

@safe
void inspectThrowingFactory()
{
    UtmZone zone = UtmZone.fromNumber(33u);
}
