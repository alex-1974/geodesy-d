/** Error types used by checked geodesy-d value construction and operations. */
module geodesy.errors;

/** Thrown by convenience APIs when an input is invalid or a checked operation cannot produce a valid result. */
final class GeodesyValueException : Exception
{
    /** Construct an exception with source location metadata. */
    @safe this(string message, string file = __FILE__, size_t line = __LINE__)
    {
        super(message, file, line);
    }
}
