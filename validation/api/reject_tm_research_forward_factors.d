module geodesy.projection.reject_tm_research_forward_factors;

import geodesy;

void main()
{
    TransverseMercator!double tm;
    GeographicCoordinate!double source;

    double convergenceRadians;
    double pointScale;

    tm.researchTryForwardFactors(
        source,
        convergenceRadians,
        pointScale);
}
