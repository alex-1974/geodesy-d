module pseudo_mercator_differential_driver;

import std.conv : to;
import std.math : nextDown, nextUp;
import std.stdio : readln, writefln;
import std.string : split, strip;

import geodesy.angle : Latitude, Longitude;
import geodesy.ellipsoid : Ellipsoid;
import geodesy.geographic : GeographicCoordinate;
import geodesy.projected : ProjectedCoordinate;
import geodesy.projection.pseudo_mercator : PseudoMercator;


private bool prepare(T)(
    const string[] fields,
    out PseudoMercator!T projection,
    out T semiMajorAxis,
    out Longitude!T longitude0,
    out T falseEasting,
    out T falseNorthing)
{
    semiMajorAxis = fields[3].to!T;
    falseEasting = fields[5].to!T;
    falseNorthing = fields[6].to!T;

    if (!Longitude!T.tryFromDegrees(
            fields[4].to!T,
            longitude0))
        return false;

    Ellipsoid!T ellipsoid;

    if (!Ellipsoid!T.trySphere(
            semiMajorAxis,
            ellipsoid))
        return false;

    return PseudoMercator!T.tryFromParameters(
        ellipsoid,
        longitude0,
        falseEasting,
        falseNorthing,
        projection);
}


private bool acceptedEasting(T)(
    const PseudoMercator!T projection,
    const T easting,
    const T northing)
{
    ProjectedCoordinate!T projected;

    if (!ProjectedCoordinate!T.tryFromComponents(
            easting,
            northing,
            projected))
        return false;

    GeographicCoordinate!T geographic;

    return projection.tryReverse(
        projected,
        geographic);
}


private bool representedEastingBounds(T)(
    const PseudoMercator!T projection,
    const T semiMajorAxis,
    const T falseEasting,
    const T falseNorthing,
    out T westEasting,
    out T eastEasting)
{
    const T span =
        cast(T) 4
        * semiMajorAxis;

    T lower =
        falseEasting
        - span;

    T upper =
        falseEasting;

    if (acceptedEasting!T(
            projection,
            lower,
            falseNorthing)
        || !acceptedEasting!T(
            projection,
            upper,
            falseNorthing))
        return false;

    while (nextUp(lower) != upper)
    {
        T middle =
            lower
            + (upper - lower)
                / cast(T) 2;

        if (!(middle > lower))
            middle = nextUp(lower);

        if (!(middle < upper))
            middle = nextDown(upper);

        if (acceptedEasting!T(
                projection,
                middle,
                falseNorthing))
            upper = middle;
        else
            lower = middle;
    }

    westEasting =
        upper;

    lower =
        falseEasting;

    upper =
        falseEasting
        + span;

    if (!acceptedEasting!T(
            projection,
            lower,
            falseNorthing)
        || acceptedEasting!T(
            projection,
            upper,
            falseNorthing))
        return false;

    while (nextUp(lower) != upper)
    {
        T middle =
            lower
            + (upper - lower)
                / cast(T) 2;

        if (!(middle > lower))
            middle = nextUp(lower);

        if (!(middle < upper))
            middle = nextDown(upper);

        if (acceptedEasting!T(
                projection,
                middle,
                falseNorthing))
            lower = middle;
        else
            upper = middle;
    }

    eastEasting =
        lower;

    return true;
}


private void differentialBoundary(T)(
    const string[] fields,
    const string scalarName)
{
    if (fields.length != 7)
    {
        writefln(
            "ERROR\t%s\tB\t%s\tfields=%u",
            fields.length >= 2 ? fields[1] : "?",
            scalarName,
            fields.length);
        return;
    }

    PseudoMercator!T projection;
    T semiMajorAxis;
    Longitude!T longitude0;
    T falseEasting;
    T falseNorthing;

    if (!prepare!T(
            fields,
            projection,
            semiMajorAxis,
            longitude0,
            falseEasting,
            falseNorthing))
    {
        writefln(
            "REJECT\t%s\tB\t%s\tprepare",
            fields[1],
            scalarName);
        return;
    }

    Latitude!T northLatitude;
    Latitude!T southLatitude;

    if (!Latitude!T.tryFromDegrees(
            cast(T) 88,
            northLatitude)
        || !Latitude!T.tryFromDegrees(
            cast(T) -88,
            southLatitude))
    {
        writefln(
            "REJECT\t%s\tB\t%s\tlatitude",
            fields[1],
            scalarName);
        return;
    }

    const northSource =
        GeographicCoordinate!T.fromComponents(
            northLatitude,
            longitude0);

    const southSource =
        GeographicCoordinate!T.fromComponents(
            southLatitude,
            longitude0);

    ProjectedCoordinate!T northProjected;
    ProjectedCoordinate!T southProjected;

    if (!projection.tryForward(
            northSource,
            northProjected)
        || !projection.tryForward(
            southSource,
            southProjected))
    {
        writefln(
            "REJECT\t%s\tB\t%s\tlatitude-boundary",
            fields[1],
            scalarName);
        return;
    }

    T westEasting;
    T eastEasting;

    if (!representedEastingBounds!T(
            projection,
            semiMajorAxis,
            falseEasting,
            falseNorthing,
            westEasting,
            eastEasting))
    {
        writefln(
            "REJECT\t%s\tB\t%s\teasting-boundary",
            fields[1],
            scalarName);
        return;
    }

    ProjectedCoordinate!T eastEndpoint;

    if (!ProjectedCoordinate!T.tryFromComponents(
            eastEasting,
            falseNorthing,
            eastEndpoint))
    {
        writefln(
            "REJECT\t%s\tB\t%s\teast-input",
            fields[1],
            scalarName);
        return;
    }

    GeographicCoordinate!T eastGeographic;

    if (!projection.tryReverse(
            eastEndpoint,
            eastGeographic))
    {
        writefln(
            "REJECT\t%s\tB\t%s\teast-reverse",
            fields[1],
            scalarName);
        return;
    }

    writefln(
        "BOK\t%s\t%s\t"
        ~ "a=%.40g\t"
        ~ "lon0_rad=%.40g\t"
        ~ "fe=%.40g\t"
        ~ "fn=%.40g\t"
        ~ "southN=%.40g\t"
        ~ "northN=%.40g\t"
        ~ "westE=%.40g\t"
        ~ "eastE=%.40g\t"
        ~ "eastLon=%.40g",
        fields[1],
        scalarName,
        semiMajorAxis,
        longitude0.radians,
        falseEasting,
        falseNorthing,
        southProjected.northing,
        northProjected.northing,
        westEasting,
        eastEasting,
        eastGeographic.longitude.radians);
}


private void differentialForward(T)(
    const string[] fields,
    const string scalarName)
{
    if (fields.length != 9)
    {
        writefln(
            "ERROR\t%s\tF\t%s\tfields=%u",
            fields.length >= 2 ? fields[1] : "?",
            scalarName,
            fields.length);
        return;
    }

    PseudoMercator!T projection;
    T semiMajorAxis;
    Longitude!T longitude0;
    T falseEasting;
    T falseNorthing;

    if (!prepare!T(
            fields,
            projection,
            semiMajorAxis,
            longitude0,
            falseEasting,
            falseNorthing))
    {
        writefln(
            "REJECT\t%s\tF\t%s\tprepare",
            fields[1],
            scalarName);
        return;
    }

    Latitude!T latitude;
    Longitude!T longitude;

    if (!Latitude!T.tryFromDegrees(
            fields[7].to!T,
            latitude)
        || !Longitude!T.tryFromDegrees(
            fields[8].to!T,
            longitude))
    {
        writefln(
            "REJECT\t%s\tF\t%s\tinput",
            fields[1],
            scalarName);
        return;
    }

    const source =
        GeographicCoordinate!T.fromComponents(
            latitude,
            longitude);

    ProjectedCoordinate!T projected;

    if (!projection.tryForward(
            source,
            projected))
    {
        writefln(
            "REJECT\t%s\tF\t%s\tdomain",
            fields[1],
            scalarName);
        return;
    }

    writefln(
        "FOK\t%s\t%s\t"
        ~ "a=%.40g\t"
        ~ "lon0_rad=%.40g\t"
        ~ "fe=%.40g\t"
        ~ "fn=%.40g\t"
        ~ "lat_rad=%.40g\t"
        ~ "lon_rad=%.40g\t"
        ~ "e=%.40g\t"
        ~ "n=%.40g",
        fields[1],
        scalarName,
        semiMajorAxis,
        longitude0.radians,
        falseEasting,
        falseNorthing,
        latitude.radians,
        longitude.radians,
        projected.easting,
        projected.northing);
}


private void differentialReverse(T)(
    const string[] fields,
    const string scalarName)
{
    if (fields.length != 9)
    {
        writefln(
            "ERROR\t%s\tR\t%s\tfields=%u",
            fields.length >= 2 ? fields[1] : "?",
            scalarName,
            fields.length);
        return;
    }

    PseudoMercator!T projection;
    T semiMajorAxis;
    Longitude!T longitude0;
    T falseEasting;
    T falseNorthing;

    if (!prepare!T(
            fields,
            projection,
            semiMajorAxis,
            longitude0,
            falseEasting,
            falseNorthing))
    {
        writefln(
            "REJECT\t%s\tR\t%s\tprepare",
            fields[1],
            scalarName);
        return;
    }

    const T easting =
        fields[7].to!T;

    const T northing =
        fields[8].to!T;

    ProjectedCoordinate!T source;

    if (!ProjectedCoordinate!T.tryFromComponents(
            easting,
            northing,
            source))
    {
        writefln(
            "REJECT\t%s\tR\t%s\tinput",
            fields[1],
            scalarName);
        return;
    }

    GeographicCoordinate!T geographic;

    if (!projection.tryReverse(
            source,
            geographic))
    {
        writefln(
            "REJECT\t%s\tR\t%s\tdomain",
            fields[1],
            scalarName);
        return;
    }

    writefln(
        "ROK\t%s\t%s\t"
        ~ "a=%.40g\t"
        ~ "lon0_rad=%.40g\t"
        ~ "fe=%.40g\t"
        ~ "fn=%.40g\t"
        ~ "e=%.40g\t"
        ~ "n=%.40g\t"
        ~ "lat_rad=%.40g\t"
        ~ "lon_rad=%.40g",
        fields[1],
        scalarName,
        semiMajorAxis,
        longitude0.radians,
        falseEasting,
        falseNorthing,
        easting,
        northing,
        geographic.latitude.radians,
        geographic.longitude.radians);
}


private void dispatch(T)(
    const string[] fields,
    const string scalarName)
{
    if (fields[0] == "B")
        differentialBoundary!T(fields, scalarName);
    else if (fields[0] == "F")
        differentialForward!T(fields, scalarName);
    else if (fields[0] == "R")
        differentialReverse!T(fields, scalarName);
    else
        writefln(
            "ERROR\t%s\t%s\t%s\tunknown-command",
            fields.length >= 2 ? fields[1] : "?",
            fields[0],
            scalarName);
}


void main()
{
    string line;

    while ((line = readln()) !is null)
    {
        const stripped =
            line.strip;

        if (stripped.length == 0
            || stripped[0] == '#')
            continue;

        const fields =
            stripped.split;

        if (fields.length < 3)
        {
            writefln(
                "ERROR\t?\t?\t?\tfields=%u",
                fields.length);
            continue;
        }

        const scalarName =
            fields[2];

        if (scalarName == "float")
            dispatch!float(fields, scalarName);
        else if (scalarName == "double")
            dispatch!double(fields, scalarName);
        else if (scalarName == "real")
            dispatch!real(fields, scalarName);
        else
            writefln(
                "ERROR\t%s\t%s\t%s\tunknown-scalar",
                fields[1],
                fields[0],
                scalarName);
    }
}
