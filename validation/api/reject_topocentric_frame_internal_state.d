module reject_topocentric_frame_internal_state;

import geodesy;

void main()
{
    auto frame =
        TopocentricFrame!double.init;

    frame._originX = 1.0;
}
