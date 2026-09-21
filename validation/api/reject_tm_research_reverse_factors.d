module geodesy.projection.reject_tm_research_reverse_factors;

import geodesy;

void main()
{
    TransverseMercator!double tm;
    ProjectedCoordinate!double source;

    double convergenceRadians;
    double pointScale;

    tm.researchTryReverseFactors(
        source,
        convergenceRadians,
        pointScale);
}
