module reject_translation_mutation;
import geodesy;
void mutate()
{
    GeocentricTranslation!double translation;
    translation.deltaX = double.nan;
}
