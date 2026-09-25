module reject_pseudo_mercator_webmercator_alias;

import geodesy;

/*
 * PM-F deliberately admits only PseudoMercator. A WebMercator alias would
 * conflate the mathematical method with CRS/tile policy.
 */
WebMercator!double value;
