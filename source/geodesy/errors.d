/** Error types used by geodesy-d value construction. */
module geodesy.errors;

/** Thrown by convenience constructors when a supplied geodetic value is invalid. */
final class GeodesyValueException : Exception
{
    this(string message, string file = __FILE__, size_t line = __LINE__)
    {
        super(message, file, line);
    }
}
