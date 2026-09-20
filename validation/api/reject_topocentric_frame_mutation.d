module reject_topocentric_frame_mutation;

import geodesy;

void main()
{
    auto frame =
        TopocentricFrame!double.init;

    frame.ellipsoid =
        Ellipsoid!double.sphere(6_371_000.0);
}
