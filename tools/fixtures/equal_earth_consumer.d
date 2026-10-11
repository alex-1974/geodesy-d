// Standalone package-root-only Equal Earth consumer: never import internals.
module equal_earth_consumer;
import geodesy;
import std.math : fabs;
import std.meta : AliasSeq;

void main() @safe
{
    static foreach (T; AliasSeq!(float, double, real))
    {{
        const ellipsoid = wgs84!T();
        EqualEarth!T projection;
        assert(EqualEarth!T.tryFromParameters(ellipsoid,
            Longitude!T.fromDegrees(cast(T) 0),
            cast(T) 0, cast(T) 0, projection));
        const source = GeographicCoordinate!T.fromComponents(
            Latitude!T.fromDegrees(cast(T) 30),
            Longitude!T.fromDegrees(cast(T) 45));
        ProjectedCoordinate!T mapped;
        assert(projection.tryForward(source, mapped));
        GeographicCoordinate!T recovered;
        assert(projection.tryReverse(mapped, recovered));
        const T tolerance = is(T == float) ? cast(T) 0.001 : cast(T) 1e-7;
        assert(fabs(recovered.latitude.degrees - cast(T) 30) < tolerance);
        assert(fabs(recovered.longitude.degrees - cast(T) 45) < tolerance);
    }}
}
