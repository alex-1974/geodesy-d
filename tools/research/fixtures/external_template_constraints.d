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

// The six free intersection function-template families need concrete
// valid argument lists to disambiguate their overloads. A bare
// `function!double` in __traits(compiles) is NOT a reliable positive
// control for overloaded function symbols; do not claim that it is.
