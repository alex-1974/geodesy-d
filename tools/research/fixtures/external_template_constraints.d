// External compile-time tests of public scalar and overload constraints.
// Compile with both dmd and ldc2, using -o- -Isource.
module external_geodesy_template_constraints;
import geodesy;

static assert(isGeodesyScalar!float);
static assert(isGeodesyScalar!double);
static assert(isGeodesyScalar!real);
static assert(!isGeodesyScalar!int);
static assert(!isGeodesyScalar!uint);
static assert(!isGeodesyScalar!string);
static assert(!isGeodesyScalar!(const(double)));

static assert(__traits(compiles, Geodesic!float));
static assert(__traits(compiles, Geodesic!double));
static assert(__traits(compiles, Geodesic!real));
static assert(!__traits(compiles, Geodesic!int));
static assert(!__traits(compiles, Geodesic!string));
static assert(!__traits(compiles, Geodesic!(const(double))));

static assert(__traits(compiles, GeodesicLine!float));
static assert(__traits(compiles, GeodesicLine!double));
static assert(__traits(compiles, GeodesicLine!real));
static assert(!__traits(compiles, GeodesicLine!int));
static assert(!__traits(compiles, GeodesicLine!string));
static assert(!__traits(compiles, GeodesicLine!(const(double))));

// Probe the six intersection function-template families by explicitly
// instantiating the function template; do not use bare template names.
static assert(__traits(compiles, allGeodesicIntersections!double));
static assert(__traits(compiles, closestGeodesicIntersection!double));
static assert(__traits(compiles, nextGeodesicIntersection!double));
static assert(__traits(compiles, tryAllGeodesicIntersections!double));
static assert(__traits(compiles, tryClosestGeodesicIntersection!double));
static assert(__traits(compiles, tryNextGeodesicIntersection!double));

static assert(!__traits(compiles, allGeodesicIntersections!int));
static assert(!__traits(compiles, closestGeodesicIntersection!int));
static assert(!__traits(compiles, nextGeodesicIntersection!int));
static assert(!__traits(compiles, tryAllGeodesicIntersections!int));
static assert(!__traits(compiles, tryClosestGeodesicIntersection!int));
static assert(!__traits(compiles, tryNextGeodesicIntersection!int));
