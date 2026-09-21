module reject_conformal_projection_factors_factory;

import geodesy;

void main()
{
    const factors =
        ConformalProjectionFactors!double.fromComponents(
            Angle!double.init,
            1.0);

    cast(void) factors;
}
