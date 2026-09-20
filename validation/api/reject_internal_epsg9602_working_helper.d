module reject_internal_epsg9602_working_helper;

import geodesy.conversion : Epsg9602WorkingScalar;

alias LeakedWorkingScalar =
    Epsg9602WorkingScalar!float;
